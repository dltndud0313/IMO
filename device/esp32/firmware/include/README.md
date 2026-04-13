# firmware/include/

이 폴더는 "설계도" 역할을 하는 헤더 파일 모음입니다.

- 데이터 구조: `types.h`
- 설정 상수: `config.h`
- 모듈 경계: `packet.h`, `emg_filter.h`, `imu_processor.h`, `calibration.h`, `state_machine.h`
- 확장 포인트: `sensor_source.h`, `transport_serial.h`
- 전체 오케스트레이션 인터페이스: `runtime_pipeline.h`

핵심 원칙은 "실제 센서가 없어도 동일 인터페이스로 동작"입니다.

