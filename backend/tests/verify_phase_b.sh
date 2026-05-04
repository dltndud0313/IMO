#!/bin/sh
# Phase B 통합 검증 — Refresh Blacklist + Rate Limit
# 실행: bash tests/verify_phase_b.sh
# 전제: docker compose up 으로 api/db/redis 가 모두 Up + CACHE_ENABLED=true

set -e

BASE="http://localhost:8000/api/v1"
EMAIL="phaseb_$(date +%s)@example.com"
PW="testpass123"

extract() {
  grep -o "\"$1\":\"[^\"]*\"" /tmp/phaseb_resp.json | sed "s/\"$1\":\"//;s/\"//"
}

echo "================================================"
echo "B-1. Refresh Token Blacklist"
echo "================================================"

echo "[1] 회원가입 → REFRESH 1"
curl -s -X POST "$BASE/auth/signup" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\",\"nickname\":\"phaseb\"}" \
  > /tmp/phaseb_resp.json
cat /tmp/phaseb_resp.json | head -c 200; echo
REFRESH_1=$(extract refreshToken)

echo
echo "[2] /refresh (REFRESH 1) → REFRESH 2 발급, REFRESH 1 blacklist"
curl -s -X POST "$BASE/auth/refresh" -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$REFRESH_1\"}" > /tmp/phaseb_resp.json
cat /tmp/phaseb_resp.json | head -c 200; echo
REFRESH_2=$(extract refreshToken)

echo
echo "[3] REFRESH 1 재사용 시도 → 401 'revoked' 기대"
curl -s -X POST "$BASE/auth/refresh" -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$REFRESH_1\"}"
echo

echo
echo "[4] /logout (REFRESH 2) → 200 loggedOut"
curl -s -X POST "$BASE/auth/logout" -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$REFRESH_2\"}"
echo

echo
echo "[5] REFRESH 2 재사용 시도 → 401 (이미 logout)"
curl -s -X POST "$BASE/auth/refresh" -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$REFRESH_2\"}"
echo

echo
echo "[6] Redis blacklist 키 확인"
docker compose exec -T redis redis-cli KEYS 'auth:blacklist:refresh:*'

echo
echo "================================================"
echo "B-2. Rate Limiting"
echo "================================================"

echo "[7] /auth/login 11회 빠르게 호출 → 11번째에 429 기대"
for i in 1 2 3 4 5 6 7 8 9 10 11; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$EMAIL\",\"password\":\"wrong\"}")
  echo "  Try $i: HTTP $CODE"
done

echo
echo "[8] Redis ratelimit 키 확인"
docker compose exec -T redis redis-cli KEYS 'ratelimit:*'

echo
echo "검증 끝. 정상이라면:"
echo "  [3]: 401 'Refresh token has been revoked'"
echo "  [4]: 200 loggedOut:true"
echo "  [5]: 401 'revoked'"
echo "  [6]: auth:blacklist:refresh:* 키 2개 (REFRESH 1, 2)"
echo "  [7]: Try 1~10 은 401, Try 11 은 429"
echo "  [8]: ratelimit:login:* 키 1개 (TTL 60초)"
