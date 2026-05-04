# 앱 센서 부착 매핑 기준

## 1. 목적

이 문서는 앱, Pi, 서버, 스마트글래스가 같은 센서 채널을 같은 의미로 해석하기 위한 공통 기준이다.

핵심은 센서 채널 번호는 고정하고, 운동 종류에 따라 각 채널이 의미하는 근육/부위만 바꾸는 것이다.

이 문서는 아래 작업의 기준으로 사용한다.

- 센서 부착 안내 화면
- Pi 캘리브레이션/운동 시작 흐름
- `session_result.muscle_map`
- 이후 히트맵/밸런스 분석

## 2. 운동 준비 흐름 기준

앱의 운동 준비 흐름은 아래 순서를 기준으로 한다.

1. 운동 선택
2. 운동 계획 설정
3. Pi로 `submit_workout_plan` 전송
4. 센서 부착 안내
5. 사용자가 센서부착완료 버튼 선택
6. Pi로 `start_calibration` 전송
7. Pi가 캘리브레이션 진행 후 상태 전송
8. 운동 진행 화면에서 운동 상태와 제어 버튼 표시

센서 부착 매핑 기준은 4번 센서 부착 안내 화면부터 사용한다.

## 3. 공통 채널 규칙

앱, Pi, 서버, 스마트글래스는 센서 채널을 아래 의미로 고정해서 사용한다.

| 채널 | 고정 역할 | 목적 |
| --- | --- | --- |
| EMG1 | 왼쪽 주동근 | 왼쪽 주요 근육 활성도 측정 |
| EMG2 | 오른쪽 주동근 | 오른쪽 주요 근육 활성도 측정 |
| EMG3 | 왼쪽 보조/보상근 | 왼쪽 보조근 또는 보상근 개입 측정 |
| EMG4 | 오른쪽 보조/보상근 | 오른쪽 보조근 또는 보상근 개입 측정 |
| IMU1 | 왼쪽 팔 | 왼쪽 팔의 궤적, 속도, 흔들림 확인 |
| IMU2 | 오른쪽 팔 | 오른쪽 팔의 궤적, 속도, 흔들림 확인 |
| IMU3 | 몸통 | 몸통 정렬, 흔들림, 반동 보상 확인 |

## 4. 설계 원칙

- EMG는 주동근과 보상근을 함께 본다.
- IMU는 동작 궤적, 좌우 비대칭, 몸통 흔들림을 보기 위한 용도로 쓴다.
- 센서 채널 번호는 운동마다 바꾸지 않는다.
- 운동별 매핑에서는 각 고정 채널의 의미만 바꾼다.
- 앱은 운동 중 고주기 실시간 센서 스트림을 직접 받지 않는다.
- 앱은 상태 이벤트와 최종 `session_result`를 받고, 상세 분석 값은 `muscle_map` 같은 요약 필드로 표현한다.

## 5. WebSocket 메시지 경계

센서 채널 규칙은 WebSocket 메시지 이름을 바꾸지 않는다.

현재 메시지 이름은 그대로 유지한다.

- `submit_workout_plan`
- `start_calibration`
- `pause_workout`
- `resume_workout`
- `stop_workout`
- `emergency_stop`
- `session_result`

운동 계획 payload key도 그대로 유지한다.

- `exercise_type`
- `set_count`
- `target_reps_per_set`
- `rest_sec`

## 6. 표기 원칙

앱 화면에 표시되는 부위명과 안내 문구는 한국어를 사용한다.

예:

- 왼쪽 대흉근
- 오른쪽 대흉근
- 왼쪽 삼두근
- 오른쪽 삼두근
- 왼쪽 이두근
- 오른쪽 이두근
- 왼쪽 전완근
- 오른쪽 전완근
- 왼쪽 측면 삼각근
- 오른쪽 측면 삼각근
- 왼쪽 상부 승모근
- 오른쪽 상부 승모근
- 몸통

다만 코드, WebSocket, API payload에서 사용하는 식별자는 영어 key를 유지한다.

예:

- `pushup`
- `bicep_curl`
- `lateral_raise`
- `muscle_map`
- `left_biceps`
- `right_biceps`

즉, 화면 표시명은 한국어, 데이터 식별자는 영어 key로 분리한다.

## 7. 운동별 센서 부착 매핑

### 7-1. Push-up

`exercise_type`: `pushup`

| 채널 | 화면 표시명 | 데이터 key | 부착 위치 | 분석 목적 |
| --- | --- | --- | --- | --- |
| EMG1 | 왼쪽 대흉근 | `left_chest` | 왼쪽 가슴 대흉근 부위 | 왼쪽 주동근 활성도 |
| EMG2 | 오른쪽 대흉근 | `right_chest` | 오른쪽 가슴 대흉근 부위 | 오른쪽 주동근 활성도 |
| EMG3 | 왼쪽 삼두근 | `left_triceps` | 왼쪽 상완 뒤쪽 삼두근 부위 | 왼쪽 보조근/보상근 개입 |
| EMG4 | 오른쪽 삼두근 | `right_triceps` | 오른쪽 상완 뒤쪽 삼두근 부위 | 오른쪽 보조근/보상근 개입 |
| IMU1 | 몸통 | `trunk` | 흉추 상부 또는 상부 등판 중앙 | 상체 정렬, 허리/몸통 흔들림 |
| IMU2 | 왼쪽 상완 | `left_upper_arm` | 왼쪽 상완 바깥쪽 | 왼팔 궤적, 좌우 비대칭 |
| IMU3 | 오른쪽 상완 | `right_upper_arm` | 오른쪽 상완 바깥쪽 | 오른팔 궤적, 좌우 비대칭 |

Push-up의 `muscle_map` 대표 key는 아래를 우선 사용한다.

- `left_chest`
- `right_chest`
- `left_triceps`
- `right_triceps`
- `trunk`

### 7-2. Bicep Curl

`exercise_type`: `bicep_curl`

| 채널 | 화면 표시명 | 데이터 key | 부착 위치 | 분석 목적 |
| --- | --- | --- | --- | --- |
| EMG1 | 왼쪽 이두근 | `left_biceps` | 왼쪽 상완 앞쪽 이두근 부위 | 왼쪽 주동근 활성도 |
| EMG2 | 오른쪽 이두근 | `right_biceps` | 오른쪽 상완 앞쪽 이두근 부위 | 오른쪽 주동근 활성도 |
| EMG3 | 왼쪽 전완근 | `left_forearm` | 왼쪽 전완 앞쪽 또는 바깥쪽 | 왼쪽 전완 과개입 확인 |
| EMG4 | 오른쪽 전완근 | `right_forearm` | 오른쪽 전완 앞쪽 또는 바깥쪽 | 오른쪽 전완 과개입 확인 |
| IMU1 | 왼쪽 전완 | `left_forearm_motion` | 왼쪽 손목 또는 전완 | 왼팔 컬 궤적, 속도 |
| IMU2 | 오른쪽 전완 | `right_forearm_motion` | 오른쪽 손목 또는 전완 | 오른팔 컬 궤적, 속도 |
| IMU3 | 몸통 | `trunk` | 흉추 상부 또는 가슴 중앙 근처 몸통 | 몸통 반동, 팔꿈치 축 흔들림 |

Bicep Curl의 `muscle_map` 대표 key는 아래를 우선 사용한다.

- `left_biceps`
- `right_biceps`
- `left_forearm`
- `right_forearm`
- `trunk`

### 7-3. Lateral Raise

`exercise_type`: `lateral_raise`

| 채널 | 화면 표시명 | 데이터 key | 부착 위치 | 분석 목적 |
| --- | --- | --- | --- | --- |
| EMG1 | 왼쪽 측면 삼각근 | `left_lateral_deltoid` | 왼쪽 어깨 측면 삼각근 부위 | 왼쪽 주동근 활성도 |
| EMG2 | 오른쪽 측면 삼각근 | `right_lateral_deltoid` | 오른쪽 어깨 측면 삼각근 부위 | 오른쪽 주동근 활성도 |
| EMG3 | 왼쪽 상부 승모근 | `left_upper_trapezius` | 왼쪽 목-어깨 사이 상부 승모근 부위 | 왼쪽 승모근 보상 여부 |
| EMG4 | 오른쪽 상부 승모근 | `right_upper_trapezius` | 오른쪽 목-어깨 사이 상부 승모근 부위 | 오른쪽 승모근 보상 여부 |
| IMU1 | 왼쪽 전완 | `left_forearm_motion` | 왼쪽 손목 또는 전완 | 왼팔 들어올림 각도, 반동 |
| IMU2 | 오른쪽 전완 | `right_forearm_motion` | 오른쪽 손목 또는 전완 | 오른팔 들어올림 각도, 반동 |
| IMU3 | 몸통 | `trunk` | 흉추 상부 또는 등판 중앙 | 몸통 흔들림, 반동 사용 |

Lateral Raise의 `muscle_map` 대표 key는 아래를 우선 사용한다.

- `left_lateral_deltoid`
- `right_lateral_deltoid`
- `left_upper_trapezius`
- `right_upper_trapezius`
- `trunk`

## 8. 데이터 key 사용 기준

앱, Pi, 서버는 같은 운동에 대해 위 표의 `데이터 key`를 공통으로 사용한다.

- 앱 화면에서는 `화면 표시명`을 보여준다.
- WebSocket, API, 로컬 저장, `muscle_map`에서는 `데이터 key`를 사용한다.
- `muscle_map` 값은 각 key에 대한 대표 활성도 또는 분석 요약값으로 해석한다.
- IMU key는 근활성도 자체가 아니라 자세/궤적/반동 판단 결과를 표현할 때 사용한다.

이 기준은 운동 중 실시간 수치 스트림 표시용이 아니다. 앱의 센서 부착 안내 UI와 운동 종료 후 수신하는 `session_result.muscle_map` 해석을 위한 기준이다.

## 9. 다음 범위

최종 `muscle_map` 스키마와 히트맵 상태 구조는 별도 작업에서 확정한다.
