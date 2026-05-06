# Phase C 작업 계획서 — 운동 추천 챗봇 (Google Gemini API)

> **작성일**: 2026-05-04 (v1.0) / 2026-05-06 (v1.1 — Anthropic → Gemini 전환)
> **선행 문서**: [phase_b_plan.md](phase_b_plan.md) (Refresh Blacklist + Rate Limit), [redis_integration_plan.md](redis_integration_plan.md) (Phase A)
> **현재 상태**: Phase A·B 완료 + EC2 운영 검증 + 시연용 더미 데이터 시드
> **이 문서의 범위**: 자기완결적 작업 매뉴얼 — 다음 작업 시 이 문서 + 현재 코드만 보고 그대로 실행 가능하도록 작성

---

## 0. 핵심 결정 사항

| # | 항목 | 결정 |
|---|------|------|
| 1 | LLM 제공자 | Google Gemini API (`google-genai` SDK, 무료 티어) |
| 2 | 모델 토글 | 환경변수 `LLM_MODEL` — 평상시 `gemini-2.5-flash`, 시연 직전 `gemini-2.5-pro` |
| 3 | 대화 형태 | **멀티턴** (5턴 히스토리 유지), 단발 응답 (스트리밍 X — 시간 남으면 추가) |
| 4 | 히스토리 저장 | Redis `chat:history:{user_id}`, TTL 1시간 (대화 종료 자동 정리) |
| 5 | 컨텍스트 주입 | 사용자 최근 7일 운동 통계를 시스템 프롬프트에 자동 첨부 |
| 6 | 가드레일 | 시스템 프롬프트에 "운동/근육/회복/자세" 외 질문 정중 거절 규칙 |
| 7 | Prompt caching | Gemini 2.5 Flash 의 implicit caching 자동 적용 (별도 호출 불필요) |
| 8 | Rate limit | 분당 10회 (Phase B 패턴 재활용) — Gemini 무료 한도(분 15·일 1500) 안쪽 |
| 9 | LLM 장애 시 정책 | fallback 메시지 응답 (서비스 가용성 우선) |
| 10 | 인증 | 필수 — 본인 운동 데이터 기반이라 익명 호출 불가 |
| 11 | 비용 | $0 — Google AI Studio 무료 티어. 결제수단 등록 불필요 |

> **설계 원칙**: Phase A/B 와 동일 — 외부 의존성 (Gemini API) 죽어도 서비스는 살아남고, 챗봇만 일시 미작동.
> **Gemini 선택 이유**: Anthropic API 는 결제수단 등록 + 최소 $5 충전 필요한데, 학생 졸업프로젝트 시연용으로 무료 한도가 충분한 Gemini 가 더 합리적. 한국어 품질도 운동 코치 시나리오에 충분.

---

## 1. 목표

### C-1. 개인화 운동 챗봇
- **현재 한계**: 사용자가 운동 데이터를 봐도 "그래서 뭐 하라는 거지?" 해석을 도와줄 사람 없음.
- **해결**: LLM 에 사용자 EMG 운동 통계를 주입해서 자연어 상담. "어깨 한 번 더 해도 돼?" → 좌우 밸런스 데이터 보고 답.
- **얻는 효과**:
  - 시연 시 평가관 즉석 질문 받아 답변 가능 (인터랙티브 임팩트)
  - 단순 통계 화면에 머물지 않고 행동 가이드 제공
  - AI 트렌드 직접 반영 (졸업프로젝트 차별점)

---

## 2. 변경/추가 파일 목록 (전체)

### 신규 파일
- `backend/core/llm.py` — Gemini SDK 래퍼 (모델 추상화, fallback)
- `backend/api/routes/chat.py` — POST /chat 라우터 (메인 엔드포인트)
- `backend/schemas/chat.py` — request/response 스키마
- `backend/tests/verify_chat.sh` — 통합 검증 스크립트

### 수정 파일

| 파일 | 변경 |
|------|------|
| `backend/core/cache.py` | chat history 헬퍼 3종 추가 (get/append/clear) + 운동 컨텍스트 빌더 |
| `backend/core/config.py` | `GEMINI_API_KEY`, `LLM_MODEL`, `CHAT_HISTORY_TTL` 추가 |
| `backend/main.py` | chat 라우터 등록 |
| `backend/requirements.txt` | `google-genai>=0.8.0,<2.0.0` 추가 (SDK) |
| `backend/docker-compose.yml` & `docker-compose.ec2.yml` | `GEMINI_API_KEY`, `LLM_MODEL` 환경변수 전달 |

### 영향 받는 파일
- 없음 — 기존 라우터/모델 건드리지 않음. 새 라우터·새 의존성만 추가.

---

## 3. 설계

### 3-1. 흐름도

```
┌────────────────────────────────────────────────────────────────┐
│ 사용자 → 앱 채팅 화면                                           │
│   "어깨 한 번 더 해도 될까?"                                    │
│      │                                                          │
│      ▼ POST /api/v1/chat { message }                            │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │ chat.py 라우터                                          │   │
│   │   1) rate_limit_by_ip("chat", 10, 60)                   │   │
│   │   2) get_current_user (JWT)                             │   │
│   │   3) Redis: chat:history:{user_id} 가져오기             │   │
│   │   4) 사용자 최근 7일 운동 통계 모아서 컨텍스트 만들기   │   │
│   │   5) llm.chat(system + history + user_msg) 호출         │   │
│   │   6) Redis: history 에 user_msg + reply 추가, TTL 갱신  │   │
│   │   7) 응답 반환                                          │   │
│   └─────────────────────────────────────────────────────────┘   │
│      │                                                          │
│      ▼ { "reply": "지난주 LATERAL_RAISE 4회 했고..." }          │
│   사용자 ← 앱 채팅 화면에 표시                                  │
└────────────────────────────────────────────────────────────────┘
```

### 3-2. API 엔드포인트

| 메서드 | 경로 | 설명 | 인증 |
|---|---|---|---|
| POST | `/api/v1/chat` | 메시지 전송, LLM 응답 받기 | 필수 |
| DELETE | `/api/v1/chat` | 현재 사용자 대화 히스토리 초기화 | 필수 |
| GET | `/api/v1/chat/history` | 현재 대화 히스토리 조회 (앱 재진입 시 복원용) | 필수 |

### 3-3. 요청/응답 스키마

**POST /chat 요청**:
```json
{ "message": "오늘 어깨 운동 추천해줘" }
```

**POST /chat 응답**:
```json
{
  "success": true,
  "data": {
    "reply": "지난주 좌우 밸런스가 -8% 라 ...",
    "model": "gemini-2.5-flash",
    "tokensUsed": { "input": 1850, "output": 320, "cached": 1500 }
  },
  "error": null
}
```

**GET /chat/history 응답**:
```json
{
  "success": true,
  "data": {
    "messages": [
      { "role": "user", "content": "...", "timestamp": "2026-05-04T..." },
      { "role": "assistant", "content": "...", "timestamp": "2026-05-04T..." }
    ]
  }
}
```

### 3-4. Redis 키 규칙

```
chat:history:{user_id}      값: JSON 직렬화된 List<Message>, TTL 1시간 (config CHAT_HISTORY_TTL)
ratelimit:chat:{ip}         값: 카운터, TTL 60초 (Phase B rate_limit 재사용)
```

### 3-5. 시스템 프롬프트 (한국어)

```
당신은 IMO (Inside Muscle Out) 앱의 운동 코치입니다.
사용자의 EMG 센서 기반 운동 기록을 보고 개인화된 조언을 한국어로 제공합니다.

규칙:
1. 운동·근육·회복·자세·영양 관련 질문에만 답변합니다.
2. 그 외 주제 (정치, 일상, 코딩 등) 는 정중히 거절하고 운동 주제로 유도합니다.
3. 의학적 진단/처방은 하지 않습니다. 통증/부상 관련은 전문의 상담을 권합니다.
4. 사용자의 최근 운동 데이터를 적극 인용하여 개인화된 답변을 합니다.
5. 1~3문장 이내로 짧고 실용적으로 답변합니다.
6. 데이터가 부족하면 솔직히 "데이터가 부족합니다" 라고 답합니다.
```

> 위 시스템 프롬프트는 매 요청마다 동일한 고정 영역. Gemini 2.5 Flash 의 implicit caching 이 이 영역을 자동 인식해 캐시 토큰 카운터에 반영.

### 3-6. 사용자 운동 컨텍스트 (system 프롬프트 뒤에 자동 첨부)

```
[사용자 최근 7일 운동 데이터]
- 총 세션 수: 12개
- 운동 종목별: PUSH_UP 5회 / LATERAL_RAISE 4회 / BICEP_CURL 3회
- 평균 타깃 근육 활성화: 64.2%
- 좌우 밸런스: 평균 -5.3% (오른쪽 우세)
- 마지막 세션: 2026-05-03 PUSH_UP 4세트
- 최근 피로 패턴: 마지막 세트에서 평균 reps 18% 감소

(최근 7일 데이터가 없으면 "최근 운동 기록 없음")
```

위 컨텍스트는 **사용자별로 다름**. Gemini 2.5 Flash 의 implicit caching 은 시스템 + 초반 토큰 자동 처리 — 별도 cache 객체 생성 불필요.

---

## 4. 단계별 구현

### Step 1. `core/config.py` 에 LLM 설정 추가

`Settings` 클래스에 다음 추가:

```python
# Google Gemini API — 운동 챗봇용 (무료 티어)
GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
# 모델 토글 — 평상시 flash (한도 풍부), 시연 직전 pro (품질).
# gemini-2.5-flash / gemini-2.5-pro
LLM_MODEL: str = os.getenv("LLM_MODEL", "gemini-2.5-flash")
# 대화 히스토리 Redis TTL (초). 1시간 = 3600.
CHAT_HISTORY_TTL: int = int(os.getenv("CHAT_HISTORY_TTL", "3600"))
# 한 대화에서 유지할 최대 턴 수 (히스토리 누적 토큰 폭발 방지)
CHAT_MAX_TURNS: int = int(os.getenv("CHAT_MAX_TURNS", "10"))
```

### Step 2. `requirements.txt` 에 SDK 추가

```
google-genai>=0.8.0,<2.0.0
```

> `google-genai` 는 신버전 통합 SDK (구 `google-generativeai` 후속). 빌드 시 `pip install -r requirements.txt` 가 새 의존성 자동 설치.

### Step 3. `core/llm.py` 신규 작성

전체 파일은 [backend/core/llm.py](../core/llm.py) 참조 — 핵심 차이점만 요약:

- `genai.Client(api_key=...)` 싱글톤, `client.aio.models.generate_content(...)` 비동기 호출.
- Gemini 는 system 이 단일 문자열 (`GenerateContentConfig.system_instruction`) — 고정 프롬프트 + 사용자 컨텍스트를 한 문자열로 결합.
- 히스토리 role 변환: 내부 저장은 `"assistant"` (앱 호환) → Gemini 호출 시점에 `"model"` 로 매핑.
- contents 형식: `[{"role": "user|model", "parts": [{"text": "..."}]}]`.
- usage 응답: `resp.usage_metadata.prompt_token_count` / `candidates_token_count` / `cached_content_token_count`.
- 예외 처리: `from google.genai.errors import APIError` — fallback 응답으로 graceful degradation.

### Step 4. `core/cache.py` 에 chat history 헬퍼 추가

파일 하단에 다음 추가:

```python
# ============================================================
# Chat History (Phase C — 운동 챗봇)
# ============================================================

def _chat_key(user_id: int) -> str:
    return f"chat:history:{user_id}"


async def get_chat_history(user_id: int) -> list:
    """대화 히스토리 조회. Redis 장애/없음 시 빈 리스트 반환."""
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
    """user 메시지 + assistant 응답을 히스토리에 추가, 최대 max_turns × 2 메시지로 윈도우.

    TTL 갱신 — 활성 대화는 expire 안 됨.
    """
    if not settings.CACHE_ENABLED:
        return
    try:
        history = await get_chat_history(user_id)
        history.extend(new_messages)
        # 슬라이딩 윈도우 — 오래된 메시지 제거
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
    """사용자의 최근 7일 운동 통계 요약 텍스트.

    LLM 시스템 프롬프트 뒤에 첨부됨. 데이터 없으면 "최근 운동 기록 없음" 반환.
    """
    from datetime import datetime, timedelta
    from sqlalchemy import select, func
    from models.session import WorkoutSession

    cutoff = datetime.utcnow() - timedelta(days=7)
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

    avg_target = sum(s.avg_target_muscle or 0 for s in sessions) / len(sessions)

    # 좌우 밸런스 — balance_summary 의 diff_value 평균 (있는 것만)
    diffs = [s.balance_summary["diff_value"] for s in sessions
             if s.balance_summary and s.balance_summary.get("diff_value") is not None]
    bal_str = f"{sum(diffs)/len(diffs):.1f}%" if diffs else "데이터 부족"

    last = sessions[0]
    last_str = f"{last.started_at.strftime('%Y-%m-%d')} {last.exercise_type} {last.set_count}세트"

    return (
        f"- 최근 7일 총 세션: {len(sessions)}개\n"
        f"- 운동별: {type_str}\n"
        f"- 평균 타깃 근육 활성화: {avg_target:.1f}%\n"
        f"- 평균 좌우 밸런스 차이: {bal_str}\n"
        f"- 마지막 세션: {last_str}"
    )
```

> ⚠️ `WorkoutSession.balance_summary` 가 JSONB 컬럼이라고 가정 — 현재 모델 확인하고 필드명 정확히 매칭 필요. 만약 컬럼이 분리되어 있으면 (예: `balance_diff_value` 단독 컬럼) 그쪽으로 변경.

### Step 5. `schemas/chat.py` 신규 작성

```python
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000)


class ChatTokensUsed(BaseModel):
    input: int = 0
    output: int = 0
    cached: int = 0


class ChatResponse(BaseModel):
    reply: str
    model: str
    tokens_used: ChatTokensUsed = Field(alias="tokensUsed")

    class Config:
        populate_by_name = True


class ChatMessage(BaseModel):
    role: str  # "user" | "assistant"
    content: str
    timestamp: Optional[datetime] = None


class ChatHistoryResponse(BaseModel):
    messages: List[ChatMessage]
```

### Step 6. `api/routes/chat.py` 신규 작성

```python
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
from core.rate_limit import rate_limit_by_ip
from core.responses import success_response
from models.user import User
from schemas.chat import ChatRequest, ChatResponse

router = APIRouter()


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
    """운동 챗봇 — 사용자 메시지 → LLM 응답."""
    history = await get_chat_history(current_user.id)
    user_ctx = await build_user_workout_context(current_user.id, db)

    result = await llm.chat(
        user_message=body.message,
        history=history,
        user_context=user_ctx,
    )

    # 히스토리에 user + assistant 메시지 모두 추가
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
```

### Step 7. `main.py` 에 라우터 등록

```python
from api.routes import auth, chat, exercises, sessions, statistics, users
# ... 기존 import ...

# ---- 라우터 등록 ----
app.include_router(auth.router, prefix="/api/v1/auth", tags=["Authentication"])
app.include_router(users.router, prefix="/api/v1/users", tags=["Users"])
app.include_router(sessions.router, prefix="/api/v1/sessions", tags=["Sessions"])
app.include_router(statistics.router, prefix="/api/v1/statistics", tags=["Statistics"])
app.include_router(exercises.router, prefix="/api/v1/exercises", tags=["Exercises"])
app.include_router(chat.router, prefix="/api/v1/chat", tags=["Chat"])  # ← 추가
```

### Step 8. docker-compose 환경변수 전달

`docker-compose.yml` 의 api 서비스 `environment` 에 추가:

```yaml
- GEMINI_API_KEY=${GEMINI_API_KEY:-}
- LLM_MODEL=${LLM_MODEL:-gemini-2.5-flash}
- CHAT_HISTORY_TTL=${CHAT_HISTORY_TTL:-3600}
- CHAT_MAX_TURNS=${CHAT_MAX_TURNS:-10}
```

`docker-compose.ec2.yml` 도 동일 (운영도 일단 flash 기본 — 시연 직전 pro 토글):

```yaml
- GEMINI_API_KEY=${GEMINI_API_KEY}
- LLM_MODEL=${LLM_MODEL:-gemini-2.5-flash}
```

`.env` (gitignore 됨, 로컬에서 직접 작성):
```
GEMINI_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
LLM_MODEL=gemini-2.5-flash
```

EC2 의 `.env` 도 같은 파일에 추가 (서버 SSH 접속 후 `vim .env` 로 직접):
```
GEMINI_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
LLM_MODEL=gemini-2.5-flash
```

> 시연 평가 직전 EC2 에서 `LLM_MODEL=gemini-2.5-pro` 로 토글해 품질 향상시킬 수 있음. 단 무료 한도 일 50회 정도라 평가 시간 외 호출 자제.
> ⚠️ API 키는 **절대 git 커밋 금지**. `.env` 가 `.gitignore` 에 있는지 한 번 확인.

---

## 5. 검증 시나리오 — `tests/verify_chat.sh` 신규

```bash
#!/bin/sh
# Phase C 챗봇 검증
# 실행: bash tests/verify_chat.sh
# 전제: docker compose up + ANTHROPIC_API_KEY 설정

set -e

BASE="http://localhost:8000/api/v1"
EMAIL="chat_$(date +%s)@example.com"
PW="testpass123"

extract() {
  grep -o "\"$1\":\"[^\"]*\"" /tmp/chat_resp.json | sed "s/\"$1\":\"//;s/\"//"
}

echo "[1] 데모 회원가입 → access token"
curl -s -X POST "$BASE/auth/signup" -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\",\"nickname\":\"chat\"}" \
  > /tmp/chat_resp.json
TOKEN=$(extract accessToken)
echo "  token: ${TOKEN:0:30}..."

echo
echo "[2] 운동 관련 질문 → 정상 답변 기대"
curl -s -X POST "$BASE/chat" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"message":"오늘 어깨 운동 추천해줘"}'
echo

echo
echo "[3] 멀티턴 — 이전 대화 컨텍스트 활용"
curl -s -X POST "$BASE/chat" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"message":"방금 추천한 운동 주의사항은?"}'
echo

echo
echo "[4] 가드레일 — 운동 외 질문 거부 기대"
curl -s -X POST "$BASE/chat" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"message":"오늘 주식 추천해줘"}'
echo

echo
echo "[5] 히스토리 조회"
curl -s "$BASE/chat/history" -H "Authorization: Bearer $TOKEN"
echo

echo
echo "[6] 히스토리 초기화"
curl -s -X DELETE "$BASE/chat" -H "Authorization: Bearer $TOKEN"
echo

echo
echo "[7] 초기화 후 히스토리 조회 → 빈 배열 기대"
curl -s "$BASE/chat/history" -H "Authorization: Bearer $TOKEN"
echo

echo
echo "[8] Redis chat 키 확인 (초기화 후라 0개 기대)"
docker compose exec -T redis redis-cli KEYS 'chat:history:*'

echo
echo "[9] Rate limit — 11회 빠른 호출 → 11번째 429 기대"
for i in 1 2 3 4 5 6 7 8 9 10 11; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/chat" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    -d '{"message":"테스트"}')
  echo "  Try $i: HTTP $CODE"
done

echo
echo "검증 끝."
```

---

## 6. 진행 순서 (체크리스트)

```
[ ] 1. Google AI Studio (aistudio.google.com) 에서 API 키 발급 + 로컬 .env 에 추가
[ ] 2. core/config.py 에 LLM 설정 4개 추가 (§4 Step 1)
[ ] 3. requirements.txt 에 google-genai SDK 추가 (§4 Step 2)
[ ] 4. core/llm.py 신규 작성 (§4 Step 3)
[ ] 5. core/cache.py 에 chat history 헬퍼 + 컨텍스트 빌더 추가 (§4 Step 4)
[ ] 6. schemas/chat.py 신규 작성 (§4 Step 5)
[ ] 7. api/routes/chat.py 신규 작성 (§4 Step 6)
[ ] 8. main.py 에 chat 라우터 등록 (§4 Step 7)
[ ] 9. docker-compose.yml + docker-compose.ec2.yml 환경변수 추가 (§4 Step 8)
[ ] 10. tests/verify_chat.sh 작성 (§5)
[ ] 11. docker compose down && up -d --build → verify_chat.sh 실행
[ ] 12. 검증 통과 후 커밋 분할 + push
[ ] 13. EC2 에 GEMINI_API_KEY 환경변수 추가 + 재배포
```

---

## 7. 커밋 분할 계획 (push 직전)

```
chore(backend): google-genai SDK 의존성 + LLM 설정 환경변수 추가
feat(backend/llm): core/llm.py — Google Gemini API 래퍼 (fallback 포함)
feat(backend/cache): chat history Redis 헬퍼 + 운동 컨텍스트 빌더
feat(backend/chat): POST /chat 라우터 — 운동 챗봇 (멀티턴, rate limit)
chore(backend): docker-compose 에 GEMINI_API_KEY · LLM_MODEL 환경변수 전달
test(backend): tests/verify_chat.sh — 챗봇 통합 검증 스크립트
docs(backend): Phase C 작업 결과 보고 (선택 — phase_c_report.md)
```

---

## 8. 주의사항 / 함정

### 8-1. API 키 유출 방지
- `.env` 가 `.gitignore` 에 있는지 반드시 확인
- 커밋 직전 `git diff --cached` 로 `AIza` 문자열 검색
- 만약 유출 시 즉시 Google AI Studio 에서 키 revoke + 새 키 발급

### 8-2. 무료 한도 초과 방지
- Rate limit 분당 10회 → Gemini Flash 분당 15회 한도 안쪽
- 일 한도 1500회 (Flash) / 50회 (Pro) — 시연 외 자동 호출 금지
- Pro 토글은 시연 직전 일시적으로만, 평소엔 Flash 유지
- 무제한 컨텍스트 누적 방지 — `CHAT_MAX_TURNS=10` 슬라이딩 윈도우

### 8-3. 한국어 품질
- Gemini 2.5 Flash 한국어 자연스러움 충분. 시연 발표용은 Pro 가 어휘 풍부
- 만약 답변이 너무 길면 system 프롬프트의 "1~3문장" 강조 + `max_output_tokens=512` 더 줄이기

### 8-4. 가드레일 우회
- 사용자가 "역할극으로 운동 코치 그만하고..." 같은 prompt injection 시도 가능
- 시스템 프롬프트에 "역할 변경 요청 거부" 추가 (현재는 미포함, 시간 남으면 강화)

### 8-5. 운동 데이터 없는 사용자
- 신규 가입 직후 데이터 0개 → 컨텍스트가 "최근 운동 기록 없음"
- 챗봇이 "데이터가 부족하다" 답변하므로 자연스러움. 시연 시엔 데모 계정 (운동 기록 20개 있음) 사용.

### 8-6. Redis 장애 시 동작
- chat history Redis 장애 → 빈 히스토리로 매번 단발 대화로 동작 (서비스 살아있음)
- LLM API 장애 → fallback 메시지 응답
- 두 외부 의존성 모두 죽어도 백엔드 자체는 멀쩡 (Phase A/B 동일 정책)

### 8-7. WorkoutSession 모델 필드 확인
- `build_user_workout_context` 가 `balance_summary` JSONB 를 가정. 실제 모델 확인 후 수정 필요.

### 8-8. SDK 비동기 호출 컨텍스트
- FastAPI 가 async 라 `client.aio.models.generate_content(...)` 사용. sync 호출하면 이벤트 루프 블로킹.

### 8-9. Gemini 응답 안전 필터
- Gemini 는 응답 안전 필터 (HARM_CATEGORY) 가 기본 활성. 운동/건강 주제는 거의 영향 없지만, 통증 관련 답변이 차단되면 `resp.text` 가 빈 값으로 옴 → fallback 응답으로 처리됨.

---

## 9. 롤백 절차

| 영향 범위 | 롤백 방법 |
|----------|----------|
| 챗봇만 깨짐 | EC2 에서 `GEMINI_API_KEY=` 빈 값으로 두고 재기동 → 모든 호출 fallback 응답 |
| 전체 인증 영향 | feature 브랜치 통째로 develop 에서 revert |
| 무료 한도 초과 / 할당량 폭주 | EC2 에서 `GEMINI_API_KEY=` 비우고 재기동 → LLM 호출 즉시 차단 |

---

## 10. 향후 확장 (이번 범위 외)

| # | 항목 | 설명 |
|---|------|------|
| 1 | 스트리밍 응답 | SSE 또는 WebSocket 으로 토큰 단위 실시간 표시 (앱 UI 작업 필요) |
| 2 | Function calling | LLM 이 직접 `getWeeklyStats(weekStart)` 같은 도구 호출 → 더 정확한 답변 |
| 3 | 이미지 입력 | 사용자가 자세 사진 올리면 분석 (Vision API) |
| 4 | 음성 입력 | TTS 와 결합해 음성 대화 |
| 5 | 다중 대화 세션 | 현재는 사용자당 1개 활성 — 여러 대화 분리 |
| 6 | LLM 응답 평가/피드백 | 사용자가 좋아요/싫어요 → 향후 RLHF 또는 모델 튜닝 |
| 7 | 비용 모니터링 대시보드 | tokens_used 누적 통계 → admin 화면 |

---

## 11. 검증 완료 정의 (DoD)

- [ ] `verify_chat.sh` 의 9개 단계 모두 기대 결과대로
- [ ] Redis 키 정확 (`chat:history:{user_id}`)
- [ ] Gemini 2.5 Flash 응답 한국어 자연스러움
- [ ] 가드레일 동작 (운동 외 질문 거절)
- [ ] 멀티턴 컨텍스트 활용 ("방금 말한 거" 같은 표현 이해)
- [ ] Pro 환경변수 토글 시 응답 품질 향상 확인 (시연 직전만 잠깐)
- [ ] 사용자 운동 데이터 인용 (예: "지난주 PUSH_UP 5회 했네요...")
- [ ] EC2 배포 후 외부에서 `https://k14c203.p.ssafy.io/api/v1/chat` 정상 호출
- [ ] Google AI Studio 에서 일별 사용량/할당량 모니터링 동작 확인

---

## 12. 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| v1.0 | 2026-05-04 | 최초 작성 — Phase C 운동 챗봇 작업 매뉴얼 (Anthropic Claude 기반) |
| v1.1 | 2026-05-06 | LLM 제공자 Anthropic → Google Gemini 전환. 이유: 결제수단 등록 부담 회피, 무료 티어로 시연 충분. 코드(llm.py·config·docker-compose) + 문서 동기화 |
