"""Locust 부하 테스트 — 통계 엔드포인트 캐시 효과 측정.

실행 (호스트에서, requirements-locust.txt 설치 후):
  locust -f tests/locustfile.py --host http://localhost:8000

웹 UI: http://localhost:8089
- Number of users: 10 (동시 가상 사용자)
- Spawn rate: 2 (초당 2명씩 추가)
- 1~2분 정도 측정

측정 시나리오:
- 각 가상 사용자가 회원가입 → 통계 화면 반복 조회
- 캐시 ON 상태와 OFF 상태(redis 컨테이너 stop)에서 각각 측정 → 비교

Before/After 비교 절차:
  1) docker compose stop redis     # 캐시 OFF (모든 요청이 DB hit)
  2) Locust 1분 측정 → 결과 캡처 (응답 시간 p50/p95/p99, RPS)
  3) docker compose start redis    # 캐시 ON
  4) Locust 1분 측정 → 결과 캡처
  5) 두 결과를 redis_load_test_report.md 에 정리
"""
import random
import time
import uuid

from locust import HttpUser, between, task


WEEK_STARTS = [
    "2026-04-27",
    "2026-04-20",
    "2026-04-13",
    "2026-04-06",
    "2026-03-30",
]


class StatsViewer(HttpUser):
    """통계 화면을 반복 조회하는 사용자 시뮬레이션."""

    # 가상 사용자가 다음 요청 사이에 0.5~1.5초 쉬기 (실제 사용자 행동 모사)
    wait_time = between(0.5, 1.5)

    def on_start(self):
        """가상 사용자 1명당 1회 — 회원가입 + 토큰 획득 + 시드 데이터 생성.

        통계 쿼리가 실제 GROUP BY/AVG 부하를 갖도록 운동 세션 N건을 미리 INSERT.
        이게 없으면 빈 테이블 조회라 DB 가 너무 빠르게 응답해서 캐시 효과가 안 보인다.
        """
        unique = f"{int(time.time() * 1000)}_{uuid.uuid4().hex[:6]}"
        email = f"locust_{unique}@example.com"

        with self.client.post(
            "/api/v1/auth/signup",
            json={
                "email": email,
                "password": "loadtest123",
                "nickname": f"locust_{unique[:8]}",
            },
            catch_response=True,
            name="POST /auth/signup",
        ) as resp:
            if resp.status_code != 201:
                resp.failure(f"signup failed: {resp.status_code} {resp.text[:200]}")
                self.token = None
                return
            data = resp.json().get("data") or {}
            self.token = data.get("accessToken")
            if not self.token:
                resp.failure("no accessToken in response")
                return

        # 시드 데이터 — 30건 세션을 6주에 걸쳐 분산. 통계 GROUP BY 가 의미있는 부하를 갖게 한다.
        self._seed_sessions(count=30)

    def _seed_sessions(self, count: int = 30):
        """가상 사용자별 운동 세션 시드 — 일자별로 분산 배치."""
        headers = {"Authorization": f"Bearer {self.token}"}
        for i in range(count):
            sid = f"sess_locust_{uuid.uuid4().hex[:12]}"
            # 6주에 걸쳐 분산 (1일 간격, 28일 범위 내 wrapping)
            day_offset = i % 28
            payload = {
                "session_id": sid,
                "exercise_type": "PUSH_UP",
                "status": "completed",
                "end_reason": "auto_completed",
                "started_at": f"2026-04-{1 + day_offset:02d}T06:00:00+09:00",
                "ended_at":   f"2026-04-{1 + day_offset:02d}T06:05:00+09:00",
                "duration_sec": 300,
                "set_count": 3,
                "target_reps_per_set": [12, 12, 10],
                "actual_reps_per_set": [12, 12, 9],
                "rest_sec": 60,
                "total_reps": 33,
                "valid_reps": 31,
                "avg_target_muscle": 60.0 + (i % 10),
                "avg_assist_muscle": 21.0,
                "avg_compensator": 17.0,
                "compensation_count": 4,
                "fatigue_onset_set": 3,
                "fatigue_onset_rep": 7,
                "comment": "locust seed",
                "calibration_summary": {"ch1_mvc": 80.0, "ch2_mvc": 75.0, "ch3_mvc": 70.0},
                "muscle_map": {
                    "chest": 65.0 + (i % 5),
                    "left_shoulder": 40.0,
                    "right_shoulder": 38.0,
                    "left_triceps": 52.0,
                    "right_triceps": 50.0,
                },
                "balance_summary": {
                    "enabled": True,
                    "reason": "ok",
                    "left_value": 40.0,
                    "right_value": 38.0,
                    "diff_value": 2.0,
                    "balance_label": "BALANCED",
                },
                "set_results": [
                    {"set_index": 1, "target_reps": 12, "actual_reps": 12, "compensation_count": 1,
                     "avg_speed": "normal",
                     "started_at": f"2026-04-{1 + day_offset:02d}T06:00:00+09:00",
                     "ended_at":   f"2026-04-{1 + day_offset:02d}T06:01:00+09:00"},
                    {"set_index": 2, "target_reps": 12, "actual_reps": 12, "compensation_count": 1,
                     "avg_speed": "normal",
                     "started_at": f"2026-04-{1 + day_offset:02d}T06:02:00+09:00",
                     "ended_at":   f"2026-04-{1 + day_offset:02d}T06:03:00+09:00"},
                    {"set_index": 3, "target_reps": 10, "actual_reps": 9, "compensation_count": 2,
                     "avg_speed": "fast",
                     "started_at": f"2026-04-{1 + day_offset:02d}T06:04:00+09:00",
                     "ended_at":   f"2026-04-{1 + day_offset:02d}T06:05:00+09:00"},
                ],
            }
            self.client.post(
                "/api/v1/sessions",
                json=payload,
                headers=headers,
                name="POST /sessions (seed)",
            )

    @task(3)
    def get_weekly(self):
        """가장 자주 호출되는 통계 — 비중 3."""
        if not self.token:
            return
        ws = random.choice(WEEK_STARTS)
        self.client.get(
            f"/api/v1/statistics/weekly?weekStart={ws}",
            headers={"Authorization": f"Bearer {self.token}"},
            name="GET /statistics/weekly",
        )

    @task(2)
    def get_heatmap(self):
        if not self.token:
            return
        ws = random.choice(WEEK_STARTS)
        self.client.get(
            f"/api/v1/statistics/weekly/heatmap?weekStart={ws}",
            headers={"Authorization": f"Bearer {self.token}"},
            name="GET /statistics/weekly/heatmap",
        )

    @task(2)
    def get_balance(self):
        if not self.token:
            return
        ws = random.choice(WEEK_STARTS)
        self.client.get(
            f"/api/v1/statistics/weekly/balance?weekStart={ws}",
            headers={"Authorization": f"Bearer {self.token}"},
            name="GET /statistics/weekly/balance",
        )
