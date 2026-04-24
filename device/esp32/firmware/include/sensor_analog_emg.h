// SZH-GJD001 계열 단일 아날로그 EMG 센서를 ESP32 파이프라인에 연결하기 위한 어댑터 선언.
#pragma once

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
    // MPU-6050 기본 I2C 주소와 버스 설정.
    int imu_i2c_port {0};
    int imu_sda_gpio {8};
    int imu_scl_gpio {9};
    uint32_t imu_i2c_clock_hz {400000};
    uint8_t imu_address {0x68};
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
    void reset();

  private:
    // 실제 장착 후에는 이 함수 내부가 adc_oneshot_read 같은 ESP-IDF 호출로 바뀐다.
    float read_raw_sample() const;
    ImuSample read_imu_sample();
    bool ensure_imu_ready();

    RawSampleReader raw_reader_ {};
    AnalogEmgSensorConfig config_ {};
    // 채널 1용 band-pass 필터 상태를 소유한다.
    ButterworthBandPassFilter band_pass_filter_ {};
    bool imu_ready_ {false};
    bool imu_init_failed_ {false};
    bool imu_read_error_logged_ {false};
};

}  // namespace mvp
