# 베이스 이미지
FROM python:3.11-slim

# 작업 디렉토리 설정
WORKDIR /app

# 의존성 복사 및 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 소스코드 복사
COPY . .

# entrypoint 실행 권한 + CRLF 제거 (Windows 에디터에서 저장된 경우 대비)
RUN sed -i 's/\r$//' /app/entrypoint.sh && chmod +x /app/entrypoint.sh

# 컨테이너 시작 시 마이그레이션 → uvicorn
CMD ["/app/entrypoint.sh"]
