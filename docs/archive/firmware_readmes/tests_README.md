# firmware/tests/

펌웨어 핵심 로직을 Ubuntu에서 검증하기 위한 호스트 기반 테스트입니다.

테스트 항목:

- 패킷 인코딩/디코딩
- EMG 계산(RMS/이동평균/정규화)
- 캘리브레이션 누적
- 상태머신 전이
- 가짜 센서 신호 변화

실행:

```bash
./scripts/run_firmware_host_tests.sh
```
