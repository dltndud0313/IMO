from __future__ import annotations

import json
import logging
import math
import re
from collections import Counter
from dataclasses import asdict, dataclass
from pathlib import Path
from threading import Lock
from typing import Any

from core.config import settings

try:
    from pypdf import PdfReader
except Exception:  # pragma: no cover - dependency may be absent in dev env
    PdfReader = None

logger = logging.getLogger("imo.rag")

_TOKEN_RE = re.compile(r"[A-Za-z0-9가-힣]{2,}")
_BLANK_LINE_RE = re.compile(r"\n\s*\n+")
_WHITESPACE_RE = re.compile(r"[ \t\r\f\v]+")
_RAG_CACHE_VERSION = 2

_DOC_HINTS = {
    "fundamental-concepts-in-emg-signal-acquisition.pdf": {
        "title": "Delsys Fundamental Concepts in EMG Signal Acquisition",
        "tags": [
            "emg",
            "signal acquisition",
            "noise",
            "artifact",
            "filter",
            "sampling",
            "adc",
            "signal quality",
            "electrode",
            "sensor",
        ],
    },
    "Your-Home-Exercise-Plan-ML3403.pdf": {
        "title": "NHS Home Exercise Plan",
        "tags": [
            "exercise",
            "wall press",
            "push up",
            "push-up",
            "press up",
            "bicep curl",
            "biceps curl",
            "standing arcs",
            "lateral raise",
            "form",
        ],
    },
    "seniam_recommendations.en.pdf": {
        "title": "SENIAM Recommendations",
        "tags": [
            "seniam",
            "surface emg",
            "electrode placement",
            "skin preparation",
            "sensor attachment",
            "muscle placement",
            "interference",
            "noise",
            "biceps",
            "biceps brachii",
            "muscle belly",
            "tendon",
            "innervation zone",
            "motor point",
        ],
    },
    "seniam_commentary.en.pdf": {
        "title": "SENIAM Commentary",
        "tags": [
            "seniam",
            "commentary",
            "surface emg",
            "electrode",
            "placement",
            "signal quality",
            "measurement",
            "biceps",
            "biceps brachii",
            "muscle belly",
            "tendon",
            "innervation zone",
            "motor point",
        ],
    },
}

_QUERY_EXPANSIONS = (
    (
        ("센서", "부착", "전극", "재부착", "떨어짐", "접촉"),
        (
            "sensor",
            "electrode",
            "placement",
            "attach",
            "attached",
            "detached",
            "reattach",
            "skin preparation",
            "contact",
        ),
    ),
    (
        ("캘리브레이션", "기준값", "baseline", "mvc", "휴식", "안정"),
        (
            "calibration",
            "baseline",
            "mvc",
            "maximum voluntary contraction",
            "rest",
            "signal quality",
        ),
    ),
    (
        ("노이즈", "잡음", "튐", "이상", "아티팩트"),
        (
            "noise",
            "artifact",
            "interference",
            "signal quality",
            "signal acquisition",
            "sampling",
            "filter",
        ),
    ),
    (
        ("imu", "관성", "가속도", "자이로", "움직임"),
        (
            "imu",
            "inertial",
            "accelerometer",
            "gyroscope",
            "motion",
            "placement",
        ),
    ),
    (
        ("emg", "근전도", "근전위"),
        (
            "emg",
            "electromyography",
            "surface emg",
            "signal acquisition",
            "electrode",
        ),
    ),
    (
        ("푸시업", "푸쉬업", "팔굽혀펴기"),
        (
            "push up",
            "push-up",
            "press up",
            "wall press",
            "chest",
            "triceps",
        ),
    ),
    (
        ("이두컬", "이두", "컬", "bicep", "biceps"),
        (
            "bicep curl",
            "biceps curl",
            "curl",
            "elbow flexion",
            "arm curl",
            "biceps",
        ),
    ),
    (
        ("레터럴레이즈", "레터럴", "사이드레이즈", "어깨"),
        (
            "lateral raise",
            "standing arcs",
            "shoulder",
            "deltoid",
            "raise",
        ),
    ),
    (
        ("힘줄", "tendon", "innervation zone", "신경지배영역"),
        (
            "tendon",
            "innervation zone",
            "motor point",
            "muscle belly",
        ),
    ),
)

_state_lock = Lock()
_state_signature: tuple[tuple[str, int, int], ...] | None = None
_state_cache: "_RagState | None" = None


@dataclass
class RagChunk:
    chunk_id: str
    source_name: str
    title: str
    page_start: int
    page_end: int
    text: str
    tags: list[str]


@dataclass
class RagMatch:
    chunk: RagChunk
    score: float


@dataclass
class _RagState:
    chunks: list[RagChunk]
    term_freqs: list[Counter[str]]
    doc_freq: dict[str, int]
    avg_len: float


def warm_rag_index() -> dict[str, Any]:
    if not settings.RAG_ENABLED:
        return {"enabled": False, "ready": False, "reason": "disabled"}

    state = _get_rag_state()
    if state is None:
        return {"enabled": True, "ready": False, "reason": "unavailable"}

    return {
        "enabled": True,
        "ready": True,
        "documents": len(_build_signature(Path(settings.RAG_DOCS_DIR))),
        "chunks": len(state.chunks),
        "cache_path": str(_cache_path(Path(settings.RAG_DOCS_DIR))),
    }


def retrieve_rag_context(query: str) -> dict[str, Any]:
    if not settings.RAG_ENABLED:
        return {"context": "", "sources": []}

    state = _get_rag_state()
    if state is None or not state.chunks:
        return {"context": "", "sources": []}

    matches = _search(query, state, top_k=settings.RAG_TOP_K)
    if not matches:
        return {"context": "", "sources": []}

    parts: list[str] = []
    sources: list[dict[str, Any]] = []
    total_chars = 0
    for index, match in enumerate(matches, start=1):
        excerpt = match.chunk.text.strip()
        if not excerpt:
            continue
        block = (
            f"[{index}] {match.chunk.title} | file={match.chunk.source_name} | "
            f"page={match.chunk.page_start}\n{excerpt}"
        )
        if total_chars and total_chars + len(block) > settings.RAG_MAX_CONTEXT_CHARS:
            break
        parts.append(block)
        total_chars += len(block)
        sources.append(
            {
                "title": match.chunk.title,
                "file": match.chunk.source_name,
                "page": match.chunk.page_start,
                "score": round(match.score, 3),
            }
        )

    return {"context": "\n\n".join(parts), "sources": sources}


def _get_rag_state() -> _RagState | None:
    global _state_cache, _state_signature

    docs_dir = Path(settings.RAG_DOCS_DIR)
    if not docs_dir.exists():
        logger.warning("RAG docs dir not found: %s", docs_dir)
        return None

    signature = _build_signature(docs_dir)
    with _state_lock:
        if _state_cache is not None and _state_signature == signature:
            return _state_cache

        state = _load_cached_state(docs_dir, signature)
        if state is None:
            state = _build_state(docs_dir)
            if state is None:
                return None
            _save_cached_state(docs_dir, signature, state)

        _state_cache = state
        _state_signature = signature
        return state


def _build_signature(docs_dir: Path) -> tuple[tuple[str, int, int], ...]:
    signature: list[tuple[str, int, int]] = []
    for doc_path in sorted(docs_dir.glob("*.pdf")):
        stat = doc_path.stat()
        signature.append((doc_path.name, stat.st_size, stat.st_mtime_ns))
    return tuple(signature)


def _cache_path(docs_dir: Path) -> Path:
    return docs_dir.parent / "rag_index_cache.json"


def _load_cached_state(
    docs_dir: Path,
    signature: tuple[tuple[str, int, int], ...],
) -> _RagState | None:
    cache_path = _cache_path(docs_dir)
    if not cache_path.exists():
        return None

    try:
        raw = json.loads(cache_path.read_text(encoding="utf-8"))
        if raw.get("version") != _RAG_CACHE_VERSION:
            return None
        if tuple(tuple(item) for item in raw.get("signature", [])) != signature:
            return None
        chunks = [RagChunk(**chunk) for chunk in raw.get("chunks", [])]
        return _build_runtime_state(chunks)
    except Exception as exc:
        logger.warning("failed to load RAG cache: %s", exc)
        return None


def _save_cached_state(
    docs_dir: Path,
    signature: tuple[tuple[str, int, int], ...],
    state: _RagState,
) -> None:
    cache_path = _cache_path(docs_dir)
    try:
        payload = {
            "version": _RAG_CACHE_VERSION,
            "signature": list(signature),
            "chunks": [asdict(chunk) for chunk in state.chunks],
        }
        cache_path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
    except Exception as exc:
        logger.warning("failed to save RAG cache: %s", exc)


def _build_state(docs_dir: Path) -> _RagState | None:
    if PdfReader is None:
        logger.warning(
            "pypdf is not installed; RAG is disabled until dependency is available"
        )
        return None

    chunks: list[RagChunk] = []
    for doc_path in sorted(docs_dir.glob("*.pdf")):
        chunks.extend(_extract_chunks_from_pdf(doc_path))

    if not chunks:
        logger.warning("no RAG chunks were extracted from %s", docs_dir)
        return None

    logger.info(
        "built RAG index from %d chunks across %d PDFs",
        len(chunks),
        len(list(docs_dir.glob("*.pdf"))),
    )
    return _build_runtime_state(chunks)


def _build_runtime_state(chunks: list[RagChunk]) -> _RagState:
    term_freqs: list[Counter[str]] = []
    doc_freq: Counter[str] = Counter()
    lengths: list[int] = []

    for chunk in chunks:
        freq = Counter(_tokenize(chunk.text))
        for token in _tokenize(chunk.title):
            freq[token] += 2
        for tag in chunk.tags:
            for token in _tokenize(tag):
                freq[token] += 3
        term_freqs.append(freq)
        lengths.append(sum(freq.values()) or 1)
        for token in freq:
            doc_freq[token] += 1

    avg_len = (sum(lengths) / len(lengths)) if lengths else 1.0
    return _RagState(
        chunks=chunks,
        term_freqs=term_freqs,
        doc_freq=dict(doc_freq),
        avg_len=avg_len,
    )


def _extract_chunks_from_pdf(doc_path: Path) -> list[RagChunk]:
    hints = _DOC_HINTS.get(doc_path.name, {})
    title = hints.get("title", doc_path.stem.replace("_", " "))
    tags = list(hints.get("tags", []))
    chunks: list[RagChunk] = []

    try:
        reader = PdfReader(str(doc_path))
    except Exception as exc:
        logger.warning("failed to open PDF %s: %s", doc_path.name, exc)
        return []

    chunk_index = 0
    for page_num, page in enumerate(reader.pages, start=1):
        try:
            text = page.extract_text() or ""
        except Exception as exc:
            logger.warning(
                "failed to extract page %s from %s: %s",
                page_num,
                doc_path.name,
                exc,
            )
            continue
        normalized = _normalize_text(text)
        if not normalized:
            continue
        for block in _split_into_chunks(normalized):
            chunk_index += 1
            chunks.append(
                RagChunk(
                    chunk_id=f"{doc_path.stem}:{page_num}:{chunk_index}",
                    source_name=doc_path.name,
                    title=title,
                    page_start=page_num,
                    page_end=page_num,
                    text=block,
                    tags=tags,
                )
            )
    return chunks


def _normalize_text(text: str) -> str:
    text = text.replace("\x00", " ")
    text = text.replace("\u00ad", "")
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = _WHITESPACE_RE.sub(" ", text)
    lines = [line.strip() for line in text.split("\n")]
    lines = [line for line in lines if line]
    return "\n".join(lines).strip()


def _split_into_chunks(text: str) -> list[str]:
    paragraphs = [p.strip() for p in _BLANK_LINE_RE.split(text) if p.strip()]
    if not paragraphs:
        paragraphs = [text]

    chunks: list[str] = []
    current = ""
    chunk_size = settings.RAG_CHUNK_SIZE
    overlap = settings.RAG_CHUNK_OVERLAP

    for paragraph in paragraphs:
        for segment in _split_oversized_paragraph(paragraph, chunk_size):
            proposed = segment if not current else f"{current}\n\n{segment}"
            if current and len(proposed) > chunk_size:
                chunks.append(current.strip())
                tail = current[-overlap:].strip() if overlap > 0 else ""
                current = f"{tail}\n\n{segment}".strip() if tail else segment
            else:
                current = proposed.strip()

    if current:
        chunks.append(current.strip())
    return chunks


def _split_oversized_paragraph(paragraph: str, chunk_size: int) -> list[str]:
    if len(paragraph) <= chunk_size:
        return [paragraph]

    sentence_parts = re.split(r"(?<=[.!?])\s+", paragraph)
    if len(sentence_parts) == 1:
        return [
            paragraph[index : index + chunk_size]
            for index in range(0, len(paragraph), chunk_size)
        ]

    segments: list[str] = []
    current = ""
    for part in sentence_parts:
        part = part.strip()
        if not part:
            continue
        proposed = part if not current else f"{current} {part}"
        if current and len(proposed) > chunk_size:
            segments.append(current.strip())
            current = part
        else:
            current = proposed.strip()
    if current:
        segments.append(current.strip())
    return segments


def _search(query: str, state: _RagState, top_k: int) -> list[RagMatch]:
    query_terms = _expand_query_terms(query)
    if not query_terms:
        return []

    total_docs = max(len(state.chunks), 1)
    avg_len = max(state.avg_len, 1.0)
    k1 = 1.4
    b = 0.75
    results: list[RagMatch] = []

    for idx, chunk in enumerate(state.chunks):
        freq = state.term_freqs[idx]
        doc_len = max(sum(freq.values()), 1)
        score = 0.0
        for term in query_terms:
            term_freq = freq.get(term, 0)
            if term_freq <= 0:
                continue
            doc_freq = state.doc_freq.get(term, 0)
            idf = math.log(1.0 + ((total_docs - doc_freq + 0.5) / (doc_freq + 0.5)))
            numerator = term_freq * (k1 + 1.0)
            denominator = term_freq + k1 * (1.0 - b + b * (doc_len / avg_len))
            score += idf * (numerator / denominator)

        if score <= 0:
            continue

        title_tokens = set(_tokenize(chunk.title))
        tag_tokens = {token for tag in chunk.tags for token in _tokenize(tag)}
        if query_terms & title_tokens:
            score += 0.6
        if query_terms & tag_tokens:
            score += 0.9

        results.append(RagMatch(chunk=chunk, score=score))

    results.sort(key=lambda item: item.score, reverse=True)
    return results[:top_k]


def _expand_query_terms(query: str) -> set[str]:
    normalized_query = query.casefold()
    terms = set(_tokenize(query))
    for triggers, expansions in _QUERY_EXPANSIONS:
        if any(trigger.casefold() in normalized_query for trigger in triggers):
            for expansion in expansions:
                terms.update(_tokenize(expansion))
    return terms


def _tokenize(text: str) -> list[str]:
    return [token.casefold() for token in _TOKEN_RE.findall(text)]
