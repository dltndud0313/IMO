"""Alembic 환경 — async 엔진은 마이그레이션에는 부적합하므로
psycopg2 동기 드라이버로 DATABASE_URL 을 변환해서 사용한다.
"""
import os
from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

# Base / 모델 import (autogenerate 가 인식하려면 반드시 필요)
from core.database import Base
from models import session as _session_models  # noqa: F401
from models import user as _user_models  # noqa: F401


config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# 환경변수 우선 — docker 컨테이너에서 DATABASE_URL 로 덮어씀
db_url = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://imo_user:imo_pass@localhost:5432/imo_db",
)
# alembic 은 동기 드라이버 (psycopg2) 사용
db_url = db_url.replace("+asyncpg", "+psycopg2")
config.set_main_option("sqlalchemy.url", db_url)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    context.configure(
        url=config.get_main_option("sqlalchemy.url"),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
