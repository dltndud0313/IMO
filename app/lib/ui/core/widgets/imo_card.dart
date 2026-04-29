import 'package:flutter/material.dart';

import '../themes/design_tokens.dart';

enum ImoCardVariant { defaultCard, subtle, hero, outlined }

enum ImoCardPadding { none, sm, md, lg }

class ImoCard extends StatelessWidget {
  const ImoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.variant = ImoCardVariant.defaultCard,
    this.paddingSize,
    this.interactive = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final ImoCardVariant variant;
  final ImoCardPadding? paddingSize;
  final bool interactive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = variant == ImoCardVariant.hero
        ? AppSpacing.heroCardRadius
        : AppSpacing.cardRadius;
    final content = Padding(
      padding: paddingSize == null ? padding : _resolvePadding(paddingSize!),
      child: child,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: _decoration(radius),
        child: Material(
          color: Colors.transparent,
          child: interactive || onTap != null
              ? InkWell(onTap: onTap, child: content)
              : content,
        ),
      ),
    );
  }

  EdgeInsets _resolvePadding(ImoCardPadding paddingSize) {
    switch (paddingSize) {
      case ImoCardPadding.none:
        return EdgeInsets.zero;
      case ImoCardPadding.sm:
        return const EdgeInsets.all(AppSpacing.sm);
      case ImoCardPadding.md:
        return const EdgeInsets.all(AppSpacing.cardPadding);
      case ImoCardPadding.lg:
        return const EdgeInsets.all(AppSpacing.largeCardPadding);
    }
  }

  BoxDecoration _decoration(double radius) {
    switch (variant) {
      case ImoCardVariant.defaultCard:
        return BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.heatmapBg.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        );
      case ImoCardVariant.subtle:
        return BoxDecoration(
          color: AppColors.cardSubtle,
          borderRadius: BorderRadius.circular(radius),
        );
      case ImoCardVariant.hero:
        return BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.heatmapBg.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        );
      case ImoCardVariant.outlined:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: AppColors.border),
        );
    }
  }
}
