from sqlalchemy import Column, BigInteger, String, Integer, DateTime, Boolean, ForeignKey, DECIMAL, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func
from core.database import Base

class WorkoutSession(Base):
    __tablename__ = "workout_sessions"

    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id"), index=True, nullable=False)
    session_id = Column(String(100), unique=True, nullable=False)
    exercise_type = Column(String(50), index=True, nullable=False)
    status = Column(String(50), nullable=False)
    end_reason = Column(String(50), nullable=False)
    
    started_at = Column(DateTime(timezone=True), index=True, nullable=False)
    ended_at = Column(DateTime(timezone=True), nullable=False)
    duration_sec = Column(Integer, nullable=False)
    
    set_count = Column(Integer, nullable=False)
    target_reps_per_set = Column(JSONB) # PostgreSQL JSONB
    actual_reps_per_set = Column(JSONB)
    rest_sec = Column(Integer, nullable=False)
    
    total_reps = Column(Integer, nullable=False)
    valid_reps = Column(Integer, nullable=False)
    
    avg_target_muscle = Column(DECIMAL(6,2))
    avg_assist_muscle = Column(DECIMAL(6,2))
    avg_compensator = Column(DECIMAL(6,2))
    compensation_count = Column(Integer, nullable=False, default=0)
    
    fatigue_onset_set = Column(Integer, nullable=True)
    fatigue_onset_rep = Column(Integer, nullable=True)
    
    comment = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class WorkoutSetResult(Base):
    __tablename__ = "workout_set_results"

    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    session_id = Column(String(100), ForeignKey("workout_sessions.session_id", ondelete="CASCADE"), nullable=False)
    set_index = Column(Integer, nullable=False)
    
    target_reps = Column(Integer, nullable=False)
    actual_reps = Column(Integer, nullable=False)
    compensation_count = Column(Integer, nullable=False, default=0)
    avg_speed = Column(String(30), nullable=False)
    
    started_at = Column(DateTime(timezone=True), nullable=False)
    ended_at = Column(DateTime(timezone=True), nullable=False)

class WorkoutCalibration(Base):
    __tablename__ = "workout_calibrations"

    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    session_id = Column(String(100), ForeignKey("workout_sessions.session_id", ondelete="CASCADE"), nullable=False)
    
    ch1_mvc = Column(DECIMAL(8,2))
    ch2_mvc = Column(DECIMAL(8,2))
    ch3_mvc = Column(DECIMAL(8,2))
    measured_at = Column(DateTime(timezone=True), server_default=func.now())

class WorkoutMuscleMap(Base):
    __tablename__ = "workout_muscle_maps"

    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    session_id = Column(String(100), ForeignKey("workout_sessions.session_id", ondelete="CASCADE"), nullable=False)
    body_part = Column(String(50), nullable=False)
    activation_value = Column(DECIMAL(6,2), nullable=False)

class WorkoutBalanceSummary(Base):
    __tablename__ = "workout_balance_summaries"

    id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    session_id = Column(String(100), ForeignKey("workout_sessions.session_id", ondelete="CASCADE"), unique=True, nullable=False)
    enabled = Column(Boolean, nullable=False, default=False)
    reason = Column(String(100))
    left_value = Column(DECIMAL(6,2))
    right_value = Column(DECIMAL(6,2))
    diff_value = Column(DECIMAL(6,2))
    balance_label = Column(String(50))
