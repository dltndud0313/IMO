#!/bin/sh
# Redis 캐시 동작 검증 스크립트.
# 실행: bash tests/verify_cache.sh
# 전제: docker compose up 으로 api/db/redis 가 모두 Up 상태.

set -e

BASE="http://localhost:8000/api/v1"
EMAIL="cache_verify_$(date +%s)@example.com"
PW="testpass123"
WEEK_START="2026-04-27"   # _dev_sample_session.json 의 started_at(2026-04-28) 이 속한 주

# 응답 시간을 ms 로 출력하는 curl 래퍼. 응답 본문 첫 80바이트도 함께 보여줌.
timed_get() {
  ms=$(curl -s -o /tmp/cache_resp.json -w "%{time_total}" -H "Authorization: Bearer $TOKEN" "$1" | awk '{ printf "%.0f", $1 * 1000 }')
  echo "${ms} ms"
  echo "  응답: $(head -c 80 /tmp/cache_resp.json)..."
}

echo "=========================================="
echo "1) 회원가입"
echo "=========================================="
curl -s -X POST "$BASE/auth/signup" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\",\"nickname\":\"cache_test\"}" \
  | tee /tmp/signup.json
echo
TOKEN=$(grep -o '"accessToken":"[^"]*"' /tmp/signup.json | sed 's/"accessToken":"//;s/"//')
if [ -z "$TOKEN" ]; then
  echo "[FATAL] 토큰 발급 실패 — signup 응답을 확인하세요. 검증 중단."
  exit 1
fi
echo "TOKEN: ${TOKEN:0:30}..."

echo
echo "=========================================="
echo "2) 첫 통계 조회 (DB hit, 캐시 miss 예상)"
echo "=========================================="
echo -n "  응답 시간: "
timed_get "$BASE/statistics/weekly?weekStart=$WEEK_START"

echo
echo "=========================================="
echo "3) 같은 통계 즉시 재조회 (캐시 hit 예상)"
echo "=========================================="
echo -n "  응답 시간: "
timed_get "$BASE/statistics/weekly?weekStart=$WEEK_START"

echo
echo "=========================================="
echo "4) 한 번 더 캐시 hit 확인"
echo "=========================================="
echo -n "  응답 시간: "
timed_get "$BASE/statistics/weekly?weekStart=$WEEK_START"

echo
echo "=========================================="
echo "5) POST /sessions — 캐시 무효화 트리거"
echo "=========================================="
# session_id 는 전역 unique 이므로 매 실행마다 새로 생성한다.
NEW_SID="sess_verify_$(date +%s)"
sed "s/\"sess_test_001\"/\"$NEW_SID\"/" _dev_sample_session.json > /tmp/post_session_payload.json
curl -s -X POST "$BASE/sessions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @/tmp/post_session_payload.json > /tmp/post_session.json
cat /tmp/post_session.json
echo

echo
echo "=========================================="
echo "6) 무효화 후 통계 재조회 (다시 캐시 miss 예상)"
echo "=========================================="
echo -n "  응답 시간: "
timed_get "$BASE/statistics/weekly?weekStart=$WEEK_START"

echo
echo "=========================================="
echo "7) 또 즉시 재조회 (다시 캐시 hit 예상)"
echo "=========================================="
echo -n "  응답 시간: "
timed_get "$BASE/statistics/weekly?weekStart=$WEEK_START"

echo
echo "=========================================="
echo "8) Redis 안에 저장된 키 확인"
echo "=========================================="
docker compose exec -T redis redis-cli KEYS 'stats:*'

echo
echo "검증 끝. 정상이라면:"
echo "  - 2,6번(첫 호출/무효화 후): 50~200ms 대"
echo "  - 3,4,7번(캐시 hit): 1~20ms 대 (수십 배 빠름)"
echo "  - 8번: stats:weekly:... 키가 보여야 함"
