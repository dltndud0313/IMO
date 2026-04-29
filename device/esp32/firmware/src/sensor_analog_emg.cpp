// SZH-GJD001 계열 EMG 4채널 + MPU-6050 3개 입력을 파이프라인으로 연결하는 센서 어댑터 구현.
#include "sensor_analog_emg.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <utility>

#include "config.h"

#if __has_include("esp_adc/adc_oneshot.h")
#include "esp_adc/adc_oneshot.h"
#endif

#if __has_include("driver/i2c_master.h")
#include "driver/i2c_master.h"
#include "esp_log.h"
#endif

namespace mvp {
namespace {

#if __has_include("driver/i2c_master.h")
constexpr char kLogTag[] = "sensor_analog_emg";
constexpr uint8_t kMpu6050RegisterWhoAmI = 0x75;
constexpr uint8_t kMpu6050RegisterPwrMgmt1 = 0x6B;
constexpr uint8_t kMpu6050RegisterAccelXoutH = 0x3B;
constexpr uint8_t kMpu6050WakeValue = 0x00;
constexpr float kMpu6050AccelScale = 16384.0F;
constexpr float kMpu6050GyroScale = 131.0F;

adc_oneshot_unit_handle_t g_emg_adc_handle = nullptr;
i2c_master_bus_handle_t g_imu_bus_handle = nullptr;
std::array<i2c_master_dev_handle_t, kImuSensorCount> g_imu_device_handles {};

#define IMU_LOGE(...)            \
    do {                         \
        if (kEnableImuInitTextLog) { \
            ESP_LOGE(kLogTag, __VA_ARGS__); \
        }                        \
    } while (0)

#define IMU_LOGW(...)            \
    do {                         \
        if (kEnableImuInitTextLog) { \
            ESP_LOGW(kLogTag, __VA_ARGS__); \
        }                        \
    } while (0)

#define IMU_LOGI(...)            \
    do {                         \
        if (kEnableImuInitTextLog) { \
            ESP_LOGI(kLogTag, __VA_ARGS__); \
        }                        \
    } while (0)

esp_err_t write_register(i2c_master_dev_handle_t device, uint8_t reg, uint8_t value, int timeout_ms) {
    const uint8_t payload[2] = {reg, value};
    return i2c_master_transmit(device, payload, sizeof(payload), timeout_ms);
}

esp_err_t read_registers(
    i2c_master_dev_handle_t device,
    uint8_t start_reg,
    uint8_t* buffer,
    std::size_t size,
    int timeout_ms
) {
    return i2c_master_transmit_receive(device, &start_reg, 1, buffer, size, timeout_ms);
}

esp_err_t read_register_byte(i2c_master_dev_handle_t device, uint8_t reg, uint8_t* value, int timeout_ms) {
    return read_registers(device, reg, value, 1, timeout_ms);
}

int16_t join_i16(uint8_t msb, uint8_t lsb) {
    return static_cast<int16_t>((static_cast<uint16_t>(msb) << 8U) | static_cast<uint16_t>(lsb));
}

bool is_supported_mpu_who_am_i(uint8_t value) {
    switch (value) {
        case 0x68:  // MPU-6050
        case 0x70:  // MPU-6500 계열
        case 0x71:  // MPU-9250 계열
        case 0x72:  // 호환 모듈에서 확인된 MPU register-map 계열
            return true;
        default:
            return false;
    }
}

bool gpio_to_adc_channel(int gpio, adc_channel_t* channel) {
    switch (gpio) {
        case 1: *channel = ADC_CHANNEL_0; return true;
        case 2: *channel = ADC_CHANNEL_1; return true;
        case 3: *channel = ADC_CHANNEL_2; return true;
        case 4: *channel = ADC_CHANNEL_3; return true;
        case 5: *channel = ADC_CHANNEL_4; return true;
        case 6: *channel = ADC_CHANNEL_5; return true;
        case 7: *channel = ADC_CHANNEL_6; return true;
        case 8: *channel = ADC_CHANNEL_7; return true;
        case 9: *channel = ADC_CHANNEL_8; return true;
        case 10: *channel = ADC_CHANNEL_9; return true;
        default: return false;
    }
}
#endif

bool is_detached_raw_sample(float raw_sample, float adc_full_scale) {
    return raw_sample <= (adc_full_scale * kAnalogEmgDetachRawLowRatio) ||
        raw_sample >= (adc_full_scale * kAnalogEmgDetachRawHighRatio);
}

float process_section(
    float input,
    float* z1,
    float* z2,
    float a1,
    float a2,
    float b0,
    float b1,
    float b2
) {
    const float x = input - (a1 * (*z1)) - (a2 * (*z2));
    const float output = (b0 * x) + (b1 * (*z1)) + (b2 * (*z2));
    *z2 = *z1;
    *z1 = x;
    return output;
}

}  // namespace

float ButterworthBandPassFilter::process(float input) {
    float output = input;
    output = process_section(output, &z1_1_, &z1_2_, -0.73945727F, 0.59923508F, 0.00223489F, 0.00446978F, 0.00223489F);
    output = process_section(output, &z2_1_, &z2_2_, -1.03789224F, 0.64082390F, 1.00000000F, 2.00000000F, 1.00000000F);
    output = process_section(output, &z3_1_, &z3_2_, -0.59186255F, 0.80647974F, 1.00000000F, -2.00000000F, 1.00000000F);
    output = process_section(output, &z4_1_, &z4_2_, -1.33318587F, 0.85392964F, 1.00000000F, -2.00000000F, 1.00000000F);
    return output;
}

void ButterworthBandPassFilter::reset() {
    z1_1_ = 0.0F;
    z1_2_ = 0.0F;
    z2_1_ = 0.0F;
    z2_2_ = 0.0F;
    z3_1_ = 0.0F;
    z3_2_ = 0.0F;
    z4_1_ = 0.0F;
    z4_2_ = 0.0F;
}

AnalogEmgSensorSource::AnalogEmgSensorSource(RawSampleReader raw_reader, AnalogEmgSensorConfig config)
    : raw_reader_(std::move(raw_reader)), config_(config) {}

SensorFrame AnalogEmgSensorSource::read_frame(uint32_t timestamp_ms) {
    SensorFrame frame;
    frame.emg.timestamp_ms = timestamp_ms;

    const std::size_t samples_to_read = std::max<std::size_t>(config_.samples_per_frame, 1U);
    const float adc_full_scale = std::max(config_.adc_full_scale, 1.0F);
    for (std::size_t channel = 0; channel < kEmgChannelCount; ++channel) {
        if (!config_.emg_channel_enabled[channel]) {
            frame.emg.channels[channel] = 0.0F;
            continue;
        }

        float sum_squares = 0.0F;
        float raw_magnitude_sum_squares = 0.0F;
        std::size_t valid_sample_count = 0;
        std::size_t magnitude_sample_count = 0;
        std::size_t detached_sample_count = 0;
        for (std::size_t index = 0; index < samples_to_read; ++index) {
            const float raw_sample = std::clamp(read_raw_sample(channel), 0.0F, adc_full_scale);
            if (is_detached_raw_sample(raw_sample, adc_full_scale)) {
                ++detached_sample_count;
                continue;
            }

            if (!emg_rest_baseline_ready_[channel]) {
                ++emg_rest_baseline_count_[channel];
                const float delta = raw_sample - emg_rest_baseline_raw_[channel];
                emg_rest_baseline_raw_[channel] +=
                    delta / static_cast<float>(emg_rest_baseline_count_[channel]);
                const float delta_after_mean = raw_sample - emg_rest_baseline_raw_[channel];
                emg_rest_noise_m2_[channel] += delta * delta_after_mean;
                if (emg_rest_baseline_count_[channel] >= kAnalogEmgRestBaselineSamples) {
                    const float variance = emg_rest_baseline_count_[channel] > 1U
                        ? emg_rest_noise_m2_[channel] /
                            static_cast<float>(emg_rest_baseline_count_[channel] - 1U)
                        : 0.0F;
                    emg_rest_noise_floor_[channel] = std::sqrt(std::max(variance, 0.0F)) / adc_full_scale;
                    emg_rest_baseline_ready_[channel] = true;
                }
                continue;
            }

            const float raw_magnitude =
                std::fabs(raw_sample - emg_rest_baseline_raw_[channel]) / adc_full_scale;
            raw_magnitude_sum_squares += raw_magnitude * raw_magnitude;
            ++magnitude_sample_count;

            float magnitude = raw_magnitude;
            const float noise_floor = std::max(
                kAnalogEmgFrameNoiseFloor,
                emg_rest_noise_floor_[channel] * kAnalogEmgRestNoiseFloorMultiplier
            );
            if (magnitude <= noise_floor) {
                magnitude = 0.0F;
            }
            sum_squares += magnitude * magnitude;
            ++valid_sample_count;
        }

        const float frame_raw_magnitude = magnitude_sample_count == 0
            ? 0.0F
            : std::sqrt(raw_magnitude_sum_squares / static_cast<float>(magnitude_sample_count));
        const bool frame_rail_detached =
            detached_sample_count >= std::max<std::size_t>(1U, samples_to_read / 2U);
        const bool frame_magnitude_detached =
            emg_rest_baseline_ready_[channel] &&
            frame_raw_magnitude >= kAnalogEmgDetachedMagnitudeThreshold;
        const bool frame_detached = frame_rail_detached || frame_magnitude_detached;

        if (frame_detached) {
            emg_detach_frame_count_[channel] = std::min(
                emg_detach_frame_count_[channel] + 1U,
                kAnalogEmgDetachConsecutiveFrames
            );
            emg_reattach_frame_count_[channel] = 0U;
            if (emg_detached_[channel] ||
                emg_detach_frame_count_[channel] >= kAnalogEmgDetachConsecutiveFrames) {
                emg_detached_[channel] = true;
                frame.emg.channels[channel] = kAnalogEmgDetachFrameValue;
                continue;
            }
        } else {
            emg_detach_frame_count_[channel] = 0U;
            if (emg_detached_[channel]) {
                if (frame_raw_magnitude <= kAnalogEmgReattachMagnitudeThreshold) {
                    emg_reattach_frame_count_[channel] = std::min(
                        emg_reattach_frame_count_[channel] + 1U,
                        kAnalogEmgReattachConsecutiveFrames
                    );
                } else {
                    emg_reattach_frame_count_[channel] = 0U;
                }
                if (emg_reattach_frame_count_[channel] < kAnalogEmgReattachConsecutiveFrames) {
                    frame.emg.channels[channel] = kAnalogEmgDetachFrameValue;
                    continue;
                }
                emg_rest_baseline_raw_[channel] = 0.0F;
                emg_rest_noise_m2_[channel] = 0.0F;
                emg_rest_noise_floor_[channel] = 0.0F;
                emg_rest_baseline_count_[channel] = 0U;
                emg_rest_baseline_ready_[channel] = false;
                emg_reattach_frame_count_[channel] = 0U;
                emg_detached_[channel] = false;
                frame.emg.channels[channel] = 0.0F;
                continue;
            }
        }

        frame.emg.channels[channel] = valid_sample_count == 0
            ? 0.0F
            : std::sqrt(sum_squares / static_cast<float>(valid_sample_count));
    }

    for (std::size_t imu_index = 0; imu_index < kImuSensorCount; ++imu_index) {
        if (!config_.imu_sensor_enabled[imu_index]) {
            frame.imus[imu_index] = {};
            continue;
        }
        frame.imus[imu_index] = read_imu_sample(imu_index);
    }

    return frame;
}

std::size_t AnalogEmgSensorSource::imu_ready_count() const {
    return imu_ready_count_;
}

std::size_t AnalogEmgSensorSource::imu_expected_count() const {
    return static_cast<std::size_t>(
        std::count(config_.imu_sensor_enabled.begin(), config_.imu_sensor_enabled.end(), true)
    );
}

float AnalogEmgSensorSource::read_debug_raw_emg_sample() {
    return read_raw_sample(0);
}

void AnalogEmgSensorSource::reset() {
    emg_rest_baseline_raw_.fill(0.0F);
    emg_rest_noise_m2_.fill(0.0F);
    emg_rest_noise_floor_.fill(0.0F);
    emg_rest_baseline_count_.fill(0U);
    emg_rest_baseline_ready_.fill(false);
    emg_detach_frame_count_.fill(0U);
    emg_reattach_frame_count_.fill(0U);
    emg_detached_.fill(false);
    emg_channel_ready_.fill(false);
    emg_ready_ = false;
    emg_init_failed_ = false;
    imu_ready_count_ = 0;
    imu_channel_ready_.fill(false);
    imu_ready_ = false;
    imu_init_failed_ = false;
    imu_read_error_logged_ = false;
}

float AnalogEmgSensorSource::read_raw_sample(std::size_t channel_index) {
    if (channel_index >= kEmgChannelCount) {
        return 0.0F;
    }
    if (!config_.emg_channel_enabled[channel_index]) {
        return 0.0F;
    }

    if (raw_reader_) {
        return raw_reader_();
    }

#if __has_include("esp_adc/adc_oneshot.h")
    if (!ensure_emg_ready() || !emg_channel_ready_[channel_index]) {
        return 0.0F;
    }

    adc_channel_t channel = ADC_CHANNEL_0;
    if (!gpio_to_adc_channel(config_.emg_adc_gpios[channel_index], &channel)) {
        return 0.0F;
    }

    int raw_value = 0;
    if (adc_oneshot_read(g_emg_adc_handle, channel, &raw_value) != ESP_OK) {
        return 0.0F;
    }
    return static_cast<float>(raw_value);
#endif

    return 0.0F;
}

bool AnalogEmgSensorSource::ensure_emg_ready() {
#if __has_include("esp_adc/adc_oneshot.h")
    if (emg_ready_) {
        return true;
    }
    if (emg_init_failed_) {
        return false;
    }

    if (g_emg_adc_handle == nullptr) {
        adc_oneshot_unit_init_cfg_t init_config {};
        init_config.unit_id = ADC_UNIT_1;
        init_config.ulp_mode = ADC_ULP_MODE_DISABLE;
        if (adc_oneshot_new_unit(&init_config, &g_emg_adc_handle) != ESP_OK) {
            emg_init_failed_ = true;
            return false;
        }
    }

    adc_oneshot_chan_cfg_t channel_config {};
    channel_config.atten = ADC_ATTEN_DB_12;
    channel_config.bitwidth = ADC_BITWIDTH_12;

    std::size_t enabled_count = 0;
    std::size_t ready_count = 0;
    for (std::size_t channel_index = 0; channel_index < kEmgChannelCount; ++channel_index) {
        if (!config_.emg_channel_enabled[channel_index]) {
            emg_channel_ready_[channel_index] = false;
            continue;
        }
        ++enabled_count;

        adc_channel_t channel = ADC_CHANNEL_0;
        if (!gpio_to_adc_channel(config_.emg_adc_gpios[channel_index], &channel)) {
            continue;
        }
        if (adc_oneshot_config_channel(g_emg_adc_handle, channel, &channel_config) != ESP_OK) {
            continue;
        }
        emg_channel_ready_[channel_index] = true;
        ++ready_count;
    }

    if (enabled_count == 0 || ready_count == 0) {
        emg_init_failed_ = true;
        return false;
    }

    emg_ready_ = true;
    return true;
#else
    return false;
#endif
}

bool AnalogEmgSensorSource::ensure_imu_ready() {
#if __has_include("driver/i2c_master.h")
    const std::size_t expected_imu_count = imu_expected_count();
    if (expected_imu_count == 0) {
        imu_ready_ = false;
        imu_ready_count_ = 0;
        return false;
    }

    if (imu_ready_ && imu_ready_count_ >= expected_imu_count) {
        return true;
    }

    if (g_imu_bus_handle == nullptr) {
        i2c_master_bus_config_t bus_config {};
        bus_config.i2c_port = static_cast<i2c_port_num_t>(config_.imu_i2c_port);
        bus_config.sda_io_num = static_cast<gpio_num_t>(config_.imu_sda_gpio);
        bus_config.scl_io_num = static_cast<gpio_num_t>(config_.imu_scl_gpio);
        bus_config.clk_source = I2C_CLK_SRC_DEFAULT;
        bus_config.glitch_ignore_cnt = 7;
        bus_config.intr_priority = 0;
        bus_config.trans_queue_depth = 0;
        bus_config.flags.enable_internal_pullup = 1;
        bus_config.flags.allow_pd = 0;

        if (i2c_new_master_bus(&bus_config, &g_imu_bus_handle) != ESP_OK) {
            IMU_LOGE(
                "failed to create I2C master bus (port=%d, sda=%d, scl=%d)",
                config_.imu_i2c_port,
                config_.imu_sda_gpio,
                config_.imu_scl_gpio
            );
            return false;
        }
    }

    for (std::size_t imu_index = 0; imu_index < kImuSensorCount; ++imu_index) {
        if (!config_.imu_sensor_enabled[imu_index]) {
            imu_channel_ready_[imu_index] = false;
            continue;
        }
        if (imu_channel_ready_[imu_index]) {
            continue;
        }

        const uint8_t imu_address = config_.imu_addresses[imu_index];
        const esp_err_t probe_result = i2c_master_probe(
            g_imu_bus_handle,
            imu_address,
            config_.imu_i2c_transaction_timeout_ms
        );
        if (probe_result != ESP_OK) {
            // 디바이스가 ACK하지 않으면 이번 tick은 건너뛰고 다음 tick에서 재시도한다.
            continue;
        }

        if (g_imu_device_handles[imu_index] == nullptr) {
            i2c_device_config_t device_config {};
            device_config.dev_addr_length = I2C_ADDR_BIT_LEN_7;
            device_config.device_address = imu_address;
            device_config.scl_speed_hz = config_.imu_i2c_clock_hz;
            device_config.scl_wait_us = 0;
            device_config.flags.disable_ack_check = 0;

            if (i2c_master_bus_add_device(g_imu_bus_handle, &device_config, &g_imu_device_handles[imu_index]) != ESP_OK) {
                IMU_LOGW(
                    "imu%u addr=0x%02X add_device failed",
                    static_cast<unsigned>(imu_index + 1U),
                    imu_address
                );
                continue;
            }
        }

        uint8_t who_am_i_value = 0;
        if (
            read_register_byte(
                g_imu_device_handles[imu_index],
                kMpu6050RegisterWhoAmI,
                &who_am_i_value,
                config_.imu_i2c_transaction_timeout_ms
            ) != ESP_OK
        ) {
            IMU_LOGW(
                "imu%u addr=0x%02X WHO_AM_I read failed",
                static_cast<unsigned>(imu_index + 1U),
                imu_address
            );
            continue;
        }
        if (!is_supported_mpu_who_am_i(who_am_i_value)) {
            IMU_LOGW(
                "imu%u addr=0x%02X unexpected WHO_AM_I=0x%02X",
                static_cast<unsigned>(imu_index + 1U),
                imu_address,
                who_am_i_value
            );
            continue;
        }
        if (
            write_register(
                g_imu_device_handles[imu_index],
                kMpu6050RegisterPwrMgmt1,
                kMpu6050WakeValue,
                config_.imu_i2c_transaction_timeout_ms
            ) != ESP_OK
        ) {
            IMU_LOGW(
                "imu%u addr=0x%02X wake failed",
                static_cast<unsigned>(imu_index + 1U),
                imu_address
            );
            continue;
        }

        imu_channel_ready_[imu_index] = true;
        IMU_LOGI(
            "imu%u addr=0x%02X ready",
            static_cast<unsigned>(imu_index + 1U),
            imu_address
        );
    }

    std::size_t ready_count = 0;
    for (std::size_t imu_index = 0; imu_index < kImuSensorCount; ++imu_index) {
        if (config_.imu_sensor_enabled[imu_index] && imu_channel_ready_[imu_index]) {
            ++ready_count;
        }
    }
    imu_ready_count_ = ready_count;

    IMU_LOGI(
        "imu ready count=%u/%u",
        static_cast<unsigned>(imu_ready_count_),
        static_cast<unsigned>(expected_imu_count)
    );

    if (imu_ready_count_ == 0) {
        // 전원 인가 직후 WHO_AM_I 실패가 날 수 있어 영구 실패로 고정하지 않고 재시도한다.
        imu_ready_ = false;
        return false;
    }

    // 하나라도 준비되면 스트리밍은 계속하고, 누락 채널은 다음 tick에서 재시도한다.
    imu_ready_ = true;
    return true;
#else
    return false;
#endif
}

ImuSample AnalogEmgSensorSource::read_imu_sample(std::size_t imu_index) {
    ImuSample sample {};
    if (imu_index >= kImuSensorCount) {
        return sample;
    }
    if (!config_.imu_sensor_enabled[imu_index]) {
        return sample;
    }

#if __has_include("driver/i2c_master.h")
    if (!ensure_imu_ready() || !imu_channel_ready_[imu_index] || g_imu_device_handles[imu_index] == nullptr) {
        return sample;
    }

    uint8_t raw_bytes[14] = {};
    if (
        read_registers(
            g_imu_device_handles[imu_index],
            kMpu6050RegisterAccelXoutH,
            raw_bytes,
            sizeof(raw_bytes),
            config_.imu_i2c_transaction_timeout_ms
        ) != ESP_OK
    ) {
        if (!imu_read_error_logged_) {
            IMU_LOGW("failed to read MPU-6050 sensor frame");
            imu_read_error_logged_ = true;
        }
        return sample;
    }
    imu_read_error_logged_ = false;

    const int16_t raw_accel_x = join_i16(raw_bytes[0], raw_bytes[1]);
    const int16_t raw_accel_y = join_i16(raw_bytes[2], raw_bytes[3]);
    const int16_t raw_accel_z = join_i16(raw_bytes[4], raw_bytes[5]);
    const int16_t raw_gyro_x = join_i16(raw_bytes[8], raw_bytes[9]);
    const int16_t raw_gyro_y = join_i16(raw_bytes[10], raw_bytes[11]);
    const int16_t raw_gyro_z = join_i16(raw_bytes[12], raw_bytes[13]);

    sample.accel = {
        static_cast<float>(raw_accel_x) / kMpu6050AccelScale,
        static_cast<float>(raw_accel_y) / kMpu6050AccelScale,
        static_cast<float>(raw_accel_z) / kMpu6050AccelScale,
    };
    sample.gyro = {
        static_cast<float>(raw_gyro_x) / kMpu6050GyroScale,
        static_cast<float>(raw_gyro_y) / kMpu6050GyroScale,
        static_cast<float>(raw_gyro_z) / kMpu6050GyroScale,
    };
#endif

    return sample;
}

}  // namespace mvp
