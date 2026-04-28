# Backend 명세 정합화 구현 계획

> **작성일**: 2026-04-28
> **목적**: 현재 백엔드 구현을 `IMO_API_Specification.md` v1.0(MVP) 명세에 정합시키기 위한 단계별 작업 계획서.
> **대상 영역**: `backend/` 디렉토리 전체 (FastAPI + PostgreSQL).

---

## 0. 사전 결정 사항

### 0-1. rep 단위 timeline 처리 방안 — **Option A (빈 배열 응답)** 채택

명세서 §2-2 #9 `session_result`(Pi → 앱) 페이로드에는 rep 단위 데이터가 없으나, §3-3 API-08 `GET /sessions/{id}` 응답에는 `graphs.repActivationTimeline / speedTimeline / stabilityTimeline` 같은 rep 단위 시계열이 명시되어 있다 — 명세 내부 모순.

| 옵션 | 내용 | 채택 여부 |
|------|------|-----------|
| **A** | rep timeline은 빈 배열 `[]`로 응답 (필드는 유지). Pi/앱 변경 없음. | ✅ |
| B | set 단위로 축소 (set별 1포인트) | ❌ |
| C | Pi 팀 협의 → session_result 확장 → DB 테이블 신규 | ❌ (v1.1로 보류) |

> Pi가 rep 단위 데이터를 보내기 시작하면 v1.1에서 채운다.

### 0-2. 명세 100% 적용 원칙

사용자 합의에 따라 명세에 있는 필드는 모두 응답한다. **실제 동작 인프라가 없는 필드도 형태는 유지**한다.

| 필드 | 명세 위치 | 실제 인프라 | 처리 |
|------|-----------|--------------|------|
| `notifications.{exerciseReminder, weeklyReport}` | API-13/14 | FCM 등 푸시 미구현 | DB 컬럼만 추가, 실제 발송 로직 없음 |
| `wearable.{glassConnected, glassDeviceName}` | API-13/14 | Lenovo Legion Glasses는 USB-C 외장 모니터(페어링 X) | DB 컬럼은 추가, 항상 `false`/`null` 가능 |
| `bodyScanData` | API-04 | 바디 스캔 기능 미구현 | nullable 컬럼만 추가, 항상 `null` |
| `graphs.repActivationTimeline` 외 | API-08 | rep 단위 데이터 없음 | 빈 배열 응답 |

---

## 1. 공통 변경 원칙

### 1-1. 응답 포맷
모든 라우터는 `{success, data, error}` 구조로 통일한다.
```json
// 성공
{ "success": true, "data": { ... }, "error": null }
// 실패
{ "success": false, "data": null, "error": { "code": "STRING", "message": "STRING" } }
```

### 1-2. 필드명 컨벤션
- DB/Python 내부: `snake_case` 유지
- HTTP 응답/요청: `camelCase` (Pydantic `alias_generator`로 변환)

### 1-3. 인증
- Access Token: 짧게 (e.g. 30분)
- Refresh Token: 길게 (e.g. 14일), **별도 시크릿 + `type: refresh` claim**

### 1-4. 에러 코드 표준
명세 §4 표를 따른다. `INVALID_REQUEST`, `VALIDATION_ERROR`, `UNAUTHORIZED`, `TOKEN_EXPIRED`, `FORBIDDEN`, `SESSION_NOT_FOUND`, `USER_NOT_FOUND`, `DUPLICATE_EMAIL`, `INTERNAL_ERROR`.

---

## 2. Phase별 작업 계획

### Phase 1 — 공통 인프라

**목표**: 이후 Phase에서 그냥 갖다 쓸 수 있는 공통 모듈/설정 정비.

**작업 항목**:
1. `core/responses.py` (신규) — `success_response(data)`, `error_response(code, message)` 헬퍼
2. `core/exceptions.py` (신규) — `APIException(code, message, status_code)` 정의
3. `main.py` — 글로벌 exception handler 등록 (`HTTPException`, `RequestValidationError`, `APIException`, `Exception` 4종)
4. `schemas/_base.py` (신규) — `CamelModel` 베이스 클래스 (`alias_generator=to_camel`, `populate_by_name=True`)
5. `core/config.py` — `JWT_SECRET`, `JWT_REFRESH_SECRET`, `ACCESS_TOKEN_EXPIRE_MINUTES`, `REFRESH_TOKEN_EXPIRE_DAYS`, `CORS_ORIGINS` 분리 + 기본값에서 시크릿 제거(필수 환경변수)
6. `main.py` — CORS 화이트리스트 적용

**다른 팀에 알릴 변경**:
- 모든 응답이 `{success, data, error}`로 감싸짐 → 앱은 `response.data.<field>`로 접근
- 에러 응답이 `error.code` / `error.message`로 변경 → 앱의 에러 핸들러 변경

---

### Phase 2 — Auth (API-01 ~ 03)

**작업 항목**:
1. `core/security.py` — `create_access_token`, `create_refresh_token`(별도 시크릿/만료/`type` claim) 추가
2. `core/security.py` — `decode_refresh_token` 추가 (refresh 시크릿으로만 검증, `type=="refresh"` 확인)
3. `schemas/auth.py` — `SignupResponse`, `LoginResponse`, `RefreshResponse` 명세대로 정의
4. `api/routes/auth.py`
   - `POST /signup`: `userId, email, nickname, accessToken, refreshToken` 반환
   - `POST /login`: `userId, accessToken, refreshToken` 반환
   - `POST /refresh`: refresh 시크릿으로 검증 → 새 access + 새 refresh(rotation) 반환

**다른 팀에 알릴 변경**:
- 앱: 회원가입 직후 토큰을 받아 자동 로그인 가능
- 앱: refresh token을 secure storage에 저장 + refresh 후 token rotation 처리

---

### Phase 3 — Users (API-04, 05, 13, 14, 15)

**작업 항목**:

`models/user.py`:
1. `User`에 `body_scan_data` (JSONB, nullable) 추가
2. `UserSettings` 모델 전면 개편
   - 기존: `tts_enabled, raspberry_pi_ip, wearable_type, auto_connect`
   - 신규:
     - `tts_enabled: bool`
     - `raspberry_pi_ip: str?`
     - `raspberry_pi_port: int?` ← **신규**
     - `glass_connected: bool` ← **신규**
     - `glass_device_name: str?` ← **신규**
     - `notifications_exercise_reminder: bool` ← **신규**
     - `notifications_weekly_report: bool` ← **신규**

`schemas/user.py`:
3. `UserProfileResponse` — camelCase, `bodyScanData` 포함
4. `WearableSettings`, `NotificationSettings`, `UserSettingsResponse` 중첩 구조
5. `UserSettingsUpdate` — 모든 필드 optional (partial update)
6. `UserDataDeleteRequest` — `confirmText: str`

`api/routes/users.py`:
7. `GET /me/profile` — 명세 응답 구조
8. `PUT /me/profile` — 명세 응답 구조
9. `GET /me/settings` — 중첩 응답
10. `PUT /me/settings` — partial update + 중첩 응답
11. `DELETE /me/data` — `confirmText == "DELETE ALL DATA"` 검증, 일치 안 하면 `VALIDATION_ERROR`
12. 운동 데이터 삭제 시 삭제된 세션 개수 반환

**다른 팀에 알릴 변경**:
- 앱: 모든 user 응답 필드명 camelCase 전환
- 앱: settings 화면이 `wearable.*`, `notifications.*` 중첩 구조로 변경
- 앱: 데이터 초기화 시 body에 `{"confirmText": "DELETE ALL DATA"}` 필수

---

### Phase 4 — Sessions (API-06 ~ 09)

**작업 항목**:

`schemas/session.py`:
1. `SessionCreate`에서 `user_id` 필드 제거 (보안)

`api/routes/sessions.py`:
2. `POST /sessions` — payload의 `user_id` 무시, JWT의 `current_user.id` 강제 사용 + `sessionId/createdAt` 응답
3. `GET /sessions` — 응답 그대로 유지하되 `{success, data, error}` 래핑
4. `GET /sessions/{sessionId}` — 응답 풍부화
   - `overallSummary`: `totalReps, totalTargetReps, completionRate, avgTargetActivation, totalCompensationCount, avgStabilityScore, fatigueOnsetSet, fatigueOnsetRep`
   - `muscleBalance`: `WorkoutBalanceSummary`에서 추출 (`leftAvg, rightAvg, balanceRatio, status`)
   - `graphs.repActivationTimeline / speedTimeline / stabilityTimeline`: 빈 배열 (Option A)
   - `sets[].repDetails`: 빈 배열
   - `sets[].avgTargetActivation, stabilityScore`: 현재 미저장이면 0 또는 nullable
5. `DELETE /sessions/{sessionId}` — `deletedSessionId` 반환

**다른 팀에 알릴 변경**:
- 앱: `POST /sessions` 페이로드에서 `user_id` 제거
- 앱: 세션 상세 응답에서 `graphs.*Timeline`이 일단 빈 배열임을 인지 (차트 빈 상태 처리)

---

### Phase 5 — Statistics (API-10 ~ 12)

**작업 항목**:

`schemas/statistics.py` 전면 개편:
1. `WeeklySummaryResponse` — `weekStart, weekEnd, exerciseType, summary{...}, dailyBreakdown[], trends{...}`
2. `WeeklyHeatmapResponse` — `weekStart, weekEnd, muscles[{muscleId, muscleName, side, avgActivation, activationLevel, sessionCount}]`
3. `WeeklyBalanceResponse` — `weekStart, weekEnd, balancePairs[{muscleName, left, right, balanceRatio, dominantSide, status}]`

`api/routes/statistics.py`:
4. 공통: `weekStart` 쿼리 파라미터 필수 (YYYY-MM-DD, 월요일), `exerciseType` 옵션
5. `weekStart` ~ `weekStart + 6일` 범위 (KST/UTC 통일 — UTC로 저장된 `started_at`을 KST로 변환 후 일자 기준)
6. `GET /weekly`
   - `summary`: 주간 합계 + `avgCompletionRate`(target 합 대비 actual), `avgTargetActivation`(가중평균 또는 단순평균)
   - `dailyBreakdown`: 7일 각각의 `{date, sessions, totalReps}` (운동 없는 날은 0)
   - `trends`: `targetActivation`, `compensationRate`, `fatigue` 3종 — 세션 시계열 + 단순 비교(첫 vs 마지막)로 INCREASING/DECREASING/STABLE 판정
7. `GET /weekly/heatmap`
   - `WorkoutMuscleMap.body_part` → `muscleId/muscleName/side` 매핑 룩업 테이블 (코드 상수)
   - `avgActivation` 평균값에 따라 `activationLevel` 5단계(`VERY_LOW` ~ `VERY_HIGH`) 산출
8. `GET /weekly/balance`
   - `WorkoutBalanceSummary` 좌/우 값 평균
   - `balanceRatio` = min(left,right)/max(left,right) * 100
   - `status`: 명세 §5-8 기준 (BALANCED ≥90, MILD 75~90, SIGNIFICANT <75)

**다른 팀에 알릴 변경**:
- 앱: 통계 화면 호출 시 `weekStart=YYYY-MM-DD` 쿼리 필수 (월요일)
- 앱: 응답 구조가 완전히 바뀌므로 차트 위젯 데이터 매핑 재작성

---

### Phase 6 — Exercises (API-16)

**작업 항목**:
1. `api/routes/exercises.py` — 응답을 `{success, data, error}`로 래핑만 (이미 완료된 상태)
2. 카탈로그는 그대로 유지

**다른 팀에 알릴 변경**: 없음 (응답 래핑 정도)

---

### Phase 7 — 운영

**작업 항목**:
1. Alembic 초기화
   - `alembic init alembic`
   - `alembic/env.py`에 `Base.metadata` 연결
   - 첫 마이그레이션 생성 (현재 스키마 + Phase 3 변경분)
2. `main.py` lifespan에서 `create_all` 제거 (Alembic이 책임지도록)
3. `docker-compose.yml` — 컨테이너 시작 시 `alembic upgrade head` 실행
4. 기본 로깅 설정 (`logging.basicConfig` + uvicorn access log)
5. `requirements.txt` 점검

**다른 팀에 알릴 변경**: 없음 (운영 변경)

---

## 3. 영향받는 파일 매트릭스

| 파일 | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 | Phase 6 | Phase 7 |
|------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| `core/config.py` | ✏️ | | | | | | |
| `core/responses.py` | ✨ | | | | | | |
| `core/exceptions.py` | ✨ | | | | | | |
| `core/security.py` | | ✏️ | | | | | |
| `core/deps.py` | | ✏️ | | | | | |
| `schemas/_base.py` | ✨ | | | | | | |
| `schemas/auth.py` | | ✏️ | | | | | |
| `schemas/user.py` | | | ✏️ | | | | |
| `schemas/session.py` | | | | ✏️ | | | |
| `schemas/statistics.py` | | | | | ✏️ | | |
| `schemas/exercise.py` | | | | | | (변경 없음) | |
| `models/user.py` | | | ✏️ | | | | |
| `models/session.py` | | | | (변경 없음) | | | |
| `api/routes/auth.py` | | ✏️ | | | | | |
| `api/routes/users.py` | | | ✏️ | | | | |
| `api/routes/sessions.py` | | | | ✏️ | | | |
| `api/routes/statistics.py` | | | | | ✏️ | | |
| `api/routes/exercises.py` | | | | | | ✏️ | |
| `main.py` | ✏️ | | | | | | ✏️ |
| `docker-compose.yml` | | | | | | | ✏️ |
| `alembic/` | | | | | | | ✨ |

✨ = 신규, ✏️ = 수정

---

## 4. 다른 팀에 공유할 마이그레이션 노트(요약)

### 앱 팀 (Flutter)
중요도 ⚠️ 높음 — Phase별로 PR 단위 노티 진행:

1. **응답 포맷 통일** — 모든 응답 `{success, data, error}` 래핑. interceptor 1회 작성.
2. **에러 응답 변경** — `error.code` / `error.message` 사용. (기존 `detail` 폐기)
3. **필드명 camelCase 전환** — `height_cm` → `heightCm` 등 전 응답 적용.
4. **회원가입 응답 강화** — 토큰 즉시 발급, 자동 로그인 가능.
5. **로그인 응답에 refreshToken 추가** — secure storage 저장 필수.
6. **Refresh token rotation** — `/auth/refresh` 호출 시 새 refresh 토큰도 받음.
7. **POST /sessions에서 user_id 제거** — payload에 더 이상 포함 X.
8. **세션 상세 응답 풍부화** — `overallSummary, muscleBalance, graphs.*` 추가. 단 `graphs.*Timeline`은 v1에서 빈 배열.
9. **Settings 구조 변경** — 평면 → 중첩(`wearable.*`, `notifications.*`). 신규 필드: `raspberryPiPort, glassConnected, glassDeviceName, notifications.{exerciseReminder, weeklyReport}`.
10. **DELETE /me/data** — body에 `{"confirmText": "DELETE ALL DATA"}` 필수.
11. **Statistics 호출 시 `weekStart` 필수** — YYYY-MM-DD(월요일).
12. **Statistics 응답 구조 전면 개편** — `summary/dailyBreakdown/trends`, `muscles[]`, `balancePairs[]`.

### Pi 팀
중요도 ⚪ 낮음 — 변경 없음:

- 백엔드 변경은 Pi ↔ 앱 WebSocket 프로토콜에 영향을 주지 않음.
- 단, `session_result` JSON 필드명이 명세서 §2-2 #9와 정확히 일치하는지 한 번만 확인 요청.

---

## 5. 미해결 이슈 / 추후 과제

| # | 항목 | 비고 |
|---|------|------|
| 1 | rep 단위 timeline 실데이터 채우기 | Pi 팀 협의 후 v1.1 |
| 2 | `bodyScanData` 실제 활용 | 바디 스캔 기능 기획 미정 |
| 3 | 푸시 알림 발송 인프라 (FCM 등) | settings 필드만 우선, 발송 로직은 v1.1 |
| 4 | `glassConnected` 런타임 상태 동기화 | 페어링 개념 없음 — 항상 false도 허용 |
| 5 | rate limiting | 운영 안정화 단계에서 |
| 6 | 테스트 코드 (`pytest`) | Phase 7 이후 별도 작업 |
| 7 | 시간대 처리 (KST/UTC) 일관화 | Phase 5에서 확정 |

---

## 6. 진행 방식

- **브랜치**: `feature/backend-spec-alignment` (단일 브랜치)
- **커밋 단위**: Phase 1 ~ 7 각각을 1개 이상의 작은 커밋으로 분할
- **검증**: Phase 별 완료 시 수동 cURL 테스트로 명세 준수 확인
- **앱 팀 노티**: Phase 단위 완료 시점마다 변경사항 공유

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| v1.0 | 2026-04-28 | 최초 작성 |
