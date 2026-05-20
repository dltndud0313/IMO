import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/themes/app_text_styles.dart';
import '../view_model/game_viewmodel.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register the navigation callback every time we (re)enter this screen.
    final viewModel = context.read<GameViewModel>();
    viewModel.setOnReadyToPlay(() {
      if (mounted) {
        context.push('/game/play', extra: viewModel);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041017),
      body: SafeArea(
        child: Consumer<GameViewModel>(
          builder: (context, vm, _) {
            return DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0A1A24),
                    Color(0xFF041017),
                    Color(0xFF02070B),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(vm: vm),
                    const SizedBox(height: 20),
                    Expanded(child: _CalibrationBody(vm: vm)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Top bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.vm});

  final GameViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIconButton(
          icon: Icons.chevron_left_rounded,
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '게임하기',
            style: AppTextStyles.title.copyWith(color: Colors.white),
          ),
        ),
        _StatusPill(
          label: vm.connectionLabel,
          connected: vm.isConnected && vm.esp32Connected,
        ),
      ],
    );
  }
}

// ─── Main body ────────────────────────────────────────────────────────────────

class _CalibrationBody extends StatelessWidget {
  const _CalibrationBody({required this.vm});

  final GameViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Center hero card ──────────────────────────────────────────────
        Expanded(
          flex: 3,
          child: _HeroCard(vm: vm),
        ),
        const SizedBox(height: 16),
        // ── Live IMU meters ───────────────────────────────────────────────
        _GlassCard(
          title: 'LIVE IMU',
          child: Row(
            children: [
              Expanded(
                child: _SignalMeter(label: '왼팔', value: vm.leftScore),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SignalMeter(label: '오른팔', value: vm.rightScore),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ── Guide card ────────────────────────────────────────────────────
        _GlassCard(
          title: 'GUIDE',
          child: Text(
            vm.isCalibrating
                ? '${GameViewModel.calibrationSeconds}초 동안 양팔을 편하게 내린 기본 자세를 유지하세요.\n카운트다운이 끝나면 기준점이 자동으로 설정됩니다.'
                : '왼팔은 왼쪽, 오른팔은 오른쪽, 양팔은 가운데 패들을 조종합니다.\n두 팔을 어깨 높이로 올리면 게임이 즉시 시작됩니다.',
            style: AppTextStyles.bodySmall
                .copyWith(color: const Color(0xFFAAC3BE), height: 1.55),
          ),
        ),
      ],
    );
  }
}

// ─── Hero card (countdown / armed) ───────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.vm});

  final GameViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x206DF2D6)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xCC112432), Color(0xCC08131B)],
        ),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'IMU BRICK BREAKER',
            style: AppTextStyles.caption.copyWith(
              color: const Color(0xFF9EC8C1),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            vm.isCalibrating ? '기준 자세 측정 중' : '게임 시작 준비 완료',
            style: AppTextStyles.title.copyWith(
              color: Colors.white,
              fontSize: 26,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            vm.isCalibrating
                ? '편안한 자세로 가만히 계세요'
                : '양팔을 들어 게임을 시작해주세요',
            style: AppTextStyles.body.copyWith(
              color: const Color(0xFFBED4CF),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: vm.isCalibrating
                ? _CountdownBadge(
                    key: const ValueKey('countdown'),
                    label: vm.calibrationCountdown,
                  )
                : _StartReadyBadge(
                    key: const ValueKey('start-ready'),
                    progress: vm.startHoldProgress,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Countdown badge ─────────────────────────────────────────────────────────

class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0x4DD8FF7D), Color(0x1F6DF2D6), Color(0x00041017)],
          stops: [0, 0.58, 1],
        ),
        border: Border.all(color: const Color(0x66D8FF7D)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTextStyles.metric.copyWith(
          color: Colors.white,
          fontSize: 68,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ─── Start-ready badge ────────────────────────────────────────────────────────

class _StartReadyBadge extends StatelessWidget {
  const _StartReadyBadge({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: const Color(0x556DF2D6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.fitness_center_rounded,
                color: Color(0xFFD8FF7D),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                '양팔을 동시에 들어 올리세요',
                style: AppTextStyles.label.copyWith(
                  color: const Color(0xFFD8FF7D),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFD8FF7D),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            progress < 0.01 ? '팔을 올리면 시작됩니다' : '잠시만 유지하세요...',
            style: AppTextStyles.caption.copyWith(
              color: const Color(0xFF9EC8C1),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0x80101B23),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTextStyles.caption.copyWith(
              color: const Color(0xFF9EC8C1),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SignalMeter extends StatelessWidget {
  const _SignalMeter({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final progress = (value / 1.2).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
            ),
            Text(
              value.toStringAsFixed(2),
              style: AppTextStyles.label.copyWith(
                color: const Color(0xFFD8FF7D),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF6DF2D6)),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.connected});

  final String label;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color =
        connected ? const Color(0xFF6DF2D6) : const Color(0xFFFFB347);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
