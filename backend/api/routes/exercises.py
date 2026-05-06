from fastapi import APIRouter, Depends

from core.deps import get_current_user
from core.exercise_catalog import EXERCISE_CATALOG
from core.responses import success_response
from models.user import User

router = APIRouter()


@router.get("")
@router.get("/", include_in_schema=False)
async def get_exercises(current_user: User = Depends(get_current_user)):
    """API-16: 지원 운동 종목 + 센서 부착 안내."""
    return success_response(
        {"exercises": [e.model_dump() for e in EXERCISE_CATALOG]}
    )
