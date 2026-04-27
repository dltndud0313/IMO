from pydantic import BaseModel
from typing import List, Literal


class EmgChannelPlacement(BaseModel):
    channelId: int
    muscleName: str
    side: Literal["CENTER", "LEFT", "RIGHT"]
    description: str


class ImuPlacement(BaseModel):
    bodyPart: str
    description: str


class SensorPlacement(BaseModel):
    emg: List[EmgChannelPlacement]
    imu: ImuPlacement


class ExerciseInfo(BaseModel):
    exerciseType: Literal["PUSH_UP", "LATERAL_RAISE", "BICEP_CURL"]
    name: str
    description: str
    targetMuscles: List[str]
    instructions: List[str]
    cautions: List[str]
    sensorPlacement: SensorPlacement
    thumbnailUrl: str
