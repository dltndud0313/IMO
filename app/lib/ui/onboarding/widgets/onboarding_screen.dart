import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentIndex = 0;

  bool get _isLastSlide => _currentIndex == _slides.length - 1;

  void _goNext() {
    if (_isLastSlide) {
      context.go('/home');
      return;
    }

    setState(() {
      _currentIndex += 1;
    });
  }

  void _skip() {
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.md,
            AppSpacing.screenHorizontal,
            AppSpacing.xl,
          ),
          child: Column(
            children: [
              _OnboardingHeader(
                showSkip: !_isLastSlide,
                onSkip: _skip,
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _OnboardingSlideView(
                    key: ValueKey(slide.title),
                    slide: slide,
                  ),
                ),
              ),
              _PageIndicator(
                length: _slides.length,
                currentIndex: _currentIndex,
              ),
              const SizedBox(height: AppSpacing.xl),
              ImoButton(
                label: _isLastSlide ? 'IMO 시작하기' : '다음',
                rightIcon: Icon(
                  _isLastSlide
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                ),
                onPressed: _goNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.showSkip,
    required this.onSkip,
  });

  final bool showSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.appBarHeight,
      child: Row(
        children: [
          Text(
            'IMO',
            style: AppTextStyles.title.copyWith(
              color: AppColors.primaryStrong,
            ),
          ),
          const Spacer(),
          if (showSkip)
            ImoButton(
              label: '건너뛰기',
              variant: ImoButtonVariant.ghost,
              size: ImoButtonSize.sm,
              fullWidth: false,
              onPressed: onSkip,
            ),
        ],
      ),
    );
  }
}

class _OnboardingSlideView extends StatelessWidget {
  const _OnboardingSlideView({
    super.key,
    required this.slide,
  });

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ImoCard(
          variant: ImoCardVariant.hero,
          paddingSize: ImoCardPadding.lg,
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.backgroundSoftGreen,
                borderRadius: BorderRadius.circular(AppSpacing.heroCardRadius),
              ),
              child: Center(
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.heroCardRadius),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.heatmapBg.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    slide.icon,
                    color: AppColors.primaryStrong,
                    size: 52,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.heroSectionGap),
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: AppTextStyles.display,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          slide.description,
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ],
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.length,
    required this.currentIndex,
  });

  final int length;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final isSelected = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: isSelected ? 22 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          ),
        );
      }),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

const _slides = [
  _OnboardingSlide(
    icon: Icons.sensors_rounded,
    title: '운동을 준비해요',
    description:
        '운동 전 웨어러블 센서를 연결하고 부착 상태를 확인합니다.',
  ),
  _OnboardingSlide(
    icon: Icons.fitness_center_rounded,
    title: '안내에 맞춰 운동해요',
    description:
        '설정한 목표에 맞춰 운동하고 IMO가 주요 상태 이벤트를 기록합니다.',
  ),
  _OnboardingSlide(
    icon: Icons.analytics_rounded,
    title: '결과를 확인해요',
    description:
        '운동 후 세션 요약, 근육 활성도, 변화 추이를 확인합니다.',
  ),
];
