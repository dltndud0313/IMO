# Redis 통합 + 부하 테스트 계획

> **작성일**: 2026-04-30
> **선행 문서**: [backend_roadmap.md](backend_roadmap.md) Task 1-2, [backend_deployment_plan.md](backend_deployment_plan.md) Phase 5
> **현재 상태**: Phase 1~7 + EC2 배포 + Jenkins CI/CD + MM 알림 완료
> **이 문서의 범위**: 통계 엔드포인트 read-through 캐싱 + Locust 부하 테스트로 before/after 검증

---

## 0. 핵심 결정 사항

| # | 항목 | 결정 |
|---|------|------|
| 1 | Redis 도입 범위 | **통계 엔드포인트 3종 read-through 캐싱만** (Phase A) |
| 2 | Refresh Token Blacklist (Phase B) | **이번 라운드에서 제외**. 동작 안정화 후 별도 작업 |
| 3 | 무효화 정책 | **SCAN 패턴 삭제 (간단)**. 정밀 무효화는 코드 복잡도 대비 이득 작음 |
| 4 | TTL | **300초 (5분)** |
| 5 | Redis 버전 | `redis:7-alpine` (Docker 이미지) |
| 6 | Python 클라이언트 | `redis==5.0.1` (`redis.asyncio` 사용) |
| 7 | 부하 테스트 도구 | **Locust** (Python 친화, 시나리오 작성 직관적) |
| 8 | 측정 항목 | 캐시 hit/miss 응답 시간, 동시 사용자 N명 시 처리량 |

> **무효화 정책 선택 근거**: 캐시 무효화는 SW 공학에서 어려운 문제 중 하나. TTL 5분이 짧아서 정밀 무효화의 이득(불필요 DB 조회 회피)이 작고, 빠뜨림 위험이 크다. SCAN 패턴은 단순·정확·실수 없음.

---

## 1. 목표 아키텍처

```
[앱] ──HTTPS──► [Nginx] ──► [api 컨테이너 (FastAPI)]
                                    │
                                    ├──► [db 컨테이너 (Postgres:15)]   ◄─ 영속화
                                    │
                                    └──► [redis 컨테이너 (Redis:7)]    ◄─ 캐시 (신규)
```

**원칙**:
- redis 도 외부 노출 X — `imo_net` 도커 내부망에서만 통신
- DB 가 진실의 원천. Redis 는 가속 캐시.
- 캐시 hit/miss 모두 응답 JSON 구조 100% 동일 (앱 영향 0)

---

## 2. 캐시 키 / TTL 규칙

### 2-1. 키 네이밍

```
stats:weekly:{user_id}:{weekStart}:{exerciseType or '_'}
stats:heatmap:{user_id}:{weekStart}:{exerciseType or '_'}
stats:balance:{user_id}:{weekStart}:{exerciseType or '_'}
```

- `weekStart` 는 `YYYY-MM-DD` 문자열 (월요일)
- `exerciseType` 미지정 시 `_` 사용 (전체 운동)
- 예시:
  - `stats:weekly:42:2026-04-27:_`
  - `stats:heatmap:42:2026-04-27:PUSH_UP`

### 2-2. TTL

- `300초 (5분)` 일괄 적용
- 자동 만료로 데이터 신선도 보장

### 2-3. 직렬화

- 응답 dict 를 JSON 문자열로 직렬화해서 저장
- 캐시에서 꺼낼 때 JSON 역직렬화 후 그대로 반환

---

## 3. 무효화 정책 (SCAN 패턴)

### 트리거 시점

| API | 호출 결과 | 무효화 대상 |
|-----|----------|------------|
| `POST /sessions` | 새 운동 세션 1건 추가 | `stats:*:{user_id}:*` |
| `DELETE /sessions/{id}` | 세션 1건 삭제 | `stats:*:{user_id}:*` |
| `DELETE /me/data` | 해당 유저 모든 세션 삭제 | `stats:*:{user_id}:*` |

### 동작 흐름

```
1. POST /sessions 처리 끝 → cache.invalidate_user_stats(user_id) 호출
2. cache.py: Redis SCAN 으로 패턴 매칭 키 찾기
3. 찾은 키 일괄 DELETE (UNLINK 가 더 좋지만 단순화 위해 DEL)
4. 캐시 비워짐 → 다음 통계 호출 시 read-through 로 자연 재생성
```

### KEYS 명령 금지 이유

`KEYS pattern` 은 단일 스레드 Redis 를 막음 (블로킹). 운영 환경에선 사용 금지가 통념. `SCAN` 은 cursor 기반 점진적 순회라 안전.

---

## 4. 변경/추가 파일 목록

### 신규 파일 (1개)

- `backend/core/cache.py` — Redis 클라이언트 + JSON get/set/delete + invalidate 헬퍼

### 수정 파일 (7개)

| 파일 | 변경 내용 |
|------|---------|
| `backend/requirements.txt` | `redis==5.0.1` 추가 |
| `backend/docker-compose.yml` | redis:7-alpine 서비스 추가 (로컬용, 6379 외부 노출 — 디버깅 편의) |
| `backend/docker-compose.ec2.yml` | redis:7-alpine 서비스 추가 (운영용, 외부 미노출) |
| `backend/core/config.py` | `REDIS_URL` 환경변수 추가 |
| `backend/api/routes/statistics.py` | 3개 엔드포인트 read-through 캐싱 적용 |
| `backend/api/routes/sessions.py` | POST/DELETE 후 invalidate 호출 |
| `backend/api/routes/users.py` | DELETE /me/data 후 invalidate 호출 |

---

## 5. 단계별 진행 계획

### Step 1. 의존성 / 설정 (10분)

1. `requirements.txt` 에 `redis==5.0.1` 추가
2. `docker-compose.yml` / `docker-compose.ec2.yml` 양쪽에 redis 서비스 추가
3. `core/config.py` 에 `REDIS_URL` 환경변수 추가 (기본값: `redis://redis:6379/0`)

### Step 2. 캐시 헬퍼 작성 (20분)

`core/cache.py` 신규:
- `redis.asyncio` 비동기 클라이언트 싱글톤
- `cache_get(key) -> dict | None`
- `cache_set(key, value: dict, ttl: int = 300)`
- `cache_delete(*keys)`
- `invalidate_user_stats(user_id)` — SCAN 패턴 + 일괄 DELETE

### Step 3. statistics.py 캐싱 적용 (30분)

3개 엔드포인트 모두 동일 패턴:

```python
cache_key = f"stats:weekly:{current_user.id}:{weekStart}:{exerciseType or '_'}"
cached = await cache_get(cache_key)
if cached is not None:
    return success_response(cached)

# ... 기존 DB 집계 로직 ...

response_dict = payload.model_dump(by_alias=True, mode="json")
await cache_set(cache_key, response_dict, ttl=300)
return success_response(response_dict)
```

### Step 4. 무효화 호출 추가 (10분)

- `sessions.py` POST 끝 + DELETE 끝 → `invalidate_user_stats(current_user.id)`
- `users.py` DELETE /me/data 끝 → 동일

### Step 5. 로컬 검증 (15분)

```bash
cd backend
docker compose up -d --build
docker compose logs -f api  # 캐시 hit/miss 로그 모니터
```

검증 시나리오:
1. 회원가입 + 로그인 → 토큰 획득
2. POST /sessions 1건 (샘플 페이로드)
3. GET /statistics/weekly?weekStart=... → 첫 호출 (cache miss, DB hit, 100~200ms)
4. 동일 호출 즉시 반복 → cache hit (1~5ms)
5. POST /sessions 1건 더 → 캐시 무효화
6. GET /statistics/weekly → 다시 cache miss (정확성 확인)

### Step 6. 부하 테스트 (40~60분)

`backend/tests/locustfile.py` 신규 (테스트 코드 디렉토리 시작점):

시나리오:
- 10명 동시 사용자, 5분간 통계 화면 반복 조회
- 측정: p50/p95/p99 응답 시간, 처리량 (RPS)
- **Redis 끄고 측정 → Redis 켜고 측정** = before/after 그래프

산출물: `backend/docs/redis_load_test_report.md` (수치 + 그래프 캡처)

### Step 7. 커밋 / 배포 (15분)

커밋 분할:
```
chore(backend): Redis 의존성 + docker-compose 추가
feat(backend/cache): core/cache.py — read-through + SCAN 무효화
feat(backend/statistics): 3개 엔드포인트 read-through 캐싱
feat(backend/sessions,users): 캐시 무효화 호출 추가
test(backend): Locust 부하 테스트 시나리오 + 결과 문서
```

브랜치 전략:
- 기존 브랜치 정책 유지: 큰 브랜치 하나(`feature/redis-caching`) + 작은 커밋 분할

배포:
- develop 머지 → Jenkins 자동 배포
- EC2 에서 redis 컨테이너 추가 기동 자동 (compose up -d 가 없는 서비스만 새로 띄움)

---

## 6. 검증 기준 (완료 정의)

| # | 항목 | 기준 |
|---|------|------|
| 1 | 캐시 hit | 동일 weekStart 두 번째 호출이 1ms 대 응답 |
| 2 | 캐시 miss | 첫 호출 또는 무효화 후 첫 호출이 정상 DB 집계 결과 반환 |
| 3 | 응답 동일성 | hit/miss 응답 JSON 구조 + 값 100% 동일 |
| 4 | 무효화 정확성 | POST /sessions 후 통계가 새 세션 반영해서 보임 |
| 5 | TTL 동작 | 5분 후 자동 만료되어 다음 호출이 cache miss |
| 6 | 부하 테스트 | 동시 사용자 10명 기준 평균 응답 시간 80% 이상 단축 |
| 7 | EC2 배포 | Jenkins 자동 배포 후 https://k14c203.p.ssafy.io 정상 동작 |

---

## 7. 주의사항 / 롤백 절차

### 주의

- redis 컨테이너 재기동 시 캐시 전부 날아감 → 정상 동작 (DB 가 원천이므로 다음 호출에서 자연 복구)
- redis 메모리 한계 도달 시 eviction 정책 필요 (현재는 `redis:7-alpine` 기본값 = `noeviction`). 메모리 작아서 운영에서 OOM 발생 시 추후 `allkeys-lru` 로 변경 검토
- `KEYS *` 같은 명령 절대 사용 금지

### 롤백

문제 발생 시:
1. `docker-compose stop redis` → api 컨테이너에서 redis 연결 실패 발생
2. 또는 `cache.py` 의 모든 함수를 no-op 으로 우회 (코드 한 줄 수정)
3. 가장 안전한 롤백: `git revert` 후 develop push → Jenkins 자동 재배포

캐싱 코드는 try/except 로 redis 장애 시 DB 직접 조회로 fallback 하는 방어 코드 포함 권장.

---

## 8. 향후 확장 (이번 범위 외)

| # | 항목 | 시점 |
|---|------|------|
| 1 | Refresh Token Blacklist (Phase B) | Phase A 안정화 후 |
| 2 | Rate Limiting (Redis token bucket) | Phase A 안정화 후 |
| 3 | 정밀 무효화 (필요 시) | 트래픽 증가로 SCAN 부담 증가 시 |
| 4 | Redis 모니터링 (메모리·hit ratio) | 운영 안정화 단계 |

---

## 9. 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| v1.0 | 2026-04-30 | 최초 작성 — Phase A 범위 확정 (캐싱 + Locust) |
