import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';

class ExerciseCategoryOption {
  const ExerciseCategoryOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;
}

class ExerciseCatalogItem {
  const ExerciseCatalogItem({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.titleEn,
    required this.target,
    required this.description,
    required this.levelLabel,
    required this.keywords,
    required this.icon,
    required this.gradient,
    this.enabled = true,
  });

  final String id;
  final String categoryId;
  final String title;
  final String titleEn;
  final String target;
  final String description;
  final String levelLabel;
  final List<String> keywords;
  final IconData icon;
  final List<Color> gradient;
  final bool enabled;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    return [
      id,
      title,
      titleEn,
      target,
      description,
      ...keywords,
    ].any((value) => value.toLowerCase().contains(normalized));
  }
}

const exerciseCategoryOptions = [
  ExerciseCategoryOption(
    id: 'upper',
    title: '상체',
    description: '가슴, 어깨, 팔 중심의 EMG/IMU 운동',
    icon: Icons.accessibility_new_rounded,
    gradient: [AppColors.primary, AppColors.primaryStrong],
  ),
  ExerciseCategoryOption(
    id: 'lower',
    title: '하체',
    description: '스쿼트, 런지 등 하체 운동 확장 예정',
    icon: Icons.directions_run_rounded,
    gradient: [AppColors.secondary, Color(0xFF5DC447)],
  ),
  ExerciseCategoryOption(
    id: 'full_body',
    title: '전신',
    description: '전신 협응과 복합 움직임 운동 확장 예정',
    icon: Icons.self_improvement_rounded,
    gradient: [Color(0xFFFFB371), AppColors.warning],
  ),
];

const exerciseCatalogItems = [
  ExerciseCatalogItem(
    id: 'pushup',
    categoryId: 'upper',
    title: '푸시업',
    titleEn: 'Push-up',
    target: '가슴 · 삼두 · 어깨',
    description: '상체 전반을 강화하는 기본 운동',
    levelLabel: '초급',
    keywords: ['팔굽혀펴기', '가슴', '삼두근', '대흉근', '어깨'],
    icon: Icons.fitness_center_rounded,
    gradient: [AppColors.primary, AppColors.primaryStrong],
  ),
  ExerciseCatalogItem(
    id: 'lateral_raise',
    categoryId: 'upper',
    title: '사이드 레터럴 레이즈',
    titleEn: 'Lateral Raise',
    target: '어깨 · 측면 삼각근',
    description: '어깨 측면을 집중적으로 쓰는 운동',
    levelLabel: '초급',
    keywords: ['싸레레', '어깨', '측면삼각근', '승모근'],
    icon: Icons.accessibility_new_rounded,
    gradient: [AppColors.secondary, Color(0xFF5DC447)],
  ),
  ExerciseCatalogItem(
    id: 'bicep_curl',
    categoryId: 'upper',
    title: '바이셉 컬',
    titleEn: 'Bicep Curl',
    target: '이두근 · 전완근',
    description: '팔꿈치 축을 유지하며 이두근을 쓰는 운동',
    levelLabel: '초급',
    keywords: ['이두컬', '이두근', '전완근', '팔'],
    icon: Icons.sports_gymnastics_rounded,
    gradient: [Color(0xFFFFB371), AppColors.warning],
  ),
];

ExerciseCategoryOption exerciseCategoryById(String categoryId) {
  return exerciseCategoryOptions.firstWhere(
    (category) => category.id == categoryId,
    orElse: () => exerciseCategoryOptions.first,
  );
}

List<ExerciseCatalogItem> exercisesByCategory(String categoryId) {
  return exerciseCatalogItems
      .where((exercise) => exercise.categoryId == categoryId)
      .toList();
}

String categoryIdForExercise(String exerciseId) {
  return exerciseCatalogItems
      .firstWhere(
        (exercise) => exercise.id == exerciseId,
        orElse: () => exerciseCatalogItems.first,
      )
      .categoryId;
}
