# firmware/tools/

개발 보조 실행 파일을 둡니다.

- `mock_stream_main.cpp`: ESP32 없이 JSONL 패킷을 생성하는 호스트용 발생기

주요 사용처:

- Pi receiver와 end-to-end 파이프라인 연결 검증
- 하드웨어 도착 전 통신/파싱/로그 경로 확인
