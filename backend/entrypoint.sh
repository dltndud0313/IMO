#!/bin/sh
set -e

# DB 스키마 마이그레이션 (versions/ 가 비어있으면 무동작)
echo "[entrypoint] running alembic upgrade head"
alembic upgrade head

echo "[entrypoint] starting uvicorn"
exec uvicorn main:app --host 0.0.0.0 --port 8000
