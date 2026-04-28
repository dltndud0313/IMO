from fastapi import APIRouter, Depends

from core.deps import get_current_user
from core.responses import success_response
from models.user import User
from schemas.exercise import (
    EmgChannelPlacement,
    ExerciseInfo,
    ImuPlacement,
    SensorPlacement,
)

router = APIRouter()


# 정적 카탈로그. 운동 종목/센서 부착 안내는 명세서 API-16 기준으로 고정.
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
                    channelId=1, muscleName="대흉근", side="CENTER",
                    description="가슴 중앙부",
                ),
                EmgChannelPlacement(
                    channelId=2, muscleName="삼두근", side="LEFT",
                    description="왼쪽 팔 뒤쪽",
                ),
                EmgChannelPlacement(
                    channelId=3, muscleName="삼두근", side="RIGHT",
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
                    channelId=1, muscleName="측면삼각근", side="LEFT",
                    description="왼쪽 어깨 측면",
                ),
                EmgChannelPlacement(
                    channelId=2, muscleName="측면삼각근", side="RIGHT",
                    description="오른쪽 어깨 측면",
                ),
                EmgChannelPlacement(
                    channelId=3, muscleName="승모근", side="CENTER",
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
                    channelId=1, muscleName="이두근", side="LEFT",
                    description="왼쪽 상완 전면",
                ),
                EmgChannelPlacement(
                    channelId=2, muscleName="이두근", side="RIGHT",
                    description="오른쪽 상완 전면",
                ),
                EmgChannelPlacement(
                    channelId=3, muscleName="전완근", side="RIGHT",
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


@router.get("")
@router.get("/", include_in_schema=False)
async def get_exercises(current_user: User = Depends(get_current_user)):
    """API-16: 지원 운동 종목 + 센서 부착 안내."""
    return success_response(
        {"exercises": [e.model_dump() for e in EXERCISE_CATALOG]}
    )
