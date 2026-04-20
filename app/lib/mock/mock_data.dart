import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/realtime_state.dart';
import '../models/session_record.dart';
import '../theme/app_theme.dart';

class MockData {
  /// 운동 모드 종목 — 채널 매핑 포함
  static const List<Exercise> workoutExercises = [
    Exercise(
      id: 'pushup',
      name: '푸시업',
      description: '가슴/삼두 근력 운동',
      icon: Icons.accessibility_new,
      color: AppTheme.primary,
      targetMuscle: '대흉근, 삼두근, 전면삼각근',
      channels: ChannelMapping(
        ch1Name: '대흉근',
        ch2Name: '삼두근',
        ch3Name: '전면삼각근',
        ch1Region: 'torso',
        ch2Region: 'upperArm',
        ch3Region: 'shoulder',
      ),
      steps: [
        '손을 어깨 너비보다 약간 넓게 바닥에 짚고 플랭크 자세를 잡습니다.',
        '몸을 일직선으로 유지하며 팔꿈치를 뒤쪽 45도로 굽혀 내려갑니다.',
        '가슴이 바닥 근처까지 내려오면 2초간 멈춥니다.',
        '가슴 근육에 힘을 주며 시작 자세로 천천히 올라옵니다.',
      ],
      cautions: [
        '허리가 꺼지거나 엉덩이가 솟지 않도록 코어에 힘을 유지하세요.',
        '팔꿈치를 과도하게 벌리면 어깨에 부담이 갑니다.',
        '호흡: 내려갈 때 들이마시고 올라올 때 내쉬세요.',
      ],
    ),
    Exercise(
      id: 'curl',
      name: '이두컬',
      description: '이두근 근력 운동',
      icon: Icons.sports_martial_arts,
      color: AppTheme.primary,
      targetMuscle: '이두근, 전완근',
      channels: ChannelMapping(
        ch1Name: '이두근',
        ch2Name: '전완근',
        ch3Name: '삼각근',
        ch1Region: 'upperArm',
        ch2Region: 'forearm',
        ch3Region: 'shoulder',
      ),
      steps: [
        '어깨 너비로 서서 양손에 덤벨을 잡고 팔을 내립니다.',
        '팔꿈치는 몸통에 붙인 채 고정합니다.',
        '이두근에 힘을 주며 덤벨을 어깨 앞까지 들어 올립니다.',
        '최고점에서 1초 멈춘 뒤 천천히 시작 자세로 내립니다.',
      ],
      cautions: [
        '반동을 쓰지 말고 이두근의 수축으로만 움직이세요.',
        '팔꿈치가 앞으로 튀어나오지 않도록 주의하세요.',
        '무게가 너무 무거우면 허리를 쓰게 됩니다.',
      ],
    ),
    Exercise(
      id: 'lateral_raise',
      name: '사이드 레터럴 레이즈',
      description: '어깨(삼각근) 운동',
      icon: Icons.open_with,
      color: AppTheme.primary,
      targetMuscle: '측면삼각근, 승모근',
      channels: ChannelMapping(
        ch1Name: '측면삼각근',
        ch2Name: '승모근',
        ch3Name: '전면삼각근',
        ch1Region: 'shoulder',
        ch2Region: 'torso',
        ch3Region: 'shoulder',
      ),
      steps: [
        '어깨 너비로 서서 양손에 덤벨을 잡고 팔을 몸 옆으로 내립니다.',
        '팔꿈치를 살짝 굽힌 상태를 유지합니다.',
        '어깨 높이까지 양팔을 옆으로 천천히 들어 올립니다.',
        '2초 멈춘 뒤 중력에 저항하며 천천히 내립니다.',
      ],
      cautions: [
        '덤벨을 어깨보다 높이 들지 마세요. 승모근 개입이 커집니다.',
        '반동을 주지 말고 어깨 근육만 사용하세요.',
        '가벼운 무게로 정확한 자세를 먼저 익히세요.',
      ],
    ),
  ];

  /// 재활 모드 종목
  static const List<Exercise> rehabExercises = [
    Exercise(
      id: 'shoulder_rehab',
      name: '어깨 재활 운동',
      description: '어깨 통증 완화 스트레칭',
      icon: Icons.self_improvement,
      color: AppTheme.rehab,
      targetMuscle: '회전근개, 삼각근',
      channels: ChannelMapping(
        ch1Name: '삼각근',
        ch2Name: '승모근',
        ch3Name: '회전근개',
        ch1Region: 'shoulder',
        ch2Region: 'torso',
        ch3Region: 'shoulder',
      ),
      steps: [
        '바르게 서서 팔을 옆으로 자연스럽게 내립니다.',
        '팔을 천천히 앞으로 들어 올려 머리 위까지 올립니다.',
        '5초간 자세를 유지합니다.',
        '천천히 시작 자세로 내립니다.',
      ],
      cautions: [
        '통증이 있다면 즉시 중단하세요.',
        '반동 없이 천천히 움직이는 것이 중요합니다.',
        '호흡을 멈추지 말고 자연스럽게 유지하세요.',
      ],
    ),
  ];

  static List<Exercise> getExercises(AppMode mode) {
    switch (mode) {
      case AppMode.workout:
        return workoutExercises;
      case AppMode.rehab:
        return rehabExercises;
    }
  }

  static const RealtimeState sampleRealtime = RealtimeState(
    repCount: 7,
    speed: RepSpeed.normal,
    isCompensation: false,
    isFatigued: false,
    ch1: 72.3,
    ch2: 45.1,
    ch3: 30.8,
  );

  static const SessionResult sampleResult = SessionResult(
    totalReps: 15,
    compensationCount: 3,
    avgCh1: 68.2,
    avgCh2: 44.0,
    avgCh3: 29.5,
    comment: '오늘 운동 15회 중 3회 보상동작이 감지되었습니다. 다음엔 자세 정렬에 신경 써보세요.',
  );

  static List<SessionRecord> get sampleHistory => [
        SessionRecord(
          date: DateTime.now().subtract(const Duration(days: 0)),
          exerciseName: '푸시업',
          totalReps: 15,
          compensationCount: 3,
          avgCh1: 68.2,
          avgCh2: 44.0,
          avgCh3: 29.5,
          comment: '오늘 운동 15회 중 3회 보상동작이 감지되었습니다.',
        ),
        SessionRecord(
          date: DateTime.now().subtract(const Duration(days: 1)),
          exerciseName: '이두컬',
          totalReps: 20,
          compensationCount: 1,
          avgCh1: 75.0,
          avgCh2: 50.3,
          avgCh3: 22.1,
          comment: '좋은 자세로 운동했습니다.',
        ),
        SessionRecord(
          date: DateTime.now().subtract(const Duration(days: 3)),
          exerciseName: '사이드 레터럴 레이즈',
          totalReps: 12,
          compensationCount: 0,
          avgCh1: 60.5,
          avgCh2: 38.7,
          avgCh3: 41.2,
          comment: '보상동작 없이 완벽하게 수행했습니다!',
        ),
      ];
}
