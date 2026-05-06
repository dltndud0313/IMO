# IMO (Inside Muscle Out) API 명세서

> **버전**: v1.0 (MVP)  
> **최종 수정**: 2026-04-27  
> **통신 방식**: Pi WebSocket Server + App WebSocket Client (JSON)  
> **기본 원칙**: 단일 소켓 연결 유지, 메시지 `type` 필드로 라우팅

---

## 목차

1. [공통 규약](#1-공통-규약)
2. [WebSocket 프로토콜 (App ↔ Raspberry Pi)](#2-websocket-프로토콜-app--raspberry-pi)
   - [2-1. 시스템 초기화](#2-1-시스템-초기화)
   - [2-2. 운동 준비](#2-2-운동-준비)
   - [2-3. 캘리브레이션](#2-3-캘리브레이션)
   - [2-4. 운동 제어](#2-4-운동-제어)
   - [2-5. 실시간 운동 데이터 스트리밍](#2-5-실시간-운동-데이터-스트리밍)
   - [2-6. 실시간 피드백 메시지](#2-6-실시간-피드백-메시지)
   - [2-7. 글래스 표시 데이터](#2-7-글래스-표시-데이터)
   - [2-8. 에러/예외 이벤트](#2-8-에러--예외-이벤트)
   - [2-9. WebSocket 메시지 타입 요약](#2-9-websocket-메시지-타입-요약)
3. [REST API (App ↔ Backend Server)](#3-rest-api-app--backend-server)
   - [3-1. 인증/사용자 관리](#3-1-인증--사용자-관리)
   - [3-2. 프로필 관리](#3-2-프로필-관리)
   - [3-3. 운동 세션 기록](#3-3-운동-세션-기록)
   - [3-4. 주간 통계 (확장)](#3-4-주간-통계-확장-기능)
   - [3-5. 설정 관리](#3-5-설정-관리)
   - [3-6. 운동 정보](#3-6-운동-정보)
   - [3-7. REST API 엔드포인트 요약](#3-7-rest-api-엔드포인트-요약)
4. [에러 코드 정의](#4-에러-코드-정의)
5. [Enum 정의](#5-enum-정의)
6. [부록: 메시지 흐름도](#6-부록-메시지-흐름도)

---

## 1. 공통 규약

### 1-1. WebSocket 메시지 공통 구조

모든 WebSocket 메시지는 아래 공통 필드를 포함한다.

```json
{
  "type": "string",           // 메시지 타입 (라우팅 키)
  "timestamp": "string",      // ISO 8601 형식 (e.g., "2026-04-27T09:30:00.000Z")
  "requestId": "string|null"  // 요청-응답 매칭용 ID (이벤트성 메시지는 null)
}
```

### 1-2. 메시지 방향 표기

| 표기 | 의미 |
|------|------|
| `App → Pi` | 앱에서 라즈베리파이로 전송하는 메시지 |
| `Pi → App` | 라즈베리파이에서 앱으로 전송하는 메시지 |
| `Pi → App (Stream)` | 라즈베리파이에서 앱으로 지속적으로 전송하는 스트리밍 메시지 |

### 1-3. REST API 공통 응답 구조

**성공 응답:**

```json
{
  "success": true,
  "data": { ... },
  "error": null
}
```

**실패 응답:**

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "string",
    "message": "string"
  }
}
```

### 1-4. 인증

| 구분 | 방식 |
|------|------|
| REST API | `Authorization: Bearer <JWT>` 헤더 사용 |
| WebSocket | 연결 시 쿼리 파라미터로 토큰 전달 (`ws://<host>:<port>?token=<JWT>`) |

---

## 2. WebSocket 프로토콜 (App ↔ Raspberry Pi)

> **연결 URL**: `ws://<raspberry-pi-ip>:<port>/ws`  
> **프로토콜**: 단일 소켓 연결을 유지하며, `type` 필드와 `payload` 필드로만 통신

---

### 2-1. 앱 → Pi (제어 명령)

#### 1. 운동 선택 및 계획 전송
```json
{
  "type": "submit_workout_plan",
  "payload": {
    "exercise_type": "pushup",
    "set_count": 3,
    "target_reps_per_set": [12, 12, 10],
    "rest_sec": 60
  }
}
```

#### 2. 캘리브레이션 시작
```json
{
  "type": "start_calibration",
  "payload": {
    "exercise_type": "pushup"
  }
}
```

#### 3. 일반 중단 (사용자 요청)
```json
{
  "type": "stop_workout",
  "payload": {
    "reason": "user_request",
    "save_result": true
  }
}
```

#### 4. 비상 중단 (위험 한계치 등)
```json
{
  "type": "emergency_stop",
  "payload": {
    "reason": "user_emergency"
  }
}
```

#### 5. 일시정지
```json
{
  "type": "pause_workout",
  "payload": {
    "reason": "user_request"
  }
}
```

#### 6. 재개
```json
{
  "type": "resume_workout",
  "payload": {
    "reason": "user_request"
  }
}
```

---

### 2-2. Pi → 앱 (상태 응답 및 이벤트)

#### 1. 연결 상태
- 디바이스 연결 상태 응답
```json
{
  "type": "connection_status",
  "payload": {
    "pi_connected": true,
    "esp32_connected": true,
    "glass_connected": true
  }
}
```

#### 2. 운동 계획 수신 결과 (ACK)
- `accepted`: true/false 반환
```json
{
  "type": "plan_ack",
  "payload": {
    "accepted": false,
    "exercise_type": "pushup",
    "set_count": 3,
    "validation_errors": [
      "rest_sec must be greater than 0"
    ]
  }
}
```

#### 3. 캘리브레이션 상태
- `status`: started / success / failed
```json
{
  "type": "calibration_status",
  "payload": {
    "status": "success",
    "message": "기준값 측정 완료",
    "calibration_summary": {
      "ch1_mvc": 82.1,
      "ch2_mvc": 76.4,
      "ch3_mvc": 69.8
    }
  }
}
```

#### 4. 운동 시작 이벤트
```json
{
  "type": "workout_started",
  "payload": {
    "exercise_type": "pushup",
    "started_at": "2026-04-27T09:28:00+09:00"
  }
}
```

#### 5. 일시정지 및 재개 알림
```json
{
  "type": "workout_paused",
  "payload": {
    "set_index": 2,
    "current_rep": 7,
    "paused_at": "2026-04-27T09:33:00+09:00"
  }
}
```

#### 6. 개별 세트 완료 알림
```json
{
  "type": "set_completed",
  "payload": {
    "set_index": 1,
    "target_reps": 12,
    "actual_reps": 12,
    "completed_at": "2026-04-27T09:30:10+09:00"
  }
}
```

#### 7. 휴식 타이머 (시작 및 종료)
```json
{
  "type": "rest_started",
  "payload": {
    "after_set_index": 1,
    "rest_sec": 60,
    "started_at": "2026-04-27T09:30:11+09:00"
  }
}
```
```json
{
  "type": "rest_finished",
  "payload": {
    "next_set_index": 2,
    "finished_at": "2026-04-27T09:31:11+09:00"
  }
}
```

#### 8. 전체 운동 종료 이벤트
```json
{
  "type": "workout_completed",
  "payload": {
    "ended_at": "2026-04-27T09:35:12+09:00",
    "status": "completed",
    "end_reason": "auto_completed"
  }
}
```

#### 9. 최종 세션 결과
- 운동이 종료되면 이 데이터를 1회만 앱으로 최종 발송함. (앱은 이 원본 데이터를 고스란히 백엔드로 전달함)
```json
{
  "type": "session_result",
  "payload": {
    "session_id": "sess_20260427_001",
    "exercise_type": "pushup",
    "status": "completed",
    "end_reason": "auto_completed",
    "started_at": "2026-04-27T09:28:00+09:00",
    "ended_at": "2026-04-27T09:35:12+09:00",
    "duration_sec": 432,
    "set_count": 3,
    "target_reps_per_set": [12, 12, 10],
    "actual_reps_per_set": [12, 12, 9],
    "rest_sec": 60,
    "total_reps": 33,
    "valid_reps": 31,
    "avg_target_muscle": 61.2,
    "avg_assist_muscle": 21.1,
    "avg_compensator": 17.7,
    "compensation_count": 4,
    "fatigue_onset_set": 3,
    "fatigue_onset_rep": 7,
    "comment": "마지막 세트에서 보상동작 증가",
    "calibration_summary": {
      "ch1_mvc": 82.1,
      "ch2_mvc": 76.4,
      "ch3_mvc": 69.8
    },
    "muscle_map": {
      "chest": 68.0,
      "left_shoulder": 42.0,
      "right_shoulder": 39.0,
      "left_triceps": 54.0,
      "right_triceps": 52.0
    },
    "balance_summary": {
      "enabled": false,
      "reason": "no_left_right_pairing"
    },
    "set_results": [ 
      { 
        "set_index": 1,
        "target_reps": 12,
        "actual_reps": 12,
        "avg_speed": "normal",
        "compensation_count": 1,
        "started_at": "2026-04-27T09:28:20+09:00",
        "ended_at": "2026-04-27T09:29:10+09:00"
       }
    ]
  }
}
```

#### 10. 오류/에러
```json
{
  "type": "error",
  "payload": {
    "code": "CALIBRATION_FAILED",
    "message": "캘리브레이션 실패"
  }
}
```


## 3. REST API (App ↔ Backend Server)

> **Base URL**: `https://api.imo-app.com/v1`  
> **인증**: Bearer Token (JWT)  
> **Content-Type**: `application/json`

---

### 3-1. 인증 / 사용자 관리

#### API-01. `POST /auth/signup` — 회원가입

| 항목 | 내용 |
|------|------|
| **관련 화면** | 온보딩 - 회원가입 |
| **필수 여부** | 선택 |

**Request Body:**

```json
{
  "email": "user@example.com",
  "password": "securePassword123",
  "nickname": "근육맨"
}
```

| 필드 | 타입 | 필수 | 유효성 검증 |
|------|------|------|-------------|
| `email` | string | ✅ | 이메일 형식 |
| `password` | string | ✅ | 8자 이상, 영문+숫자 |
| `nickname` | string | ✅ | 1~20자 |

**Response `201 Created`:**

```json
{
  "success": true,
  "data": {
    "userId": "usr-uuid-001",
    "email": "user@example.com",
    "nickname": "근육맨",
    "accessToken": "eyJhbG...",
    "refreshToken": "eyJhbG..."
  },
  "error": null
}
```

---

#### API-02. `POST /auth/login` — 로그인

| 항목 | 내용 |
|------|------|
| **관련 화면** | 온보딩 |
| **필수 여부** | 필수 |

**Request Body:**

```json
{
  "email": "user@example.com",
  "password": "securePassword123"
}
```

**Response `200 OK`:**

```json
{
  "success": true,
  "data": {
    "userId": "usr-uuid-001",
    "accessToken": "eyJhbG...",
    "refreshToken": "eyJhbG..."
  },
  "error": null
}
```

---

#### API-03. `POST /auth/refresh` — 토큰 갱신

| 항목 | 내용 |
|------|------|
| **필수 여부** | 필수 |

**Request Body:**

```json
{
  "refreshToken": "eyJhbG..."
}
```

**Response `200 OK`:**

```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbG...",
    "refreshToken": "eyJhbG..."
  },
  "error": null
}
```

---

#### API-17. `GET /auth/email/check` — 이메일 중복 확인

| 항목 | 내용 |
|------|------|
| **관련 화면** | 회원가입 (입력 즉시 검증) |
| **필수 여부** | 선택 |
| **인증** | ❌ |

**Request Query Parameters:**

| 필드 | 타입 | 필수 | 유효성 검증 |
|------|------|------|-------------|
| `email` | string | ✅ | RFC 5322 이메일 형식 |

**예시:** `GET /api/v1/auth/email/check?email=test@example.com`

**Response `200 OK`:**

```json
{
  "success": true,
  "data": {
    "available": true
  },
  "error": null
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `available` | bool | `true` 면 미가입 (사용 가능), `false` 면 이미 가입됨 |

**Rate Limit:** IP당 분당 20회 (이메일 enumeration 공격 속도 제한)

---

### 3-2. 프로필 관리

#### API-04. `GET /users/me/profile` — 프로필 조회

| 항목 | 내용 |
|------|------|
| **관련 화면** | 마이페이지 - 프로필 관리 |
| **필수 여부** | 필수 |
| **인증** | ✅ Bearer Token |

**Response `200 OK`:**

```json
{
  "success": true,
  "data": {
    "userId": "usr-uuid-001",
    "nickname": "근육맨",
    "age": 28,
    "gender": "MALE",
    "heightCm": 175.5,
    "weightKg": 72.0,
    "profileImageUrl": null,
    "bodyScanData": null,
    "createdAt": "2026-04-01T10:00:00Z",
    "updatedAt": "2026-04-20T15:30:00Z"
  },
  "error": null
}
```

---

#### API-05. `PUT /users/me/profile` — 프로필 수정

| 항목 | 내용 |
|------|------|
| **관련 화면** | 온보딩 - 프로필 입력, 마이페이지 - 프로필 관리 |
| **필수 여부** | 필수 |
| **인증** | ✅ Bearer Token |

**Request Body:**

```json
{
  "nickname": "근육맨",
  "age": 28,
  "gender": "MALE",
  "heightCm": 175.5,
  "weightKg": 72.0
}
```

| 필드 | 타입 | 필수 | 유효성 검증 |
|------|------|------|-------------|
| `nickname` | string | ✅ | 1~20자 |
| `age` | int | ✅ | 1~120 |
| `gender` | string | ✅ | `MALE` / `FEMALE` / `OTHER` |
| `heightCm` | float | ✅ | 50.0~300.0 |
| `weightKg` | float | ✅ | 10.0~500.0 |

**Response `200 OK`:**

```json
{
  "success": true,
  "data": {
    "userId": "usr-uuid-001",
    "nickname": "근육맨",
    "age": 28,
    "gender": "MALE",
    "heightCm": 175.5,
    "weightKg": 72.0,
    "updatedAt": "2026-04-27T09:00:00Z"
  },
  "error": null
}
```

---

#### API-18. `PUT /users/me/password` — 비밀번호 변경

| 항목 | 내용 |
|------|------|
| **관련 화면** | 마이페이지 - 비밀번호 변경 |
| **필수 여부** | 선택 |
| **인증** | ✅ Bearer Token |

**Request Body:**

```json
{
  "currentPassword": "oldpass123",
  "newPassword": "newpass456"
}
```

| 필드 | 타입 | 필수 | 유효성 검증 |
|------|------|------|-------------|
| `currentPassword` | string | ✅ | 현재 비밀번호 |
| `newPassword` | string | ✅ | 8자 이상 |

**Response `200 OK`:**

```json
{
  "success": true,
  "data": {
    "changed": true
  },
  "error": null
}
```

**Error:**
- `401 UNAUTHORIZED` — `Current password is incorrect`

**보안 정책:** 비번 변경 후 다른 기기의 refresh 토큰은 무효화하지 않음 (이번 라운드 결정 — 시연 중 자동 로그아웃 회피).

---

### 3-3. 운동 세션 기록

#### API-06. `POST /sessions` — 세션 결과 저장

| 항목 | 내용 |
|------|------|
| **관련 FR** | FR-43, FR-44, FR-45 |
| **관련 화면** | 홈 - 세션 결과 |
| **필수 여부** | 필수 |
| **인증** | ✅ Bearer Token |

**Request Body:**

```json
{
  "user_id": 123,
  "session_id": "sess_20260427_001",
  "exercise_type": "pushup",
  "status": "completed",
  "end_reason": "auto_completed",
  "started_at": "2026-04-27T09:28:00+09:00",
  "ended_at": "2026-04-27T09:35:12+09:00",
  "duration_sec": 432,
  "set_count": 3,
  "target_reps_per_set": [12, 12, 10],
  "actual_reps_per_set": [12, 12, 9],
  "rest_sec": 60,
  "total_reps": 33,
  "valid_reps": 31,
  "avg_target_muscle": 61.2,
  "avg_assist_muscle": 21.1,
  "avg_compensator": 17.7,
  "compensation_count": 4,
  "fatigue_onset_set": 3,
  "fatigue_onset_rep": 7,
  "comment": "마지막 세트에서 보상동작 증가",
  "calibration_summary": {
    "ch1_mvc": 82.1,
    "ch2_mvc": 76.4,
    "ch3_mvc": 69.8
  },
  "muscle_map": {
    "chest": 68.0,
    "left_shoulder": 42.0,
    "right_shoulder": 39.0,
    "left_triceps": 54.0,
    "right_triceps": 52.0
  },
  "balance_summary": {
    "enabled": false,
    "reason": "no_left_right_pairing"
  },
  "set_results": [
    {
      "set_index": 1,
      "target_reps": 12,
      "actual_reps": 12,
      "compensation_count": 1,
      "avg_speed": "normal",
      "started_at": "2026-04-27T09:28:20+09:00",
      "ended_at": "2026-04-27T09:29:10+09:00"
    },
    {
      "set_index": 2,
      "target_reps": 12,
      "actual_reps": 12,
      "compensation_count": 1,
      "avg_speed": "normal",
      "started_at": "2026-04-27T09:30:11+09:00",
      "ended_at": "2026-04-27T09:31:00+09:00"
    },
    {
      "set_index": 3,
      "target_reps": 10,
      "actual_reps": 9,
      "compensation_count": 2,
      "avg_speed": "fast",
      "started_at": "2026-04-27T09:32:01+09:00",
      "ended_at": "2026-04-27T09:35:12+09:00"
    }
  ]
}
```

**Response `201 Created`:**

```json
{
  "success": true,
  "data": {
    "sessionId": "sess-uuid-001",
    "createdAt": "2026-04-27T09:50:05.000Z"
  },
  "error": null
}
```

---

#### API-07. `GET /sessions` — 세션 목록 조회 (날짜별)

| 항목 | 내용 |
|------|------|
| **관련 FR** | FR-46 |
| **관련 화면** | 기록 - 달력 조회, 날짜별 목록 |
| **필수 여부** | 필수 |
| **인증** | ✅ Bearer Token |

**Query Parameters:**

| 파라미터 | 타입 | 필수 | 설명 | 예시 |
|----------|------|------|------|------|
| `date` | string | ❌ | 특정 날짜 조회 | `2026-04-27` |
| `month` | string | ❌ | 월 단위 조회 (달력용) | `2026-04` |
| `exerciseType` | string | ❌ | 운동 종류 필터 | `PUSH_UP` |
| `page` | int | ❌ | 페이지 번호 (기본: 1) | `1` |
| `size` | int | ❌ | 페이지 크기 (기본: 20) | `20` |

**Example:** `GET /sessions?month=2026-04`

**Response `200 OK`:**

```json
{
  "success": true,
  "data": {
    "sessions": [
      {
        "sessionId": "sess-uuid-001",
        "exerciseType": "PUSH_UP",
        "date": "2026-04-27",
        "startTime": "2026-04-27T09:35:00.050Z",
        "endTime": "2026-04-27T09:50:00.000Z",
        "totalReps": 30,
        "totalSets": 3,
        "completionRate": 100.0,
        "avgTargetActivation": 62.1
      },
      {
        "sessionId": "sess-uuid-002",
        "exerciseType": "BICEP_CURL",
        "date": "2026-04-25",
        "startTime": "2026-04-25T18:00:00.000Z",
        "endTime": "2026-04-25T18:12:00.000Z",
        "totalReps": 24,
        "totalSets": 3,
        "completionRate": 80.0,
        "avgTargetActivation": 58.3
      }
    ],
    "exerciseDates": ["2026-04-01", "2026-04-03", "2026-04-05", "2026-04-25", "2026-04-27"],
    "pagination": {
      "page": 1,
      "size": 20,
      "totalCount": 15,
      "totalPages": 1
    }
  },
  "error": null
}
```

> **참고**: `exerciseDates`는 달력 화면에서 운동 수행 날짜에 마커를 표시하기 위한 필드다.

---

#### API-08. `GET /sessions/{sessionId}` — 세션 상세 조회

| 항목 | 내용 |
|------|------|
| **관련 FR** | FR-47, FR-48, FR-49 |
| **관련 화면** | 기록 - 상세 보기, 좌우 비교, 세트 결과 표시 |
| **필수 여부** | 필수 |
| **인증** | ✅ Bearer Token |

**Response `200 OK`:**

```json
{
  "success": true,
  "data": {
    "sessionId": "sess-uuid-001",
    "exerciseType": "PUSH_UP",
    "startTime": "2026-04-27T09:35:00.050Z",
    "endTime": "2026-04-27T09:50:00.000Z",
    "totalDurationSeconds": 900,
    "sets": [
      {
        "setNumber": 1,
        "targetReps": 12,
        "actualReps": 12,
        "durationSeconds": 180,
        "restDurationSeconds": 60,
        "avgSpeed": "NORMAL",
        "compensationCount": 1,
        "avgTargetActivation": 68.5,
        "stabilityScore": 85.0,
        "repDetails": [
          {
            "repNumber": 1,
            "durationMs": 2800,
            "speedStatus": "NORMAL",
            "compensationDetected": false,
            "emgPeaks": [
              { "channelId": 1, "muscleName": "대흉근", "peak": 75.2 },
              { "channelId": 2, "muscleName": "삼두근(좌)", "peak": 52.3 },
              { "channelId": 3, "muscleName": "삼두근(우)", "peak": 54.1 }
            ],
            "stabilityDeviation": 2.1
          }
        ]
      },
      {
        "setNumber": 2,
        "targetReps": 10,
        "actualReps": 10,
        "durationSeconds": 160,
        "restDurationSeconds": 60,
        "avgSpeed": "NORMAL",
        "compensationCount": 2,
        "avgTargetActivation": 62.1,
        "stabilityScore": 80.0,
        "repDetails": []
      },
      {
        "setNumber": 3,
        "targetReps": 8,
        "actualReps": 8,
        "durationSeconds": 140,
        "restDurationSeconds": 0,
        "avgSpeed": "SLOW",
        "compensationCount": 3,
        "avgTargetActivation": 55.8,
        "stabilityScore": 72.0,
        "repDetails": []
      }
    ],
    "overallSummary": {
      "totalReps": 30,
      "totalTargetReps": 30,
      "completionRate": 100.0,
      "avgTargetActivation": 62.1,
      "totalCompensationCount": 6,
      "avgStabilityScore": 79.0,
      "fatigueOnsetSet": 3,
      "fatigueOnsetRep": 5
    },
    "muscleBalance": {
      "leftAvg": 52.3,
      "rightAvg": 54.1,
      "balanceRatio": 96.7,
      "status": "BALANCED"
    },
    "graphs": {
      "repActivationTimeline": [
        { "setNumber": 1, "repNumber": 1, "ch1": 75.2, "ch2": 52.3, "ch3": 54.1 },
        { "setNumber": 1, "repNumber": 2, "ch1": 73.8, "ch2": 50.1, "ch3": 53.5 },
        { "setNumber": 1, "repNumber": 3, "ch1": 71.5, "ch2": 49.2, "ch3": 52.8 }
      ],
      "speedTimeline": [
        { "setNumber": 1, "repNumber": 1, "durationMs": 2800 },
        { "setNumber": 1, "repNumber": 2, "durationMs": 2650 },
        { "setNumber": 1, "repNumber": 3, "durationMs": 2700 }
      ],
      "stabilityTimeline": [
        { "setNumber": 1, "repNumber": 1, "deviation": 2.1 },
        { "setNumber": 1, "repNumber": 2, "deviation": 1.8 },
        { "setNumber": 1, "repNumber": 3, "deviation": 2.5 }
      ]
    }
  },
  "error": null
}
```

> **참고**: `graphs` 필드는 FR-48(그래프 시각화) 요구사항을 위해 시계열 데이터를 포함한다.

---

#### API-09. `DELETE /sessions/{sessionId}` — 세션 삭제

| 항목 | 내용 |
|------|------|
| **필수 여부** | 선택 |
| **인증** | ✅ Bearer Token |

**Response `200 OK`:**

```json
{
  "success": true,
  "data": {
    "deletedSessionId": "sess-uuid-001"
  },
  "error": null
}
```

---

### 3-4. 주간 통계 (확장 기능)

#### API-10. `GET /statistics/weekly` — 주간 통계 조회

| 항목 | 내용 |
|------|------|
| **관련 FR** | FR-51 ~ FR-56 |
| **관련 화면** | 통계 - 주간 통계 메인, 기간 이동, 운동 필터 |
| **필수 여부** | 선택 (확장 기능) |
| **인증** | ✅ Bearer Token |

**Query Parameters:**

| 파라미터 | 타입 | 필수 | 설명 | 예시 |
|----------|------|------|------|------|
| `weekStart` | string | ✅ | 주 시작일 (YYYY-MM-DD, 월요일) | `2026-04-20` |
| `exerciseType` | string | ❌ | 운동 종류 필터 (미지정 시 전체) | `PUSH_UP` |

**Example:** `GET /statistics/weekly?weekStart=2026-04-20&exerciseType=PUSH_UP`

**Response `200 OK`:**

```json
{
  "success": true,
  "data": {
    "weekStart": "2026-04-20",
    "weekEnd": "2026-04-26",
    "exerciseType": "PUSH_UP",
    "summary": {
      "totalSessions": 4,
      "totalReps": 120,
      "totalSets": 12,
      "avgCompletionRate": 92.5,
      "avgTargetActivation": 65.3,
      "totalExerciseMinutes": 58
    },
    "dailyBreakdown": [
      { "date": "2026-04-20", "sessions": 1, "totalReps": 30 },
      { "date": "2026-04-21", "sessions": 0, "totalReps": 0 },
      { "date": "2026-04-22", "sessions": 1, "totalReps": 28 },
      { "date": "2026-04-23", "sessions": 1, "totalReps": 32 },
      { "date": "2026-04-24", "sessions": 0, "totalReps": 0 },
      { "date": "2026-04-25", "sessions": 1, "totalReps": 30 },
      { "date": "2026-04-26", "sessions": 0, "totalReps": 0 }
    ],
    "trends": {
      "targetActivation": {
        "values": [68.5, 65.2, 63.1, 60.5],
        "dates": ["2026-04-20", "2026-04-22", "2026-04-23", "2026-04-25"],
        "trend": "DECREASING"
      },
      "compensationRate": {
        "values": [8.3, 10.0, 14.3, 16.7],
        "dates": ["2026-04-20", "2026-04-22", "2026-04-23", "2026-04-25"],
        "trend": "INCREASING"
      },
      "fatigue": {
        "values": [85.0, 82.0, 78.0, 72.0],
        "dates": ["2026-04-20", "2026-04-22", "2026-04-23", "2026-04-25"],
        "trend": "INCREASING"
      }
    }
  },
  "error": null
}
```

---

#### API-11. `GET /statistics/weekly/heatmap` — 주간 히트맵 데이터

| 항목 | 내용 |
|------|------|
| **관련 FR** | FR-54, FR-57 |
| **관련 화면** | 통계 - 히트맵 탭, 2D 아바타 |
| **필수 여부** | 선택 (확장 기능) |
| **인증** | ✅ Bearer Token |

**Query Parameters:**

| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| `weekStart` | string | ✅ | 주 시작일 (YYYY-MM-DD) |
| `exerciseType` | string | ❌ | 운동 종류 필터 |

**Response `200 OK`:**

```json
{
  "success": true,
  "data": {
    "weekStart": "2026-04-20",
    "weekEnd": "2026-04-26",
    "muscles": [
      {
        "muscleId": "pectoralis_major",
        "muscleName": "대흉근",
        "side": "CENTER",
        "avgActivation": 65.3,
        "activationLevel": "HIGH",
        "sessionCount": 4
      },
      {
        "muscleId": "triceps_left",
        "muscleName": "삼두근",
        "side": "LEFT",
        "avgActivation": 52.1,
        "activationLevel": "MEDIUM",
        "sessionCount": 4
      },
      {
        "muscleId": "triceps_right",
        "muscleName": "삼두근",
        "side": "RIGHT",
        "avgActivation": 54.8,
        "activationLevel": "MEDIUM",
        "sessionCount": 4
      },
      {
        "muscleId": "deltoid_left",
        "muscleName": "삼각근",
        "side": "LEFT",
        "avgActivation": 25.3,
        "activationLevel": "LOW",
        "sessionCount": 4
      },
      {
        "muscleId": "deltoid_right",
        "muscleName": "삼각근",
        "side": "RIGHT",
        "avgActivation": 27.1,
        "activationLevel": "LOW",
        "sessionCount": 4
      }
    ]
  },
  "error": null
}
```

---

#### API-12. `GET /statistics/weekly/balance` — 주간 좌우 밸런스 데이터

| 항목 | 내용 |
|------|------|
| **관련 FR** | FR-55 |
| **관련 화면** | 통계 - 밸런스 탭 |
| **필수 여부** | 선택 (확장 기능) |
| **인증** | ✅ Bearer Token |

**Query Parameters:**

| 파라미터 | 타입 | 필수 | 설명 |
|----------|------|------|------|
| `weekStart` | string | ✅ | 주 시작일 (YYYY-MM-DD) |
| `exerciseType` | string | ❌ | 운동 종류 필터 |

**Response `200 OK`:**

```json
{
  "success": true,
  "data": {
    "weekStart": "2026-04-20",
    "weekEnd": "2026-04-26",
    "balancePairs": [
      {
        "muscleName": "삼두근",
        "left": {
          "avgActivation": 52.1,
          "maxActivation": 68.5,
          "minActivation": 38.2
        },
        "right": {
          "avgActivation": 54.8,
          "maxActivation": 71.2,
          "minActivation": 40.1
        },
        "balanceRatio": 95.1,
        "dominantSide": "RIGHT",
        "status": "BALANCED"
      },
      {
        "muscleName": "삼각근",
        "left": {
          "avgActivation": 25.3,
          "maxActivation": 35.2,
          "minActivation": 18.1
        },
        "right": {
          "avgActivation": 27.1,
          "maxActivation": 38.5,
          "minActivation": 19.3
        },
        "balanceRatio": 93.4,
        "dominantSide": "RIGHT",
        "status": "BALANCED"
      }
    ]
  },
  "error": null
}
```

**필드 설명:**

| 필드 | 타입 | 설명 |
|------|------|------|
| `balanceRatio` | float | 좌우 비율 (0~100, 100이 완벽 균형) |
| `dominantSide` | string | 우세한 쪽 (`LEFT` / `RIGHT`) |
| `status` | string | `BALANCED` / `MILD_IMBALANCE` / `SIGNIFICANT_IMBALANCE` |

---

### 3-5. 설정 관리

#### API-13. `GET /users/me/settings` — 사용자 설정 조회

| 항목 | 내용 |
|------|------|
| **관련 화면** | 마이페이지 |
| **필수 여부** | 필수 |
| **인증** | ✅ Bearer Token |

**Response `200 OK`:**

```json
{
  "success": true,
  "data": {
    "ttsEnabled": true,
    "wearable": {
      "raspberryPiIp": "192.168.0.50",
      "raspberryPiPort": 8765,
      "glassConnected": false,
      "glassDeviceName": null
    },
    "notifications": {
      "exerciseReminder": true,
      "weeklyReport": true
    }
  },
  "error": null
}
```

---

#### API-14. `PUT /users/me/settings` — 사용자 설정 수정

| 항목 | 내용 |
|------|------|
| **관련 화면** | 마이페이지 - TTS 설정, 웨어러블 설정 |
| **필수 여부** | 필수 |
| **인증** | ✅ Bearer Token |

**Request Body (부분 업데이트 지원):**

```json
{
  "ttsEnabled": false,
  "wearable": {
    "raspberryPiIp": "192.168.0.50",
    "raspberryPiPort": 8765
  }
}
```

**Response `200 OK`:**

```json
{
  "success": true,
  "data": {
    "updatedAt": "2026-04-27T10:00:00Z"
  },
  "error": null
}
```

---

#### API-15. `DELETE /users/me/data` — 운동 데이터 초기화

| 항목 | 내용 |
|------|------|
| **관련 화면** | 마이페이지 - 데이터 초기화 |
| **필수 여부** | 선택 |
| **인증** | ✅ Bearer Token |

**Request Body:**

```json
{
  "confirmText": "DELETE ALL DATA"
}
```

> ⚠️ **주의**: 이 API는 되돌릴 수 없는 작업이다. `confirmText`에 정확한 문자열을 입력해야 실행된다.

**Response `200 OK`:**

```json
{
  "success": true,
  "data": {
    "deletedSessionCount": 47,
    "deletedAt": "2026-04-27T10:05:00Z"
  },
  "error": null
}
```

---

### 3-6. 운동 정보

#### API-16. `GET /exercises` — 운동 종목 목록 조회

| 항목 | 내용 |
|------|------|
| **관련 FR** | FR-06, FR-07 |
| **관련 화면** | 홈 - 운동 선택, 운동 안내 |
| **필수 여부** | 필수 |
| **인증** | ✅ Bearer Token |

**Response `200 OK`:**

```json
{
  "success": true,
  "data": {
    "exercises": [
      {
        "exerciseType": "PUSH_UP",
        "name": "푸시업",
        "description": "가슴, 삼두근, 전면 삼각근을 주로 자극하는 상체 복합 운동입니다.",
        "targetMuscles": ["대흉근", "삼두근", "전면 삼각근"],
        "instructions": [
          "양손을 어깨 너비로 벌리고 바닥에 짚습니다.",
          "몸을 일직선으로 유지하며 팔꿈치를 굽혀 내려갑니다.",
          "가슴이 바닥에 가까워지면 팔을 펴서 올라옵니다."
        ],
        "cautions": [
          "허리가 처지지 않도록 코어에 힘을 유지합니다.",
          "팔꿈치가 과도하게 벌어지지 않도록 주의합니다."
        ],
        "sensorPlacement": {
          "emg": [
            { "channelId": 1, "muscleName": "대흉근", "side": "CENTER", "description": "가슴 중앙부" },
            { "channelId": 2, "muscleName": "삼두근", "side": "LEFT", "description": "왼쪽 팔 뒤쪽" },
            { "channelId": 3, "muscleName": "삼두근", "side": "RIGHT", "description": "오른쪽 팔 뒤쪽" }
          ],
          "imu": { "bodyPart": "상완", "description": "오른쪽 상완에 IMU 센서를 부착하세요." }
        },
        "thumbnailUrl": "/assets/exercises/push_up.png"
      },
      {
        "exerciseType": "LATERAL_RAISE",
        "name": "싸레레 (사이드 레터럴 레이즈)",
        "description": "측면 삼각근을 주로 자극하는 어깨 고립 운동입니다.",
        "targetMuscles": ["측면 삼각근", "전면 삼각근", "승모근"],
        "instructions": [
          "양손에 덤벨을 들고 몸 옆에 자연스럽게 내립니다.",
          "팔꿈치를 살짝 구부린 상태로 양팔을 옆으로 들어올립니다.",
          "어깨 높이까지 올린 후 천천히 내립니다."
        ],
        "cautions": [
          "반동을 이용하지 않도록 주의합니다.",
          "승모근에 과도한 힘이 들어가지 않도록 합니다."
        ],
        "sensorPlacement": {
          "emg": [
            { "channelId": 1, "muscleName": "측면삼각근", "side": "LEFT", "description": "왼쪽 어깨 측면" },
            { "channelId": 2, "muscleName": "측면삼각근", "side": "RIGHT", "description": "오른쪽 어깨 측면" },
            { "channelId": 3, "muscleName": "승모근", "side": "CENTER", "description": "목 뒤 상부 승모근" }
          ],
          "imu": { "bodyPart": "전완", "description": "오른쪽 전완에 IMU 센서를 부착하세요." }
        },
        "thumbnailUrl": "/assets/exercises/lateral_raise.png"
      },
      {
        "exerciseType": "BICEP_CURL",
        "name": "이두컬",
        "description": "이두근을 주로 자극하는 팔 고립 운동입니다.",
        "targetMuscles": ["이두근", "전완근"],
        "instructions": [
          "양손에 덤벨을 들고 팔을 자연스럽게 내립니다.",
          "팔꿈치를 고정한 채 전완을 올려 덤벨을 어깨 방향으로 컬합니다.",
          "최대 수축 후 천천히 내립니다."
        ],
        "cautions": [
          "팔꿈치가 앞뒤로 움직이지 않도록 고정합니다.",
          "반동을 사용하지 않도록 주의합니다."
        ],
        "sensorPlacement": {
          "emg": [
            { "channelId": 1, "muscleName": "이두근", "side": "LEFT", "description": "왼쪽 상완 전면" },
            { "channelId": 2, "muscleName": "이두근", "side": "RIGHT", "description": "오른쪽 상완 전면" },
            { "channelId": 3, "muscleName": "전완근", "side": "RIGHT", "description": "오른쪽 전완 상부" }
          ],
          "imu": { "bodyPart": "전완", "description": "오른쪽 전완에 IMU 센서를 부착하세요." }
        },
        "thumbnailUrl": "/assets/exercises/bicep_curl.png"
      }
    ]
  },
  "error": null
}
```

---

### 3-7. REST API 엔드포인트 요약

| ID | Method | Endpoint | 설명 | 필수 | 인증 |
|----|--------|----------|------|------|------|
| API-01 | `POST` | `/auth/signup` | 회원가입 | 선택 | ❌ |
| API-02 | `POST` | `/auth/login` | 로그인 | 필수 | ❌ |
| API-03 | `POST` | `/auth/refresh` | 토큰 갱신 | 필수 | ❌ |
| API-04 | `GET` | `/users/me/profile` | 프로필 조회 | 필수 | ✅ |
| API-05 | `PUT` | `/users/me/profile` | 프로필 수정 | 필수 | ✅ |
| API-06 | `POST` | `/sessions` | 세션 저장 | 필수 | ✅ |
| API-07 | `GET` | `/sessions` | 세션 목록 조회 | 필수 | ✅ |
| API-08 | `GET` | `/sessions/{sessionId}` | 세션 상세 조회 | 필수 | ✅ |
| API-09 | `DELETE` | `/sessions/{sessionId}` | 세션 삭제 | 선택 | ✅ |
| API-10 | `GET` | `/statistics/weekly` | 주간 통계 | 선택 | ✅ |
| API-11 | `GET` | `/statistics/weekly/heatmap` | 주간 히트맵 | 선택 | ✅ |
| API-12 | `GET` | `/statistics/weekly/balance` | 주간 밸런스 | 선택 | ✅ |
| API-13 | `GET` | `/users/me/settings` | 설정 조회 | 필수 | ✅ |
| API-14 | `PUT` | `/users/me/settings` | 설정 수정 | 필수 | ✅ |
| API-15 | `DELETE` | `/users/me/data` | 데이터 초기화 | 선택 | ✅ |
| API-16 | `GET` | `/exercises` | 운동 종목 목록 | 필수 | ✅ |
| API-17 | `GET` | `/auth/email/check` | 이메일 중복 확인 | 선택 | ❌ |
| API-18 | `PUT` | `/users/me/password` | 비밀번호 변경 | 선택 | ✅ |

---

## 4. 에러 코드 정의

### 4-1. WebSocket 에러 코드

| 에러 코드 | 타입 | 심각도 | 설명 | 관련 FR |
|-----------|------|--------|------|---------|
| `EMG_CHANNEL_LOST` | SENSOR | CRITICAL | EMG 채널 신호 유실 | EX-01 |
| `EMG_SIGNAL_NOISE` | SENSOR | WARNING | EMG 신호 과도한 노이즈 | EX-01 |
| `IMU_DISCONNECTED` | SENSOR | CRITICAL | IMU 센서 연결 끊김 | EX-01 |
| `IMU_SIGNAL_ERROR` | SENSOR | WARNING | IMU 신호 이상 | EX-01 |
| `ESP32_COMM_LOST` | COMMUNICATION | CRITICAL | ESP32 통신 단절 | EX-02 |
| `ESP32_TIMEOUT` | COMMUNICATION | WARNING | ESP32 응답 지연 | EX-02 |
| `GLASS_DISCONNECTED` | COMMUNICATION | WARNING | 스마트글래스 연결 해제 | EX-03 |
| `CALIBRATION_FAILED` | CALIBRATION | CRITICAL | 캘리브레이션 실패 | EX-04 |
| `CALIBRATION_TIMEOUT` | CALIBRATION | WARNING | 캘리브레이션 시간 초과 | EX-04 |
| `PLAN_SYNC_FAILED` | SYSTEM | CRITICAL | 운동 계획 동기화 실패 | EX-05 |
| `REST_PERIOD_ERROR` | SYSTEM | WARNING | 휴식 구간 중 오류 | EX-06 |
| `SYSTEM_OVERLOAD` | SYSTEM | CRITICAL | 시스템 과부하 | EX-07 |

### 4-2. REST API 에러 코드

| HTTP Status | 에러 코드 | 설명 |
|-------------|-----------|------|
| 400 | `INVALID_REQUEST` | 잘못된 요청 형식 |
| 400 | `VALIDATION_ERROR` | 유효성 검증 실패 |
| 401 | `UNAUTHORIZED` | 인증 실패 |
| 401 | `TOKEN_EXPIRED` | 토큰 만료 |
| 403 | `FORBIDDEN` | 권한 없음 |
| 404 | `SESSION_NOT_FOUND` | 세션을 찾을 수 없음 |
| 404 | `USER_NOT_FOUND` | 사용자를 찾을 수 없음 |
| 409 | `DUPLICATE_EMAIL` | 이메일 중복 |
| 500 | `INTERNAL_ERROR` | 서버 내부 오류 |

---

## 5. Enum 정의

### 5-1. 운동 종류 (`ExerciseType`)

| 값 | 한글명 |
|----|--------|
| `PUSH_UP` | 푸시업 |
| `LATERAL_RAISE` | 싸레레 (사이드 레터럴 레이즈) |
| `BICEP_CURL` | 이두컬 |

### 5-2. 속도 상태 (`SpeedStatus`)

| 값 | 한글명 | 기준 |
|----|--------|------|
| `SLOW` | 느림 | 반복 1회 > 기준 시간 상한 |
| `NORMAL` | 적절 | 기준 범위 이내 |
| `FAST` | 빠름 | 반복 1회 < 기준 시간 하한 |

### 5-3. 보상동작 수준 (`CompensationLevel`)

| 값 | 한글명 | 설명 |
|----|--------|------|
| `NONE` | 정상 | 보상동작 없음 |
| `MILD` | 경미 | 경미한 보상동작 감지 |
| `SEVERE` | 심각 | 심한 보상동작 감지 |

### 5-4. 안정성 상태 (`StabilityStatus`)

| 값 | 한글명 |
|----|--------|
| `STABLE` | 안정 |
| `UNSTABLE` | 불안정 |

### 5-5. 운동 단계 (`ExercisePhase`)

| 값 | 한글명 |
|----|--------|
| `EXERCISING` | 운동 중 |
| `REST` | 휴식 중 |
| `COMPLETED` | 완료 |

### 5-6. 센서 상태 (`SensorStatus`)

| 값 | 한글명 |
|----|--------|
| `OK` | 정상 |
| `ERROR` | 오류 |
| `DISCONNECTED` | 미연결 |

### 5-7. 캘리브레이션 단계 (`CalibrationPhase`)

| 값 | 한글명 | 설명 |
|----|--------|------|
| `REST` | 안정 상태 | 안정 상태 기준값 측정 |
| `MVC` | 최대 수축 | 최대 수의 수축 측정 |
| `PROCESSING` | 계산 중 | 기준값 계산 처리 |

### 5-8. 좌우 밸런스 상태 (`BalanceStatus`)

| 값 | 한글명 | 기준 |
|----|--------|------|
| `BALANCED` | 균형 | 비율 ≥ 90% |
| `MILD_IMBALANCE` | 경미한 불균형 | 75% ≤ 비율 < 90% |
| `SIGNIFICANT_IMBALANCE` | 심한 불균형 | 비율 < 75% |

### 5-9. 근활성 수준 (`ActivationLevel`)

| 값 | 한글명 | 기준 (%MVC) |
|----|--------|-------------|
| `VERY_LOW` | 매우 낮음 | 0 ~ 20 |
| `LOW` | 낮음 | 20 ~ 40 |
| `MEDIUM` | 보통 | 40 ~ 60 |
| `HIGH` | 높음 | 60 ~ 80 |
| `VERY_HIGH` | 매우 높음 | 80 ~ 100 |

### 5-10. 성별 (`Gender`)

| 값 | 한글명 |
|----|--------|
| `MALE` | 남성 |
| `FEMALE` | 여성 |
| `OTHER` | 기타 |

### 5-11. 운동 종료 사유 (`StopReason`)

| 값 | 한글명 | 설명 |
|----|--------|------|
| `USER_MANUAL_STOP` | 수동 종료 | 사용자가 직접 종료 |
| `EMERGENCY` | 비상 종료 | 비상 상황으로 종료 |
| `ERROR` | 오류 종료 | 시스템 오류로 종료 |

### 5-12. 코칭 메시지 카테고리 (`CoachingCategory`)

| 값 | 한글명 | 설명 |
|----|--------|------|
| `SPEED` | 속도 | 속도 관련 코칭 |
| `COMPENSATION` | 보상동작 | 보상동작 관련 경고 |
| `STABILITY` | 안정성 | 안정성 관련 코칭 |
| `FATIGUE` | 피로도 | 근피로도 관련 코칭 |
| `ENCOURAGEMENT` | 격려 | 동기부여 메시지 |

### 5-13. 추세 방향 (`TrendDirection`)

| 값 | 한글명 |
|----|--------|
| `INCREASING` | 증가 추세 |
| `DECREASING` | 감소 추세 |
| `STABLE` | 안정적 |

### 5-14. 에러 심각도 (`Severity`)

| 값 | 한글명 | 설명 |
|----|--------|------|
| `INFO` | 정보 | 참고 수준 |
| `WARNING` | 경고 | 주의 필요 (운동 계속 가능) |
| `CRITICAL` | 심각 | 즉시 조치 필요 (운동 일시 중지) |
| `FATAL` | 치명적 | 운동 즉시 중단 필요 |

---

## 6. 부록: 메시지 흐름도

### A. 운동 전체 플로우

```
[App]                              [Raspberry Pi]                    [Smart Glass]
  |                                      |                                |
  |  1. 시스템 초기화                      |                                |
  |---SYSTEM_STATUS_REQUEST------------>|                                |
  |<--SYSTEM_STATUS_RESPONSE------------|                                |
  |                                      |                                |
  |  2. 운동 준비                          |                                |
  |---EXERCISE_SELECT------------------>|                                |
  |<--EXERCISE_SELECT_ACK---------------|                                |
  |---EXERCISE_PLAN_SEND--------------->|                                |
  |<--EXERCISE_PLAN_ACK-----------------|                                |
  |                                      |                                |
  |  3. 캘리브레이션 + 글래스 모드 전환     |                                |
  |---CALIBRATION_START---------------->|----글래스 운동 모드 전환------->|
  |<--CALIBRATION_START_ACK-------------|  (시작과 동시에 즉시 전환)       |
  |<--CALIBRATION_PROGRESS (반복)--------|                                |
  |<--CALIBRATION_RESULT----------------|                                |
  |                                      |                                |
  |  4. 운동 진행                          |                                |
  |---EXERCISE_START------------------->|                                |
  |<--EXERCISE_START_ACK----------------|                                |
  |                                      |                                |
  |  ┌─── 세트 반복 ──────────────────────┐                                |
  |  │ ┌─── 반복 횟수만큼 ──────────────┐ │                                |
  |  │ │<--REALTIME_DATA (10Hz)---------|─│──GLASS_DISPLAY_DATA (5Hz)--->|
  |  │ │<--REP_COMPLETED---------------|─│                               |
  |  │ │<--COACHING_MESSAGE (조건부)----|─│                               |
  |  │ └──────────────────────────────┘ │                                |
  |  │<--SET_COMPLETED------------------|                                |
  |  │ ┌─── 휴식 (마지막 세트 제외) ────┐ │                                |
  |  │ │<--REST_TIMER (1초 간격)--------|─│                               |
  |  │ └──────────────────────────────┘ │                                |
  |  └──────────────────────────────────┘                                |
  |                                      |                                |
  |  5. 운동 종료                          |                                |
  |<--EXERCISE_COMPLETED----------------|                                |
  |                                      |                                |
  |  6. 결과 저장 (REST API)              |                                |
  |---POST /sessions------------------->| (Backend Server)               |
  |                                      |                                |
```

### B. 비상 종료 플로우

```
[App]                              [Raspberry Pi]
  |                                      |
  |  운동 진행 중...                       |
  |<--REALTIME_DATA (Stream)------------|
  |                                      |
  |  [사용자 수동 종료]                    |
  |---EXERCISE_STOP (USER_MANUAL_STOP)->|
  |<--EXERCISE_STOP_ACK (partial)-------|
  |                                      |
  |  또는                                 |
  |                                      |
  |  [시스템 오류 발생]                    |
  |<--SYSTEM_ERROR----------------------|
  |---EXERCISE_STOP (ERROR)------------>|
  |<--EXERCISE_STOP_ACK----------------|
  |                                      |
  |  부분 결과 저장                        |
  |---POST /sessions------------------->| (Backend Server)
  |                                      |
```

### C. 글래스 연결 해제 시 앱 전환 플로우

```
[App]                              [Raspberry Pi]          [Smart Glass]
  |                                      |                        |
  |<--REALTIME_DATA (Stream)------------|                        |
  |                                      |--GLASS_DISPLAY_DATA-->|
  |                                      |                        |
  |                                      |     ✕ 글래스 연결 해제  |
  |                                      |                        |
  |<--SYSTEM_ERROR (GLASS_DISCONNECTED)-|                        |
  |                                      |                        |
  |  [앱 중심 모드로 전환]                 |                        |
  |<--REALTIME_DATA (Stream 유지)-------|                        |
  |                                      |                        |
  |  앱 화면에 글래스 정보도 함께 표시     |                        |
  |                                      |                        |
```

---

## 변경 이력

| 버전 | 날짜 | 작성자 | 변경 내용 |
|------|------|--------|-----------|
| v1.0 | 2026-04-27 | - | 최초 작성 (MVP 기준) |
