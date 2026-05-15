import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/dependencies.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../../domain/models/user_profile.dart';
import '../../core/themes/design_tokens.dart';
import '../widgets/gender_selector.dart';
import '../widgets/profile_photo_picker_placeholder.dart';
import '../widgets/profile_unit_value_picker.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, this.email, this.password});

  final String? email;
  final String? password;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nicknameController = TextEditingController();
  int _step = 0;
  String? _gender;
  int _birthYear = 1995;
  int _height = 170;
  int _weight = 65;
  bool _photoSelected = false;
  bool _submitting = false;

  bool get _canProceed {
    return switch (_step) {
      0 => _nicknameController.text.trim().isNotEmpty,
      1 => _gender != null,
      _ => true,
    };
  }

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (!_canProceed || _submitting) {
      return;
    }
    if (_step == _steps.length - 1) {
      await _completeSignUp();
      return;
    }
    setState(() => _step += 1);
  }

  Future<void> _completeSignUp() async {
    final email = widget.email;
    final password = widget.password;
    if (email == null || password == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 정보가 없습니다. 처음부터 다시 시도해주세요.')),
      );
      context.go('/signup');
      return;
    }

    setState(() => _submitting = true);
    try {
      final nickname = _nicknameController.text.trim();
      await getIt<AuthRepository>().signUp(email, password, nickname);
      getIt<UserProfileRepository>().clearCache();
      await getIt<UserProfileRepository>().updateProfile(
        UserProfile(
          nickname: nickname,
          age: DateTime.now().year - _birthYear,
          gender: _genderCode,
          heightCm: _height.toDouble(),
          weightKg: _weight.toDouble(),
        ),
      );
      if (!mounted) {
        return;
      }
      context.go('/home');
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString().contains('Email already exists')
          ? '이미 가입된 이메일입니다.'
          : '가입에 실패했습니다.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String get _genderCode {
    return switch (_gender) {
      '남성' => 'MALE',
      '여성' => 'FEMALE',
      _ => 'OTHER',
    };
  }

  Future<void> _pickNumber({
    required String title,
    required int min,
    required int max,
    required int value,
    required ValueChanged<int> onSelected,
  }) async {
    final values = [for (var i = min; i <= max; i++) i];
    final initialIndex = values.indexOf(value).clamp(0, values.length - 1);
    final controller = FixedExtentScrollController(initialItem: initialIndex);
    var selectedIndex = initialIndex;

    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SizedBox(
                height: 360,
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Text(title, style: AppTextStyles.sectionTitle),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 52,
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.buttonRadius,
                              ),
                            ),
                          ),
                          ListWheelScrollView.useDelegate(
                            controller: controller,
                            itemExtent: 52,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setModalState(() => selectedIndex = index);
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: values.length,
                              builder: (context, index) {
                                final isSelected = index == selectedIndex;
                                return Center(
                                  child: Text(
                                    '${values[index]}',
                                    style: TextStyle(
                                      fontSize: isSelected ? 28 : 22,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.primaryStrong
                                          : AppColors.textTertiary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Material(
                        color: AppColors.primary,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.pillRadius),
                        child: InkWell(
                          onTap: () => Navigator.of(context)
                              .pop(values[selectedIndex]),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.pillRadius),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: Center(
                              child: Text(
                                '선택',
                                style: AppTextStyles.bodyLg.copyWith(
                                  color: AppColors.card,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      onSelected(result);
    }
  }

  void _goBack() {
    if (_step == 0) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/signup');
      }
      return;
    }
    setState(() => _step -= 1);
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: _goBack,
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
          AppSpacing.screenHorizontal,
          AppSpacing.lg,
        ),
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: SafeArea(
          top: false,
          child: _ProfileNextButton(
            label: _step == _steps.length - 1 ? '가입 완료' : '다음',
            enabled: _canProceed && !_submitting,
            onTap: _goNext,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.lg,
            AppSpacing.screenHorizontal,
            AppSpacing.lg,
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                child: LinearProgressIndicator(
                  value: (_step + 1) / _steps.length,
                  minHeight: 4,
                  backgroundColor: AppColors.divider,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 46),
              Text(
                step.title,
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 42),
              _buildStepBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case 0:
        return _NicknameStep(
          controller: _nicknameController,
          photoSelected: _photoSelected,
          onPhotoTap: () => setState(() => _photoSelected = true),
        );
      case 1:
        return GenderSelector(
          selected: _gender,
          onChanged: (value) => setState(() => _gender = value),
        );
      case 2:
        return Center(
          child: ProfileUnitValuePicker(
            value: '$_birthYear',
            unit: '년',
            onTap: () => _pickNumber(
              title: '출생년도',
              min: 1940,
              max: DateTime.now().year,
              value: _birthYear,
              onSelected: (value) => setState(() => _birthYear = value),
            ),
          ),
        );
      case 3:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileUnitValuePicker(
              value: '$_height',
              unit: 'cm',
              onTap: () => _pickNumber(
                title: '키',
                min: 120,
                max: 220,
                value: _height,
                onSelected: (value) => setState(() => _height = value),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ProfileUnitValuePicker(
              value: '$_weight',
              unit: 'kg',
              onTap: () => _pickNumber(
                title: '몸무게',
                min: 30,
                max: 180,
                value: _weight,
                onSelected: (value) => setState(() => _weight = value),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _NicknameStep extends StatelessWidget {
  const _NicknameStep({
    required this.controller,
    required this.photoSelected,
    required this.onPhotoTap,
  });

  final TextEditingController controller;
  final bool photoSelected;
  final VoidCallback onPhotoTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ProfilePhotoPickerPlaceholder(
          selected: photoSelected,
          onTap: onPhotoTap,
        ),
        const SizedBox(height: 38),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('닉네임', style: AppTextStyles.body),
        ),
        const SizedBox(height: AppSpacing.xs),
        _PillTextInput(controller: controller, hint: '운동 고수'),
      ],
    );
  }
}

class _PillTextInput extends StatelessWidget {
  const _PillTextInput({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlignVertical: TextAlignVertical.center,
      style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyLg.copyWith(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _ProfileNextButton extends StatelessWidget {
  const _ProfileNextButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? AppColors.primary
          : AppColors.primary.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        child: SizedBox(
          height: 58,
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.bodyLg.copyWith(
                color: AppColors.card,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSetupStep {
  const _ProfileSetupStep({required this.title});

  final String title;
}

const _steps = [
  _ProfileSetupStep(title: '닉네임과 프로필 사진'),
  _ProfileSetupStep(title: '성별을 선택해주세요'),
  _ProfileSetupStep(title: '출생년도'),
  _ProfileSetupStep(title: '키와 몸무게'),
];
