from __future__ import annotations

import re
from dataclasses import dataclass

from schemas.exercise import (
    EmgChannelPlacement,
    ExerciseInfo,
    ImuPlacement,
    SensorPlacement,
)

EXERCISE_CATALOG: list[ExerciseInfo] = [
    ExerciseInfo(
        exerciseType="PUSH_UP",
        name="푸시업",
        description="가슴, 삼두근, 전면 삼각근을 주로 자극하는 상체 복합 운동입니다.",
        targetMuscles=["대흉근", "삼두근", "전면 삼각근"],
        instructions=[
            "양손을 어깨 너비로 벌리고 바닥에 짚습니다.",
            "몸을 일직선으로 유지하며 팔꿈치를 굽혀 내려갑니다.",
            "가슴이 바닥에 가까워지면 팔을 펴서 올라옵니다.",
        ],
        cautions=[
            "허리가 처지지 않도록 코어에 힘을 유지합니다.",
            "팔꿈치가 과도하게 벌어지지 않도록 주의합니다.",
        ],
        sensorPlacement=SensorPlacement(
            emg=[
                EmgChannelPlacement(
                    channelId=1,
                    muscleName="대흉근",
                    side="CENTER",
                    description="가슴 중앙부",
                ),
                EmgChannelPlacement(
                    channelId=2,
                    muscleName="삼두근",
                    side="LEFT",
                    description="왼쪽 팔 뒤쪽",
                ),
                EmgChannelPlacement(
                    channelId=3,
                    muscleName="삼두근",
                    side="RIGHT",
                    description="오른쪽 팔 뒤쪽",
                ),
            ],
            imu=ImuPlacement(
                bodyPart="상완",
                description="오른쪽 상완에 IMU 센서를 부착하세요.",
            ),
        ),
        thumbnailUrl="/assets/exercises/push_up.png",
    ),
    ExerciseInfo(
        exerciseType="LATERAL_RAISE",
        name="싸레레 (사이드 레터럴 레이즈)",
        description="측면 삼각근을 주로 자극하는 어깨 고립 운동입니다.",
        targetMuscles=["측면 삼각근", "전면 삼각근", "승모근"],
        instructions=[
            "양손에 덤벨을 들고 몸 옆에 자연스럽게 내립니다.",
            "팔꿈치를 살짝 구부린 상태로 양팔을 옆으로 들어올립니다.",
            "어깨 높이까지 올린 후 천천히 내립니다.",
        ],
        cautions=[
            "반동을 이용하지 않도록 주의합니다.",
            "승모근에 과도한 힘이 들어가지 않도록 합니다.",
        ],
        sensorPlacement=SensorPlacement(
            emg=[
                EmgChannelPlacement(
                    channelId=1,
                    muscleName="측면삼각근",
                    side="LEFT",
                    description="왼쪽 어깨 측면",
                ),
                EmgChannelPlacement(
                    channelId=2,
                    muscleName="측면삼각근",
                    side="RIGHT",
                    description="오른쪽 어깨 측면",
                ),
                EmgChannelPlacement(
                    channelId=3,
                    muscleName="승모근",
                    side="CENTER",
                    description="목 뒤 상부 승모근",
                ),
            ],
            imu=ImuPlacement(
                bodyPart="전완",
                description="오른쪽 전완에 IMU 센서를 부착하세요.",
            ),
        ),
        thumbnailUrl="/assets/exercises/lateral_raise.png",
    ),
    ExerciseInfo(
        exerciseType="BICEP_CURL",
        name="이두컬",
        description="이두근을 주로 자극하는 팔 고립 운동입니다.",
        targetMuscles=["이두근", "전완근"],
        instructions=[
            "양손에 덤벨을 들고 팔을 자연스럽게 내립니다.",
            "팔꿈치를 고정한 채 전완을 올려 덤벨을 어깨 방향으로 컬합니다.",
            "최대 수축 후 천천히 내립니다.",
        ],
        cautions=[
            "팔꿈치가 앞뒤로 움직이지 않도록 고정합니다.",
            "반동을 사용하지 않도록 주의합니다.",
        ],
        sensorPlacement=SensorPlacement(
            emg=[
                EmgChannelPlacement(
                    channelId=1,
                    muscleName="이두근",
                    side="LEFT",
                    description="왼쪽 상완 전면",
                ),
                EmgChannelPlacement(
                    channelId=2,
                    muscleName="이두근",
                    side="RIGHT",
                    description="오른쪽 상완 전면",
                ),
                EmgChannelPlacement(
                    channelId=3,
                    muscleName="전완근",
                    side="RIGHT",
                    description="오른쪽 전완 상부",
                ),
            ],
            imu=ImuPlacement(
                bodyPart="전완",
                description="오른쪽 전완에 IMU 센서를 부착하세요.",
            ),
        ),
        thumbnailUrl="/assets/exercises/bicep_curl.png",
    ),
]

SUPPORTED_EXERCISE_DISPLAY_NAMES = (
    "푸시업",
    "사이드 레터럴 레이즈",
    "이두 컬",
)
SUPPORTED_EXERCISE_SUMMARY = ", ".join(SUPPORTED_EXERCISE_DISPLAY_NAMES)

SUPPORT_SCOPE_SYSTEM_CONTEXT = (
    f"현재 IMO 앱에서 기록·분석 가능한 운동은 {SUPPORTED_EXERCISE_SUMMARY} 3가지뿐입니다. "
    "이 범위를 벗어난 운동이나 부위 추천을 요청받으면 현재 앱에서 지원하지 않는다고 명확히 안내하세요. "
    "지원하지 않는 운동을 마치 앱에서 기록하거나 분석할 수 있는 것처럼 설명하지 마세요. "
    "가능하면 지원 운동 안에서 대안을 제시하세요."
)


@dataclass(frozen=True)
class UnsupportedRequestRule:
    topic: str
    keywords: tuple[str, ...]
    alternative: str


_REQUEST_INTENT_MARKERS = (
    "추천",
    "루틴",
    "운동",
    "종목",
    "동작",
    "알려줘",
    "해줘",
    "뭐",
    "무엇",
    "어떤",
    "가능",
)

_UNSUPPORTED_REQUEST_RULES = (
    UnsupportedRequestRule(
        topic="하체",
        keywords=(
            "하체",
            "스쿼트",
            "런지",
            "레그프레스",
            "레그컬",
            "레그익스텐션",
            "힙쓰러스트",
            "데드리프트",
            "카프레이즈",
            "불가리안스플릿스쿼트",
        ),
        alternative="푸시업, 사이드 레터럴 레이즈, 이두 컬을 조합한 상체 루틴",
    ),
    UnsupportedRequestRule(
        topic="등",
        keywords=(
            "등운동",
            "광배",
            "랫풀다운",
            "풀업",
            "친업",
            "바벨로우",
            "덤벨로우",
            "시티드로우",
            "티바로우",
        ),
        alternative="푸시업과 이두 컬 중심의 상체 루틴",
    ),
    UnsupportedRequestRule(
        topic="복근/코어",
        keywords=(
            "복근",
            "코어운동",
            "플랭크",
            "크런치",
            "싯업",
            "레그레이즈",
            "행잉레그레이즈",
            "앱휠",
        ),
        alternative="푸시업 중심의 상체 루틴",
    ),
    UnsupportedRequestRule(
        topic="후면 어깨",
        keywords=("후면어깨", "리어델트", "리어델트플라이", "페이스풀"),
        alternative="사이드 레터럴 레이즈 중심의 어깨 루틴",
    ),
)


def _normalize_query(text: str) -> str:
    return re.sub(r"\s+", "", text).casefold()


def _has_scope_request_intent(normalized_message: str) -> bool:
    return any(marker in normalized_message for marker in _REQUEST_INTENT_MARKERS)


def find_scope_guardrail_reply(message: str) -> str | None:
    normalized_message = _normalize_query(message)
    if not normalized_message or not _has_scope_request_intent(normalized_message):
        return None

    for rule in _UNSUPPORTED_REQUEST_RULES:
        if any(keyword in normalized_message for keyword in rule.keywords):
            return (
                f"현재 IMO 앱에서 기록·분석 가능한 운동은 {SUPPORTED_EXERCISE_SUMMARY}입니다. "
                f"요청하신 {rule.topic} 관련 운동은 아직 앱에서 지원하지 않습니다. "
                f"원하시면 현재 지원 운동 기준으로 {rule.alternative} 추천을 도와드릴게요."
            )

    return None
