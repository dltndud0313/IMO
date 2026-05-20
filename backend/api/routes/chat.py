import asyncio
import logging
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
from core.deps import get_optional_current_user
from core.exceptions import Unauthorized
from core.exercise_catalog import find_scope_guardrail_reply
from core.rag import retrieve_rag_context
from core.rate_limit import rate_limit_by_ip
from core.responses import success_response
from models.user import User
from schemas.chat import ChatRequest

router = APIRouter()
logger = logging.getLogger("imo.chat")

_ANONYMOUS_CHAT_KEY = "anonymous"
_ANONYMOUS_USER_CONTEXT = "익명 로컬 RAG 테스트 모드입니다. 사용자 운동 기록 정보는 없습니다."


def _guardrail_result(reply: str) -> dict:
    return {
        "reply": reply,
        "model": "guardrail",
        "tokens_used": {"input": 0, "output": 0, "cached": 0},
        "sources": [],
    }


def _chat_owner_key(current_user: User | None) -> str | int:
    if current_user is not None:
        return current_user.id
    return _ANONYMOUS_CHAT_KEY


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
    current_user: User | None = Depends(get_optional_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user is None and not settings.CHAT_ALLOW_ANONYMOUS:
        raise Unauthorized()

    owner_key = _chat_owner_key(current_user)
    history = await get_chat_history(owner_key)
    guardrail_reply = find_scope_guardrail_reply(body.message)

    if guardrail_reply:
        result = _guardrail_result(guardrail_reply)
    else:
        if current_user is not None:
            user_ctx = await build_user_workout_context(current_user.id, db)
        else:
            user_ctx = _ANONYMOUS_USER_CONTEXT

        rag_result = await asyncio.to_thread(retrieve_rag_context, body.message)
        logger.info(
            "chat rag sources user=%s sources=%s",
            owner_key,
            rag_result["sources"],
        )

        result = await llm.chat(
            user_message=body.message,
            history=history,
            user_context=user_ctx,
            rag_context=rag_result["context"],
        )
        result["sources"] = rag_result["sources"]

    now = datetime.now(timezone.utc).isoformat()
    new_msgs = [
        {"role": "user", "content": body.message, "timestamp": now},
        {"role": "assistant", "content": result["reply"], "timestamp": now},
    ]
    await append_chat_messages(owner_key, new_msgs, settings.CHAT_MAX_TURNS)

    return success_response(
        {
            "reply": result["reply"],
            "model": result["model"],
            "tokensUsed": result["tokens_used"],
            "sources": result.get("sources", []),
        }
    )


@router.delete("")
@router.delete("/", include_in_schema=False)
async def chat_clear(current_user: User | None = Depends(get_optional_current_user)):
    if current_user is None and not settings.CHAT_ALLOW_ANONYMOUS:
        raise Unauthorized()

    await clear_chat_history(_chat_owner_key(current_user))
    return success_response({"cleared": True})


@router.get("/history")
async def chat_history(current_user: User | None = Depends(get_optional_current_user)):
    if current_user is None and not settings.CHAT_ALLOW_ANONYMOUS:
        raise Unauthorized()

    history = await get_chat_history(_chat_owner_key(current_user))
    return success_response({"messages": history})
