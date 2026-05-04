import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';

const _brandBlue = Color(0xFF82BCF3);

class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.sheet,
    this.showCharacter = false,
    this.topFlex = 7,
    this.sheetPadding = const EdgeInsets.fromLTRB(24, 28, 24, 32),
  });

  final Widget sheet;
  final bool showCharacter;
  final int topFlex;
  final EdgeInsets sheetPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _brandBlue,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              flex: topFlex,
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _brandBlue,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (showCharacter) ...[
                      Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          color: AppColors.card.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.accessibility_new_rounded,
                          color: AppColors.card,
                          size: 58,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    Text(
                      'IMO',
                      style: AppTextStyles.display.copyWith(
                        color: AppColors.card,
                        fontSize: 56,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: sheetPadding,
              decoration: const BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: AppSpacing.xl),
                  sheet,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      ),
    );
  }
}
