"""Google Gemini API 래퍼 — 운동 챗봇 전용.

설계 원칙:
- 모델은 settings.LLM_MODEL 환경변수로 토글 (개발 flash / 시연 pro).
- API 호출 실패 시 fallback 응답 반환 (서비스 가용성 우선, Phase A/B 동일 패턴).
- google-genai SDK 의 비동기 클라이언트 (client.aio) 사용 — FastAPI async 호환.
- Gemini 2.5 Flash 는 implicit caching 자동 적용 — 별도 cache_control 호출 불필요.
"""
import logging
from typing import List, Optional

from google import genai
from google.genai import types
from google.genai.errors import APIError

from core.config import settings

logger = logging.getLogger("imo.llm")


SYSTEM_PROMPT = """\
당신은 IMO (Inside Muscle Out) 앱의 운동 코치입니다.
사용자의 EMG 센서 기반 운동 기록을 보고 개인화된 조언을 한국어로 제공합니다.

규칙:
1. 운동·근육·회복·자세·영양 관련 질문에만 답변합니다.
2. 그 외 주제 (정치, 일상, 코딩 등) 는 정중히 거절하고 운동 주제로 유도합니다.
3. 의학적 진단/처방은 하지 않습니다. 통증/부상 관련은 전문의 상담을 권합니다.
4. 사용자의 최근 운동 데이터를 적극 인용하여 개인화된 답변을 합니다.
5. 1~3문장 이내로 짧고 실용적으로 답변합니다.
6. 데이터가 부족하면 솔직히 "데이터가 부족합니다" 라고 답합니다."""


FALLBACK_REPLY = "죄송합니다. 지금은 답변할 수 없습니다. 잠시 후 다시 시도해주세요."


_client: Optional[genai.Client] = None


def get_client() -> genai.Client:
    """Gemini 클라이언트 싱글톤."""
    global _client
    if _client is None:
        if not settings.GEMINI_API_KEY:
            raise RuntimeError("GEMINI_API_KEY 가 설정되지 않았습니다.")
        _client = genai.Client(api_key=settings.GEMINI_API_KEY)
    return _client


def _to_gemini_role(role: str) -> str:
    # 내부 히스토리는 'user'/'assistant' 로 저장 (앱 호환). LLM 호출 시점에만 변환.
    return "model" if role == "assistant" else "user"


async def chat(
    user_message: str,
    history: List[dict],
    user_context: str,
) -> dict:
    """챗봇 응답 생성.

    Args:
        user_message: 사용자 입력 메시지.
        history: 이전 대화 [{"role": "user|assistant", "content": "..."}, ...]
        user_context: 사용자 운동 데이터 요약 텍스트 (system 뒤에 결합).

    Returns:
        {"reply": "...", "model": "...", "tokens_used": {input, output, cached}}
        실패 시 fallback 응답.
    """
    if not settings.GEMINI_API_KEY:
        logger.warning("GEMINI_API_KEY 없음 — fallback 응답")
        return {"reply": FALLBACK_REPLY, "model": "fallback", "tokens_used": {}}

    # Gemini system_instruction 은 단일 문자열 — 고정 프롬프트 + 사용자 컨텍스트 결합.
    system_instruction = (
        f"{SYSTEM_PROMPT}\n\n[사용자 최근 운동 데이터]\n{user_context}"
    )

    contents = [
        {
            "role": _to_gemini_role(m["role"]),
            "parts": [{"text": m["content"]}],
        }
        for m in history
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
    except APIError as e:
        logger.warning("LLM 호출 실패: %s", e)
        return {"reply": FALLBACK_REPLY, "model": "fallback", "tokens_used": {}}
    except Exception as e:
        logger.exception("LLM 호출 중 예상치 못한 에러: %s", e)
        return {"reply": FALLBACK_REPLY, "model": "fallback", "tokens_used": {}}
