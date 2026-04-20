import 'package:flutter/material.dart';

import '../../services/settings_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/ui/gradient_button.dart';

class IntroScreen extends StatefulWidget {
  /// 온보딩 완료 후 이동할 다음 화면을 반환하는 콜백
  final Future<Widget> Function() onDone;
  const IntroScreen({super.key, required this.onDone});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _ctrl = PageController();
  int _page = 0;

  static const _pages = [
    _IntroPageData(
      icon: Icons.fitness_center,
      title: 'Inside Muscle Out에\n오신 걸 환영해요',
      description:
          'EMG 센서로 근육의 움직임을 실시간으로 측정해\n당신의 운동을 더 똑똑하게 만들어 드려요.',
      gradient: AppGradients.primary,
      accent: Color(0xFF4DA8FF),
    ),
    _IntroPageData(
      icon: Icons.accessibility_new,
      title: '실시간 자세 분석',
      description:
          '운동 중 반복 수와 자세를 분석해\n보상동작이 감지되면 바로 알려드려요.',
      gradient: AppGradients.rehab,
      accent: Color(0xFF22D3A4),
    ),
    _IntroPageData(
      icon: Icons.insights,
      title: '개인화된 운동 리포트',
      description:
          '주간 운동 기록과 AI 코칭을 통해\n꾸준한 성장을 확인할 수 있어요.',
      gradient: AppGradients.action,
      accent: Color(0xFFFF6B35),
    ),
    _IntroPageData(
      icon: Icons.emoji_events,
      title: '목표를 세우고\n달성해봐요',
      description: '주간 목표를 설정하고\n꾸준히 운동하는 습관을 만들어보세요.',
      gradient: AppGradients.achievement,
      accent: Color(0xFFEC4899),
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await SettingsService().setIntroSeen(true);
    if (!mounted) return;
    final next = await widget.onDone();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => next,
        transitionsBuilder: (context, anim, secondaryAnim, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _next() {
    if (_page >= _pages.length - 1) {
      _finish();
    } else {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _pages[_page];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 페이지별 배경 글로우
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  current.accent.withValues(alpha: isDark ? 0.22 : 0.14),
                  theme.scaffoldBackgroundColor,
                ],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Skip
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.space8),
                    child: TextButton(
                      onPressed: _finish,
                      child: Text(
                        '건너뛰기',
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                // 페이지
                Expanded(
                  child: PageView.builder(
                    controller: _ctrl,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => _IntroPage(data: _pages[i]),
                  ),
                ),
                // 인디케이터
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: active ? current.gradient : null,
                        color: active
                            ? null
                            : (isDark
                                ? AppTheme.borderDark
                                : AppTheme.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppTokens.space24),
                // CTA
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.space20,
                    0,
                    AppTokens.space20,
                    AppTokens.space24,
                  ),
                  child: GradientButton(
                    label: _page >= _pages.length - 1 ? '시작하기' : '다음',
                    gradient: current.gradient,
                    icon: _page >= _pages.length - 1
                        ? Icons.arrow_forward_rounded
                        : null,
                    onPressed: _next,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroPageData {
  final IconData icon;
  final String title;
  final String description;
  final LinearGradient gradient;
  final Color accent;
  const _IntroPageData({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.accent,
  });
}

class _IntroPage extends StatelessWidget {
  final _IntroPageData data;
  const _IntroPage({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 그라데이션 아이콘 블롭
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: data.gradient,
              boxShadow: [
                BoxShadow(
                  color: data.accent.withValues(alpha: 0.4),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Icon(data.icon, size: 96, color: Colors.white),
          ),
          const SizedBox(height: AppTokens.space40),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.25,
            ),
          ),
          const SizedBox(height: AppTokens.space16),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
