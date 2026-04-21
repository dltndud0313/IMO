# Inside Muscle Out

EMG(근전도) 센서와 포즈 감지 기반의 스마트 운동 분석 모바일 앱입니다.
사용자의 근육 활성도와 자세를 실시간으로 측정·분석해 올바른 운동 폼과
적절한 운동 강도를 피드백합니다.

## 주요 기능

- 실시간 EMG 신호 시각화 (ESP32 센서 연동)
- 포즈 감지 기반 자세/보상동작 분석
- 운동 루틴 관리 및 세션 기록
- 성취(뱃지) 시스템과 통계 대시보드
- TTS 기반 음성 피드백
- 다크모드 지원

## 기술 스택

- **Framework**: Flutter (Dart SDK `^3.11.4`)
- **상태관리**: Riverpod
- **차트**: fl_chart
- **포즈 감지**: Google ML Kit Pose Detection
- **로컬 저장**: sqflite, shared_preferences
- **음성**: flutter_tts
- **폰트**: Google Fonts (Inter)

## 프로젝트 구조

```
lib/
├── main.dart                  # 앱 진입점 · 스플래시 · 분기 로직
├── db/                        # sqflite 로컬 DB 헬퍼
├── mock/                      # 개발용 mock 데이터
├── models/                    # 도메인 모델 (user, exercise, routine 등)
├── providers/                 # Riverpod 프로바이더
├── screens/                   # 화면 위젯
│   ├── auth/                  # 로그인 · 회원가입
│   ├── onboarding/            # 인트로 · 프로필 설정 · 바디 캡처
│   └── routine/               # 루틴 리스트 · 편집 · 세션
├── services/                  # 포즈 감지 · TTS · 저장 · 설정
├── theme/                     # 라이트/다크 테마 정의
├── utils/                     # 네비게이션 헬퍼
└── widgets/                   # 재사용 위젯 (EMG 파형 · 히트맵 · 캘린더 등)
```

## 실행

```bash
# 의존성 설치
flutter pub get

# 에뮬레이터 또는 연결된 디바이스에서 실행
flutter run

# 웹으로 실행
flutter run -d chrome
```

## 지원 플랫폼

- Android
- iOS
- Web

데스크톱(Windows/macOS/Linux)은 프로젝트 범위에서 제외되어 있습니다.

## 관련 문서

- Git 컨벤션: [`docs/Git Workflow.md`](../docs/Git%20Workflow.md)
- ESP32 ↔ Pi 통신 프로토콜: [`shared/protocol/esp32_pi_packet_format.md`](../shared/protocol/esp32_pi_packet_format.md)
