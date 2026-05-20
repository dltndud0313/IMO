import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/themes/design_tokens.dart';
import '../view_model/game_viewmodel.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041017),
      body: SafeArea(
        child: Consumer<GameViewModel>(
          builder: (context, viewModel, _) {
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: viewModel.showPreparationScreen
                    ? _PreparationStage(
                        key: const ValueKey('game-preparation'),
                        viewModel: viewModel,
                      )
                    : _GameplayStage(
                        key: const ValueKey('game-play'),
                        viewModel: viewModel,
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PreparationStage extends StatelessWidget {
  const _PreparationStage({
    super.key,
    required this.viewModel,
  });

  final GameViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            children: [
              _GameTopBar(connectionLabel: viewModel.connectionLabel),
              const SizedBox(height: 18),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _PreparationHero(viewModel: viewModel)),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 320,
                            child: _PreparationSidePanel(viewModel: viewModel),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _PreparationHero(viewModel: viewModel)),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 250,
                            child: _PreparationSidePanel(viewModel: viewModel),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PreparationHero extends StatelessWidget {
  const _PreparationHero({
    required this.viewModel,
  });

  final GameViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCounting = viewModel.isPreparing;
        final compact = constraints.maxHeight < 560;
        final padding = compact ? 20.0 : 28.0;
        final titleSize = compact ? 40.0 : 52.0;
        final countdownSize = compact ? 156.0 : 200.0;
        final startBadgeWidth = compact ? 300.0 : 360.0;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x206DF2D6)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xCC112432),
                Color(0xCC08131B),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              children: [
                Text(
                  'IMU BRICK BREAKER',
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFF9EC8C1),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
                SizedBox(height: compact ? 10 : 16),
                Text(
                  viewModel.preparationTitle,
                  style: AppTextStyles.display.copyWith(
                    color: Colors.white,
                    fontSize: titleSize,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: compact ? 10 : 14),
                Text(
                  viewModel.preparationDescription,
                  style: AppTextStyles.bodyLg.copyWith(
                    color: const Color(0xFFBED4CF),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: isCounting
                      ? _CountdownBadge(
                          key: const ValueKey('countdown-badge'),
                          label: viewModel.preparationCountdown,
                          size: countdownSize,
                        )
                      : _StartReadyBadge(
                          key: const ValueKey('start-ready-badge'),
                          progress: viewModel.startHoldProgress,
                          width: startBadgeWidth,
                        ),
                ),
                const Spacer(),
                Text(
                  viewModel.liveInputHint,
                  style: AppTextStyles.body.copyWith(
                    color: const Color(0xFFD8FF7D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PreparationSidePanel extends StatelessWidget {
  const _PreparationSidePanel({
    required this.viewModel,
  });

  final GameViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GlassCard(
          title: 'Connection',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                viewModel.connectionLabel,
                style: AppTextStyles.sectionTitle.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                viewModel.connectionDetail,
                style: AppTextStyles.bodySmall.copyWith(
                  color: const Color(0xFFAAC3BE),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _GlassCard(
          title: 'Live IMU',
          child: Column(
            children: [
              _SignalMeter(label: '왼팔', value: viewModel.leftScore),
              const SizedBox(height: 12),
              _SignalMeter(label: '오른팔', value: viewModel.rightScore),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _GlassCard(
            title: 'Guide',
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                isConnectedText(viewModel),
                style: AppTextStyles.bodySmall.copyWith(
                  color: const Color(0xFFAAC3BE),
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String isConnectedText(GameViewModel viewModel) {
    if (viewModel.isPreparing) {
      return '15초 동안 기본 자세를 유지하세요.\n카운트다운이 끝나면 양팔 들기 제스처를 기다립니다.';
    }
    return '두 팔을 동시에 들어 올리면 즉시 게임이 시작됩니다.\n한쪽 팔만 들면 시작되지 않습니다.';
  }
}

class _GameplayStage extends StatelessWidget {
  const _GameplayStage({
    super.key,
    required this.viewModel,
  });

  final GameViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            children: [
              _GameTopBar(connectionLabel: viewModel.connectionLabel),
              const SizedBox(height: 14),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 290,
                            child: _HudPanel(viewModel: viewModel),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: _BoardPanel(viewModel: viewModel)),
                        ],
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 220,
                            child: _HudPanel(viewModel: viewModel),
                          ),
                          const SizedBox(height: 14),
                          Expanded(child: _BoardPanel(viewModel: viewModel)),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HudPanel extends StatelessWidget {
  const _HudPanel({
    required this.viewModel,
  });

  final GameViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GlassCard(
          title: 'Level / Score',
          child: Row(
            children: [
              Expanded(
                child: _MetricBlock(
                  label: 'LEVEL',
                  value: '${viewModel.displayLevel}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricBlock(
                  label: 'SCORE',
                  value: '${viewModel.score}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricBlock(
                  label: 'LIFE',
                  value: '${viewModel.lives}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _GlassCard(
          title: 'Live IMU',
          child: Column(
            children: [
              _SignalMeter(label: '왼팔', value: viewModel.leftScore),
              const SizedBox(height: 12),
              _SignalMeter(label: '오른팔', value: viewModel.rightScore),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _GlassCard(
            title: 'Guide',
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                viewModel.gameplayHint,
                style: AppTextStyles.body.copyWith(
                  color: const Color(0xFFBED4CF),
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BoardPanel extends StatelessWidget {
  const _BoardPanel({
    required this.viewModel,
  });

  final GameViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x206DF2D6)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0E1E28),
            Color(0xFF061018),
          ],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: AspectRatio(
          aspectRatio: GameViewModel.boardWidth / GameViewModel.boardHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _GameBoardPainter(viewModel.board),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _BoardChip(label: 'level ${viewModel.displayLevel}'),
                            const SizedBox(width: 8),
                            _BoardChip(label: 'score ${viewModel.score}'),
                            const Spacer(),
                            _BoardChip(label: 'life ${viewModel.lives}'),
                          ],
                        ),
                        const Spacer(),
                        if (viewModel.showBoardOverlay)
                          _BoardOverlay(
                            title: viewModel.boardOverlayTitle,
                            message: viewModel.boardOverlayMessage,
                            hint: viewModel.gameplayHint,
                          ),
                        const Spacer(),
                        Row(
                          children: const [
                            _BoardChip(label: 'left arm'),
                            SizedBox(width: 8),
                            _BoardChip(label: 'center both arms'),
                            SizedBox(width: 8),
                            _BoardChip(label: 'right arm'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameTopBar extends StatelessWidget {
  const _GameTopBar({
    required this.connectionLabel,
  });

  final String connectionLabel;

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
        _StatusPill(label: connectionLabel),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0x80101B23),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: const Color(0xFF8EB7B1),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.metric.copyWith(
              color: Colors.white,
              fontSize: 30,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalMeter extends StatelessWidget {
  const _SignalMeter({
    required this.label,
    required this.value,
  });

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
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6DF2D6)),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
  });

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

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

class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({
    super.key,
    required this.label,
    required this.size,
  });

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0x4DD8FF7D),
            Color(0x1F6DF2D6),
            Color(0x00041017),
          ],
          stops: [0, 0.58, 1],
        ),
        border: Border.all(color: const Color(0x66D8FF7D)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTextStyles.metric.copyWith(
          color: Colors.white,
          fontSize: 72,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StartReadyBadge extends StatelessWidget {
  const _StartReadyBadge({
    super.key,
    required this.progress,
    required this.width,
  });

  final double progress;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: const Color(0x336DF2D6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'START',
            style: AppTextStyles.metric.copyWith(
              color: const Color(0xFFD8FF7D),
              fontSize: 48,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '양팔을 동시에 들어 올리세요',
            style: AppTextStyles.body.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD8FF7D)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardOverlay extends StatelessWidget {
  const _BoardOverlay({
    required this.title,
    required this.message,
    required this.hint,
  });

  final String title;
  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: const Color(0xD9071118),
            border: Border.all(color: const Color(0x286DF2D6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTextStyles.title.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: AppTextStyles.body.copyWith(
                  color: const Color(0xFFBED4CF),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                hint,
                style: AppTextStyles.bodySmall.copyWith(
                  color: const Color(0xFFD8FF7D),
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardChip extends StatelessWidget {
  const _BoardChip({
    required this.label,
  });

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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

class _GameBoardPainter extends CustomPainter {
  const _GameBoardPainter(this.snapshot);

  final GameBoardSnapshot snapshot;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / snapshot.width, size.height / snapshot.height);
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
        colors: [
          Color(0xFF102331),
          Color(0xFF09141D),
          Color(0xFF040A10),
        ],
      ).createShader(Rect.fromLTWH(0, 0, snapshot.width, snapshot.height));
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
    final baseRect = Rect.fromLTWH(paddle.x, paddle.y, paddle.width, paddle.height);
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
    final ballPaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(snapshot.ball.x, snapshot.ball.y),
      snapshot.ball.radius,
      ballPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GameBoardPainter oldDelegate) {
    return oldDelegate.snapshot != snapshot;
  }
}
