-- 1. Workout Sessions (세션 기본 정보 및 전체 요약 데이터)
CREATE TABLE `workout_sessions` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `user_id` BIGINT NOT NULL,
    `session_id` VARCHAR(100) NOT NULL UNIQUE COMMENT 'Pi에서 발급하거나 백엔드에서 생성한 고유 세션 ID',
    `exercise_type` VARCHAR(50) NOT NULL COMMENT '운동 종류 (예: pushup, bicepcurl)',
    `status` VARCHAR(50) NOT NULL COMMENT '상태 (completed, stopped, emergency_stopped 등)',
    `end_reason` VARCHAR(50) NOT NULL COMMENT '종료 사유 (auto_completed, user_stopped 등)',
    
    `started_at` DATETIME NOT NULL COMMENT '세션 시작 시간',
    `ended_at` DATETIME NOT NULL COMMENT '세션 종료 시간',
    `duration_sec` INT NOT NULL COMMENT '총 소요 시간(초)',
    
    `set_count` INT NOT NULL COMMENT '진행한 총 세트 수',
    `target_reps_per_set` JSON COMMENT '세트별 목표 횟수 배열',
    `actual_reps_per_set` JSON COMMENT '세트별 실제 횟수 배열',
    `rest_sec` INT NOT NULL COMMENT '세트 간 휴식 시간(초)',
    
    `total_reps` INT NOT NULL COMMENT '전체 반복 횟수',
    `valid_reps` INT NOT NULL COMMENT '유효 반복 횟수 (보상동작 없는 횟수)',
    
    `avg_target_muscle` DECIMAL(6,2) COMMENT '세션 평균 목표근 활성도',
    `avg_assist_muscle` DECIMAL(6,2) COMMENT '세션 평균 보조근 활성도',
    `avg_compensator` DECIMAL(6,2) COMMENT '세션 평균 보상근 활성도',
    `compensation_count` INT NOT NULL DEFAULT 0 COMMENT '세션 전체 보상동작 횟수',
    
    `fatigue_onset_set` INT COMMENT '피로도 시작 세트 번호 (없으면 NULL)',
    `fatigue_onset_rep` INT COMMENT '피로도 시작 반복 횟수 (없으면 NULL)',
    
    `comment` TEXT COMMENT '세션 코멘트 (예: 마지막 세트에서 보상동작 증가)',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Workout Set Results (세트별 상세 결과)
CREATE TABLE `workout_set_results` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `session_id` VARCHAR(100) NOT NULL,
    `set_index` INT NOT NULL COMMENT '세트 번호 (1부터 시작)',
    
    `target_reps` INT NOT NULL COMMENT '세트 목표 횟수',
    `actual_reps` INT NOT NULL COMMENT '세트 실제 달성 횟수',
    `compensation_count` INT NOT NULL DEFAULT 0 COMMENT '해당 세트 내 보상동작 횟수',
    `avg_speed` VARCHAR(30) NOT NULL COMMENT '평균 속도 (fast, normal, slow 등)',
    
    `started_at` DATETIME NOT NULL COMMENT '세트 시작 시간',
    `ended_at` DATETIME NOT NULL COMMENT '세트 종료 시간',
    
    CONSTRAINT `fk_set_session_id`
        FOREIGN KEY (`session_id`) REFERENCES `workout_sessions` (`session_id`)
        ON DELETE CASCADE
);

-- 3. Workout Calibrations (해당 세션 진행 시 측정된 캘리브레이션 기준값)
CREATE TABLE `workout_calibrations` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `session_id` VARCHAR(100) NOT NULL,
    
    `ch1_mvc` DECIMAL(8,2) COMMENT '채널 1 MVC 값',
    `ch2_mvc` DECIMAL(8,2) COMMENT '채널 2 MVC 값',
    `ch3_mvc` DECIMAL(8,2) COMMENT '채널 3 MVC 값',
    
    `measured_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '측정 시간',
    
    CONSTRAINT `fk_calib_session_id`
        FOREIGN KEY (`session_id`) REFERENCES `workout_sessions` (`session_id`)
        ON DELETE CASCADE
);

-- 4. Workout Muscle Maps (해당 세션의 부위별 활성도, 히트맵/아바타 표시용)
-- JSON의 "muscle_map": {"chest": 68.0, "left_shoulder": 42.0} 구조를 여러 Row로 풀어서 저장
CREATE TABLE `workout_muscle_maps` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `session_id` VARCHAR(100) NOT NULL,
    
    `body_part` VARCHAR(50) NOT NULL COMMENT '운동 부위 (chest, left_shoulder, left_triceps 등)',
    `activation_value` DECIMAL(6,2) NOT NULL COMMENT '활성도 값 (0~100)',
    
    CONSTRAINT `fk_muscle_session_id`
        FOREIGN KEY (`session_id`) REFERENCES `workout_sessions` (`session_id`)
        ON DELETE CASCADE
);

-- 5. Workout Balance Summaries (좌우 밸런스 요약값, 선택)
CREATE TABLE `workout_balance_summaries` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `session_id` VARCHAR(100) NOT NULL UNIQUE,
    
    `enabled` BOOLEAN NOT NULL DEFAULT FALSE COMMENT '밸런스 평가 가능 여부 (양측 센서 정상 장착 여부)',
    `reason` VARCHAR(100) COMMENT '평가 불가 사유 (no_left_right_pairing 등)',
    
    `left_value` DECIMAL(6,2) COMMENT '좌측 활성도',
    `right_value` DECIMAL(6,2) COMMENT '우측 활성도',
    `diff_value` DECIMAL(6,2) COMMENT '좌우 편차',
    `balance_label` VARCHAR(50) COMMENT '밸런스 평가 라벨 (balanced, mild_imbalance 등)',
    
    CONSTRAINT `fk_balance_session_id`
        FOREIGN KEY (`session_id`) REFERENCES `workout_sessions` (`session_id`)
        ON DELETE CASCADE
);

-- ==== 조회 성능 최적화를 위한 인덱스 ====
CREATE INDEX `idx_sessions_user_id` ON `workout_sessions` (`user_id`);
CREATE INDEX `idx_sessions_exercise_type` ON `workout_sessions` (`exercise_type`);
CREATE INDEX `idx_sessions_started_at` ON `workout_sessions` (`started_at`);
