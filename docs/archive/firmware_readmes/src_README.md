# firmware/src/

`include/`에서 선언한 기능의 실제 구현 파일이 들어 있습니다.

핵심 파일:

- `runtime_pipeline.cpp`: 센서 입력부터 패킷 송출까지 한 주기(tick)의 전체 흐름
- `packet.cpp`: JSONL 인코딩/디코딩
- `emg_filter.cpp`, `imu_processor.cpp`: 경량 전처리
- `calibration.cpp`, `state_machine.cpp`: 캘리브레이션/상태 제어

MVP에서는 계산을 가볍게 유지해 실시간성과 디버깅 용이성을 우선합니다.
