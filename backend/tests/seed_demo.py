"""시연용 더미 데이터 시드 스크립트.

데모 계정 (demo@imo.com / demo1234) 을 생성(또는 로그인) 하고 최근 14일치 운동
세션을 다양한 종목·날짜로 채워 넣는다. stdlib 만 사용해 추가 의존성 없음.

사용:
    python tests/seed_demo.py                                       # 로컬 (기본 12개)
    python tests/seed_demo.py --count 20 --clean                    # 20개로, 기존 데이터 삭제 후
    BACKEND_URL=https://k14c203.p.ssafy.io python tests/seed_demo.py  # EC2
"""
import argparse
import json
import os
import random
import sys
import uuid
from datetime import datetime, timedelta, timezone
from urllib.error import HTTPError
from urllib.request import Request, urlopen

BACKEND_URL = os.getenv("BACKEND_URL", "http://localhost:8000")
DEMO_EMAIL = "demo@imo.com"
DEMO_PASSWORD = "demo1234"
DEMO_NICKNAME = "데모"
CONFIRM_TEXT = "DELETE ALL DATA"

KST = timezone(timedelta(hours=9))


def http(method, path, body=None, token=None):
    """HTTP 요청 — (status_code, json_response) 반환. 4xx/5xx 도 예외 없이 반환."""
    url = f"{BACKEND_URL}{path}"
    data = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = Request(url, data=data, headers=headers, method=method)
    try:
        with urlopen(req, timeout=10) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            return e.code, {"raw": str(e)}


def signup_or_login():
    code, resp = http("POST", "/api/v1/auth/signup", body={
        "email": DEMO_EMAIL, "password": DEMO_PASSWORD, "nickname": DEMO_NICKNAME,
    })
    if code == 201 and resp.get("success"):
        print(f"[+] 새 데모 계정 생성: {DEMO_EMAIL}")
        return resp["data"]["accessToken"]
    print(f"[i] 데모 계정 이미 존재 — 로그인")
    code, resp = http("POST", "/api/v1/auth/login", body={
        "email": DEMO_EMAIL, "password": DEMO_PASSWORD,
    })
    if code != 200 or not resp.get("success"):
        print(f"[!] 로그인 실패 ({code}): {resp}")
        sys.exit(1)
    return resp["data"]["accessToken"]


def clear_data(token):
    code, resp = http(
        "DELETE", "/api/v1/users/me/data",
        body={"confirmText": CONFIRM_TEXT}, token=token,
    )
    if code == 200 and resp.get("success"):
        print(f"[+] 기존 운동 데이터 삭제 완료")
    else:
        print(f"[!] 데이터 삭제 실패 ({code}): {resp}")


def make_session(exercise, days_ago, set_count):
    base = datetime.now(KST) - timedelta(days=days_ago)
    started = base.replace(
        hour=random.randint(7, 21),
        minute=random.choice([0, 15, 30, 45]),
        second=0, microsecond=0,
    )
    duration = set_count * 60 + (set_count - 1) * 60
    ended = started + timedelta(seconds=duration)

    target = random.choice([10, 12, 15])
    actuals = []
    for s in range(set_count):
        # 마지막 세트만 살짝 부족하게 (피로 효과 표현)
        actuals.append(target if s < set_count - 1 else max(target - random.randint(0, 3), 6))

    set_results = []
    cur = started
    for s in range(set_count):
        set_results.append({
            "set_index": s + 1,
            "target_reps": target,
            "actual_reps": actuals[s],
            "compensation_count": random.randint(0, 3),
            "avg_speed": random.choice(["normal", "fast", "slow"]),
            "started_at": cur.isoformat(),
            "ended_at": (cur + timedelta(seconds=60)).isoformat(),
        })
        cur += timedelta(seconds=120)

    return {
        "session_id": f"seed_{uuid.uuid4().hex[:12]}",
        "exercise_type": exercise,
        "status": "completed",
        "end_reason": "auto_completed",
        "started_at": started.isoformat(),
        "ended_at": ended.isoformat(),
        "duration_sec": duration,
        "set_count": set_count,
        "target_reps_per_set": [target] * set_count,
        "actual_reps_per_set": actuals,
        "rest_sec": 60,
        "total_reps": sum(actuals),
        "valid_reps": sum(actuals) - random.randint(0, 4),
        # API 계약 (2026-05-18 통일): 활성도 값은 전부 0~100 percent.
        "avg_target_muscle": round(random.uniform(55, 75), 1),
        "avg_assist_muscle": round(random.uniform(15, 30), 1),
        "avg_compensator": round(random.uniform(10, 25), 1),
        "compensation_count": sum(r["compensation_count"] for r in set_results),
        "fatigue_onset_set": set_count if random.random() > 0.3 else None,
        "fatigue_onset_rep": random.randint(5, 10) if random.random() > 0.3 else None,
        "comment": None,
        "calibration_summary": {
            "ch1_mvc": round(random.uniform(70, 90), 1),
            "ch2_mvc": round(random.uniform(70, 90), 1),
            "ch3_mvc": round(random.uniform(70, 90), 1),
        },
        # 키 명명은 app schema / Pi 송신 키와 정합 (docs/pi_muscle_map_alignment.md).
        # pushup 키 기준 시드 — 다른 운동 시드 추가 시 운동별 분기 필요.
        "muscle_map": {
            "left_chest": round(random.uniform(50, 80), 1),
            "right_chest": round(random.uniform(50, 80), 1),
            "left_triceps": round(random.uniform(40, 60), 1),
            "right_triceps": round(random.uniform(40, 60), 1),
        },
        "balance_summary": {
            "enabled": True,
            "reason": "left_right_pairing_ok",
            "left_value": round(random.uniform(35, 50), 1),
            "right_value": round(random.uniform(35, 50), 1),
            "diff_value": round(random.uniform(0, 10), 1),
            "balance_label": random.choice(["BALANCED", "MILD_IMBALANCE", "SIGNIFICANT_IMBALANCE"]),
        },
        "set_results": set_results,
    }


def post_session(token, payload):
    code, resp = http("POST", "/api/v1/sessions", body=payload, token=token)
    if code in (200, 201) and resp.get("success"):
        return True
    print(f"[!] 세션 저장 실패 {payload['session_id']} ({code}): {str(resp)[:200]}")
    return False


def main():
    parser = argparse.ArgumentParser(description="시연용 더미 데이터 시드 스크립트")
    parser.add_argument("--clean", action="store_true",
                        help="기존 운동 데이터 삭제 후 시드")
    parser.add_argument("--count", type=int, default=12,
                        help="생성할 세션 수 (기본 12)")
    args = parser.parse_args()

    print(f"=== 시연용 더미 데이터 시드 ({BACKEND_URL}) ===")
    token = signup_or_login()

    if args.clean:
        clear_data(token)

    exercises = ["PUSH_UP", "LATERAL_RAISE", "BICEP_CURL"]
    success = 0
    for _ in range(args.count):
        days_ago = random.randint(0, 13)
        ex = random.choice(exercises)
        sets = random.choice([3, 4, 5])
        payload = make_session(ex, days_ago, sets)
        if post_session(token, payload):
            success += 1
            print(f"  [+] {payload['session_id']} | {ex:13s} | {days_ago:>2}일전 | {sets}세트")

    print(f"\n=== 완료: {success}/{args.count} 세션 생성 ===")
    print(f"데모 계정: {DEMO_EMAIL} / {DEMO_PASSWORD}")


if __name__ == "__main__":
    main()
