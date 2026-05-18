import 'package:flutter_test/flutter_test.dart';
import 'package:imo/data/services/pi_message.dart';
import 'package:imo/domain/models/exercise_type.dart';

void main() {
  test('parses Pi session_result payload into WorkoutSession', () {
    final message = PiMessage.tryParse({
      'type': 'session_result',
      'payload': {
        'session_id': 'sess_20260427_001',
        'exercise_type': 'pushup',
        'status': 'completed',
        'end_reason': 'auto_completed',
        'started_at': '2026-04-27T09:28:00+09:00',
        'ended_at': '2026-04-27T09:35:12+09:00',
        'duration_sec': 432,
        'set_count': 3,
        'target_reps_per_set': [12, 12, 10],
        'actual_reps_per_set': [12, 12, 9],
        'rest_sec': 60,
        'total_reps': 33,
        'valid_reps': 31,
        // 스케일 계약(2026-05-18 통일): Pi payload 는 0~100 percent.
        'avg_target_muscle': 61.2,
        'avg_assist_muscle': 21.1,
        'avg_compensator': 17.7,
        'compensation_count': 4,
        'fatigue_onset_set': 3,
        'fatigue_onset_rep': 7,
        'comment': 'compensation increased in final set',
        'calibration_summary': {
          'ch1_mvc': 82.1,
          'ch2_mvc': 76.4,
          'ch3_mvc': 69.8,
        },
        'muscle_map': {
          'chest': 68.0,
          'left_shoulder': 42.0,
          'right_shoulder': 39.0,
          'left_triceps': 54.0,
          'right_triceps': 52.0,
        },
        'balance_summary': {
          'enabled': false,
          'reason': 'no_left_right_pairing',
        },
        'set_results': [
          {
            'set_index': 1,
            'target_reps': 12,
            'actual_reps': 12,
            'avg_speed': 'normal',
            'compensation_count': 1,
            'started_at': '2026-04-27T09:28:20+09:00',
            'ended_at': '2026-04-27T09:29:10+09:00',
          },
        ],
      },
    });

    expect(message, isA<SessionResultMessage>());

    final session = (message as SessionResultMessage).session;
    expect(session.sessionId, 'sess_20260427_001');
    expect(session.exerciseType, ExerciseType.pushUp);
    expect(session.status, 'completed');
    expect(session.totalReps, 33);
    expect(session.setResults, hasLength(1));
    expect(session.muscleMap?.values['chest'], 68.0);
    expect(session.balanceSummary?.enabled, isFalse);
  });

  test('keeps non-pushup muscle_map keys in domain model', () {
    final message = PiMessage.tryParse({
      'type': 'session_result',
      'payload': {
        'session_id': 'sess_bicep_001',
        'exercise_type': 'bicep_curl',
        'status': 'completed',
        'end_reason': 'auto_completed',
        'started_at': '2026-04-27T09:28:00+09:00',
        'ended_at': '2026-04-27T09:35:12+09:00',
        'duration_sec': 240,
        'set_count': 2,
        'target_reps_per_set': [10, 10],
        'actual_reps_per_set': [10, 9],
        'rest_sec': 60,
        'total_reps': 19,
        'valid_reps': 18,
        'avg_target_muscle': 70.0,
        'avg_assist_muscle': 20.0,
        'avg_compensator': 10.0,
        'compensation_count': 2,
        'muscle_map': {
          'left_biceps': 72.0,
          'right_biceps': 68.0,
          'left_forearm': 44.0,
          'right_forearm': 41.0,
        },
        'set_results': [],
      },
    });

    expect(message, isA<SessionResultMessage>());

    final session = (message as SessionResultMessage).session;
    expect(session.exerciseType, ExerciseType.bicepCurl);
    expect(session.muscleMap?.values['left_biceps'], 72.0);
    expect(session.muscleMap?.values['right_forearm'], 41.0);
  });
}
