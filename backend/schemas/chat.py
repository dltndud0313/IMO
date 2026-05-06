from datetime import datetime
from typing import List, Optional

from pydantic import Field

from schemas._base import CamelModel


class ChatRequest(CamelModel):
    message: str = Field(min_length=1, max_length=2000)


class ChatTokensUsed(CamelModel):
    input: int = 0
    output: int = 0
    cached: int = 0


class ChatResponse(CamelModel):
    reply: str
    model: str
    tokens_used: ChatTokensUsed


class ChatMessage(CamelModel):
    role: str  # "user" | "assistant"
    content: str
    timestamp: Optional[datetime] = None


class ChatHistoryResponse(CamelModel):
    messages: List[ChatMessage]
