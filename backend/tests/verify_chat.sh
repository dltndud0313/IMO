#!/bin/sh

set -eu

BASE="${BASE:-http://localhost:8000/api/v1}"
EMAIL="chat_$(date +%s)@example.com"
PW="testpass123"

extract() {
  grep -o "\"$1\":\"[^\"]*\"" /tmp/chat_resp.json | sed "s/\"$1\":\"//;s/\"//"
}

post_chat() {
  MESSAGE="$1"
  cat > /tmp/chat_body.json <<JSON
{"message":"$MESSAGE"}
JSON
  curl -s -X POST "$BASE/chat" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data-binary @/tmp/chat_body.json \
    > /tmp/chat_resp.json
  cat /tmp/chat_resp.json
  echo
}

echo "================================================"
echo "Phase C chat verification"
echo "================================================"

echo
echo "[1] signup -> access token"
curl -s -X POST "$BASE/auth/signup" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\",\"nickname\":\"chat\"}" \
  > /tmp/chat_resp.json
TOKEN=$(extract accessToken)
[ -n "$TOKEN" ]
printf '  token: %.30s...\n' "$TOKEN"

echo
echo "[2] supported request"
post_chat "어깨 운동 추천해줘"
grep -q '"success":true' /tmp/chat_resp.json

echo
echo "[3] unsupported lower-body guardrail"
post_chat "하체 운동 추천해줘"
grep -q '"model":"guardrail"' /tmp/chat_resp.json

echo
echo "[4] follow-up supported request"
post_chat "그럼 지금 앱에서 할 수 있는 운동 루틴 추천해줘"
grep -q '"success":true' /tmp/chat_resp.json

echo
echo "[5] history lookup"
curl -s "$BASE/chat/history" -H "Authorization: Bearer $TOKEN" > /tmp/chat_resp.json
cat /tmp/chat_resp.json
echo

echo
echo "[6] clear history"
curl -s -X DELETE "$BASE/chat" -H "Authorization: Bearer $TOKEN" > /tmp/chat_resp.json
cat /tmp/chat_resp.json
echo

echo
echo "[7] empty history after clear"
curl -s "$BASE/chat/history" -H "Authorization: Bearer $TOKEN" > /tmp/chat_resp.json
cat /tmp/chat_resp.json
echo
grep -q '"messages":\[\]' /tmp/chat_resp.json

echo
echo "[8] redis chat keys"
docker compose exec -T redis redis-cli KEYS 'chat:history:*'

echo
echo "[9] rate limit check"
for i in 1 2 3 4 5 6 7 8 9 10 11; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/chat" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"message":"테스트"}')
  echo "  Try $i: HTTP $CODE"
done

echo
echo "verification complete"
