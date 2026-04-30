# Phase B 작업 계획서 — Refresh Blacklist + Rate Limiting

> **작성일**: 2026-04-30
> **선행 문서**: [redis_integration_plan.md](redis_integration_plan.md) (Phase A), [redis_load_test_report.md](redis_load_test_report.md)
> **현재 상태**: Phase A (Redis 캐싱) 완료 + 부하 테스트 검증 완료
> **이 문서의 범위**: 자기완결적 작업 매뉴얼 — 다음 작업 시 이 문서 + 현재 코드만 보고 그대로 실행 가능하도록 작성

---

## 0. 핵심 결정 사항

| # | 항목 | 결정 |
|---|------|------|
| 1 | 작업 범위 | **둘 다 (B-1 Blacklist + B-2 Rate Limit)** |
| 2 | Blacklist 키 형식 | **SHA256 앞 32자** (토큰 그대로 저장 X — 메모리·보안) |
| 3 | Logout 엔드포인트 | **추가** (POST /api/v1/auth/logout) |
| 4 | Rate Limit 구현 | **직접 구현** (Redis INCR + EXPIRE, slowapi 미사용) |
| 5 | Redis 장애 시 정책 | Blacklist: silent pass (가용성 우선). Rate Limit: silent pass (DDoS보단 가용성 우선) |
| 6 | TTL 정책 | Blacklist = 토큰 남은 만료시간(자동 정리). Rate Limit = 60초 윈도우 |

> **설계 원칙**: 보안 기능이지만 Redis 장애가 곧 서비스 중단으로 이어지면 안 됨. Redis 죽어도 서비스는 살아남고, 보안 기능만 일시 미작동 (Phase A 와 동일 fallback 패턴).

---

## 1. 목표

### B-1. Refresh Token Blacklist
- **현재 문제**: refresh 토큰이 14일간 유효. 탈취 시 만료까지 차단 불가.
- **해결**: rotation/logout 시 이전 토큰을 Redis blacklist 에 TTL 과 함께 등록. `decode_refresh_token` 에서 blacklist 체크 추가.
- **얻는 효과**: 토큰 1회용화 (rotation 후 이전 토큰 즉시 무효), 명시적 로그아웃, 토큰 탈취 대응

### B-2. Rate Limiting
- **현재 문제**: 회원가입·로그인 무차별 호출 가능. brute-force 방어 없음.
- **해결**: IP 기반 분당 호출 횟수 제한. Redis `INCR + EXPIRE` 토큰 버킷.
- **얻는 효과**: 자동 회원가입 봇 차단, 로그인 brute-force 방어, refresh API 남용 방지

---

## 2. 변경/추가 파일 목록 (전체)

### 신규 파일
- `backend/core/rate_limit.py` — Rate limit 데코레이터·dependency 헬퍼
- `backend/tests/verify_phase_b.sh` — 통합 검증 스크립트

### 수정 파일

| 파일 | 변경 |
|------|------|
| `backend/core/cache.py` | blacklist 헬퍼 3종 추가 |
| `backend/core/security.py` | `decode_refresh_token` 을 **async 로 변경** + blacklist 체크 통합 |
| `backend/core/exceptions.py` | `TooManyRequests` 예외 클래스 추가 (또는 rate_limit.py 안에 정의) |
| `backend/api/routes/auth.py` | `/refresh` 에 blacklist 등록 + `/logout` 신규 + 모든 auth 라우터에 rate limit dependency |
| `backend/main.py` | `_http_status_to_code` 에 `429: TOO_MANY_REQUESTS` 매핑 추가 |
| `backend/schemas/auth.py` | `LogoutResponse` 추가 (선택 — 재사용해도 OK) |

### 영향 받는 파일 (decode_refresh_token async 화 때문)
- `backend/api/routes/auth.py` 의 `/refresh` 만 호출 중. 다른 호출처 없음 (확인됨).

---

## 3. Phase B-1: Refresh Token Blacklist

### 3-1. 설계

```
┌────────────────────────────────────────────────────────────┐
│ Refresh Token 사용 흐름 (After Phase B-1)                   │
│                                                            │
│  앱: POST /auth/refresh  { refreshToken: <T1> }            │
│      │                                                     │
│      ▼                                                     │
│  decode_refresh_token(T1):                                 │
│    1) is_refresh_token_blacklisted(T1)?                    │
│         ┌─ True  → Unauthorized "Token revoked"            │
│         └─ False → 계속                                     │
│    2) JWT 서명·만료·type 검증                               │
│      │                                                     │
│      ▼                                                     │
│  blacklist_refresh_token(T1, ttl=남은만료초)               │
│    └ Redis: SET auth:blacklist:refresh:{sha256(T1)} 1 EX ttl│
│      │                                                     │
│      ▼                                                     │
│  새 access + refresh 발급(T2)                               │
│      │                                                     │
│      ▼                                                     │
│  앱: 다음에 T1 다시 쓰면 → blacklist 체크에서 401            │
│      앱: T2 로 정상 동작                                    │
└────────────────────────────────────────────────────────────┘
```

### 3-2. Redis 키 규칙

```
auth:blacklist:refresh:{sha256(token)[:32]}
값: "1" (단순 존재 확인용)
TTL: 토큰의 남은 만료시간 (token.exp - now). 자동 정리.
```

**키에 SHA256 을 쓰는 이유**:
- 토큰 자체는 200자 내외. 그대로 키로 쓰면 Redis 메모리 낭비.
- 해시는 단방향 — Redis 가 침해당해도 원본 토큰 복원 불가.
- 32자 prefix 는 충돌 확률 무시 가능 (2^128 공간).

### 3-3. 단계별 구현

#### Step 1. `core/cache.py` 에 blacklist 헬퍼 3종 추가

파일 하단에 다음 코드 추가:

```python
# ============================================================
# Refresh Token Blacklist (Phase B-1)
# ============================================================

import hashlib


def _refresh_token_key(token: str) -> str:
    """refresh 토큰의 SHA256 앞 32자를 Redis 키로 사용 (메모리·보안)."""
    digest = hashlib.sha256(token.encode("utf-8")).hexdigest()[:32]
    return f"auth:blacklist:refresh:{digest}"


async def blacklist_refresh_token(token: str, ttl_sec: int) -> None:
    """refresh 토큰을 blacklist 에 등록. TTL = 토큰 남은 만료시간."""
    if not settings.CACHE_ENABLED or ttl_sec <= 0:
        return
    try:
        await get_client().set(_refresh_token_key(token), "1", ex=ttl_sec)
    except (RedisError, OSError) as e:
        logger.warning("blacklist_refresh_token failed: %s", e)


async def is_refresh_token_blacklisted(token: str) -> bool:
    """blacklist 등록 여부. Redis 장애 시 False 반환 (서비스 가용성 우선)."""
    if not settings.CACHE_ENABLED:
        return False
    try:
        result = await get_client().get(_refresh_token_key(token))
        return result is not None
    except (RedisError, OSError) as e:
        logger.warning("is_refresh_token_blacklisted failed: %s", e)
        return False
```

#### Step 2. `core/security.py` 에서 `decode_refresh_token` 을 async 로 변경

기존 sync 함수를 async 로 바꾸고 blacklist 체크 통합. 다른 호출처는 `auth.py /refresh` 1곳뿐 — 거기서 `await` 추가.

```python
async def decode_refresh_token(token: str) -> dict:
    """refresh 시크릿으로 디코드 + type=refresh 검증 + blacklist 체크."""
    # 순환 import 회피: 함수 안에서 import
    from core.cache import is_refresh_token_blacklisted

    # 1) blacklist 먼저 — 만료된 JWT 전에 차단 (만료 후에도 blacklist 유효해야 함)
    if await is_refresh_token_blacklisted(token):
        raise Unauthorized("Refresh token has been revoked")

    # 2) 기존 JWT 검증
    try:
        payload = jwt.decode(
            token, settings.REFRESH_SECRET_KEY, algorithms=[ALGORITHM]
        )
    except jwt.ExpiredSignatureError:
        raise TokenExpired("Refresh token expired")
    except JWTError:
        raise Unauthorized("Invalid refresh token")

    if payload.get("type") != REFRESH_TOKEN_TYPE:
        raise Unauthorized("Invalid token type")
    return payload
```

> ⚠️ `decode_access_token` 은 그대로 sync 유지. 이쪽은 blacklist 안 함 (access 는 30분 짧으니 만료 대기 OK).

#### Step 3. `api/routes/auth.py` 의 `/refresh` 수정 + `/logout` 추가

기존 `/refresh` 를 다음과 같이 수정:

```python
import time
from core.cache import blacklist_refresh_token
# ... 기존 import 들 ...


@router.post("/refresh")
async def refresh_token(request: RefreshRequest):
    """API-03 토큰 갱신. refresh 검증 + 이전 토큰 blacklist + 새 토큰 발급."""
    payload = await decode_refresh_token(request.refresh_token)  # await 추가
    sub = payload.get("sub")
    if not sub:
        raise Unauthorized("Invalid refresh token payload")

    # 이전 refresh 토큰을 blacklist 등록 (TTL = 남은 만료시간)
    exp = payload.get("exp")
    if exp:
        ttl = max(0, int(exp - time.time()))
        await blacklist_refresh_token(request.refresh_token, ttl)

    new_access = create_access_token(subject=sub)
    new_refresh = create_refresh_token(subject=sub)
    body = RefreshResponse(access_token=new_access, refresh_token=new_refresh)
    return success_response(body.model_dump(by_alias=True))


@router.post("/logout")
async def logout(request: RefreshRequest):
    """로그아웃 — refresh 토큰을 blacklist 등록 (멱등).

    이미 만료된/무효화된 토큰이어도 200 으로 종결한다 (앱 측 단순화).
    """
    from core.exceptions import APIException
    try:
        payload = await decode_refresh_token(request.refresh_token)
        exp = payload.get("exp")
        if exp:
            ttl = max(0, int(exp - time.time()))
            await blacklist_refresh_token(request.refresh_token, ttl)
    except APIException:
        # 이미 무효 토큰 — 멱등 응답
        pass
    return success_response({"loggedOut": True})
```

> 참고: `RefreshRequest` 스키마 재사용 OK (필드 동일). 별도 `LogoutRequest` 만들 필요 X.

### 3-4. 검증 시나리오 (B-1 단독)

```bash
# 1) 회원가입 → REFRESH 1 받음
# 2) /refresh 호출 (REFRESH 1) → 200 + REFRESH 2 발급. 내부에서 REFRESH 1 blacklist 됨.
# 3) /refresh 다시 호출 (REFRESH 1 재사용) → 401 "Refresh token has been revoked"
# 4) /refresh 호출 (REFRESH 2) → 200 + REFRESH 3 발급. REFRESH 2 blacklist 됨.
# 5) /logout 호출 (REFRESH 3) → 200 {loggedOut:true}. REFRESH 3 blacklist 됨.
# 6) /refresh 호출 (REFRESH 3) → 401 (이미 logout 으로 차단됨)
# 7) Redis 키 확인: docker compose exec redis redis-cli KEYS 'auth:blacklist:refresh:*'
#    → 3개 키 (REFRESH 1, 2, 3 각각의 SHA256)
```

---

## 4. Phase B-2: Rate Limiting

### 4-1. 설계

```
요청 들어옴 → FastAPI Dependency 체크 → 통과 시 라우터 진입
                  │
                  ▼
        check_rate_limit(key, max, window)
                  │
                  ▼
        Redis: INCR ratelimit:{key}
        ├ 결과가 1 이면 EXPIRE 설정 (첫 요청)
        └ max 초과면 TooManyRequests (429)
                  │
                  ▼
        Redis 장애 시 → 통과 (서비스 우선)
```

### 4-2. 적용 정책

| 엔드포인트 | 제한 | 근거 |
|-----------|------|------|
| `POST /auth/signup` | IP당 분당 5회 | 자동 가입 봇 차단. 정상 사용자엔 영향 X |
| `POST /auth/login` | IP당 분당 10회 | 비밀번호 brute-force 차단. 오타로 8~9번은 OK |
| `POST /auth/refresh` | IP당 분당 30회 | 정상 앱은 30분에 1번. 30/min 도 충분 |
| 그 외 | 미적용 (이번 라운드) | 통계·세션은 인증 사용자만 호출. JWT 자체가 1차 방어 |

> **IP 추출 주의**: Nginx 뒤에 있으면 `X-Forwarded-For` 헤더 봐야 진짜 IP 가짐. 현재 Nginx 설정([backend_deployment_plan.md](backend_deployment_plan.md) Phase 3-3) 에서 `X-Forwarded-For` 전달 중. 다만 `request.client.host` 는 nginx IP (127.0.0.1) 를 잡으므로 **반드시 `X-Forwarded-For` 헤더 우선 사용**.

### 4-3. 단계별 구현

#### Step 1. `core/rate_limit.py` 신규 작성

전체 파일 내용:

```python
"""Redis 기반 rate limit — INCR + EXPIRE 단순 token bucket.

각 (key, window_sec) 조합당 카운터. 첫 INCR 시 EXPIRE 설정.
max 초과 시 TooManyRequests(429) 발생.
Redis 장애 시 silent pass (서비스 가용성 우선).

사용 예 (FastAPI dependency):
    @router.post("/login", dependencies=[Depends(rate_limit_by_ip("login", 10, 60))])
"""
import logging

from fastapi import Request
from redis.exceptions import RedisError

from core.cache import get_client
from core.config import settings
from core.exceptions import APIException

logger = logging.getLogger("imo.ratelimit")


class TooManyRequests(APIException):
    """429 Too Many Requests — rate limit 초과."""
    def __init__(self, message: str = "Too many requests"):
        super().__init__(
            status_code=429,
            code="TOO_MANY_REQUESTS",
            message=message,
        )


async def check_rate_limit(key: str, max_requests: int, window_sec: int) -> None:
    """Rate limit 체크. 초과 시 TooManyRequests 발생.

    Redis 장애 시 silent pass — DDoS 방어보다 가용성 우선 (Phase A 와 동일 정책).
    """
    if not settings.CACHE_ENABLED:
        return
    redis_key = f"ratelimit:{key}"
    try:
        client = get_client()
        count = await client.incr(redis_key)
        if count == 1:
            # 첫 요청 — 윈도우 시작점 표시
            await client.expire(redis_key, window_sec)
        if count > max_requests:
            raise TooManyRequests(
                f"Rate limit exceeded: {max_requests} requests per {window_sec}s"
            )
    except (RedisError, OSError) as e:
        logger.warning("rate_limit check failed (key=%s): %s", key, e)
        # Redis 장애 시 통과


def _client_ip(request: Request) -> str:
    """프록시 뒤에 있을 수 있으므로 X-Forwarded-For 우선."""
    xff = request.headers.get("x-forwarded-for")
    if xff:
        # XFF 는 콤마 구분 — 가장 왼쪽이 원본 클라이언트 IP
        return xff.split(",")[0].strip()
    if request.client and request.client.host:
        return request.client.host
    return "unknown"


def rate_limit_by_ip(prefix: str, max_requests: int, window_sec: int = 60):
    """FastAPI dependency 헬퍼.

    사용:
        @router.post("/login", dependencies=[Depends(rate_limit_by_ip("login", 10, 60))])
    """
    async def _dep(request: Request):
        ip = _client_ip(request)
        await check_rate_limit(f"{prefix}:{ip}", max_requests, window_sec)
    return _dep
```

#### Step 2. `api/routes/auth.py` 의 3개 엔드포인트에 dependency 추가

```python
from fastapi import Depends
from core.rate_limit import rate_limit_by_ip
# ... 기존 import 들 ...


@router.post(
    "/signup",
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(rate_limit_by_ip("signup", 5, 60))],
)
async def signup(user_in: UserCreate, db: AsyncSession = Depends(get_db)):
    # ... 기존 로직 그대로 ...


@router.post(
    "/login",
    dependencies=[Depends(rate_limit_by_ip("login", 10, 60))],
)
async def login(user_in: UserLogin, db: AsyncSession = Depends(get_db)):
    # ... 기존 로직 그대로 ...


@router.post(
    "/refresh",
    dependencies=[Depends(rate_limit_by_ip("refresh", 30, 60))],
)
async def refresh_token(request: RefreshRequest):
    # ... 위에서 수정한 B-1 로직 그대로 ...
```

#### Step 3. `main.py` 의 에러 코드 매핑에 429 추가

```python
def _http_status_to_code(status_code: int) -> str:
    return {
        400: "INVALID_REQUEST",
        401: "UNAUTHORIZED",
        403: "FORBIDDEN",
        404: "NOT_FOUND",
        409: "CONFLICT",
        422: "VALIDATION_ERROR",
        429: "TOO_MANY_REQUESTS",   # ← 추가
        500: "INTERNAL_ERROR",
    }.get(status_code, "INTERNAL_ERROR")
```

> 참고: `TooManyRequests` 가 `APIException` 을 상속하고 자체 `code` 를 가지므로 `api_exception_handler` 가 먼저 잡아서 응답함. 위 매핑은 폴백 안전망.

### 4-4. 검증 시나리오 (B-2 단독)

```bash
# 1) /auth/login 11회 빠르게 호출
#    → 1~10: 401 (잘못된 비밀번호) 또는 200
#    → 11: 429 TOO_MANY_REQUESTS
# 2) 60초 대기 후 다시 호출 → 정상 동작
# 3) Redis 키 확인:
#    docker compose exec redis redis-cli KEYS 'ratelimit:login:*'
#    → ratelimit:login:127.0.0.1 같은 키 (TTL 60초)
```

---

## 5. 통합 검증 — `tests/verify_phase_b.sh` 신규

전체 파일 내용:

```bash
#!/bin/sh
# Phase B 통합 검증 — Refresh Blacklist + Rate Limit
# 실행: bash tests/verify_phase_b.sh
# 전제: docker compose up 으로 api/db/redis 가 모두 Up + CACHE_ENABLED=true

set -e

BASE="http://localhost:8000/api/v1"
EMAIL="phaseb_$(date +%s)@example.com"
PW="testpass123"

extract() {
  grep -o "\"$1\":\"[^\"]*\"" /tmp/phaseb_resp.json | sed "s/\"$1\":\"//;s/\"//"
}

echo "================================================"
echo "B-1. Refresh Token Blacklist"
echo "================================================"

echo "[1] 회원가입 → REFRESH 1"
curl -s -X POST "$BASE/auth/signup" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\",\"nickname\":\"phaseb\"}" \
  > /tmp/phaseb_resp.json
cat /tmp/phaseb_resp.json | head -c 200; echo
REFRESH_1=$(extract refreshToken)

echo
echo "[2] /refresh (REFRESH 1) → REFRESH 2 발급, REFRESH 1 blacklist"
curl -s -X POST "$BASE/auth/refresh" -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$REFRESH_1\"}" > /tmp/phaseb_resp.json
cat /tmp/phaseb_resp.json | head -c 200; echo
REFRESH_2=$(extract refreshToken)

echo
echo "[3] REFRESH 1 재사용 시도 → 401 'revoked' 기대"
curl -s -X POST "$BASE/auth/refresh" -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$REFRESH_1\"}"
echo

echo
echo "[4] /logout (REFRESH 2) → 200 loggedOut"
curl -s -X POST "$BASE/auth/logout" -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$REFRESH_2\"}"
echo

echo
echo "[5] REFRESH 2 재사용 시도 → 401 (이미 logout)"
curl -s -X POST "$BASE/auth/refresh" -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$REFRESH_2\"}"
echo

echo
echo "[6] Redis blacklist 키 확인"
docker compose exec -T redis redis-cli KEYS 'auth:blacklist:refresh:*'

echo
echo "================================================"
echo "B-2. Rate Limiting"
echo "================================================"

echo "[7] /auth/login 11회 빠르게 호출 → 11번째에 429 기대"
for i in 1 2 3 4 5 6 7 8 9 10 11; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$EMAIL\",\"password\":\"wrong\"}")
  echo "  Try $i: HTTP $CODE"
done

echo
echo "[8] Redis ratelimit 키 확인"
docker compose exec -T redis redis-cli KEYS 'ratelimit:*'

echo
echo "검증 끝. 정상이라면:"
echo "  [3]: 401 'Refresh token has been revoked'"
echo "  [4]: 200 loggedOut:true"
echo "  [5]: 401 'revoked'"
echo "  [6]: auth:blacklist:refresh:* 키 2개 (REFRESH 1, 2)"
echo "  [7]: Try 1~10 은 401, Try 11 은 429"
echo "  [8]: ratelimit:login:* 키 1개 (TTL 60초)"
```

스크립트는 LF 로 저장 필수 (`.gitattributes` 가 자동 처리). 권한:
```bash
sed -i 's/\r$//' tests/verify_phase_b.sh
chmod +x tests/verify_phase_b.sh
```

---

## 6. 진행 순서 (체크리스트)

다음에 와서 이 순서대로 진행:

```
[ ] 1. core/cache.py 에 blacklist 헬퍼 3종 추가 (§3-3 Step 1)
[ ] 2. core/security.py decode_refresh_token async 변환 + blacklist 체크 (§3-3 Step 2)
[ ] 3. api/routes/auth.py /refresh 수정 + /logout 추가 (§3-3 Step 3)
[ ] 4. core/rate_limit.py 신규 작성 (§4-3 Step 1)
[ ] 5. api/routes/auth.py 3개 엔드포인트에 rate limit dependency (§4-3 Step 2)
[ ] 6. main.py 429 매핑 추가 (§4-3 Step 3)
[ ] 7. tests/verify_phase_b.sh 작성 (§5)
[ ] 8. 로컬 docker compose 재기동 + 검증 스크립트 실행
[ ] 9. EC2 배포 영향 확인 (※ 코드 변경만, 인프라 추가 X — 그대로 docker compose up -d --build 로 적용)
[ ] 10. 커밋 분할 + push
```

---

## 7. 커밋 분할 계획 (push 직전)

```
feat(backend/cache): refresh 토큰 blacklist 헬퍼 3종 (SHA256 키, TTL 자동)
feat(backend/security): decode_refresh_token async 화 + blacklist 체크 통합
feat(backend/auth): /refresh rotation 시 이전 토큰 blacklist + /logout 신규
feat(backend/rate-limit): core/rate_limit.py 신규 — Redis INCR/EXPIRE 기반
feat(backend/auth): signup·login·refresh 에 IP 기반 rate limit dependency
chore(backend/main): 429 TOO_MANY_REQUESTS 에러 코드 매핑 추가
test(backend): tests/verify_phase_b.sh — Phase B 통합 검증 스크립트
docs(backend): Phase B 작업 결과 보고 (선택 — phase_b_report.md)
```

---

## 8. 주의사항 / 함정

### 8-1. `decode_refresh_token` async 화의 파급
- 현재 호출처: **`api/routes/auth.py /refresh` 1곳** (확인 완료, 2026-04-30 기준).
- 다른 코드에서 호출 추가될 일 없음. 만약 추가되면 `await` 누락 시 coroutine 객체 반환되어 검증 실패함 → 빠르게 잡힘.

### 8-2. 순환 import 회피
- `core/security.py` → `core/cache.py` (blacklist 함수)
- `core/cache.py` → `core/config.py` (settings)
- 현재 import 그래프상 직접 순환은 없지만, 안전을 위해 **`security.py` 안에서 `cache.py` import 는 함수 내부로**.

### 8-3. SHA256 충돌
- 32자 prefix = 128비트 공간. 충돌 확률 ≪ 다른 모든 보안 결함. 무시 가능.
- 만에 하나 충돌 시: 다른 사용자의 토큰이 잘못 차단될 뿐, 인증을 통과시키진 않음 (false-positive 방향이라 안전한 방향).

### 8-4. Rate limit 의 IP 위조
- `X-Forwarded-For` 는 클라이언트가 위조 가능 (Nginx 가 덧붙이지 않고 그대로 통과시키면).
- 현재 Nginx 설정 ([backend_deployment_plan.md §3-3](backend_deployment_plan.md)) 은 `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;` 사용 — 클라이언트가 보낸 헤더 + nginx 가 본 IP 를 이어붙임.
- 정확한 원본 IP 를 받으려면 `X-Real-IP` 헤더를 nginx 에서 강제로 덮어 쓰는 게 더 안전. **이번 라운드는 XFF 그대로 사용 후, 운영 트래픽 분석하며 필요 시 nginx 설정 보강**.

### 8-5. Redis 장애 시 동작
- Blacklist: 통과 (탈취 토큰 막을 수 없지만 정상 토큰 사용은 가능 — 가용성 우선)
- Rate Limit: 통과 (DDoS 발생 시 무방비, 다만 서비스 자체는 살아남음)
- 두 정책 모두 **Phase A 와 동일** — Redis 가 죽어도 서비스 자체는 멀쩡

### 8-6. 테스트 시 Redis FLUSHDB 필요할 수도
- Phase A 검증 잔여 데이터 (blacklist + ratelimit 키)가 있으면 일부 검증 단계가 의도와 다르게 동작.
- 검증 시작 전에 `docker compose exec redis redis-cli FLUSHDB` 권장.

---

## 9. 롤백 절차

문제 발생 시:

| 영향 범위 | 롤백 방법 |
|----------|----------|
| 특정 기능만 깨짐 | 해당 커밋만 `git revert <sha>` |
| 전체 인증 깨짐 | `feature/phase-b` 브랜치 통째로 develop 에서 revert |
| 운영 즉시 차단 | EC2 에서 `docker compose exec api sh` → `CACHE_ENABLED=false` 환경변수로 재기동 (blacklist + ratelimit 동시에 무력화, 서비스는 살아남음) |

---

## 10. 향후 확장 (이번 범위 외)

| # | 항목 | 설명 |
|---|------|------|
| 1 | Access token blacklist | 30분 짧아 우선순위 낮음. 필요 시 동일 패턴 |
| 2 | 사용자 단위 rate limit | IP 가 아닌 user_id 기반. 인증 후 라우터에 적용 |
| 3 | Sliding window log | 더 정확한 rate limit (현재는 fixed window) |
| 4 | Login 실패 횟수 누적 차단 | 단일 IP/계정 5회 실패 시 5분 잠금 |
| 5 | Suspicious activity 알림 | rate limit 빈발 IP 를 Mattermost 로 알림 |

---

## 11. 검증 완료 정의 (DoD)

- [ ] `verify_phase_b.sh` 의 8개 단계 모두 기대 결과대로
- [ ] Redis 키 정확 (`auth:blacklist:refresh:*`, `ratelimit:*`)
- [ ] TTL 동작 (15초 후 KEYS 재확인 시 ratelimit 키 사라져야 함 — 60초 TTL은 좀 길지만 자동 만료 확인 가능)
- [ ] 기존 Phase A 캐시 동작 그대로 (`verify_cache.sh` 도 통과해야 함)
- [ ] EC2 배포 후 외부에서 `https://k14c203.p.ssafy.io/api/v1/auth/login` 11회 호출 시 429 반환

---

## 12. 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| v1.0 | 2026-04-30 | 최초 작성 — Phase B 작업 매뉴얼 자기완결 형태로 작성 |
