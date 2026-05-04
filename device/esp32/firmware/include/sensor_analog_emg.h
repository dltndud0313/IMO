// SZH-GJD001 계열 단일 아날로그 EMG 센서를 ESP32 파이프라인에 연결하기 위한 어댑터 선언.
#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <functional>

#include "sensor_source.h"

namespace mvp {

struct AnalogEmgSensorConfig {
    // 판매처 예제의 500Hz 전제를 기본값으로 둔다.
    uint32_t source_sample_rate_hz {500};
    // 파이프라인 한 tick 안에서 몇 개의 ADC 샘플을 묶어 읽을지 결정한다.
    std::size_t samples_per_frame {10};
    // ESP32 ADC를 12bit 기준으로 가정한 기본 full-scale 값이다.
    float adc_full_scale {4095.0F};
    // EMG 모듈 아날로그 출력을 읽는 ESP32 ADC GPIO들.
    std::array<int, kEmgChannelCount> emg_adc_gpios {4, 5, 6, 7};
    // false인 채널은 읽지 않고 0으로 고정한다(미연결 채널 노이즈 방지).
    std::array<bool, kEmgChannelCount> emg_channel_enabled {true, false, false, false};
    // MPU-6050 I2C 주소와 버스 설정. IMU별로 다른 I2C 버스를 줄 수 있다.
    std::array<int, kImuSensorCount> imu_i2c_ports {0, 0, 1};
    std::array<int, kImuSensorCount> imu_sda_gpios {8, 8, 10};
    std::array<int, kImuSensorCount> imu_scl_gpios {9, 9, 11};
    uint32_t imu_i2c_clock_hz {100000};
    int imu_i2c_transaction_timeout_ms {20};
    std::array<uint8_t, kImuSensorCount> imu_addresses {0x68, 0x69, 0x6A};
    std::array<bool, kImuSensorCount> imu_sensor_enabled {true, true, false};
};

class ButterworthBandPassFilter {
  public:
    float process(float input);
    void reset();

  private:
    float z1_1_ {0.0F};
    float z1_2_ {0.0F};
    float z2_1_ {0.0F};
    float z2_2_ {0.0F};
    float z3_1_ {0.0F};
    float z3_2_ {0.0F};
    float z4_1_ {0.0F};
    float z4_2_ {0.0F};
};

class AnalogEmgSensorSource : public ISensorSource {
  public:
    // 실제 하드웨어 전에는 테스트 코드가 임의 raw ADC 값을 주입할 수 있게 콜백을 열어둔다.
    using RawSampleReader = std::function<float(void)>;

    explicit AnalogEmgSensorSource(
        RawSampleReader raw_reader = {},
        AnalogEmgSensorConfig config = {}
    );

    SensorFrame read_frame(uint32_t timestamp_ms) override;
    std::size_t imu_ready_count() const override;
    std::size_t imu_expected_count() const override;
    float read_debug_raw_emg_sample();
    void reset();

  private:
    // 실제 장착 후에는 이 함수 내부가 adc_oneshot_read 같은 ESP-IDF 호출로 바뀐다.
    float read_raw_sample(std::size_t channel_index);
    ImuSample read_imu_sample(std::size_t imu_index);
    bool ensure_imu_ready();
    bool ensure_emg_ready();

    RawSampleReader raw_reader_ {};
    AnalogEmgSensorConfig config_ {};
    std::array<float, kEmgChannelCount> emg_rest_baseline_raw_ {};
    std::array<float, kEmgChannelCount> emg_rest_noise_m2_ {};
    std::array<float, kEmgChannelCount> emg_rest_noise_floor_ {};
    std::array<std::size_t, kEmgChannelCount> emg_rest_baseline_count_ {};
    std::array<bool, kEmgChannelCount> emg_rest_baseline_ready_ {};
    std::array<std::size_t, kEmgChannelCount> emg_detach_frame_count_ {};
    std::array<std::size_t, kEmgChannelCount> emg_reattach_frame_count_ {};
    std::array<bool, kEmgChannelCount> emg_detached_ {};
    std::array<bool, kEmgChannelCount> emg_channel_ready_ {};
    bool emg_ready_ {false};
    bool emg_init_failed_ {false};
    std::size_t imu_ready_count_ {0};
    std::array<bool, kImuSensorCount> imu_channel_ready_ {};
    bool imu_ready_ {false};
    bool imu_init_failed_ {false};
    bool imu_read_error_logged_ {false};
};

}  // namespace mvp
