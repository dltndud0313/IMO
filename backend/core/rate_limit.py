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
            code="TOO_MANY_REQUESTS",
            message=message,
            status_code=429,
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
