# SSAFY 2학기 3번째 프로젝트

## 프로젝트 개요


## 폴더 구조

아직 세부 구조는 프로젝트 진행에 따라 변경될 수 있으며, 현재는 역할 단위의 상위 디렉터리만 우선 구성한 상태입니다.

- `app/`  
  모바일 애플리케이션 관련 소스와 자원을 관리하는 디렉터리입니다.

- `device/`  
  프로젝트에서 사용하는 디바이스 측 코드를 관리하는 디렉터리입니다.  
  ESP32 및 Raspberry Pi에서 동작하는 코드가 포함됩니다.
  - `device/esp32/firmware/`: ESP-IDF 기반 ESP32-S3 펌웨어
  - `device/esp32/scripts/`: ESP32 호스트 테스트 스크립트
  - `device/raspberry-pi/`: Raspberry Pi 관련 코드 위치

- `docs/`  
  프로젝트 진행에 필요한 문서들을 정리하는 디렉터리입니다.  
  Git 작업 방식, 협업 규칙, 설계 관련 문서를 보관합니다.

- `shared/`  
  여러 구성 요소가 함께 참조하는 공통 자원들을 관리하는 디렉터리입니다.
  통신 규약, 공통 설정, 상수 정의 등이 포함될 수 있습니다.
  - `shared/protocol/esp32_pi_packet_format.md`: ESP32-Pi 직렬 패킷 포맷 문서
