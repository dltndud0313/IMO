# 백엔드 작업 총정리

> **기간**: 2026-04-28
> **범위**: `backend/` 전체 (FastAPI + PostgreSQL + Alembic)
> **목적**: `IMO_API_Specification.md` v1.0 (MVP) 명세에 맞춰 전면 정합화 + 로컬 동작 검증

---

## 1. 한 줄 요약

> Phase 1~7 코드 작업 + 12단계 cURL 검증 완료. 로컬 도커 환경에서 명세 100% 준수 확인.

---

## 2. Phase별 변경 요약

| Phase | 영역 | 핵심 변경 |
|-------|------|-----------|
| 1 | 공통 인프라 | 응답/에러 헬퍼, camelCase 베이스 모델, JWT 시크릿 분리, CORS 화이트리스트, 글로벌 예외 핸들러 |
| 2 | Auth | 회원가입 시 토큰 즉시 발급, refresh 별도 시크릿/`type` claim, refresh rotation |
| 3 | Users | `body_scan_data` 컬럼 추가, Settings 중첩 구조 + partial update, `confirmText` 검증 |
| 4 | Sessions | `user_id` JWT 강제(보안), 세션 상세 풍부화 (graphs는 빈 배열 — Option A), FK flush 처리 |
| 5 | Statistics | `weekStart` 필수 파라미터, `summary/dailyBreakdown/trends`, `muscles[]`, `balancePairs[]` |
| 6 | Exercises | `success_response` 래핑 |
| 7 | 운영 | Alembic 마이그레이션 자동 적용, 기본 로깅, entrypoint.sh |

상세는 [`backend_implementation_plan.md`](backend_implementation_plan.md) 참고.

---

## 3. 검증 중 발견·수정한 버그 6건

| # | 버그 | 원인 | 수정 |
|---|------|------|------|
| 1 | `EmailStr` import 시 `email-validator` 누락 | Pydantic의 EmailStr 타입은 별도 패키지 의존 | `requirements.txt` 에 `email-validator==2.1.1` + `pydantic[email]` |
| 2 | bcrypt 해시 호출 시 `password cannot be longer than 72 bytes` | passlib 1.7.4(2020 last) ↔ 최신 bcrypt 호환성 | `bcrypt==4.0.1` 핀 |
| 3 | POST /sessions 시 FK violation | `session_id`(unique String) FK는 SQLAlchemy 의존성 자동 정렬 안 됨 | 부모 INSERT 후 `await db.flush()` |
| 4 | DB 컨테이너 첫 실행 시 SQL 에러 가능성 | `backend_db_schema.sql` 이 MySQL 문법인데 Postgres init 으로 마운트 | docker-compose 마운트 제거 (Alembic 이 스키마 책임) |
| 5 | docker-compose.yml `version: '3.8'` 경고 | obsolete | 라인 제거 |
| 6 | 컨테이너 안에서 만든 alembic 파일이 호스트에 안 보임 | api 서비스 volume mount 누락 | `volumes: - ./:/app` 추가 |

---

## 4. 로컬 검증 결과 (12단계 cURL 골든 패스)

| # | 단계 | 검증 포인트 | 결과 |
|---|------|-------------|------|
| 1 | 서버 부팅 | uvicorn / alembic upgrade head | ✅ |
| 2 | DB 마이그레이션 | 7개 테이블 생성 | ✅ |
| 3 | 헬스체크 `GET /` | 외부 도달 가능 | ✅ |
| 4 | `POST /auth/signup` | `{success, data, error}` + camelCase + 5필드(`userId/email/nickname/accessToken/refreshToken`) | ✅ |
| 5 | `GET /users/me/profile` | Bearer 인증, `bodyScanData` 컬럼, camelCase | ✅ |
| 6 | `GET /users/me/settings` | `wearable.*` / `notifications.*` 중첩 구조 + 자동 생성 기본값 | ✅ |
| 7 | `POST /sessions` | `user_id` JWT 강제, 5개 테이블 분산 저장 | ✅ |
| 8 | `GET /sessions/{id}` | `overallSummary` (completionRate=97.1), `muscleBalance` (ratio=92.9 BALANCED), `graphs.*Timeline=[]` | ✅ |
| 9 | `GET /statistics/weekly?weekStart=...` | `summary/dailyBreakdown(7일)/trends(3종)` + 정확한 계산값 | ✅ |
| 10 | 잘못된 비번 로그인 | `error.code: UNAUTHORIZED` | ✅ |
| 11 | 토큰 없이 보호 엔드포인트 | `error.code: UNAUTHORIZED` (글로벌 핸들러 동작) | ✅ |
| 12 | 중복 이메일 회원가입 | `error.code: DUPLICATE_EMAIL` | ✅ |

---

## 5. 변경된 파일 전체 목록

### 신규 파일 (10개)
- `backend/core/responses.py` — 응답 포맷 헬퍼
- `backend/core/exceptions.py` — 도메인 에러 + 표준 에러 단축 헬퍼
- `backend/schemas/_base.py` — `CamelModel` 베이스
- `backend/alembic.ini` — Alembic 설정
- `backend/alembic/env.py` — Alembic 환경 (asyncpg → psycopg2 변환)
- `backend/alembic/script.py.mako` — 마이그레이션 템플릿
- `backend/alembic/versions/.gitkeep`
- `backend/alembic/versions/2026_04_28_0607-af4a8ae8f0ab_init_schema.py` — 첫 마이그레이션
- `backend/entrypoint.sh` — 컨테이너 시작 시 마이그레이션 + uvicorn
- `backend/_dev_sample_session.json` — 로컬 검증용 샘플 (운영 git 무시 권장)

### 수정 파일 (12개)
- `backend/main.py` — 글로벌 예외 핸들러, CORS 화이트리스트, lifespan에서 create_all 제거
- `backend/Dockerfile` — entrypoint.sh CMD
- `backend/docker-compose.yml` — version 제거, volume mount, 환경변수 추가
- `backend/requirements.txt` — `email-validator`, `bcrypt==4.0.1` 추가
- `backend/core/config.py` — JWT access/refresh 분리, CORS_ORIGINS 환경변수
- `backend/core/security.py` — `create_refresh_token`, `decode_refresh_token`, type claim
- `backend/core/deps.py` — 새 디코더 사용
- `backend/models/user.py` — `body_scan_data`, UserSettings 모델 전면 개편
- `backend/schemas/auth.py` — Signup/Login/Refresh Response, camelCase
- `backend/schemas/user.py` — Profile/Settings 중첩 구조, partial update, DataDelete
- `backend/schemas/session.py` — `user_id` 필드 제거
- `backend/schemas/statistics.py` — Weekly Summary/Heatmap/Balance 명세 응답 구조
- `backend/api/routes/auth.py` — 라우터 3종 명세 응답 + 표준 에러
- `backend/api/routes/users.py` — 라우터 5종 명세 응답
- `backend/api/routes/sessions.py` — 보안 + 풍부화 + FK flush
- `backend/api/routes/statistics.py` — `weekStart` + MUSCLE_LOOKUP + trend 판정
- `backend/api/routes/exercises.py` — `success_response` 래핑

---

## 6. 다른 팀에 공유할 사항

### 앱 팀 (Flutter) ⚠️ 12개 변경

> 앱 팀이 클라이언트 측을 수정해야 하는 항목.

1. **응답 포맷 통일** — 모든 응답 `{success, data, error}` 래핑 → interceptor 1회 작성
2. **에러 응답 변경** — `error.code` / `error.message` 사용 (기존 `detail` 폐기)
3. **필드명 camelCase 전환** — `height_cm` → `heightCm` 등 전 응답 적용
4. **회원가입 응답 강화** — 토큰 즉시 발급, 자동 로그인 가능
5. **로그인 응답에 refreshToken 추가** — secure storage 저장 필수
6. **Refresh token rotation** — `/auth/refresh` 호출 시 새 refresh 토큰도 받음
7. **POST /sessions에서 user_id 제거** — payload에 더 이상 포함 X (백엔드가 JWT에서 강제)
8. **세션 상세 응답 풍부화** — `overallSummary, muscleBalance, graphs.*` 추가. 단 `graphs.*Timeline`은 v1에서 빈 배열
9. **Settings 구조 변경** — 평면 → 중첩(`wearable.*`, `notifications.*`). 신규 필드: `raspberryPiPort, glassConnected, glassDeviceName, notifications.{exerciseReminder, weeklyReport}`
10. **DELETE /me/data** — body에 `{"confirmText": "DELETE ALL DATA"}` 필수
11. **Statistics 호출 시 `weekStart` 필수** — `YYYY-MM-DD` (월요일)
12. **Statistics 응답 구조 전면 개편** — `summary/dailyBreakdown/trends`, `muscles[]`, `balancePairs[]`

### Pi 팀 ⚪ 변경 없음

- WebSocket 프로토콜 그대로
- `session_result` JSON 필드명만 명세서 §2-2 #9와 일치하는지 한 번만 확인 요청

---

## 7. 미해결 / v1.1 보류 항목

| # | 항목 | 보류 이유 |
|---|------|-----------|
| 1 | rep 단위 timeline 실데이터 | Pi 출력 자체에 rep 단위 데이터 없음. Pi 팀 협의 필요 |
| 2 | `bodyScanData` 실제 활용 | 바디 스캔 기능 기획 미정 |
| 3 | 푸시 알림 발송 (FCM) | settings 필드만 우선, 발송 로직은 후순위 |
| 4 | `glassConnected` 런타임 동기화 | Lenovo Legion Glasses는 USB-C 외장 모니터로 페어링 개념 없음 |
| 5 | rate limiting | 운영 안정화 단계 |
| 6 | 테스트 코드 (`pytest`) | Phase 7 이후 별도 작업 |
| 7 | 시간대(KST/UTC) 일관화 | 통계 경계 정확화 시 재검토 |

---

## 8. 검증 환경 메모

- OS: Windows 11
- 셸: Git Bash (한글 입력은 git bash + curl 조합에서 인코딩 문제 있음 — 영문으로 검증)
- Docker Desktop: v29.1.3
- DB: postgres:15-alpine 컨테이너
- 백엔드: 자체 빌드 컨테이너 (Python 3.11-slim 베이스)
- 검증 시점 KST: 2026-04-28 15:09 (UTC 06:09)

---

## 9. 다음 단계

→ [`backend_roadmap.md`](backend_roadmap.md) 참고

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| v1.0 | 2026-04-28 | 최초 작성 — Phase 1~7 + 로컬 검증 12단계 완료 |
