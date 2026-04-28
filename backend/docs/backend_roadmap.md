# 백엔드 로드맵

> **작성일**: 2026-04-28
> **현재 상태**: Phase 1~7 코드 변경 완료 + 로컬 검증 종료 ([backend_summary.md](backend_summary.md) 참고)
> **다음 목표**: Redis 통합 → EC2 수동 배포 → CI/CD 자동화

---

## 0. 우선순위 원칙

> **수동으로 한 번 성공한 절차를 자동화하라.**

- Jenkins부터 만들면 수동으로도 안 되는 걸 자동화하려고 헤맴
- Redis 같은 코드 단계 추가는 EC2 가기 전에 끝내야 디버깅 쉬움
- 인프라(EC2/Nginx/HTTPS) → 자동화(Jenkins) → 알림(MM Webhook) 순

---

## 1. 단기 (이번 주)

### Task 1-1. Git 커밋 ⚡ 즉시
**왜 지금**: 6개 버그 픽스 + Phase 1~7 코드 변경 + 첫 alembic 마이그레이션 파일이 작업 트리에 떠있음. 날아가면 다시 작업 못 함.

**작업**:
- 명세 정합화 변경분을 하나의 큰 브랜치(`feature/backend-spec-alignment`)에 묶고
- Phase 단위로 작은 커밋들로 분할
- `_dev_sample_session.json` 은 `.gitignore` 에 추가 (운영 코드 아님)
- alembic 첫 마이그레이션 파일은 **반드시 커밋** (EC2/팀원 환경 동기화 핵심)

**예상 시간**: 10~30분

**예상 커밋 분할 예**:
```
chore(backend): docker-compose · volume mount + cors/jwt env
fix(backend): bcrypt 4.0.1 핀 + email-validator 추가
chore(backend): MySQL init.sql 마운트 제거 (alembic 사용)
feat(backend/phase1): 공통 응답·에러·camelCase·CORS 정비
feat(backend/phase2): refresh 시크릿/타입 분리, signup 토큰 즉시 발급
feat(backend/phase3): Settings 중첩, bodyScanData, confirmText
feat(backend/phase4): /sessions 보안 + 상세 풍부화
feat(backend/phase5): /statistics weekStart + summary/daily/trends
feat(backend/phase6): /exercises success 래핑
feat(backend/phase7): alembic + entrypoint + 로깅
fix(backend): /sessions FK 의존성 — 부모 flush 후 자식 INSERT
chore(backend): alembic init schema 첫 마이그레이션
```

---

### Task 1-2. Redis 통합 — 통계 캐싱 (Option A)
**왜**: 사용자가 "Redis 써보고 싶다" 명시. 통계 화면 응답 속도 체감 큼.

**대상 엔드포인트**:
- `GET /statistics/weekly`
- `GET /statistics/weekly/heatmap`
- `GET /statistics/weekly/balance`

**캐시 키 규칙**:
```
stats:weekly:{user_id}:{weekStart}:{exerciseType or '_'}
stats:heatmap:{user_id}:{weekStart}:{exerciseType or '_'}
stats:balance:{user_id}:{weekStart}:{exerciseType or '_'}
```

**TTL**: 5분 (300초)

**무효화 조건**:
- `POST /sessions` 시 해당 유저의 모든 `stats:*:{user_id}:*` 키 삭제 (간단)
  - 또는 해당 주차 키만 정밀 삭제 (advanced)
- `DELETE /sessions/{id}` 시 동일
- `DELETE /me/data` 시 동일

**작업 항목**:
1. `requirements.txt` 에 `redis==5.0.1` (또는 `redis-py-cluster`) 추가
2. `docker-compose.yml` 에 redis 서비스 추가 (`redis:7-alpine`)
3. `core/cache.py` 신규 — 비동기 redis 클라이언트 + JSON 직렬화 헬퍼
4. `core/config.py` — `REDIS_URL` 환경변수
5. `api/routes/statistics.py` 3개 엔드포인트에 캐시 read-through
6. `api/routes/sessions.py` POST/DELETE 시 무효화
7. 로컬 검증: 첫 호출은 DB hit, 두번째 호출은 캐시 hit (응답 속도 차이 확인)

**Redis 추가 이후 옵션 (시간 남으면)**:
- **Refresh Token Blacklist** — rotation 시 이전 refresh 토큰을 redis 에 TTL=만료시간 으로 blacklist 추가. `decode_refresh_token` 에서 blacklist 체크.

**예상 시간**: 1~2시간

---

## 2. 중기 (다음 주)

### Task 2-1. EC2 수동 배포 1회

**선행 확인 (이거 결정 안 되면 진행 X)**:
- [ ] EC2 인스턴스 발급 받았는가? (SSAFY 제공 가능성)
- [ ] 도메인 보유 여부? (없으면 EC2 IP 직접 사용 — 명세서의 `api.imo-app.com` 은 임시값)
- [ ] DB 분리 여부? (MVP는 EC2 안 도커 Postgres 로 충분)
- [ ] HTTPS 필요? (앱이 HTTP 로 붙어도 OK 면 일단 생략)

**작업 단계**:
1. EC2 SSH 접속 + Docker / Docker Compose 설치
2. 백엔드 코드 클론 또는 scp 업로드
3. `.env` 파일 작성 (운영 시크릿)
   - `JWT_SECRET=<랜덤 강한 문자열>`
   - `JWT_REFRESH_SECRET=<위와 다른 랜덤 문자열>`
   - `CORS_ORIGINS=https://<앱 도메인>` (앱이 모바일이면 실제로는 별 의미 없음 — 어차피 모바일 클라는 CORS 영향 안 받음)
   - `DATABASE_URL=postgresql+asyncpg://imo_user:<운영용 비번>@db:5432/imo_db`
   - `REDIS_URL=redis://redis:6379/0`
4. `docker-compose.yml` 운영 시 변경 — 개발용 `volumes: - ./:/app` 제거 또는 `docker-compose.override.yml` 분리
5. `docker compose up -d` → entrypoint.sh 자동 마이그레이션 + uvicorn
6. 보안그룹: 8000 인바운드 (또는 80/443 + 리버스 프록시)
7. 헬스체크: `curl http://<ec2-ip>:8000/`
8. 골든패스 cURL 12개 (로컬 검증과 동일) 재실행

**예상 시간**: 반나절

---

### Task 2-2. Nginx + HTTPS (선택)

**왜**: 발표 시 https URL이면 좋음. 8000 포트 직접 노출 회피.

**작업**:
1. EC2 에 Nginx 설치 (또는 Nginx 컨테이너)
2. 80 포트로 백엔드 8000 reverse proxy
3. Let's Encrypt 무료 SSL 발급 (도메인 필요)
4. 80 → 443 리다이렉트
5. 보안그룹: 8000 인바운드 차단, 80/443만 허용

**예상 시간**: 1~3시간 (도메인 DNS 셋업 시간 포함)

---

## 3. 장기 (스프린트 단위)

### Task 3-1. Jenkins CI/CD

**선행 확인**:
- [ ] SSAFY Jenkins 인스턴스 발급 받음? (받았다면 그것 사용)
- [ ] 못 받으면 EC2에 직접 Jenkins 설치 (별도 인스턴스 권장 — API 서버 리소스 잡아먹음)

**파이프라인 흐름**:
```
GitLab/GitHub push
  └─> Jenkins webhook
      └─> Build (docker compose build)
          └─> Test (pytest, 있으면)
              └─> SSH to EC2
                  └─> git pull / scp
                      └─> docker compose up -d --build
                          └─> alembic upgrade head (자동 — entrypoint.sh)
                              └─> Mattermost webhook 알림
```

**작업 항목**:
1. 프로젝트 루트에 `Jenkinsfile` 작성
2. Jenkins 에 GitLab/GitHub credentials 등록
3. EC2 SSH key 등록
4. 파이프라인 첫 실행 (수동 트리거) → 디버깅
5. webhook 트리거로 자동화

**예상 시간**: 1~2일

---

### Task 3-2. Mattermost Webhook 알림

**선행**:
- MM 채널에서 "Incoming Webhook" 추가 → URL 발급

**Jenkinsfile 끝에 추가**:
```groovy
post {
    success {
        sh """curl -X POST '${MM_WEBHOOK_URL}' \\
            -H 'Content-Type: application/json' \\
            -d '{"text":"✅ 백엔드 배포 성공\\n브랜치: ${env.BRANCH_NAME}\\n커밋: ${env.GIT_COMMIT}"}'"""
    }
    failure {
        sh """curl -X POST '${MM_WEBHOOK_URL}' \\
            -H 'Content-Type: application/json' \\
            -d '{"text":"❌ 백엔드 배포 실패\\n빌드 로그: ${env.BUILD_URL}"}'"""
    }
}
```

**예상 시간**: 30분

---

### Task 3-3. 테스트 코드 (pytest)

**최소 범위 — 골든 패스 자동화**:
- `tests/conftest.py` — TestClient + 테스트용 DB(SQLite 또는 별도 Postgres 컨테이너)
- `tests/test_auth.py` — signup/login/refresh
- `tests/test_users.py` — profile/settings
- `tests/test_sessions.py` — POST/GET/DELETE
- `tests/test_statistics.py` — weekStart 검증

**확장**:
- 에러 케이스 (`UNAUTHORIZED`, `DUPLICATE_EMAIL`, `VALIDATION_ERROR`)
- 보안 (다른 사용자의 sessionId 조회 시 SESSION_NOT_FOUND)

**예상 시간**: 1~2일

---

### Task 3-4. Rate Limiting

**왜**: 운영 안정성. 무차별 회원가입/로그인 차단.

**도구 후보**:
- `slowapi` (FastAPI 친화)
- Redis 기반 token bucket 직접 구현

**적용 대상**:
- `/auth/signup` — IP당 분당 5회
- `/auth/login` — IP당 분당 10회
- `/auth/refresh` — IP당 분당 30회

**예상 시간**: 2~4시간

---

## 4. v1.1 이후 (외부 의존 / 우선순위 낮음)

| # | 항목 | 차단 요인 |
|---|------|-----------|
| 1 | rep 단위 timeline 실데이터 채우기 | Pi 팀 협의 → `session_result` 페이로드 확장 → DB 테이블 신규 |
| 2 | 푸시 알림 발송 (FCM 등) | 인프라 셋업 + 앱 측 토큰 등록 |
| 3 | `bodyScanData` 활용 | 바디 스캔 기능 기획 미정 |
| 4 | 시간대(KST/UTC) 일관화 | 운영 데이터 누적 후 경계 버그 발생 시 재검토 |
| 5 | DB → RDS 분리 | 트래픽 증가 시 |
| 6 | 백엔드 다중화 (수평 확장) | 트래픽 증가 시 |

---

## 5. 의사결정 대기 항목

진행 전에 사용자/팀 확인 필요:

| # | 항목 | 결정 필요 시점 |
|---|------|----------------|
| 1 | EC2 인스턴스 보유 여부 / SSAFY 제공? | Task 2-1 시작 전 |
| 2 | 도메인 보유 여부 | Task 2-2 시작 전 |
| 3 | SSAFY Jenkins 인스턴스 사용 가능? | Task 3-1 시작 전 |
| 4 | Mattermost 채널 + 권한 | Task 3-2 시작 전 |
| 5 | Redis 두 번째 활용 (refresh blacklist) 도입 여부 | Task 1-2 진행 중 |

---

## 6. 타임라인 (러프 추정)

```
W1 (이번 주)
├── Task 1-1 (커밋)        ~30분
└── Task 1-2 (Redis 캐싱)   1~2h

W2 (다음 주)
├── Task 2-1 (EC2 배포)     반나절
└── Task 2-2 (Nginx HTTPS)  1~3h

W3 (스프린트 후반)
├── Task 3-1 (Jenkins)      1~2일
├── Task 3-2 (MM Webhook)   30분
└── Task 3-3 (pytest)       1~2일

W4+ (운영 안정화)
└── Task 3-4 (Rate limit)   2~4h
```

---

## 7. 진행 시 참고 문서

- 명세서: [`IMO_API_Specification.md`](IMO_API_Specification.md)
- Phase별 상세 계획: [`backend_implementation_plan.md`](backend_implementation_plan.md)
- 작업 결과 정리: [`backend_summary.md`](backend_summary.md)

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| v1.0 | 2026-04-28 | 최초 작성 — Phase 1~7 완료 직후 |
