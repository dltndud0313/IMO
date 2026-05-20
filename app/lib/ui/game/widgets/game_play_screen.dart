import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/themes/app_text_styles.dart';
import '../view_model/game_viewmodel.dart';

class GamePlayScreen extends StatefulWidget {
  const GamePlayScreen({super.key});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Start game after first frame so the landscape layout is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GameViewModel>().beginGameplay();
      }
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    context.read<GameViewModel>().returnToSetup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041017),
      body: SafeArea(
        child: Consumer<GameViewModel>(
          builder: (context, vm, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > constraints.maxHeight;

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
                  child: wide
                      ? _LandscapeLayout(vm: vm)
                      : _PortraitLayout(vm: vm),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─── Landscape layout ─────────────────────────────────────────────────────────

class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout({required this.vm});

  final GameViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 220, child: _HudPanel(vm: vm)),
          const SizedBox(width: 12),
          Expanded(child: _BoardPanel(vm: vm)),
        ],
      ),
    );
  }
}

// ─── Portrait fallback layout ─────────────────────────────────────────────────

class _PortraitLayout extends StatelessWidget {
  const _PortraitLayout({required this.vm});

  final GameViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          SizedBox(height: 120, child: _HudRow(vm: vm)),
          const SizedBox(height: 10),
          Expanded(child: _BoardPanel(vm: vm)),
        ],
      ),
    );
  }
}

// ─── HUD panel (landscape sidebar) ───────────────────────────────────────────

class _HudPanel extends StatelessWidget {
  const _HudPanel({required this.vm});

  final GameViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Back button
        Row(
          children: [
            _RoundIconButton(
              icon: Icons.chevron_left_rounded,
              onTap: () => context.pop(),
            ),
            const SizedBox(width: 8),
            Text(
              '게임하기',
              style: AppTextStyles.label.copyWith(color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _GlassCard(
          title: 'SCORE',
          child: Row(
            children: [
              Expanded(
                child: _MetricBlock(
                  label: 'LV',
                  value: '${vm.displayLevel}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBlock(
                  label: 'PTS',
                  value: '${vm.score}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricBlock(
                  label: '♥',
                  value: '${vm.lives}',
                  valueColor: const Color(0xFFFF7F7F),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _GlassCard(
          title: 'LIVE IMU',
          child: Column(
            children: [
              _SignalMeter(label: '왼팔', value: vm.leftScore),
              const SizedBox(height: 10),
              _SignalMeter(label: '오른팔', value: vm.rightScore),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _GlassCard(
            title: 'CONTROL',
            child: Text(
              '왼팔 → 좌측 패들\n오른팔 → 우측 패들\n양팔 → 가운데 패들\n\n공이 활성화된 패들\n세그먼트에 맞아야\n합니다.',
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFFAAC3BE),
                height: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── HUD row (portrait compact) ───────────────────────────────────────────────

class _HudRow extends StatelessWidget {
  const _HudRow({required this.vm});

  final GameViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RoundIconButton(
          icon: Icons.chevron_left_rounded,
          onTap: () => context.pop(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _GlassCard(
            title: 'SCORE',
            child: Row(
              children: [
                _MetricBlock(label: 'LV', value: '${vm.displayLevel}'),
                const SizedBox(width: 8),
                _MetricBlock(label: 'PTS', value: '${vm.score}'),
                const SizedBox(width: 8),
                _MetricBlock(
                  label: '♥',
                  value: '${vm.lives}',
                  valueColor: const Color(0xFFFF7F7F),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 160,
          child: _GlassCard(
            title: 'IMU',
            child: Column(
              children: [
                _SignalMeter(label: 'L', value: vm.leftScore),
                const SizedBox(height: 6),
                _SignalMeter(label: 'R', value: vm.rightScore),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Board panel ──────────────────────────────────────────────────────────────

class _BoardPanel extends StatelessWidget {
  const _BoardPanel({required this.vm});

  final GameViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x206DF2D6)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1E28), Color(0xFF061018)],
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Center(
        child: AspectRatio(
          aspectRatio: GameViewModel.boardWidth / GameViewModel.boardHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _GameBoardPainter(vm.board)),
                // Paddle labels at bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _BoardChip(label: '왼팔'),
                      SizedBox(width: 8),
                      _BoardChip(label: '양팔'),
                      SizedBox(width: 8),
                      _BoardChip(label: '오른팔'),
                    ],
                  ),
                ),
                // Overlay for non-running states
                if (vm.showBoardOverlay)
                  Positioned.fill(
                    child: _BoardOverlay(vm: vm),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Board overlay ────────────────────────────────────────────────────────────

class _BoardOverlay extends StatelessWidget {
  const _BoardOverlay({required this.vm});

  final GameViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xCC041017),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: const Color(0xD9071118),
            border: Border.all(color: const Color(0x386DF2D6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                vm.boardOverlayTitle,
                style: AppTextStyles.title.copyWith(
                  color: Colors.white,
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                vm.boardOverlayMessage,
                style: AppTextStyles.body.copyWith(
                  color: const Color(0xFFBED4CF),
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ),
              if (vm.isArmed || vm.isLevelReady || vm.isGameOver || vm.isVictory) ...[
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: vm.startHoldProgress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFD8FF7D),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CustomPainter ────────────────────────────────────────────────────────────

class _GameBoardPainter extends CustomPainter {
  const _GameBoardPainter(this.snapshot);

  final GameBoardSnapshot snapshot;

  @override
  void paint(Canvas canvas, Size size) {
    final scale =
        math.min(size.width / snapshot.width, size.height / snapshot.height);
    final dx = (size.width - snapshot.width * scale) / 2;
    final dy = (size.height - snapshot.height * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    _drawBackground(canvas);
    _drawBricks(canvas);
    _drawPaddle(canvas);
    _drawBall(canvas);

    canvas.restore();
  }

  void _drawBackground(Canvas canvas) {
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF102331), Color(0xFF09141D), Color(0xFF040A10)],
      ).createShader(
        Rect.fromLTWH(0, 0, snapshot.width, snapshot.height),
      );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, snapshot.width, snapshot.height),
      fillPaint,
    );

    final gridPaint = Paint()
      ..color = const Color(0x196DF2D6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double y = 54; y < snapshot.height; y += 42) {
      canvas.drawLine(
        Offset(18, y),
        Offset(snapshot.width - 18, y),
        gridPaint,
      );
    }
    for (double x = 36; x < snapshot.width; x += 84) {
      canvas.drawLine(
        Offset(x, 16),
        Offset(x, snapshot.height - 16),
        gridPaint,
      );
    }
  }

  void _drawBricks(Canvas canvas) {
    final fillPaint = Paint()..color = snapshot.brickColor;
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke;

    for (final brick in snapshot.bricks) {
      final rect = Rect.fromLTWH(brick.x, brick.y, brick.width, brick.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        fillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        strokePaint,
      );
    }
  }

  void _drawPaddle(Canvas canvas) {
    final paddle = snapshot.paddle;
    final baseRect =
        Rect.fromLTWH(paddle.x, paddle.y, paddle.width, paddle.height);
    final basePaint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final dividerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 2;
    final activePaint = Paint()..color = const Color(0xFFD8FF7D);

    canvas.drawRRect(
      RRect.fromRectAndRadius(baseRect, const Radius.circular(10)),
      basePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(baseRect, const Radius.circular(10)),
      borderPaint,
    );

    final segmentWidth = paddle.width / 3;
    for (var i = 0; i < 3; i++) {
      final segmentX = paddle.x + segmentWidth * i;
      final segmentRect = Rect.fromLTWH(
        segmentX,
        paddle.y,
        i == 2 ? paddle.x + paddle.width - segmentX : segmentWidth,
        paddle.height,
      );

      if (i == paddle.activeIndex) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(segmentRect, const Radius.circular(10)),
          activePaint,
        );
      }
      if (i > 0) {
        canvas.drawLine(
          Offset(segmentX, paddle.y),
          Offset(segmentX, paddle.y + paddle.height),
          dividerPaint,
        );
      }
    }
  }

  void _drawBall(Canvas canvas) {
    canvas.drawCircle(
      Offset(snapshot.ball.x, snapshot.ball.y),
      snapshot.ball.radius,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _GameBoardPainter oldDelegate) =>
      oldDelegate.snapshot != snapshot;
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
      padding: const EdgeInsets.all(14),
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
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: const Color(0xFF8EB7B1),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.metric.copyWith(
              color: valueColor ?? Colors.white,
              fontSize: 24,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
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
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
              ),
            ),
            Text(
              value.toStringAsFixed(2),
              style: AppTextStyles.caption.copyWith(
                color: const Color(0xFFD8FF7D),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF6DF2D6)),
          ),
        ),
      ],
    );
  }
}

class _BoardChip extends StatelessWidget {
  const _BoardChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white,
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
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
