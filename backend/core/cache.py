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


# ============================================================
# Chat History (Phase C — 운동 챗봇)
# ============================================================

def _chat_key(user_id: int) -> str:
    return f"chat:history:{user_id}"


async def get_chat_history(user_id: int) -> list:
    """대화 히스토리 조회. Redis 장애/없음 시 빈 리스트."""
    if not settings.CACHE_ENABLED:
        return []
    try:
        raw = await get_client().get(_chat_key(user_id))
        if not raw:
            return []
        return json.loads(raw)
    except (RedisError, OSError, ValueError) as e:
        logger.warning("get_chat_history failed (user=%s): %s", user_id, e)
        return []


async def append_chat_messages(user_id: int, new_messages: list, max_turns: int = 10) -> None:
    """user 메시지 + assistant 응답을 히스토리에 추가, 슬라이딩 윈도우 max_turns × 2."""
    if not settings.CACHE_ENABLED:
        return
    try:
        history = await get_chat_history(user_id)
        history.extend(new_messages)
        max_msgs = max_turns * 2
        if len(history) > max_msgs:
            history = history[-max_msgs:]
        await get_client().set(
            _chat_key(user_id),
            json.dumps(history, ensure_ascii=False, default=str),
            ex=settings.CHAT_HISTORY_TTL,
        )
    except (RedisError, OSError, TypeError, ValueError) as e:
        logger.warning("append_chat_messages failed (user=%s): %s", user_id, e)


async def clear_chat_history(user_id: int) -> None:
    """대화 초기화 — DELETE /chat 에서 호출."""
    if not settings.CACHE_ENABLED:
        return
    try:
        await get_client().delete(_chat_key(user_id))
    except (RedisError, OSError) as e:
        logger.warning("clear_chat_history failed (user=%s): %s", user_id, e)


async def build_user_workout_context(user_id: int, db) -> str:
    """사용자의 최근 7일 운동 통계 요약 텍스트 — LLM 컨텍스트로 주입.

    데이터 없으면 "최근 운동 기록 없음" 반환.
    """
    from datetime import datetime, timedelta, timezone
    from sqlalchemy import select
    from models.session import WorkoutBalanceSummary, WorkoutSession

    cutoff = datetime.now(timezone.utc) - timedelta(days=7)
    q = (
        select(WorkoutSession)
        .where(WorkoutSession.user_id == user_id)
        .where(WorkoutSession.started_at >= cutoff)
        .order_by(WorkoutSession.started_at.desc())
    )
    result = await db.execute(q)
    sessions = result.scalars().all()

    if not sessions:
        return "최근 7일 운동 기록 없음"

    # 운동 종목 분포
    by_type: dict = {}
    for s in sessions:
        by_type[s.exercise_type] = by_type.get(s.exercise_type, 0) + 1
    type_str = " / ".join(f"{k} {v}회" for k, v in by_type.items())

    avg_target = sum(float(s.avg_target_muscle or 0) for s in sessions) / len(sessions)

    # 좌우 밸런스 평균 — 별도 테이블에서 join
    session_ids = [s.session_id for s in sessions]
    bal_q = select(WorkoutBalanceSummary).where(
        WorkoutBalanceSummary.session_id.in_(session_ids),
        WorkoutBalanceSummary.diff_value.isnot(None),
    )
    bal_result = await db.execute(bal_q)
    balances = bal_result.scalars().all()
    if balances:
        avg_diff = sum(float(b.diff_value) for b in balances) / len(balances)
        bal_str = f"{avg_diff:.1f}%"
    else:
        bal_str = "데이터 부족"

    last = sessions[0]
    last_str = f"{last.started_at.strftime('%Y-%m-%d')} {last.exercise_type} {last.set_count}세트"

    return (
        f"- 최근 7일 총 세션: {len(sessions)}개\n"
        f"- 운동별: {type_str}\n"
        f"- 평균 타깃 근육 활성화: {avg_target:.1f}%\n"
        f"- 평균 좌우 밸런스 차이: {bal_str}\n"
        f"- 마지막 세션: {last_str}"
    )
