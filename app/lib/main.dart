import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:math' as math;

import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/intro_screen.dart';
import 'screens/onboarding/profile_setup_screen.dart';
import 'services/profile_storage.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 세로 고정
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  // 설정 로드
  await SettingsService().load();
  runApp(const ProviderScope(child: MuscleVisionApp()));
}

class MuscleVisionApp extends StatelessWidget {
  const MuscleVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SettingsService().themeMode,
      builder: (_, mode, _) => MaterialApp(
        title: 'Inside Muscle Out',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        home: const _Bootstrap(),
      ),
    );
  }
}

/// 스플래시 → 로그인 분기
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap>
    with TickerProviderStateMixin {
  final _storage = ProfileStorage();
  late final AnimationController _fadeCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _logoScale;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutBack),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _fadeCtrl.forward();
    _check();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    // 최소 1.5초 스플래시 표시
    final results = await Future.wait([
      _storage.isLoggedIn(),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);
    final loggedIn = results[0] as bool;

    // 첫 실행 시 기능 소개 슬라이드
    if (!SettingsService().introSeen) {
      _navigate(IntroScreen(onDone: _resolveNextAfterIntro));
      return;
    }
    await _resolveNext(loggedIn);
  }

  /// IntroScreen에서 호출 — 자체 Navigator로 다음 화면 push
  Future<Widget> _resolveNextAfterIntro() async {
    final loggedIn = await _storage.isLoggedIn();
    if (!loggedIn) return const LoginScreen();
    final onboarded = await _storage.hasOnboarded();
    return onboarded ? const HomeScreen() : const ProfileSetupScreen();
  }

  Future<void> _resolveNext(bool loggedIn) async {
    if (!loggedIn) {
      _navigate(const LoginScreen());
      return;
    }
    final onboarded = await _storage.hasOnboarded();
    _navigate(onboarded ? const HomeScreen() : const ProfileSetupScreen());
  }

  void _navigate(Widget screen) {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, anim, secondaryAnim, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 그라데이션 히어로 배경
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B0D10), Color(0xFF2A3470), Color(0xFF7B96E8)],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          // 맥박 링 (EMG 컨셉)
          Center(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, _) {
                return SizedBox(
                  width: 320,
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: List.generate(3, (i) {
                      final delay = i * 0.33;
                      final t = ((_pulseCtrl.value + delay) % 1.0);
                      final scale = 0.4 + t * 0.9;
                      final opacity = (1 - t).clamp(0.0, 1.0);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: opacity * 0.4),
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),
          // 로고 + 타이틀
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _logoScale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, Color(0xFFE8EEFF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        size: 56,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space24),
                    const Text(
                      'Inside Muscle Out',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space8),
                    Text(
                      'EMG 기반 스마트 운동 분석',
                      style: TextStyle(
                        fontSize: 14,
                        letterSpacing: 0.3,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 하단 웨이브폼 장식
          Positioned(
            left: 0,
            right: 0,
            bottom: 60,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, _) => CustomPaint(
                size: const Size(double.infinity, 40),
                painter: _WavePainter(t: _pulseCtrl.value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// EMG 컨셉 웨이브폼 — 스플래시 하단 장식.
class _WavePainter extends CustomPainter {
  _WavePainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final midY = size.height / 2;
    const steps = 80;
    for (int i = 0; i <= steps; i++) {
      final x = size.width * (i / steps);
      final phase = i / steps * math.pi * 4 + t * math.pi * 2;
      // EMG 유사 — 일부 구간에 스파이크
      final spike = (i % 20 == 0) ? math.sin(phase * 3) * 14 : 0.0;
      final y = midY + math.sin(phase) * 6 + spike;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.t != t;
}
