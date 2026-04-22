# firmware/include/

이 폴더는 "설계도" 역할을 하는 헤더 파일 모음입니다.

- 데이터 구조: `types.h`
- 설정 상수: `config.h`
- 모듈 경계: `packet.h`, `emg_filter.h`, `imu_processor.h`, `calibration.h`, `state_machine.h`
- 확장 포인트: `sensor_source.h`, `transport_serial.h`
- 전체 오케스트레이션 인터페이스: `runtime_pipeline.h`

핵심 원칙은 "실제 센서가 없어도 동일 인터페이스로 동작"입니다.

추가로 처음 볼 때는 아래 순서가 좋습니다.

- `types.h`
  - `OutputPacket` 필드와 `RuntimeState` 정의가 들어 있습니다.
- `sensor_source.h`
  - mock 센서와 실제 센서를 같은 방식으로 연결하는 공통 인터페이스입니다.
- `config.h`
  - 샘플링 주기, baud rate, 임계값 같은 기본 설정이 들어 있습니다.
  - 패킷 포맷 기본값(`JSON_V1`, `BINARY_V2`)도 여기서 선택합니다.
