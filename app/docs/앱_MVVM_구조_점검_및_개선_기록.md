# 앱 MVVM 구조 점검 및 개선 기록

작성일: 2026-05-07

## 1. 문서 목적

이 문서는 IMO Flutter 앱을 구현하면서 MVVM/feature-first 구조가 얼마나 유지되고 있는지 점검하고, 현재 코드의 유지보수 리스크와 개선 방향을 기록하기 위한 문서이다.

단순히 "폴더를 나누었다"는 수준이 아니라, 왜 특정 기능을 구현했는지, 전체 시스템 구조에서 어떤 영향을 주는지, 앞으로 Pi 통신/로컬 저장/기록/통계/결과 화면이 붙어도 확장 가능한 구조인지 판단하는 것을 목표로 한다.

## 2. 전체 시스템에서 앱의 역할

현재 IMO 시스템에서 앱은 센서 원본 데이터를 직접 분석하는 주체가 아니다.

앱의 핵심 역할은 다음과 같다.

- 사용자가 운동을 선택하고 운동 계획을 설정한다.
- Pi로 WebSocket 명령을 전송한다.
- Pi가 보내는 상태 이벤트를 수신한다.
- 운동 종료 후 Pi가 보내는 `session_result`를 수신한다.
- `session_result`를 앱 로컬 SQLite에 우선 저장한다.
- 저장된 결과를 기록/결과/통계 화면에서 표시한다.
- 필요 시 서버 API로 결과를 업로드하거나 서버 기록/통계를 조회한다.

즉 앱은 다음 역할을 담당한다.

```text
운동 제어
-> 상태 표시
-> 결과 수신
-> 로컬 저장
-> 기록/통계/결과 표시
```

이 기준에서 가장 중요한 설계 원칙은 다음이다.

```text
운동 결과 데이터의 1차 저장소는 앱 로컬 SQLite이며,
서버 업로드는 선택/확장 기능으로 분리한다.
```

## 3. 지금까지의 구조 개선 흐름

| 시점 | 작업 | 의도 |
| --- | --- | --- |
| 1차 | MVVM/feature-first 폴더 구조 정리 | 기능별 화면과 레이어를 분리하기 위한 기반 마련 |
| 2차 | 디자인 토큰 및 공용 컴포넌트 정리 | 화면별 하드코딩 스타일 증가 방지 |
| 3차 | AppScaffold/BottomNavShell 도입 | 공통 레이아웃과 하단 네비게이션 일관성 확보 |
| 4차 | Pi WebSocket DTO 및 메시지 규약 정리 | 앱과 Pi 간 `type + payload` 계약 고정 |
| 5차 | 운동 준비 플로우 연결 | 운동 선택, 계획 설정, 센서 부착, 캘리브레이션 흐름 구성 |
| 6차 | session_result DTO/domain 모델 정의 | Pi 최종 결과 payload를 앱 도메인 모델로 변환 |
| 7차 | 센서 부착 매핑/muscle_map 스키마 정리 | 결과 시각화와 센서 안내 UI 기준 마련 |
| 8차 | 로컬 임시 저장 구조 추가 | 운동 결과 유실 방지와 후속 기록/결과 화면 기반 마련 |

이 흐름은 전체적으로 타당하다.

다만 화면 구현 속도를 우선하면서 일부 화면에 상태 관리와 데이터 호출이 직접 들어갔고, 이 부분이 현재 구조 개선의 핵심 대상이다.

## 4. 현재 구조 점검 결과

### 4.1 유지되고 있는 장점

현재 앱은 큰 폴더 구조 기준으로는 무너지지 않았다.

```text
lib/
  config/
  data/
    dto/
    repositories/
    services/
  domain/
    models/
    use_cases/
  ui/
    auth/
    onboarding/
    home/
    workout_setup/
    workout/
    session_result/
    history/
    stats/
    mypage/
    core/
```

좋은 점은 다음과 같다.

- feature-first 구조가 유지되고 있다.
- `auth`, `workout_setup`, `history`, `stats`, `mypage` 등 기능별 폴더가 나뉘어 있다.
- `ApiService`, `AuthService`, `PiSocketService`, `LocalDbService`가 service 레이어에 분리되어 있다.
- `SessionResultDto`, `WorkoutSession`, `MuscleMap`, `SensorPlacement` 등 데이터 계약을 모델로 남겨두었다.
- `ui/core`에 공용 UI와 디자인 토큰을 모아두었다.
- `LocalSessionRepository`를 추가해 결과 유실 방지 기반을 마련했다.

### 4.2 현재 구조의 한계

현재 문제는 "폴더 구조가 없다"가 아니다.

문제는 일부 화면에서 실제 의존성 흐름이 MVVM 구조를 충분히 따르지 않는 것이다.

현재 일부 흐름은 다음과 같다.

```text
View
-> getIt
-> Repository 또는 ApiService
-> setState
```

예시:

- `ui/stats/widgets/stats_screen.dart`에서 `ApiService`를 직접 호출한다.
- `ui/history/widgets/history_screen.dart`에서 `SessionHistoryRepository`를 직접 호출한다.
- `ui/mypage/widgets/mypage_screen.dart`에서 `UserProfileRepository`를 직접 호출한다.
- `ui/workout_setup/widgets/plan_setting_screen.dart`에서 `WorkoutRepository`를 직접 호출한다.
- `ui/workout/widgets/workout_screen.dart`에서 WebSocket 관련 repository와 stream을 직접 다룬다.

이 구조는 동작은 하지만, 유지보수 관점에서는 화면 파일이 점점 무거워질 위험이 있다.

## 5. 이상적인 의존성 방향

최종적으로 지향하는 구조는 다음이다.

```text
View
-> ViewModel
-> UseCase
-> Repository Interface
-> Repository Implementation
-> Service / Local DB / WebSocket / API
```

각 레이어의 책임은 다음과 같다.

| 레이어 | 책임 |
| --- | --- |
| View | UI 렌더링, 사용자 입력 전달 |
| ViewModel | 화면 상태, 로딩/에러/성공 상태, 버튼 액션 처리 |
| UseCase | 하나의 사용자/비즈니스 흐름 처리 |
| Repository | 데이터 출처 결정, 로컬/서버/WebSocket 추상화 |
| Service | 실제 API, SQLite, WebSocket 호출 |

모든 화면을 한 번에 완벽한 MVVM으로 바꾸는 것은 현실적이지 않다.

대신 복잡도가 높은 영역부터 점진적으로 개선한다.

## 6. 핵심 개선 대상

### 6.1 운동 종료 결과 저장 흐름

가장 먼저 정리해야 할 흐름이다.

현재 프로젝트의 핵심 데이터는 Pi가 보내는 `session_result`이다.

결과 저장 정책은 다음으로 고정한다.

```text
Pi session_result 수신
-> SessionResultDto 파싱
-> WorkoutSession 변환
-> LocalSessionRepository에 SQLite 우선 저장
-> 저장 성공 후 결과 화면 표시
-> 서버 업로드는 후속 큐/동기화 작업으로 분리
```

이 흐름이 중요한 이유:

- 네트워크나 서버 장애가 있어도 운동 결과가 유실되지 않는다.
- 기록 화면과 결과 화면의 원본 데이터 기준이 명확해진다.
- 나중에 서버 업로드 실패/재시도 정책을 붙이기 쉽다.

현재 상태:

- `SessionResultDto -> WorkoutSession` 변환은 구현되어 있다.
- `LocalSessionRepository`와 `LocalDbService`는 구현되어 있다.
- 아직 `session_result` 수신 시 로컬 우선 저장으로 자동 연결되지는 않았다.

개선 방향:

- `EndWorkoutSessionUseCase` 또는 별도 `SaveSessionResultUseCase`를 만든다.
- `WorkoutRepository.sessionResult`를 구독해 로컬 저장을 먼저 수행한다.
- 서버 업로드는 별도 작업으로 분리한다.

### 6.2 ActiveWorkoutViewModel 도입

운동 중 화면은 WebSocket 이벤트와 사용자 제어가 동시에 발생하는 복잡한 화면이다.

현재 운동 화면에서 직접 처리하면 복잡도가 빠르게 커진다.

`ActiveWorkoutViewModel`이 관리해야 할 상태:

- Pi 연결 상태
- 운동 중/일시정지/종료 상태
- pause/resume/stop/emergency 명령
- `workout_paused`, `workout_resumed`, `workout_completed` 수신 상태
- `session_result` 수신 여부
- 저장 진행 상태
- 화면 표시용 메시지

View는 다음 정도만 담당해야 한다.

```text
ViewModel state 표시
버튼 클릭 시 ViewModel 메서드 호출
```

### 6.3 WorkoutSetupViewModel 도입

운동 준비 플로우는 다음 단계를 포함한다.

```text
운동 선택
-> 운동 계획 설정
-> submit_workout_plan
-> plan_ack 수신
-> 센서 부착 완료
-> sensors_attached / start_calibration
-> calibration_status started/success/failed
-> 운동 화면 진입
```

이 흐름은 View가 직접 판단하면 화면 간 중복이 많아진다.

`WorkoutSetupViewModel`이 관리해야 할 상태:

- 선택한 운동
- 운동 계획
- plan_ack 결과
- 센서 부착 확인 여부
- 캘리브레이션 진행 상태
- 캘리브레이션 실패 메시지
- 다음 단계 이동 가능 여부

### 6.4 HistoryViewModel 도입

기록 화면은 앞으로 서버 API, 로컬 DB, empty/error 상태가 모두 섞일 가능성이 높다.

ViewModel이 담당해야 할 상태:

- 현재 선택 월
- 현재 선택 날짜
- 날짜별 세션 목록
- 로딩 상태
- empty state
- 에러 메시지
- 상세 화면으로 넘길 session id

현재 화면에서 repository를 직접 호출하는 구조는 ViewModel로 옮긴다.

### 6.5 StatsViewModel 및 StatsRepository 도입

통계 화면은 앞으로 가장 복잡해질 가능성이 높다.

관리해야 할 상태:

- 주간/월간/3개월 필터
- 운동별 필터
- 히트맵 데이터
- 좌우 밸런스 데이터
- 추세 데이터
- 로딩/refresh/empty/error 상태

현재 `stats_screen.dart`에서 `ApiService`를 직접 호출하는 것은 단기 구현으로는 가능하지만, 장기적으로는 유지보수에 불리하다.

개선 방향:

- `StatsRepository`를 만든다.
- `StatsViewModel`이 repository를 호출한다.
- View는 `StatsViewModel`의 state만 표시한다.

## 7. Domain Repository Interface 도입 판단

장기적으로는 `domain/repositories`에 interface를 두는 것이 좋다.

예시:

```dart
abstract class SessionRepository {
  Future<void> saveSession(WorkoutSession session);
  Future<List<WorkoutSession>> getSessionsByDate(DateTime date);
  Future<WorkoutSession?> getSessionDetail(String sessionId);
}
```

그리고 data layer에서 구현한다.

```dart
class LocalSessionRepositoryImpl implements SessionRepository {
  final LocalDbService localDbService;
}
```

효과:

- UseCase가 data layer 구현체에 직접 의존하지 않는다.
- SQLite에서 서버 API로 바뀌어도 ViewModel/UseCase 영향이 작다.
- 테스트가 쉬워진다.

다만 현재 프로젝트 일정상 전체 repository interface를 한 번에 도입하는 것은 과하다.

우선순위는 다음과 같다.

1. 세션 저장 흐름
2. 운동 중 상태 관리
3. 기록/통계 조회

이 세 영역부터 interface를 적용한다.

## 8. 당장 하지 않을 것

현재 시점에서는 아래 작업을 바로 하지 않는다.

- 전체 앱을 한 번에 Clean Architecture로 재작성
- 모든 화면의 ViewModel 강제 도입
- 단순한 splash/onboarding 화면까지 과도하게 추상화
- UI 파일 대규모 재작성
- 공용 컴포넌트 추가 리팩토링
- 3D avatar 구현
- 통계 계산 로직 완성

이번 개선의 목표는 "완벽한 구조"가 아니라 "복잡도가 터지는 지점부터 막는 구조"이다.

## 9. 개선 우선순위

### 1순위: session_result 로컬 우선 저장 연결

목표:

```text
Pi session_result 수신 후 SQLite에 먼저 저장
```

예상 작업:

- `SaveSessionResultUseCase` 추가
- `EndWorkoutSessionUseCase` 수정
- `WorkoutRepository.sessionResult` 수신 후 `LocalSessionRepository.saveSessionResult()` 호출
- 저장 성공/실패 로그 및 상태 처리

### 2순위: ActiveWorkoutViewModel 구현

목표:

```text
운동 중 화면에서 WebSocket/Timer/제어 버튼 로직 제거
```

예상 작업:

- `WorkoutViewModel` 또는 `ActiveWorkoutViewModel` 구현
- pause/resume/stop/emergency 메서드 이동
- connection/session_result stream 구독 이동
- View는 state만 표시

### 3순위: WorkoutSetupViewModel 구현

목표:

```text
운동 준비 플로우의 상태와 Pi 메시지 송수신을 ViewModel로 이동
```

예상 작업:

- plan submit
- plan_ack 처리
- sensor attached
- calibration_status 처리
- 성공/실패 상태 관리

### 4순위: HistoryViewModel 구현

목표:

```text
기록 화면에서 Repository 직접 호출 제거
```

예상 작업:

- 선택 날짜/월 상태 이동
- 기록 목록 로딩/empty/error 상태 관리
- 서버 또는 로컬 DB 조회 정책 분리

### 5순위: StatsRepository + StatsViewModel 구현

목표:

```text
통계 화면의 API 직접 호출 제거
```

예상 작업:

- 주차/운동 필터 상태 이동
- heatmap/balance/trend 데이터 로딩 분리
- 로딩/refresh/empty/error 상태 분리

## 10. 현재 구조에 대한 최종 판단

현재 앱 구조는 실패한 구조가 아니다.

오히려 다음 기반은 잘 잡혀 있다.

- feature-first 폴더 구조
- 공용 UI와 디자인 토큰
- Pi WebSocket 메시지 모델
- session_result DTO/domain 모델
- sensor placement/muscle_map 기준
- 로컬 SQLite 저장 구조

하지만 아직 실제 MVVM 책임 분리는 완성되지 않았다.

현재 상태는 다음과 같이 표현할 수 있다.

```text
MVVM을 지향하는 feature-first 구조는 잡혀 있으나,
일부 핵심 화면은 아직 StatefulWidget 중심으로 상태와 데이터 호출을 직접 처리한다.
따라서 운동/기록/통계처럼 복잡도가 높은 기능부터 ViewModel과 UseCase 중심으로 점진 개선한다.
```

## 11. 포트폴리오 설명 문장

아래 문장은 포트폴리오 또는 발표 자료에 사용할 수 있다.

```text
초기에는 빠른 화면 구현을 위해 일부 화면에서 Repository와 Service를 직접 호출했지만,
운동 중 WebSocket 이벤트, 세션 결과 저장, 기록/통계 조회가 복잡해지면서
ViewModel 중심으로 상태 관리 책임을 분리하는 방향으로 구조를 개선했습니다.

특히 Pi로부터 수신한 session_result를 서버 업로드보다 먼저 로컬 SQLite에 저장하도록 설계하여,
네트워크 장애나 서버 오류 상황에서도 운동 결과가 유실되지 않도록 했습니다.

이를 통해 View는 UI 렌더링에 집중하고,
ViewModel은 화면 상태와 사용자 액션을 관리하며,
Repository는 WebSocket/API/Local DB 접근을 담당하도록 역할을 분리했습니다.
```

## 12. 다음 액션

다음 작업부터는 새 기능을 화면 파일에 바로 붙이지 않고, 아래 기준을 먼저 확인한다.

```text
1. 이 기능의 상태는 어느 ViewModel이 소유하는가?
2. 이 기능은 UseCase가 필요한 흐름인가?
3. 데이터 출처는 API, Pi WebSocket, Local DB 중 무엇인가?
4. Repository가 데이터 출처를 감싸고 있는가?
5. View가 getIt, ApiService, PiSocketService를 직접 호출하지 않는가?
6. 실패/로딩/empty 상태가 화면에 흩어지지 않는가?
```

이 기준을 통과하지 못하면, 기능 구현 전에 구조부터 작게 정리한다.
## 13. 2026-05-07 MVVM 안정화 MR 반영 기록

이번 작업은 Flutter 앱의 화면 파일에 몰려 있던 Repository 호출, WebSocket listener, API 호출, 로딩 상태 관리를 ViewModel과 Repository 계층으로 단계적으로 이동한 작업이다. 목적은 UI를 새로 고치는 것이 아니라, 기존 화면 동작을 유지하면서 각 계층의 책임을 더 명확하게 나누는 것이었다.

### 13.1 완료한 작업 범위

```text
1단계: session_result 로컬 우선 저장 연결
2단계: WorkoutViewModel 정리
3단계: WorkoutSetupViewModel 정리
4단계: HistoryViewModel 정리
5단계: StatsRepository + StatsViewModel 도입
6단계: Domain Repository Interface 부분 도입
```

### 13.2 session_result 로컬 우선 저장 연결

Pi에서 `session_result`를 수신했을 때 앱이 결과를 먼저 로컬 SQLite에 저장하도록 연결했다. `EndWorkoutSessionUseCase.listenAndSaveAutomatically()`가 앱 실행 중 한 번만 동작하도록 guard를 두었고, `setupDependencies()` 흐름에서 자동 저장 listener가 시작되도록 구성했다.

개선된 점:

- 운동 결과 저장 책임이 화면이 아니라 UseCase로 이동했다.
- Pi 통합 테스트 중 서버 저장이 늦어져도 앱 내부에는 결과를 먼저 보존할 수 있는 구조가 생겼다.
- 추후 서버 sync 실패/재시도 정책을 붙일 수 있는 출발점이 생겼다.

### 13.3 WorkoutViewModel 정리

`WorkoutScreen`에서 직접 처리하던 운동 제어 명령과 일부 stream listener를 `WorkoutViewModel`로 이동했다.

이동한 책임:

- `pauseWorkout`
- `resumeWorkout`
- `stopWorkout`
- `emergencyStop`
- `workoutPaused` listener
- `workoutResumed` listener
- `connection status` listener

보류한 책임:

- Timer
- elapsedSeconds
- timeLabel

Timer는 현재 화면의 `_state`와 강하게 묶인 UI 표시용 상태라서, 억지로 ViewModel로 옮기면 diff와 구조 변경이 커진다고 판단해 보류했다.

개선된 점:

- 운동 중 화면이 Pi 제어 명령을 직접 알 필요가 줄었다.
- WebSocket 이벤트 수신과 화면 상태 변경의 경계가 조금 더 명확해졌다.
- 화면은 버튼 이벤트 연결과 UI 표시를 담당하고, ViewModel은 운동 제어 명령과 listener 생명주기를 담당하게 되었다.

### 13.4 WorkoutSetupViewModel 정리

운동 준비 플로우에서 Pi와 통신하는 책임을 `WorkoutSetupViewModel`로 이동했다.

이동한 책임:

- `submit_workout_plan` 전송
- `plan_ack` 대기
- 센서 부착 완료 처리
- `sensors_attached` 전송
- `start_calibration` 전송
- `calibration_status` listener 관리
- calibration 시작 명령 연결

화면에 남긴 책임:

- 입력값 상태
- 버튼 onPressed
- SnackBar 표시
- navigation
- `_stage` 기반 UI 표시
- autoStart 분기

개선된 점:

- 운동 준비 플로우의 Pi 메시지 송수신 책임이 화면에서 분리되었다.
- PlanSetting, SensorGuide, Calibration 화면이 직접 Repository를 호출하는 범위가 줄었다.
- `calibration_status` 구독과 cancel 처리를 ViewModel이 담당하면서 listener 생명주기가 명확해졌다.
- UI 흐름은 유지하면서 통신 흐름만 분리했기 때문에 회귀 위험을 낮췄다.

### 13.5 HistoryViewModel 정리

기록 화면의 날짜별 목록 조회, 월/날짜 선택 상태, 상세 조회를 `HistoryViewModel`로 이동했다.

이동한 책임:

- 날짜별 세션 목록 로딩
- loading / empty / error 상태
- `visibleMonth`
- `selectedDay`
- `selectedDateText`
- `moveMonth`
- `selectDay`
- 상세 세션 조회

보류한 책임:

- LocalSessionRepository 기반 로컬 우선 조회 전환

History 조회는 현재 `SessionHistoryRepository` 기반 서버 조회 흐름을 유지했다. 1단계에서 `session_result`는 로컬에 먼저 저장되지만, 기록 탭을 바로 로컬 우선 조회로 바꾸려면 서버/로컬 병합 정책, sync 상태, 중복 제거 기준이 필요하므로 별도 설계로 분리했다.

개선된 점:

- 기록 화면에서 날짜 계산과 세션 로딩 책임이 분리되었다.
- 월 이동/날짜 선택 후 목록 갱신 흐름이 ViewModel 안에 모였다.
- 상세 화면도 Repository를 직접 호출하지 않고 ViewModel을 통해 조회하게 되었다.
- 추후 로컬 우선 조회 정책을 도입할 때 화면 변경 없이 ViewModel/Repository 쪽에서 확장하기 쉬워졌다.

### 13.6 StatsRepository + StatsViewModel 도입

통계 화면에서 `ApiService`를 직접 호출하던 구조를 제거하고, `StatsRepository`와 `StatsViewModel`을 도입했다.

이동한 책임:

- weekly stats API 호출
- weekly heatmap API 호출
- weekly balance API 호출
- 통계 loading / error / data 상태
- `weekOffset`
- `weekStart`
- `weekStartText`
- `moveWeek`
- selectedTab / selectTab

보류한 책임:

- selectedExercise 필터
- selectedPeriod 필터

운동별/기간별 필터는 기존 기능 이동이 아니라 새 기능 추가에 가까우므로 이번 구조 안정화 MR에서는 제외했다.

개선된 점:

- 통계 화면이 API 호출 세부사항을 직접 알지 않게 되었다.
- 통계 데이터 로딩 상태가 ViewModel에 모였다.
- 주차 이동과 선택 탭 상태가 ViewModel에 모여 화면 책임이 줄었다.
- 추후 히트맵/밸런스/추세 데이터를 실제 서버 응답 구조에 맞춰 확장하기 쉬워졌다.

### 13.7 Domain Repository Interface 부분 도입

UseCase가 data layer 구현체를 직접 import하는 구조를 줄이기 위해 domain repository interface를 일부 도입했다.

도입한 interface:

- `IWorkoutRepository`
- `IDeviceConnectionRepository`
- `ICalibrationRepository`

개선된 점:

- UseCase가 concrete data repository에 직접 의존하는 범위가 줄었다.
- domain layer가 data layer 구현체를 덜 알게 되어 의존 방향이 더 자연스러워졌다.
- 테스트나 mock 대체가 쉬워지는 기반이 생겼다.
- 단, Session/History 쪽 interface는 로컬/서버 조회 정책 설계가 먼저 필요하므로 이번 MR에서는 무리하게 도입하지 않았다.

### 13.8 구조적으로 좋아진 관점

이번 작업으로 좋아진 부분은 단순히 파일을 나눈 것이 아니라, 변경 이유와 책임이 더 분명해졌다는 점이다.

```text
Before
View -> getIt -> Repository/Service 직접 호출 -> setState

After
View -> ViewModel -> Repository/UseCase -> Service/API/WebSocket/Local DB
```

좋아진 관점:

- 유지보수성: 화면 파일에서 통신/로딩/선택 상태가 빠져 기능 수정 위치를 찾기 쉬워졌다.
- 테스트 가능성: ViewModel/UseCase 단위로 검증할 수 있는 책임이 늘어났다.
- 확장성: Pi 통신, 로컬 저장, 서버 API, 통계 필터를 화면 변경 없이 확장할 여지가 커졌다.
- 회귀 안정성: UI를 다시 쓰지 않고 책임만 이동했기 때문에 화면 디자인 변경 위험을 줄였다.
- 의존성 관리: domain usecase가 data 구현체를 직접 아는 범위를 줄이기 시작했다.
- 협업성: 화면 담당, 통신 담당, 저장 담당의 작업 경계가 더 명확해졌다.

### 13.9 남은 과제

이번 MR에서 의도적으로 하지 않은 작업도 있다.

- Workout timer의 ViewModel 이동
- History의 LocalSessionRepository 우선 조회 전환
- 서버/로컬 session 병합 정책
- Stats의 운동별/기간별 필터 추가
- SessionRepository interface 도입
- Pi 실연결 기반 workout 진행 화면 통합 테스트
- session_result 생성 후 기록 상세 화면 회귀 테스트

특히 History 로컬 우선 조회는 단순히 Repository만 바꾸면 되는 문제가 아니다. 로컬 저장 데이터와 서버 조회 데이터가 동시에 존재할 수 있으므로, 중복 제거 기준과 sync 상태 정책을 먼저 정한 뒤 진행해야 한다.

### 13.10 이번 작업의 결론

이번 MVVM 안정화 작업은 "화면을 예쁘게 바꾸는 작업"이 아니라 "앞으로 기능이 붙어도 버틸 수 있게 책임을 정리하는 작업"이었다.

그 결과, 운동 진행, 운동 준비, 기록, 통계 흐름에서 화면이 직접 통신과 데이터 로딩을 담당하던 구조가 줄었고, ViewModel/Repository/UseCase 계층이 더 분명해졌다.

다음 기능 작업부터는 새 기능을 화면 파일에 바로 붙이기 전에 아래 순서를 먼저 확인한다.

```text
1. 이 상태는 ViewModel이 가져야 하는가?
2. 이 동작은 UseCase가 필요한가?
3. 데이터 출처는 API, Pi WebSocket, Local DB 중 무엇인가?
4. Repository interface가 필요한가?
5. 서버/로컬 데이터 병합 정책이 필요한가?
6. 화면은 UI 렌더링과 이벤트 연결만 하고 있는가?
```
