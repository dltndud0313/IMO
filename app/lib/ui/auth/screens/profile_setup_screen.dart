import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/themes/design_tokens.dart';
import '../widgets/gender_selector.dart';
import '../widgets/profile_photo_picker_placeholder.dart';
import '../widgets/profile_unit_value_picker.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

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

  void _goNext() {
    if (!_canProceed) {
      return;
    }
    if (_step == _steps.length - 1) {
      context.go('/home');
      return;
    }
    setState(() => _step += 1);
  }

  void _goBack() {
    if (_step == 0) {
      context.go('/signup');
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
        centerTitle: true,
        title: Column(
          children: [
            Text(step.appBarTitle, style: AppTextStyles.sectionTitle),
            Text(
              '${_step + 1} / ${_steps.length}',
              style: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
            ),
          ],
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
            label: _step == _steps.length - 1 ? '완료' : '다음',
            enabled: _canProceed,
            onTap: _goNext,
          ),
        ),
      ),
      body: Padding(
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
            const SizedBox(height: AppSpacing.xs),
            Text(
              step.subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLg.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 42),
            Expanded(child: _buildStepBody()),
          ],
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
        return ProfileUnitValuePicker(
          value: '$_birthYear',
          unit: '년',
          onTap: () =>
              setState(() => _birthYear = _birthYear == 1995 ? 1996 : 1995),
        );
      case 3:
        return Column(
          children: [
            ProfileUnitValuePicker(
              value: '$_height',
              unit: 'cm',
              onTap: () => setState(() => _height = _height == 170 ? 171 : 170),
            ),
            const SizedBox(height: AppSpacing.md),
            ProfileUnitValuePicker(
              value: '$_weight',
              unit: 'kg',
              onTap: () => setState(() => _weight = _weight == 65 ? 66 : 65),
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
  const _ProfileSetupStep({
    required this.appBarTitle,
    required this.title,
    required this.subtitle,
  });

  final String appBarTitle;
  final String title;
  final String subtitle;
}

const _steps = [
  _ProfileSetupStep(
    appBarTitle: '닉네임 & 프로필',
    title: '닉네임과 프로필 사진',
    subtitle: '앱에서 사용할 정보예요',
  ),
  _ProfileSetupStep(
    appBarTitle: '성별 선택',
    title: '성별을 선택해주세요',
    subtitle: '정확한 분석에 사용돼요',
  ),
  _ProfileSetupStep(
    appBarTitle: '출생년도',
    title: '출생년도',
    subtitle: '입력란을 눌러 선택하세요',
  ),
  _ProfileSetupStep(
    appBarTitle: '키 & 몸무게',
    title: '키와 몸무게',
    subtitle: '입력란을 눌러 선택하세요',
  ),
];
