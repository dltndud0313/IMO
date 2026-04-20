import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';

/// Shimmer 로딩 플레이스홀더.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppTokens.radiusSm,
    this.shape = BoxShape.rectangle,
  });

  const Skeleton.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = 0,
        shape = BoxShape.circle;

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppTheme.cardElevatedDark : const Color(0xFFEDEEF2);
    final hl = isDark ? AppTheme.borderDark : Colors.white;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final dx = _ctrl.value * 2 - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.rectangle
                ? BorderRadius.circular(widget.radius)
                : null,
            gradient: LinearGradient(
              begin: Alignment(-1 + dx * 2, 0),
              end: Alignment(1 + dx * 2, 0),
              colors: [base, hl, base],
              stops: const [0.3, 0.5, 0.7],
            ),
          ),
        );
      },
    );
  }
}

/// 카드 형태 스켈레톤 (홈 대시보드용).
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 120});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      height: height,
      radius: AppTokens.radiusMd,
    );
  }
}
