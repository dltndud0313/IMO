from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from core import llm
from core.cache import (
    append_chat_messages,
    build_user_workout_context,
    clear_chat_history,
    get_chat_history,
)
from core.config import settings
from core.database import get_db
from core.deps import get_current_user
from core.exercise_catalog import find_scope_guardrail_reply
from core.rate_limit import rate_limit_by_ip
from core.responses import success_response
from models.user import User
from schemas.chat import ChatRequest

router = APIRouter()


def _guardrail_result(reply: str) -> dict:
    return {
        "reply": reply,
        "model": "guardrail",
        "tokens_used": {"input": 0, "output": 0, "cached": 0},
    }


@router.post(
    "",
    dependencies=[Depends(rate_limit_by_ip("chat", 10, 60))],
)
@router.post(
    "/",
    dependencies=[Depends(rate_limit_by_ip("chat", 10, 60))],
    include_in_schema=False,
)
async def chat_send(
    body: ChatRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """운동 챗봇 — 사용자 메시지 → LLM 응답.

    히스토리는 Redis 에 사용자별 1개. 슬라이딩 윈도우로 최대 CHAT_MAX_TURNS 턴.
    """
    history = await get_chat_history(current_user.id)
    guardrail_reply = find_scope_guardrail_reply(body.message)

    if guardrail_reply:
        result = _guardrail_result(guardrail_reply)
    else:
        user_ctx = await build_user_workout_context(current_user.id, db)
        result = await llm.chat(
            user_message=body.message,
            history=history,
            user_context=user_ctx,
        )

    now = datetime.now(timezone.utc).isoformat()
    new_msgs = [
        {"role": "user", "content": body.message, "timestamp": now},
        {"role": "assistant", "content": result["reply"], "timestamp": now},
    ]
    await append_chat_messages(current_user.id, new_msgs, settings.CHAT_MAX_TURNS)

    return success_response({
        "reply": result["reply"],
        "model": result["model"],
        "tokensUsed": result["tokens_used"],
    })


@router.delete("")
@router.delete("/", include_in_schema=False)
async def chat_clear(current_user: User = Depends(get_current_user)):
    """현재 사용자의 대화 히스토리 초기화."""
    await clear_chat_history(current_user.id)
    return success_response({"cleared": True})


@router.get("/history")
async def chat_history(current_user: User = Depends(get_current_user)):
    """현재 대화 히스토리 조회 (앱 재진입 시 복원용)."""
    history = await get_chat_history(current_user.id)
    return success_response({"messages": history})
