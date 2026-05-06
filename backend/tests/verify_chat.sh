#!/bin/sh
# Phase C 챗봇 검증 — POST/DELETE/GET /chat + 가드레일 + rate limit
# 실행: bash tests/verify_chat.sh
# 전제: docker compose up + GEMINI_API_KEY 설정

set -e

BASE="http://localhost:8000/api/v1"
EMAIL="chat_$(date +%s)@example.com"
PW="testpass123"

extract() {
  grep -o "\"$1\":\"[^\"]*\"" /tmp/chat_resp.json | sed "s/\"$1\":\"//;s/\"//"
}

echo "================================================"
echo "Phase C — 운동 챗봇"
echo "================================================"

echo
echo "[1] 데모 회원가입 → access token"
curl -s -X POST "$BASE/auth/signup" -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\",\"nickname\":\"chat\"}" \
  > /tmp/chat_resp.json
TOKEN=$(extract accessToken)
echo "  token: ${TOKEN:0:30}..."

echo
# 한글 본문은 Windows Git Bash 의 인자 인코딩 문제로 깨질 수 있어 파일로 우회.
# heredoc 'JSON' 은 변수 확장 없이 그대로 파일에 기록 → 인코딩/quote 안전.
echo "[2] 운동 관련 질문 → 정상 답변 기대"
cat > /tmp/chat_body.json <<'JSON'
{"message":"오늘 어깨 운동 추천해줘"}
JSON
curl -s -X POST "$BASE/chat" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  --data-binary @/tmp/chat_body.json
echo

echo
echo "[3] 멀티턴 — 이전 컨텍스트 활용 기대"
cat > /tmp/chat_body.json <<'JSON'
{"message":"방금 추천한 운동 주의사항은?"}
JSON
curl -s -X POST "$BASE/chat" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  --data-binary @/tmp/chat_body.json
echo

echo
echo "[4] 가드레일 — 운동 외 질문 거부 기대"
cat > /tmp/chat_body.json <<'JSON'
{"message":"오늘 주식 추천해줘"}
JSON
curl -s -X POST "$BASE/chat" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  --data-binary @/tmp/chat_body.json
echo

echo
echo "[5] 히스토리 조회 → 6개 메시지 기대 (3턴)"
curl -s "$BASE/chat/history" -H "Authorization: Bearer $TOKEN"
echo

echo
echo "[6] 히스토리 초기화"
curl -s -X DELETE "$BASE/chat" -H "Authorization: Bearer $TOKEN"
echo

echo
echo "[7] 초기화 후 히스토리 조회 → 빈 배열 기대"
curl -s "$BASE/chat/history" -H "Authorization: Bearer $TOKEN"
echo

echo
echo "[8] Redis chat 키 확인 (초기화 후라 0개 기대)"
docker compose exec -T redis redis-cli KEYS 'chat:history:*'

echo
echo "[9] Rate limit — 11회 빠른 호출 → 11번째 429 기대"
cat > /tmp/chat_body.json <<'JSON'
{"message":"테스트"}
JSON
for i in 1 2 3 4 5 6 7 8 9 10 11; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/chat" \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    --data-binary @/tmp/chat_body.json)
  echo "  Try $i: HTTP $CODE"
done

echo
echo "검증 끝."
