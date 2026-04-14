# firmware/tools/

개발 보조 실행 파일을 둡니다.

- `mock_stream_main.cpp`: ESP32 없이 JSONL 패킷을 생성하는 호스트용 발생기

주요 사용처:

- Pi receiver와 end-to-end 파이프라인 연결 검증
- 하드웨어 도착 전 통신/파싱/로그 경로 확인

생성되는 패킷 형식은 아래 문서를 기준으로 동일하게 맞춥니다.

- `../../README.md`
  - 패킷 필드 예시값과 `state` 의미를 빠르게 볼 수 있습니다.
- `../../../shared/protocol/esp32_pi_packet_format.md`
  - ESP32-Pi 공통 패킷 포맷 기준 문서입니다.
