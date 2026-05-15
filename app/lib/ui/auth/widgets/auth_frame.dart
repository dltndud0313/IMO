import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';

const _brandBlue = Color(0xFF82BCF3);

class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.sheet,
    this.showCharacter = false,
    this.characterImage,
    this.characterSize = 108,
    this.showBrandText = true,
    this.backgroundColor = _brandBlue,
    this.backgroundGradient,
    this.backgroundImage,
    this.topFlex = 7,
    this.topContentAlignment = Alignment.center,
    this.showDecorations = false,
    this.sheetPadding = const EdgeInsets.fromLTRB(24, 28, 24, 32),
  });

  final Widget sheet;
  final bool showCharacter;
  final String? characterImage;
  final double characterSize;
  final bool showBrandText;
  final Color backgroundColor;
  final Gradient? backgroundGradient;
  final ImageProvider? backgroundImage;
  final int topFlex;
  final Alignment topContentAlignment;
  final bool showDecorations;
  final EdgeInsets sheetPadding;

  @override
  Widget build(BuildContext context) {
    final hasGradient = backgroundGradient != null;
    final hasImage = backgroundImage != null;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: hasGradient || hasImage ? null : backgroundColor,
          gradient: backgroundGradient,
          image: hasImage
              ? DecorationImage(image: backgroundImage!, fit: BoxFit.cover)
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showDecorations) const _BackgroundDecorations(),
            SafeArea(
              top: false,
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            Expanded(
                              flex: topFlex,
                              child: Align(
                                alignment: topContentAlignment,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (showCharacter) ...[
                                        if (characterImage != null)
                                          Image.asset(
                                            characterImage!,
                                            width: characterSize,
                                            height: characterSize,
                                            fit: BoxFit.contain,
                                          )
                                        else
                                          Container(
                                            width: characterSize,
                                            height: characterSize,
                                            decoration: BoxDecoration(
                                              color: AppColors.card
                                                  .withValues(alpha: 0.18),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.accessibility_new_rounded,
                                              color: AppColors.card,
                                              size: characterSize * 0.54,
                                            ),
                                          ),
                                        if (showBrandText)
                                          const SizedBox(
                                              height: AppSpacing.xl),
                                      ],
                                      if (showBrandText)
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
                            ),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.fromLTRB(
                                sheetPadding.left,
                                sheetPadding.top,
                                sheetPadding.right,
                                sheetPadding.bottom +
                                    MediaQuery.paddingOf(context).bottom,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(28),
                                ),
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
                    ),
                  );
                },
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

class _BackgroundDecorations extends StatelessWidget {
  const _BackgroundDecorations();

  static const _color = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: const [
          Positioned(
            top: 90,
            left: 32,
            child: _DecorIcon(
              icon: Icons.fitness_center,
              size: 30,
              opacity: 0.55,
              rotation: -0.25,
            ),
          ),
          Positioned(
            top: 150,
            right: 38,
            child: _DecorIcon(
              icon: Icons.favorite,
              size: 24,
              opacity: 0.5,
            ),
          ),
          Positioned(
            top: 260,
            left: 22,
            child: _DecorIcon(
              icon: Icons.auto_awesome,
              size: 22,
              opacity: 0.55,
            ),
          ),
          Positioned(
            top: 310,
            right: 26,
            child: _DecorIcon(
              icon: Icons.bolt,
              size: 30,
              opacity: 0.55,
              rotation: 0.3,
            ),
          ),
          Positioned(
            top: 530,
            left: 28,
            child: _DecorIcon(
              icon: Icons.auto_awesome,
              size: 26,
              opacity: 0.55,
            ),
          ),
          Positioned(
            top: 600,
            right: 34,
            child: _DecorIcon(
              icon: Icons.fitness_center,
              size: 26,
              opacity: 0.5,
              rotation: 0.4,
            ),
          ),
          Positioned(
            top: 720,
            left: 40,
            child: _DecorIcon(
              icon: Icons.favorite,
              size: 20,
              opacity: 0.5,
            ),
          ),
          Positioned(
            top: 780,
            right: 30,
            child: _DecorIcon(
              icon: Icons.auto_awesome,
              size: 20,
              opacity: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorIcon extends StatelessWidget {
  const _DecorIcon({
    required this.icon,
    required this.size,
    required this.opacity,
    this.rotation = 0,
  });

  final IconData icon;
  final double size;
  final double opacity;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      size: size,
      color: _BackgroundDecorations._color.withValues(alpha: opacity),
    );
    if (rotation == 0) {
      return iconWidget;
    }
    return Transform.rotate(angle: rotation, child: iconWidget);
  }
}
