import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_tokens.dart';

/// 그라데이션 CTA 버튼 — Freeletics 스타일.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.gradient = AppGradients.primary,
    this.icon,
    this.height = 56,
    this.expanded = true,
    this.glow = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final LinearGradient gradient;
  final IconData? icon;
  final double height;
  final bool expanded;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final glowColor = gradient.colors.first;

    final content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled
            ? gradient
            : LinearGradient(
                colors: [
                  gradient.colors.first.withValues(alpha: 0.4),
                  gradient.colors.last.withValues(alpha: 0.4),
                ],
              ),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        boxShadow: enabled && glow ? AppTokens.shadowGlow(glowColor) : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                }
              : null,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          child: SizedBox(
            height: height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: content) : content;
  }
}
