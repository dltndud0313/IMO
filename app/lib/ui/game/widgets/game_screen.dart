import 'dart:ui' show FontFeature;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../view_model/game_viewmodel.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '게임하기',
      showBackButton: true,
      onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      scrollable: true,
      body: Consumer<GameViewModel>(
        builder: (context, viewModel, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroSection(viewModel: viewModel),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 980;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 320,
                          child: _Sidebar(viewModel: viewModel),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(child: _BoardPanel(viewModel: viewModel)),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Sidebar(viewModel: viewModel),
                      const SizedBox(height: AppSpacing.lg),
                      _BoardPanel(viewModel: viewModel),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.viewModel,
  });

  final GameViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.hero,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Glass Game Prototype',
            style: AppTextStyles.caption.copyWith(
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('IMU Brick Breaker', style: AppTextStyles.display),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '양팔 IMU로 왼쪽, 가운데, 오른쪽 패들을 활성화하는 3분할 브릭 브레이커입니다. '
            '시작 전에는 안정 자세를 자동 baseline으로 측정하고, 양팔을 동시에 들면 공이 발사됩니다.',
            style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              ImoChip(
                label: viewModel.connectionLabel,
                variant: viewModel.isConnected
                    ? ImoChipVariant.success
                    : ImoChipVariant.warning,
                icon: Icon(
                  viewModel.isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                ),
              ),
              ImoChip(
                label: 'phase ${viewModel.phaseLabel}',
                variant: ImoChipVariant.outline,
              ),
              ImoChip(
                label: 'control ${viewModel.controlLabel}',
                variant: ImoChipVariant.outline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.viewModel,
  });

  final GameViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricCard(
          label: 'Connection',
          value: viewModel.connectionLabel,
          note: viewModel.frameStatus,
          emphasizeMetric: false,
        ),
        const SizedBox(height: AppSpacing.md),
        _MetricCard(
          label: 'Level / Score',
          value: '${viewModel.displayLevel}',
          note: 'score ${viewModel.score}\nlives ${viewModel.lives}',
        ),
        const SizedBox(height: AppSpacing.md),
        _MetricCard(
          label: 'Gesture State',
          value: viewModel.gestureLabel,
          note: viewModel.gestureNote,
          emphasizeMetric: false,
        ),
        const SizedBox(height: AppSpacing.md),
        _StatusCard(
          message: viewModel.statusMessage,
          tone: viewModel.statusTone,
        ),
        const SizedBox(height: AppSpacing.md),
        ImoCard(
          paddingSize: ImoCardPadding.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Live IMU Input', style: AppTextStyles.label),
              const SizedBox(height: AppSpacing.md),
              _SignalRow(label: '왼팔', value: viewModel.leftScore),
              const SizedBox(height: AppSpacing.sm),
              _SignalRow(label: '오른팔', value: viewModel.rightScore),
              const SizedBox(height: AppSpacing.sm),
              _SignalRow(label: '몸통', value: viewModel.torsoScore),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ImoCard(
          paddingSize: ImoCardPadding.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Control Rule', style: AppTextStyles.label),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '시작 자세 2초 유지: baseline 캘리브레이션\n'
                '왼팔 들기: 왼쪽 패들 활성화\n'
                '오른팔 들기: 오른쪽 패들 활성화\n'
                '양팔 들기: 가운데 패들 활성화 / 시작 제스처\n'
                '몸통 흔들림이 크면 양팔 시작 제스처는 무효 처리',
                style: AppTextStyles.bodySmall,
              ),
            ],
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
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F212C),
            Color(0xFF071118),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.heroCardRadius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.heatmapBg.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: AspectRatio(
        aspectRatio: GameViewModel.boardWidth / GameViewModel.boardHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _GameBoardPainter(viewModel.board),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          _BoardChip(label: 'phase ${viewModel.phaseLabel}'),
                          _BoardChip(label: 'control ${viewModel.controlLabel}'),
                          _BoardChip(label: 'ball ${viewModel.ballLabel}'),
                        ],
                      ),
                      const Spacer(),
                      if (viewModel.showOverlay) _OverlayNotice(viewModel: viewModel),
                      const Spacer(),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        alignment: WrapAlignment.spaceBetween,
                        children: const [
                          _BoardChip(label: 'IMU1 left arm'),
                          _BoardChip(label: 'IMU2 right arm'),
                          _BoardChip(label: 'IMU3 torso'),
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
    );
  }
}

class _OverlayNotice extends StatelessWidget {
  const _OverlayNotice({
    required this.viewModel,
  });

  final GameViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: const Color(0xCC071118),
            borderRadius: BorderRadius.circular(AppSpacing.heroCardRadius),
            border: Border.all(color: const Color(0x406DF2D6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                viewModel.overlayTitle,
                style: AppTextStyles.title.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                viewModel.overlayDescription,
                style: AppTextStyles.body.copyWith(color: const Color(0xFFB8D1CA)),
                textAlign: TextAlign.center,
              ),
              if (viewModel.overlayHint.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  viewModel.overlayHint,
                  style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFFD8FF7D)),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _CalibrationBanner(viewModel: viewModel),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalibrationBanner extends StatelessWidget {
  const _CalibrationBanner({
    required this.viewModel,
  });

  final GameViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: const Color(0x286DF2D6)),
      ),
      child: Column(
        children: [
          Text(
            'Calibration',
            style: AppTextStyles.caption.copyWith(
              color: const Color(0xFF9AC8BF),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            viewModel.calibrationStage,
            style: AppTextStyles.metric.copyWith(
              color: Colors.white,
              fontSize: 28,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            viewModel.calibrationDetail,
            style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFFB8D1CA)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0x33D8FF7D),
                  const Color(0x146DF2D6),
                  Colors.transparent,
                ],
                stops: const [0, 0.6, 1],
              ),
              border: Border.all(color: const Color(0x33D8FF7D)),
            ),
            alignment: Alignment.center,
            child: Text(
              viewModel.calibrationCount,
              style: AppTextStyles.metric.copyWith(
                color: const Color(0xFFD8FF7D),
                fontSize: 34,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.note,
    this.emphasizeMetric = true,
  });

  final String label;
  final String value;
  final String note;
  final bool emphasizeMetric;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: (emphasizeMetric ? AppTextStyles.metric : AppTextStyles.sectionTitle).copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(note, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.message,
    required this.tone,
  });

  final String message;
  final GameStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = switch (tone) {
      GameStatusTone.warning => (const Color(0xFFFFF3D9), const Color(0xFFB97509)),
      GameStatusTone.danger => (const Color(0xFFFFE3DE), const Color(0xFFB91C1C)),
      GameStatusTone.success => (const Color(0xFFE7F8EC), const Color(0xFF15803D)),
      GameStatusTone.normal => (const Color(0xFFE7F4FF), const Color(0xFF0F5D92)),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.$1,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Text(
        message,
        style: AppTextStyles.body.copyWith(
          color: palette.$2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTextStyles.body)),
        Text(
          value.toStringAsFixed(2),
          style: AppTextStyles.label.copyWith(
            color: AppColors.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
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
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
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
    final gridPaint = Paint()
      ..color = const Color(0x146DF2D6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double y = 60; y < snapshot.height; y += 54) {
      canvas.drawLine(
        Offset(28, y),
        Offset(snapshot.width - 28, y),
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
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, strokePaint);
    }
  }

  void _drawPaddle(Canvas canvas) {
    final paddle = snapshot.paddle;
    final baseRect = Rect.fromLTWH(paddle.x, paddle.y, paddle.width, paddle.height);
    final basePaint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final dividerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..strokeWidth = 3;
    final activePaint = Paint()..color = const Color(0xFFD8FF7D);
    final activeBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke;

    canvas.drawRect(baseRect, basePaint);
    canvas.drawRect(baseRect, borderPaint);

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
        canvas.drawRect(segmentRect, activePaint);
        canvas.drawRect(segmentRect, activeBorderPaint);
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
