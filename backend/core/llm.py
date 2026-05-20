"""Google Gemini-backed chat wrapper for the IMO backend."""

from __future__ import annotations

import logging
import re
from typing import Any, Optional

from google import genai
from google.genai import types
from google.genai.errors import APIError

from core.config import settings
from core.exercise_catalog import SUPPORT_SCOPE_SYSTEM_CONTEXT

logger = logging.getLogger("imo.llm")


SYSTEM_PROMPT = """\
당신은 IMO(Inside Muscle Out) 앱의 운동 코치입니다.

응답 원칙:
1. 항상 한국어로 답합니다.
2. 사용자가 이해하기 쉽게 짧고 명확하게 설명합니다.
3. 앱이 지원하는 운동과 센서 사용 맥락 안에서 답합니다.
4. PDF 문서 근거가 있으면 그 내용을 우선 반영하되, 문서에 없는 내용은 단정하지 않습니다.
5. 의료 진단처럼 들릴 수 있는 표현은 피하고, 필요한 경우 점검 순서나 일반적인 주의사항을 안내합니다.
6. 길어도 핵심은 1~3개의 짧은 문단 또는 bullet 안에 정리합니다.
"""


FALLBACK_REPLY = (
    "죄송합니다. 지금은 답변을 생성할 수 없습니다. 잠시 후 다시 시도해 주세요."
)

_BICEPS_HINT_RE = re.compile(
    r"(biceps?|bicep|이두|이두근|biceps brachii)", re.IGNORECASE
)
_TENDON_HINT_RE = re.compile(
    r"(tendon|힘줄|innervation zone|신경지배|motor point|모터 포인트)",
    re.IGNORECASE,
)
_SENSOR_HINT_RE = re.compile(
    r"(sensor|electrode|전극|부착|reattach|detach|skin preparation|피부)",
    re.IGNORECASE,
)
_NOISE_HINT_RE = re.compile(
    r"(noise|artifact|노이즈|잡음|sampling|filter|필터|signal quality|신호 품질)",
    re.IGNORECASE,
)
_CALIBRATION_HINT_RE = re.compile(
    r"(calibration|baseline|mvc|캘리브레이션|기준값|보정)", re.IGNORECASE
)
_EXERCISE_HINT_RE = re.compile(
    r"(wall press|push ?up|푸시업|bicep curl|biceps curl|이두컬|lateral raise|standing arcs|레터럴 레이즈)",
    re.IGNORECASE,
)


_client: Optional[genai.Client] = None


def get_client() -> genai.Client:
    global _client
    if _client is None:
        if not settings.GEMINI_API_KEY:
            raise RuntimeError("GEMINI_API_KEY is not configured.")
        _client = genai.Client(api_key=settings.GEMINI_API_KEY)
    return _client


def _to_gemini_role(role: str) -> str:
    return "model" if role == "assistant" else "user"


def _parse_rag_context(rag_context: str) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    if not rag_context.strip():
        return entries

    blocks = [block.strip() for block in rag_context.split("\n\n") if block.strip()]
    for block in blocks:
        lines = [line.strip() for line in block.splitlines() if line.strip()]
        if not lines:
            continue

        header = lines[0]
        match = re.match(
            r"\[(?P<rank>\d+)\]\s+(?P<title>.+?)\s+\|\s+file=(?P<file>.+?)\s+\|\s+page=(?P<page>\d+)",
            header,
        )
        excerpt = " ".join(lines[1:]).strip()
        if not excerpt:
            excerpt = header

        if match:
            entries.append(
                {
                    "rank": int(match.group("rank")),
                    "title": match.group("title").strip(),
                    "file": match.group("file").strip(),
                    "page": int(match.group("page")),
                    "excerpt": excerpt,
                }
            )
        else:
            entries.append(
                {
                    "rank": len(entries) + 1,
                    "title": "RAG Source",
                    "file": "unknown",
                    "page": 0,
                    "excerpt": excerpt,
                }
            )
    return entries


def _dedupe_preserve_order(items: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for item in items:
        normalized = item.strip()
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        result.append(normalized)
    return result


def _build_rule_based_summary(user_message: str, entries: list[dict[str, Any]]) -> list[str]:
    message = user_message.strip()
    bullets: list[str] = []
    source_text = " ".join(entry["excerpt"] for entry in entries[:3])
    blended_text = f"{message} {source_text}"

    if _BICEPS_HINT_RE.search(blended_text) and _TENDON_HINT_RE.search(blended_text):
        bullets.append(
            "SENIAM 계열 문서 기준으로 이두근 전극은 근복(muscle belly) 쪽에 두고, 힘줄 부위와 "
            "innervation zone(신경지배대) 가까이는 피하는 방향으로 안내합니다."
        )

    if _SENSOR_HINT_RE.search(blended_text):
        bullets.append(
            "전극은 피부와 밀착되게 부착하고, 땀·유분·털처럼 접촉 저항을 키우는 요소를 먼저 정리하는 것이 좋습니다."
        )

    if _NOISE_HINT_RE.search(blended_text):
        bullets.append(
            "노이즈가 크면 전극 접촉 상태, 케이블 흔들림, 신호 취득 조건을 먼저 점검하는 것이 좋다고 문서들이 공통적으로 설명합니다."
        )

    if _CALIBRATION_HINT_RE.search(blended_text):
        bullets.append(
            "캘리브레이션 전에는 움직임과 불필요한 근수축을 줄이고, 센서 접촉 상태를 먼저 안정화하는 쪽이 유리합니다."
        )

    if _EXERCISE_HINT_RE.search(blended_text):
        bullets.append(
            "운동 가이드 문서는 반동을 줄이고, 제어된 속도로 가동범위를 유지하라고 안내하는 경우가 많습니다."
        )

    if not bullets and entries:
        bullets.append(
            "관련 PDF 문서를 찾았지만 로컬 LLM API 키가 없어 문서 핵심만 한국어로 간단히 정리해 드립니다."
        )
        bullets.append(
            "아래 참고 문서 위치를 함께 보고, 필요하면 질문을 더 구체적으로 바꿔 다시 물어보는 것이 좋습니다."
        )

    return _dedupe_preserve_order(bullets)[:3]


def _build_source_lines(entries: list[dict[str, Any]]) -> list[str]:
    lines = [
        f"- {entry['title']} ({entry['file']}, p.{entry['page']})"
        for entry in entries[:3]
    ]
    return _dedupe_preserve_order(lines)


def _build_rag_fallback_reply(user_message: str, rag_context: str) -> str:
    entries = _parse_rag_context(rag_context)
    if not entries:
        return FALLBACK_REPLY

    summary_lines = _build_rule_based_summary(user_message, entries)
    source_lines = _build_source_lines(entries)

    parts = [
        "현재 로컬 LLM API 키가 없어 PDF 문서를 기준으로 먼저 한국어 요약만 제공합니다.",
    ]
    if summary_lines:
        parts.append("\n".join(summary_lines))
    if source_lines:
        parts.append("참고 문서\n" + "\n".join(source_lines))
    parts.append(
        "더 자연스러운 한국어 설명이 필요하면 GEMINI_API_KEY를 설정한 뒤 다시 질문해 주세요."
    )
    return "\n\n".join(parts)


async def chat(
    user_message: str,
    history: list[dict[str, Any]],
    user_context: str,
    rag_context: str = "",
) -> dict[str, Any]:
    """Generate a chat reply, optionally augmented with retrieved PDF context."""
    if not settings.GEMINI_API_KEY:
        logger.warning("GEMINI_API_KEY missing; returning RAG fallback reply")
        reply = _build_rag_fallback_reply(user_message, rag_context)
        model = "rag_fallback" if rag_context.strip() else "fallback"
        return {"reply": reply, "model": model, "tokens_used": {}}

    system_parts = [
        SYSTEM_PROMPT,
        f"[서비스 지원 범위]\n{SUPPORT_SCOPE_SYSTEM_CONTEXT}",
        f"[사용자 운동 컨텍스트]\n{user_context}",
    ]
    if rag_context:
        system_parts.append(
            "[검색된 PDF 문서 발췌]\n"
            f"{rag_context}\n\n"
            "위 발췌문을 우선 근거로 삼아 답하고, 문서에 없는 내용은 추정처럼 표현해 주세요. "
            "답변은 반드시 한국어로 작성하고, 필요하면 간단한 점검 순서나 주의사항을 덧붙여 주세요."
        )
    system_instruction = "\n\n".join(system_parts)

    contents = [
        {
            "role": _to_gemini_role(message["role"]),
            "parts": [{"text": message["content"]}],
        }
        for message in history
    ]
    contents.append({"role": "user", "parts": [{"text": user_message}]})

    try:
        resp = await get_client().aio.models.generate_content(
            model=settings.LLM_MODEL,
            contents=contents,
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                max_output_tokens=1024,
            ),
        )
        reply = (resp.text or "").strip() or FALLBACK_REPLY
        usage = resp.usage_metadata
        return {
            "reply": reply,
            "model": settings.LLM_MODEL,
            "tokens_used": {
                "input": getattr(usage, "prompt_token_count", 0) or 0,
                "output": getattr(usage, "candidates_token_count", 0) or 0,
                "cached": getattr(usage, "cached_content_token_count", 0) or 0,
            },
        }
    except APIError as exc:
        logger.warning("LLM API error: %s", exc)
        return {"reply": FALLBACK_REPLY, "model": "fallback", "tokens_used": {}}
    except Exception as exc:
        logger.exception("LLM unexpected error: %s", exc)
        return {"reply": FALLBACK_REPLY, "model": "fallback", "tokens_used": {}}
