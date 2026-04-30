"""Redis 비동기 캐시 헬퍼.

설계 원칙:
- DB 가 진실의 원천. Redis 는 read-through 가속 캐시.
- 캐시 hit/miss 응답 JSON 구조 100% 동일 (앱 영향 0).
- Redis 장애 시 DB 직접 조회로 fallback (캐시는 깨져도 서비스는 살림).
- 무효화는 SCAN 패턴 일괄 삭제 (간단·정확). KEYS 는 단일 스레드 블로킹이라 금지.
"""
import json
import logging
from typing import Any, Optional

import redis.asyncio as aioredis
from redis.asyncio import Redis
from redis.exceptions import RedisError

from core.config import settings

logger = logging.getLogger("imo.cache")


# 모듈 싱글톤. 앱 라이프사이클 동안 단일 커넥션 풀 공유.
_client: Optional[Redis] = None


def get_client() -> Redis:
    """Redis 비동기 클라이언트 싱글톤 반환.

    socket_connect_timeout / socket_timeout 을 짧게 잡아서 Redis 장애 시
    각 요청이 빠르게 fallback (DB 직접 조회) 하도록 한다.
    """
    global _client
    if _client is None:
        _client = aioredis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True,
            socket_connect_timeout=0.3,
            socket_timeout=0.3,
        )
    return _client


async def cache_get(key: str) -> Optional[Any]:
    """캐시에서 JSON 으로 저장된 값을 꺼내 dict/list 등으로 복원해서 반환.

    캐시 없거나 Redis 장애 시 None 반환 → 호출 측은 DB 조회로 fallback.
    settings.CACHE_ENABLED=False 면 항상 None 반환 (Before/After 비교 측정용).
    """
    if not settings.CACHE_ENABLED:
        return None
    try:
        raw = await get_client().get(key)
    except (RedisError, OSError) as e:
        logger.warning("cache_get failed (key=%s): %s", key, e)
        return None
    if raw is None:
        return None
    try:
        return json.loads(raw)
    except (TypeError, ValueError) as e:
        logger.warning("cache_get JSON decode failed (key=%s): %s", key, e)
        return None


async def cache_set(key: str, value: Any, ttl: int = 300) -> None:
    """JSON 직렬화 후 TTL 와 함께 저장. 장애 시 silent fail (서비스는 계속)."""
    if not settings.CACHE_ENABLED:
        return
    try:
        payload = json.dumps(value, ensure_ascii=False, default=str)
        await get_client().set(key, payload, ex=ttl)
    except (RedisError, OSError, TypeError, ValueError) as e:
        logger.warning("cache_set failed (key=%s): %s", key, e)


async def cache_delete(*keys: str) -> int:
    """주어진 키들을 일괄 삭제. 삭제된 키 개수 반환. 장애 시 0."""
    if not settings.CACHE_ENABLED or not keys:
        return 0
    try:
        return int(await get_client().delete(*keys))
    except (RedisError, OSError) as e:
        logger.warning("cache_delete failed (keys=%s): %s", keys, e)
        return 0


async def invalidate_user_stats(user_id: int) -> int:
    """해당 유저의 모든 통계 캐시를 SCAN 으로 찾아 일괄 삭제.

    패턴: stats:*:{user_id}:*
    KEYS 는 단일 스레드 Redis 를 블로킹하므로 금지. SCAN cursor 기반 점진 순회.
    """
    if not settings.CACHE_ENABLED:
        return 0
    pattern = f"stats:*:{user_id}:*"
    deleted_total = 0
    try:
        client = get_client()
        cursor = 0
        # SCAN 한 번 호출당 일정 개수씩 키를 받아오므로 cursor=0 될 때까지 반복.
        while True:
            cursor, batch = await client.scan(cursor=cursor, match=pattern, count=100)
            if batch:
                deleted_total += int(await client.delete(*batch))
            if cursor == 0:
                break
    except (RedisError, OSError) as e:
        logger.warning("invalidate_user_stats failed (user_id=%s): %s", user_id, e)
        return deleted_total
    if deleted_total:
        logger.info("invalidated %d stats cache keys for user %s", deleted_total, user_id)
    return deleted_total


# ============================================================
# 통계 캐시 키 규칙 (statistics.py 와 sessions/users 무효화에서 공유)
# ============================================================

def stats_key(kind: str, user_id: int, week_start: str, exercise_type: Optional[str]) -> str:
    """stats:{kind}:{user_id}:{weekStart}:{exerciseType or '_'}"""
    et = exercise_type if exercise_type else "_"
    return f"stats:{kind}:{user_id}:{week_start}:{et}"
