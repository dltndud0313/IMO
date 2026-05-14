class SmartglassMockLiveMessages {
  const SmartglassMockLiveMessages._();

  static List<Map<String, dynamic>> buildSequence() {
    return const [
      {
        'type': 'connection_status',
        'payload': {
          'pi_connected': true,
          'esp32_connected': true,
          'glass_connected': true,
        },
      },
      {
        'type': 'plan_ack',
        'payload': {
          'accepted': true,
          'exercise_type': 'Push-up',
          'set_count': 3,
        },
      },
      {
        'type': 'smartglass_snapshot',
        'payload': {
          'connection_state': 'connected',
          'session_phase': 'sensor_attachment_pending',
          'workout_label': 'Push-up',
          'current_set': 0,
          'total_sets': 3,
          'rep_count': 0,
          'target_rep': 12,
          'pace_state': 'ready',
          'pose_state': 'ready',
          'activation_percent': 0,
          'activation_label': '측정 전',
          'rest_seconds': 0,
          'calibration_progress': 0,
          'sensor_placements': [
            '대흉근 좌/우 부착 확인',
            '삼두근 좌/우 부착 확인',
            '좌우 팔 IMU 방향 확인',
            '몸통 IMU 고정 확인',
          ],
          'status_highlights': [
            '센서 부착 진행 중',
            '앱에서 부착 완료 확인 필요',
          ],
          'source_label': 'Mock smartglass_snapshot',
          'session_message': '앱에서 센서 부착 완료를 누르면 캘리브레이션 시작 단계로 진입합니다.',
        },
      },
      {
        'type': 'smartglass_snapshot',
        'payload': {
          'connection_state': 'connected',
          'session_phase': 'calibration_ready',
          'workout_label': 'Push-up',
          'current_set': 0,
          'total_sets': 3,
          'rep_count': 0,
          'target_rep': 12,
          'pace_state': 'ready',
          'pose_state': 'ready',
          'activation_percent': 0,
          'activation_label': '측정 전',
          'rest_seconds': 0,
          'calibration_progress': 0,
          'sensor_placements': ['시작 자세 유지', '시선 정면 고정', '몸통 흔들림 최소화'],
          'status_highlights': ['센서 확인 완료', '캘리브레이션 시작 가능'],
          'source_label': 'Mock smartglass_snapshot',
          'session_message': '앱에서 시작 버튼을 누르면 Pi로 신호를 보내고 스마트글래스는 즉시 진행 화면으로 넘어갑니다.',
        },
      },
      {
        'type': 'calibration_status',
        'payload': {
          'status': 'started',
          'message': '기준값 수집 중',
          'progress': 0.35,
          'exercise_type': 'Push-up',
          'set_count': 3,
          'target_rep': 12,
        },
      },
      {
        'type': 'calibration_status',
        'payload': {
          'status': 'started',
          'message': '거의 완료되었습니다',
          'progress': 0.82,
          'exercise_type': 'Push-up',
          'set_count': 3,
          'target_rep': 12,
        },
      },
      {
        'type': 'calibration_status',
        'payload': {
          'status': 'success',
          'message': '캘리브레이션 완료',
          'progress': 1.0,
          'exercise_type': 'Push-up',
          'set_count': 3,
          'target_rep': 12,
        },
      },
      {
        'type': 'workout_started',
        'payload': {
          'exercise_type': 'Push-up',
          'set_count': 3,
          'target_rep': 12,
          'started_at': '2026-05-14T10:00:00Z',
        },
      },
      {
        'type': 'workout_event',
        'payload': {
          'event': 'stable',
          'exercise_type': 'Push-up',
          'phase': 'active',
          'current_set_index': 1,
          'current_rep': 4,
          'target_rep': 12,
          'details': {
            'total_sets': 3,
            'activation_percent': 63,
            'activation_label': '가슴-삼두 활성 양호',
            'status_highlights': ['속도 안정', '좌우 밸런스 양호'],
            'session_message': '현재 세트의 핵심 정보만 크게 노출하는 실시간 상태입니다.',
          },
        },
      },
      {
        'type': 'workout_event',
        'payload': {
          'event': 'speed_warning',
          'exercise_type': 'Push-up',
          'phase': 'active',
          'current_set_index': 1,
          'current_rep': 9,
          'target_rep': 12,
          'details': {
            'total_sets': 3,
            'activation_percent': 74,
            'activation_label': '수축 강도 높음',
            'warning_message': '속도 과다 주의',
            'detail_message': '반복 속도가 빨라지고 있어 반동이 섞이지 않는지 확인이 필요합니다.',
            'status_highlights': ['속도 경고', '마지막 3회 남음'],
          },
        },
      },
      {
        'type': 'rest_started',
        'payload': {
          'exercise_type': 'Push-up',
          'after_set_index': 1,
          'total_sets': 3,
          'rest_sec': 30,
        },
      },
      {
        'type': 'rest_finished',
        'payload': {
          'exercise_type': 'Push-up',
          'next_set_index': 2,
          'total_sets': 3,
          'target_rep': 12,
        },
      },
      {
        'type': 'workout_event',
        'payload': {
          'event': 'pose_imbalance',
          'exercise_type': 'Push-up',
          'phase': 'active',
          'current_set_index': 2,
          'current_rep': 5,
          'target_rep': 12,
          'details': {
            'total_sets': 3,
            'activation_percent': 58,
            'activation_label': '좌우 사용 편차 감지',
            'warning_message': '좌우 밸런스 교정 필요',
            'status_highlights': ['좌우 편차 감지', '폼 교정 우선'],
          },
        },
      },
      {
        'type': 'workout_completed',
        'payload': {
          'exercise_type': 'Push-up',
          'set_count': 3,
          'total_reps': 36,
          'total_target_reps': 36,
          'avg_activation_percent': 66,
          'activation_label': '세션 평균 양호',
          'status': 'completed',
          'message': '모든 세트가 완료되었습니다.',
        },
      },
    ];
  }
}
