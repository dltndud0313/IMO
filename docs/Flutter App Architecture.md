# Flutter App Architecture (IMO)

> Flutter 공식 아키텍처 가이드(<https://docs.flutter.dev/app-architecture/guide>)
> 를 기반으로 한 IMO 모바일 앱의 구조 설계 문서.

---

## 1. 시스템 컨텍스트

### 1.1 데이터 플로우

```
[ESP32 + EMG/IMU 센서] ──BLE/Serial──> [Raspberry Pi]
                                            │
                          ┌─────────────────┴─────────────────┐
                          │                                   │
                          ↓ HDMI / USB-C 또는 자체 출력         ↓ WebSocket (JSON)
                   [스마트글래스]                            [Flutter App]
                   (Pi가 직접 렌더링)                       (앱 자체 UI)
                                                                │
                                                                ↓ SQLite (로컬 캐시 / 업로드 큐)
                                                                │
                                                                ↓ REST (HTTPS, Bearer JWT)
                                                          [Backend Server]
```

- **글래스 출력은 Raspberry Pi가 직접 담당**한다. Flutter 앱은 글래스를 모른다.
- Flutter 앱이 책임지는 통신은 **두 갈래로 분리**된다.
  - **Pi ↔ 앱: WebSocket 단일 채널 (JSON, `type` + `payload`)**
    - 운동 준비(plan/calibration) 명령 송신, 상태 이벤트 수신, 종료 후 `session_result` 1회 수신.
    - Pi REST는 사용하지 않는다.
  - **앱 ↔ Backend: REST API**
    - 회원/프로필/설정/세션 영속화/통계 조회.
- 운동 종료 후 `session_result`는 **반드시 앱 로컬 SQLite에 먼저 저장**한 뒤 백엔드로 업로드한다 (자세한 흐름은 6.3 참고).

### 1.2 앱이 책임지는 범위

| 범위 | 내용 |
|---|---|
| 사용자 입력 | 프로필 입력, 운동 종목 선택, 시작/정지 |
| 시스템 상태 | 센서·Pi·앱 연결 상태 표시 (FR-01~05) |
| 실시간 모니터링 | 반복수, 속도, 보상동작 경고, 근활성도 (FR-22~25, FR-27) |
| 결과 저장/조회 | 세션 결과 저장, 달력/상세 조회, 그래프 (FR-29~32) |
| 설정 | 프로필 관리, 웨어러블 설정, TTS on/off |

---

## 2. 아키텍처 개요

### 2.1 3계층 구조

```
┌───────────────────────────────────────┐
│  UI Layer                              │
│   ─ View (Widget)                      │
│   ─ ViewModel (ChangeNotifier, 1:1)    │
├───────────────────────────────────────┤
│  Domain Layer (Optional)               │
│   ─ UseCase (필요한 것만)                │
├───────────────────────────────────────┤
│  Data Layer                            │
│   ─ Repository (변환·캐싱·단일 진실)      │
│   ─ Service (외부 통신만, stateless)     │
└───────────────────────────────────────┘
```

### 2.2 의존성 규칙

- 의존성은 **항상 위에서 아래 한 방향**으로만 흐른다.
- **같은 계층끼리 직접 의존 금지** (Repository ↔ Repository, Service ↔ Service 등).
- 계층 간 결합이 필요하면 UseCase로 끌어올린다.

### 2.3 계층별 책임 요약

| 계층 | 컴포넌트 | 책임 | 의존 가능 대상 |
|---|---|---|---|
| UI | View | 위젯 렌더링, 단순 레이아웃 로직 | ViewModel |
| UI | ViewModel | UI 상태, 사용자 액션 처리 | UseCase / Repository |
| Domain | UseCase | 여러 Repository 결합 / 복잡 로직 | Repository |
| Data | Repository | 도메인 모델 변환, 캐싱, 단일 진실 | Service |
| Data | Service | API·DB·플랫폼 통신, stateless | 외부 라이브러리 |

---

## 3. 폴더 구조 (Feature-first)

```
lib/
├── main.dart
├── config/
│   ├── router.dart            # go_router
│   ├── theme.dart
│   └── dependencies.dart      # get_it 등록
│
├── ui/
│   ├── core/                  # 공통 위젯, 디자인 토큰
│   │   ├── widgets/
│   │   └── themes/
│   │
│   ├── onboarding/
│   │   ├── view_model/
│   │   └── widgets/
│   ├── home/
│   ├── workout/               # 핵심 기능
│   │   ├── view_model/
│   │   │   └── workout_viewmodel.dart
│   │   └── widgets/
│   │       ├── workout_screen.dart
│   │       ├── rep_counter.dart
│   │       ├── speed_indicator.dart
│   │       └── warning_banner.dart
│   ├── session_result/
│   ├── history/
│   ├── stats/
│   └── mypage/
│
├── domain/
│   ├── models/
│   │   ├── user_profile.dart
│   │   ├── exercise_type.dart
│   │   ├── sensor_frame.dart
│   │   ├── realtime_feedback.dart
│   │   ├── workout_session.dart
│   │   └── connection_status.dart
│   └── use_cases/
│       ├── start_workout_session_usecase.dart
│       ├── end_workout_session_usecase.dart
│       └── check_system_ready_usecase.dart
│
└── data/
    ├── repositories/
    │   ├── workout_repository.dart
    │   ├── session_history_repository.dart
    │   ├── user_profile_repository.dart
    │   ├── calibration_repository.dart
    │   └── device_connection_repository.dart
    └── services/
        ├── pi_socket_service.dart        # Pi WebSocket (유일한 Pi 통신 채널)
        ├── backend_api_service.dart      # Backend REST 클라이언트
        ├── local_db_service.dart         # SQLite (drift) — 로컬 캐시 + 업로드 큐
        └── shared_prefs_service.dart
```

### 3.1 폴더별 역할

#### `lib/main.dart`
앱의 엔트리 포인트. DI 초기화, 라우터·테마 주입, `runApp()` 호출만 담당하고 비즈니스 로직은 두지 않는다.

#### `lib/config/`
앱 전역 설정만 모은다. 어떤 feature에도 종속되지 않는 코드.
- `router.dart` — `go_router` 정의. 모든 화면 경로와 가드 한곳에서 관리.
- `theme.dart` — Material/Cupertino 테마, 색상 팔레트, 타이포그래피.
- `dependencies.dart` — `get_it` 등록 함수. Service·Repository·UseCase·ViewModel 주입 그래프 정의.

#### `lib/ui/` — UI Layer
화면(View)과 ViewModel을 feature 단위로 묶는다. **`ui/` 안의 코드는 `domain/`·`data/`만 의존**한다.

- `ui/core/` — 모든 feature가 공유하는 UI 자원.
  - `widgets/` — 버튼, 카드, 다이얼로그 등 재사용 위젯.
  - `themes/` — 디자인 토큰 (간격, 그림자, 애니메이션 상수 등).
- `ui/onboarding/` — 앱 소개, 프로필 입력, (선택) 신체 스캔.
- `ui/home/` — 메인 진입 화면. 운동 시작 버튼, 연결 상태 요약.
- `ui/workout/` — **실시간 운동 모니터링 화면**. 핵심 feature.
  - `view_model/workout_viewmodel.dart` — Repository Stream 구독, UI 상태 관리.
  - `widgets/workout_screen.dart` — 화면 전체 레이아웃.
  - `widgets/rep_counter.dart`, `speed_indicator.dart`, `warning_banner.dart` — 화면을 구성하는 작은 UI 조각들.
- `ui/session_result/` — 운동 종료 직후 요약 결과 화면.
- `ui/history/` — 달력 조회, 날짜별 목록, 상세 보기.
- `ui/stats/` — 주간·월간 통계, 근육 히트맵 등 (선택 기능).
- `ui/mypage/` — 프로필 관리, 웨어러블 설정, TTS on/off, 데이터 초기화.

> 각 feature 폴더는 동일한 패턴을 가진다: `view_model/` (ChangeNotifier) + `widgets/` (View 위젯들).

#### `lib/domain/` — Domain Layer
순수 비즈니스 로직. **Flutter 패키지에 의존하지 않는다** (위젯·context 사용 금지).

- `domain/models/` — 앱 전역에서 쓰는 도메인 엔티티 (`freezed` 기반 immutable).
  - `user_profile.dart` — 사용자 프로필.
  - `exercise_type.dart` — 운동 종목 enum (pushup / sideLateralRaise / bicepCurl).
  - `sensor_frame.dart` — EMG·IMU 한 프레임.
  - `realtime_feedback.dart` — Pi가 판정한 실시간 피드백 (반복수, 속도, 경고 등).
  - `workout_session.dart` — 한 세션의 결과 전체.
  - `connection_status.dart` — 센서·Pi·앱 연결 상태.
- `domain/use_cases/` — 여러 Repository를 결합하거나 복잡한 규칙을 캡슐화한 작업.
  - `start_workout_session_usecase.dart` — 캘리브레이션 로드 + 세션 시작.
  - `end_workout_session_usecase.dart` — 세션 종료 + 결과 계산 + 저장.
  - `check_system_ready_usecase.dart` — 모든 센서·연결 정상 여부 종합 판정 (FR-10).

#### `lib/data/` — Data Layer
외부 세계와의 접점. UI는 이 계층의 **Repository**까지만 직접 사용하고, Service에는 닿지 않는다.

- `data/repositories/` — 데이터의 단일 진실 공급원. raw 응답을 도메인 모델로 변환·캐싱·결합.
  - `workout_repository.dart` — 실시간 피드백 Stream + 세션 시작/종료 명령.
  - `session_history_repository.dart` — 세션 저장·조회 (로컬 DB + 서버 동기화).
  - `user_profile_repository.dart` — 프로필 CRUD.
  - `calibration_repository.dart` — 캘리브레이션 기준값 저장·조회.
  - `device_connection_repository.dart` — 연결 상태 Stream.
- `data/services/` — 외부 통신 어댑터. **stateless**, 응답을 가공하지 않고 그대로 반환.
  - `pi_socket_service.dart` — Pi WebSocket 클라이언트. raw JSON Stream 노출. **Pi와의 유일한 통신 채널**이며, Pi REST는 존재하지 않는다.
  - `backend_api_service.dart` — Backend REST 클라이언트 (`dio` 기반). 인증, 프로필, 세션 영속화, 통계 조회 담당.
  - `local_db_service.dart` — `drift` 기반 SQLite 래퍼. 세션 결과 로컬 우선 저장과 업로드 큐 테이블을 관리한다 (6.3 참고).
  - `shared_prefs_service.dart` — 간단한 설정값 저장 (`shared_preferences`).

---

## 4. 도메인 모델

`freezed` 기반 immutable 모델로 정의한다.

| 모델 | 주요 필드 |
|---|---|
| `UserProfile` | nickname, age, gender, height, weight |
| `ExerciseType` | enum: pushup, sideLateralRaise, bicepCurl |
| `CalibrationData` | exerciseType, baselineEmg, baselineImu, createdAt |
| `SensorFrame` | timestamp, emgCh1~3, accel(x,y,z), gyro(x,y,z) |
| `RealtimeFeedback` | repCount, speedLevel, warnings, muscleActivation |
| `WorkoutSession` | id, date, exerciseType, duration, summary, frames |
| `ConnectionStatus` | esp32, raspberryPi, app 각 상태 enum |

---

## 5. 컴포넌트 설계

### 5.1 Service (외부 통신, stateless)

| Service | 역할 | 관련 요구사항 |
|---|---|---|
| `PiSocketService` | Pi WebSocket. 운동 준비 명령 송신, 상태 이벤트 + `session_result` 수신 | FR-11~21 |
| `BackendApiService` | Backend REST. 인증/프로필/설정/세션 영속화/통계 | FR-01~05, FR-43~56 |
| `LocalDbService` | Drift(SQLite) — 세션 로컬 우선 저장, 업로드 큐, 캘리브레이션 캐시 | FR-43, FR-46~47 |
| `SharedPrefsService` | 설정 저장 (TTS on/off 등) | FR-28 |

### 5.2 Repository (도메인 모델로 변환, 단일 진실)

| Repository | 노출 인터페이스 | 의존 Service |
|---|---|---|
| `DeviceConnectionRepository` | `Stream<ConnectionStatus>` | PiSocket |
| `CalibrationRepository` | `Future<CalibrationData>` save/load | PiSocket, LocalDb |
| `WorkoutRepository` | 운동 준비 명령 + 상태 이벤트 Stream + `session_result` 수신 | PiSocket |
| `SessionHistoryRepository` | 세션 CRUD (로컬 우선 저장 → 업로드 큐 → 서버 동기화) | LocalDb, BackendApi |
| `UserProfileRepository` | 프로필 CRUD | BackendApi, LocalDb |

### 5.3 UseCase (다중 Repository 결합 또는 복잡 로직)

가이드 원칙: **얇은 wrapper UseCase는 만들지 않는다**. 단순 조회는 ViewModel이 Repository를 직접 호출.

| UseCase | 이유 |
|---|---|
| `CheckSystemReadyUseCase` | DeviceConnection + Calibration 두 repo로 FR-10 판정 |
| `StartWorkoutSessionUseCase` | Calibration 로드 → Workout 시작 |
| `EndWorkoutSessionUseCase` | Workout 종료 → 결과 계산 → SessionHistory 저장 |

### 5.4 ViewModel (View와 1:1)

| ViewModel | 의존 |
|---|---|
| `OnboardingViewModel` | UserProfileRepository |
| `HomeViewModel` | DeviceConnectionRepository, UserProfileRepository |
| `ExerciseSetupViewModel` | CalibrationRepository, CheckSystemReadyUseCase |
| `WorkoutViewModel` | StartWorkoutSessionUseCase, WorkoutRepository, EndWorkoutSessionUseCase |
| `SessionResultViewModel` | SessionHistoryRepository |
| `HistoryViewModel` | SessionHistoryRepository |
| `MyPageViewModel` | UserProfileRepository, SharedPrefsService |

---

## 6. 핵심 플로우 — 실시간 운동 모니터링

### 6.1 데이터 전파 경로

```
PiSocketService
  └─ Stream<Map> rawFrames                    // raw JSON
       │
       ▼
WorkoutRepository
  └─ Stream<RealtimeFeedback>                 // 도메인 모델로 변환
       │
       ▼
WorkoutViewModel (ChangeNotifier)
  └─ subscribe & update state
  └─ notifyListeners()
       │
       ▼
WorkoutScreen (View)
  └─ ListenableBuilder rebuild
```

### 6.2 ViewModel 골격

```dart
class WorkoutViewModel extends ChangeNotifier {
  final WorkoutRepository _repo;
  final StartWorkoutSessionUseCase _start;
  final EndWorkoutSessionUseCase _end;

  WorkoutViewModel(this._repo, this._start, this._end);

  StreamSubscription<RealtimeFeedback>? _sub;
  WorkoutUiState _state = WorkoutUiState.idle();
  WorkoutUiState get state => _state;

  Future<void> startWorkout(ExerciseType type) async {
    await _start(type);
    _sub = _repo.feedbackStream.listen(_onFeedback);
  }

  void _onFeedback(RealtimeFeedback f) {
    _state = _state.copyWith(
      repCount: f.repCount,
      speed: f.speed,
      warnings: f.warnings,
    );
    notifyListeners();
  }

  Future<void> stopWorkout() async {
    await _sub?.cancel();
    final session = await _end();
    _state = _state.copyWith(finished: true, session: session);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
```

---

## 6.3 세션 결과 로컬 우선 저장 & 업로드 큐

운동 종료 후 받는 `session_result`는 **반드시 SQLite에 먼저 저장**한 뒤 서버로 올린다. 네트워크 단절·서버 장애가 발생해도 결과를 잃지 않도록 한다.

### 전체 흐름

```
Pi ──session_result──> 앱 ──insert──> SQLite (workout_sessions_local, status=pending)
                                │
                                ├──enqueue──> upload_queue
                                │
                                ↓ 즉시 또는 next_retry_at 도래 시
                       BackendApiService.saveSession()
                                │
                ┌───────────────┴───────────────┐
                ▼                               ▼
        성공: status=synced              실패: status=failed
              synced_at 기록                    retry_count++
              upload_queue에서 삭제             next_retry_at 갱신
```

### 6.3.1 로컬 테이블

`LocalDbService`에 다음 두 테이블을 둔다 (drift schema).

#### `workout_sessions_local`

```text
- local_id           TEXT PK    # 앱 내부에서만 쓰는 고유 ID (e.g., "local_20260427_001")
- user_id            INTEGER
- session_id         TEXT       # Pi가 발급한 세션 ID
- exercise_type      TEXT
- status             TEXT       # session_result.status (completed/stopped/...)
- end_reason         TEXT
- started_at         TEXT       # ISO 8601
- ended_at           TEXT
- duration_sec       INTEGER
- total_reps         INTEGER
- valid_reps         INTEGER
- set_count          INTEGER
- upload_status      TEXT       # pending / syncing / synced / failed
- payload_json       TEXT       # session_result.payload 전체 원본 JSON 문자열
- created_at         TEXT
- updated_at         TEXT
- synced_at          TEXT NULL  # 서버 업로드 성공 시각
```

**핵심 원칙**
- `payload_json`에 Pi 원본 페이로드를 통째로 보관해두고, 서버 업로드 시 그대로 직렬화한다.
- 기록 화면은 별도 컬럼(`exercise_type`, `total_reps`, `started_at` 등)을 인덱스/요약 표시용으로 활용한다.

#### `upload_queue`

```text
- queue_id           TEXT PK    # e.g., "queue_20260427_001"
- local_session_id   TEXT       # workout_sessions_local.local_id 참조
- request_type       TEXT       # 현재는 'POST_SESSION' 만 사용
- retry_count        INTEGER
- next_retry_at      TEXT NULL  # 다음 재시도 시각 (ISO 8601)
- last_error_code    TEXT NULL
- last_error_message TEXT NULL
- created_at         TEXT
- updated_at         TEXT
```

### 6.3.2 `upload_status` 상태 머신

| 값 | 의미 |
|---|---|
| `pending` | 로컬 저장 완료, 서버 업로드 대기 |
| `syncing` | 현재 업로드 시도 중 |
| `synced` | 서버 업로드 성공 (큐에서 제거됨) |
| `failed` | 직전 업로드 시도 실패 (큐에 남아 다음 재시도 대기) |

상태 전이는 `pending → syncing → synced`(성공) 또는 `pending → syncing → failed → syncing → ...`(재시도) 한 방향으로만 흐른다.

### 6.3.3 처리 순서

운동 종료 후 `WorkoutRepository`가 `session_result`를 받으면, `EndWorkoutSessionUseCase`(또는 `SessionHistoryRepository.saveSession`)가 다음 순서로 처리한다.

1. `workout_sessions_local`에 INSERT — `upload_status = pending`, `payload_json = session_result.payload 직렬화`.
2. `upload_queue`에 INSERT — `request_type = POST_SESSION`, `retry_count = 0`, `next_retry_at = null`.
3. 즉시 업로드 시도:
    - `upload_status = syncing` 으로 변경.
    - `BackendApiService.saveSession(payload_json + user_id)` 호출.
4. 성공:
    - `upload_status = synced`, `synced_at = now()` 기록.
    - 해당 `upload_queue` 행 삭제.
5. 실패:
    - `upload_status = failed`, `retry_count += 1`.
    - 정책에 따라 `next_retry_at` 갱신.
    - `last_error_code` / `last_error_message` 기록.

### 6.3.4 재시도 정책 (MVP)

단순 고정 백오프로 시작한다.

| 시도 | 다음 재시도 간격 |
|---|---|
| 1차 실패 후 | 10초 |
| 2차 실패 후 | 30초 |
| 3차 실패 후 | 60초 |
| 그 이후 | 더 이상 자동 폴링하지 않고, 앱 재실행 / 네트워크 복구 / 명시적 사용자 재시도 시점에만 재개 |

**재시도 트리거**
- 인메모리 타이머 (`Timer`) — 현재 세션 종료 직후 한정.
- 앱 resume (`AppLifecycleState.resumed`).
- 네트워크 복구 (`connectivity_plus` 등으로 감지 시).

### 6.3.5 책임 분리

| 책임 | 담당 |
|---|---|
| 로컬 INSERT, 상태 갱신, 큐 enqueue/dequeue | `SessionHistoryRepository` (LocalDb 호출) |
| 서버 업로드 호출 | `SessionHistoryRepository` (BackendApi 호출) |
| 큐 폴링/재시도 트리거 | `SessionHistoryRepository` 내부 워커, 또는 `UploadQueueWorker`(있으면) |
| 화면 표시 (동기화 뱃지 등) | `HistoryViewModel`이 `upload_status` 컬럼을 그대로 노출 |

> ViewModel과 UseCase는 큐 존재를 몰라도 된다. "세션 저장 요청 → 즉시 성공 반환(로컬 저장 보장됨)" 인터페이스로 노출하면 충분하다.

### 6.3.6 한 줄 요약

> **앱은 Pi의 `session_result`를 받으면 SQLite에 원본 JSON과 핵심 요약값을 먼저 저장하고 `pending`으로 큐에 넣은 뒤, 서버 업로드 성공 시 `synced` / 실패 시 `failed`로 갱신한다. 네트워크 복구·앱 resume 시점에 큐를 다시 비운다.**

---

## 7. 상태관리 / 의존성 주입

| 항목 | 선택 |
|---|---|
| 상태 관리 | `ChangeNotifier` + `ListenableBuilder` (또는 `provider`) |
| 의존성 주입 | `get_it` |

가이드가 명시적으로 권장하는 조합. 학습 비용이 낮고 공식 예제와 가장 가깝다.

### DI 등록 예시

```dart
final getIt = GetIt.instance;

void setupDependencies() {
  // Services (singleton)
  getIt.registerSingleton(PiSocketService());
  getIt.registerSingleton(BackendApiService(/* dio with auth interceptor */));
  getIt.registerSingleton(LocalDbService());

  // Repositories (singleton)
  getIt.registerSingleton(
    WorkoutRepository(getIt(), getIt()),
  );
  getIt.registerSingleton(
    SessionHistoryRepository(getIt(), getIt()),
  );
  // ...

  // UseCases (singleton)
  getIt.registerSingleton(
    StartWorkoutSessionUseCase(getIt(), getIt()),
  );

  // ViewModels (factory: 매번 새로 생성)
  getIt.registerFactory(
    () => WorkoutViewModel(getIt(), getIt(), getIt()),
  );
}
```

---

## 8. 사용 패키지

| 용도 | 패키지 |
|---|---|
| 상태관리 | `provider` |
| DI | `get_it` |
| 라우팅 | `go_router` |
| 모델 | `freezed`, `json_serializable` |
| HTTP | `dio` |
| WebSocket | `web_socket_channel` |
| 로컬 DB | `drift` |
| 차트 | `fl_chart` |
| 캘린더 | `table_calendar` |

---

## 9. 구현 우선순위

1. 폴더 구조 + DI 등록 + 라우팅 스켈레톤
2. 도메인 모델 `freezed` 정의
3. `PiSocketService` + `BackendApiService` (Mock 구현 먼저)
4. `WorkoutRepository` 연결, fake stream으로 `WorkoutViewModel` + UI 동작 확인
5. `LocalDbService` + `SessionHistoryRepository` (저장/조회)
6. 시스템 초기화 화면 (FR-01~05) + `CheckSystemReadyUseCase`
7. Mock을 실제 Pi 통신으로 교체
8. 통계/시각화 등 선택 기능

---

## 10. 설계 원칙 체크리스트

- [ ] View는 데이터 로직을 갖지 않는다 (단순 if/animation/layout만 허용).
- [ ] ViewModel은 View와 1:1로 매칭된다.
- [ ] Repository는 raw 데이터를 도메인 모델로 변환해서 노출한다.
- [ ] Service는 stateless이며 외부 통신만 담당한다.
- [ ] 같은 계층 컴포넌트끼리 직접 의존하지 않는다.
- [ ] 단순 wrapping뿐인 UseCase는 만들지 않는다.
- [ ] 실시간 데이터는 Service → Repository → ViewModel 순으로 Stream을 흘려보낸다.
