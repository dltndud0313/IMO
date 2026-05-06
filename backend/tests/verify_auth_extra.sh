#!/bin/sh
# 신규 인증 API 검증 — 이메일 중복 확인 + 비밀번호 변경
# 실행: bash tests/verify_auth_extra.sh

set -e

BASE="http://localhost:8000/api/v1"
EMAIL="pwtest_$(date +%s)@example.com"
NEW_EMAIL="newbie_$(date +%s)@example.com"

echo "================================================"
echo "이메일 중복 확인"
echo "================================================"

echo
echo "[1] 미가입 이메일 → available:true 기대"
curl -s "$BASE/auth/email/check?email=$NEW_EMAIL"
echo

echo
echo "[2] 회원가입"
RESP=$(curl -s -X POST "$BASE/auth/signup" -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"oldpass123\",\"nickname\":\"pw\"}")
echo "$RESP" | head -c 150
echo
TOKEN=$(echo "$RESP" | grep -o '"accessToken":"[^"]*"' | sed 's/"accessToken":"//;s/"//')

echo
echo "[3] 가입한 이메일 → available:false 기대"
curl -s "$BASE/auth/email/check?email=$EMAIL"
echo

echo
echo "[4] 잘못된 이메일 형식 → HTTP 422 기대"
curl -s -o /dev/null -w "  HTTP %{http_code}\n" "$BASE/auth/email/check?email=notanemail"

echo
echo "================================================"
echo "비밀번호 변경"
echo "================================================"

echo
echo "[5] 비번 변경 → changed:true 기대"
curl -s -X PUT "$BASE/users/me/password" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"currentPassword":"oldpass123","newPassword":"newpass456"}'
echo

echo
echo "[6] 옛 비번 로그인 → HTTP 401 기대"
curl -s -o /dev/null -w "  HTTP %{http_code}\n" -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"oldpass123\"}"

echo
echo "[7] 새 비번 로그인 → HTTP 200 기대"
curl -s -o /dev/null -w "  HTTP %{http_code}\n" -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"newpass456\"}"

echo
echo "[8] 현재 비번 틀림 → 401 + UNAUTHORIZED 기대"
curl -s -X PUT "$BASE/users/me/password" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"currentPassword":"wrong","newPassword":"another123"}'
echo

echo
echo "검증 끝."
