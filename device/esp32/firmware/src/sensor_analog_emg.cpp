// SZH-GJD001 예제의 500Hz band-pass 아이디어를 현재 파이프라인에 맞게 옮긴 단일채널 EMG 어댑터 구현.
#include "sensor_analog_emg.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <utility>

#if __has_include("driver/i2c_master.h")
#include "driver/i2c_master.h"
#include "esp_log.h"
#endif

namespace mvp {
namespace {

#if __has_include("driver/i2c_master.h")
constexpr char kLogTag[] = "sensor_analog_emg";
constexpr uint8_t kMpu6050RegisterPwrMgmt1 = 0x6B;
constexpr uint8_t kMpu6050RegisterAccelXoutH = 0x3B;
constexpr uint8_t kMpu6050WakeValue = 0x00;
constexpr float kMpu6050AccelScale = 16384.0F;
constexpr float kMpu6050GyroScale = 131.0F;

i2c_master_bus_handle_t g_imu_bus_handle = nullptr;
i2c_master_dev_handle_t g_imu_device_handle = nullptr;

esp_err_t write_register(i2c_master_dev_handle_t device, uint8_t reg, uint8_t value) {
    const uint8_t payload[2] = {reg, value};
    return i2c_master_transmit(device, payload, sizeof(payload), -1);
}

esp_err_t read_registers(i2c_master_dev_handle_t device, uint8_t start_reg, uint8_t* buffer, std::size_t size) {
    return i2c_master_transmit_receive(device, &start_reg, 1, buffer, size, -1);
}

int16_t join_i16(uint8_t msb, uint8_t lsb) {
    return static_cast<int16_t>((static_cast<uint16_t>(msb) << 8U) | static_cast<uint16_t>(lsb));
}
#endif

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
    // IIR biquad 한 섹션의 내부 상태를 갱신한다. 판매처 예제의 z1/z2 구조를 그대로 옮긴 것이다.
    const float x = input - (a1 * (*z1)) - (a2 * (*z2));
    const float output = (b0 * x) + (b1 * (*z1)) + (b2 * (*z2));
    *z2 = *z1;
    *z1 = x;
    return output;
}

}  // namespace

float ButterworthBandPassFilter::process(float input) {
    float output = input;
    // 판매처 제공 예제의 계수를 그대로 이어 붙여 4개 섹션 band-pass를 구성한다.
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

    // 프레임당 여러 raw 샘플을 읽어 절대값 평균으로 묶어주면 단일 ADC 샘플보다 안정적으로 들어온다.
    const std::size_t samples_to_read = std::max<std::size_t>(config_.samples_per_frame, 1U);
    float envelope_sum = 0.0F;

    for (std::size_t index = 0; index < samples_to_read; ++index) {
        const float raw_sample = read_raw_sample();
        // ADC 값을 0~1 범위로 정규화한 뒤 중심점을 0 근처로 옮겨 band-pass 입력으로 사용한다.
        const float centered = (raw_sample / config_.adc_full_scale) - 0.5F;
        const float filtered = band_pass_filter_.process(centered);
        // 정류(rectify) 후 평균을 내서 채널 활성도처럼 쓰기 쉬운 envelope를 만든다.
        envelope_sum += std::fabs(filtered);
    }

    frame.emg.channels = {
        envelope_sum / static_cast<float>(samples_to_read),
        // 현재 검토 중인 센서는 단일채널 전제로 두고 있으므로 나머지 채널은 0으로 둔다.
        0.0F,
        0.0F,
    };
    frame.imu = read_imu_sample();
    return frame;
}

void AnalogEmgSensorSource::reset() {
    band_pass_filter_.reset();
    imu_ready_ = false;
}

float AnalogEmgSensorSource::read_raw_sample() const {
    if (raw_reader_) {
        // 호스트 테스트나 샘플 주입 시에는 외부 콜백 값을 그대로 사용한다.
        return raw_reader_();
    }

    // 실제 장착 후 이 자리에 ESP-IDF adc_oneshot_read 연동을 넣으면 된다.
    return 0.0F;
}

bool AnalogEmgSensorSource::ensure_imu_ready() {
#if __has_include("driver/i2c_master.h")
    if (imu_ready_) {
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
            ESP_LOGW(kLogTag, "failed to init I2C bus");
            return false;
        }
    }

    if (g_imu_device_handle == nullptr) {
        i2c_device_config_t device_config {};
        device_config.dev_addr_length = I2C_ADDR_BIT_LEN_7;
        device_config.device_address = config_.imu_address;
        device_config.scl_speed_hz = config_.imu_i2c_clock_hz;
        device_config.scl_wait_us = 0;
        device_config.flags.disable_ack_check = 0;

        if (i2c_master_bus_add_device(g_imu_bus_handle, &device_config, &g_imu_device_handle) != ESP_OK) {
            ESP_LOGW(kLogTag, "failed to add MPU-6050 device at 0x%02x", config_.imu_address);
            return false;
        }
    }

    if (write_register(g_imu_device_handle, kMpu6050RegisterPwrMgmt1, kMpu6050WakeValue) != ESP_OK) {
        ESP_LOGW(kLogTag, "failed to wake MPU-6050");
        return false;
    }

    imu_ready_ = true;
    ESP_LOGI(
        kLogTag,
        "MPU-6050 ready on I2C port=%d sda=%d scl=%d addr=0x%02x",
        config_.imu_i2c_port,
        config_.imu_sda_gpio,
        config_.imu_scl_gpio,
        config_.imu_address
    );
    return true;
#else
    return false;
#endif
}

ImuSample AnalogEmgSensorSource::read_imu_sample() {
    ImuSample sample {};

#if __has_include("driver/i2c_master.h")
    if (!ensure_imu_ready()) {
        return sample;
    }

    uint8_t raw_bytes[14] = {};
    if (read_registers(g_imu_device_handle, kMpu6050RegisterAccelXoutH, raw_bytes, sizeof(raw_bytes)) != ESP_OK) {
        ESP_LOGW(kLogTag, "failed to read MPU-6050 frame");
        return sample;
    }

    const int16_t accel_x = join_i16(raw_bytes[0], raw_bytes[1]);
    const int16_t accel_y = join_i16(raw_bytes[2], raw_bytes[3]);
    const int16_t accel_z = join_i16(raw_bytes[4], raw_bytes[5]);
    const int16_t gyro_x = join_i16(raw_bytes[8], raw_bytes[9]);
    const int16_t gyro_y = join_i16(raw_bytes[10], raw_bytes[11]);
    const int16_t gyro_z = join_i16(raw_bytes[12], raw_bytes[13]);

    sample.accel = {
        static_cast<float>(accel_x) / kMpu6050AccelScale,
        static_cast<float>(accel_y) / kMpu6050AccelScale,
        static_cast<float>(accel_z) / kMpu6050AccelScale,
    };
    sample.gyro = {
        static_cast<float>(gyro_x) / kMpu6050GyroScale,
        static_cast<float>(gyro_y) / kMpu6050GyroScale,
        static_cast<float>(gyro_z) / kMpu6050GyroScale,
    };
#endif

    return sample;
}

}  // namespace mvp
