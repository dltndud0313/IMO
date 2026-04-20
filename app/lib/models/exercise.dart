import 'package:flutter/material.dart';

/// 운동/재활 모드
enum AppMode { workout, rehab }

/// 운동 종목에 매핑되는 EMG 채널 정보
class ChannelMapping {
  final String ch1Name; // CH1 근육 이름
  final String ch2Name; // CH2 근육 이름
  final String ch3Name; // CH3 근육 이름
  /// 아바타에서 색칠할 신체 부위 키
  /// (예: 'chest', 'upperArm', 'shoulder' 등)
  final String ch1Region;
  final String ch2Region;
  final String ch3Region;

  const ChannelMapping({
    required this.ch1Name,
    required this.ch2Name,
    required this.ch3Name,
    required this.ch1Region,
    required this.ch2Region,
    required this.ch3Region,
  });
}

/// 운동 종목 정보
class Exercise {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final ChannelMapping channels;

  /// 자세 가이드 단계별 설명
  final List<String> steps;

  /// 주의사항 목록
  final List<String> cautions;

  /// 타겟 근육 요약
  final String targetMuscle;

  const Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.channels,
    this.steps = const [],
    this.cautions = const [],
    this.targetMuscle = '',
  });
}
