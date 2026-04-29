import 'dart:ui';

import 'package:flutter/material.dart';

import '../themes/design_tokens.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.child,
    this.body,
    this.heroSlot,
    this.showBackButton = false,
    this.onBack,
    this.actions,
    this.bottom,
    this.scrollable = false,
    this.horizontalPadding = true,
    this.safeArea = true,
    this.bottomNavigationBar,
    this.background,
    this.floatingActionButton,
  }) : assert(child != null || body != null, 'child or body is required');

  final String? title;
  final String? subtitle;
  final Widget? child;
  final Widget? body;
  final Widget? heroSlot;
  final bool showBackButton;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Widget? bottom;
  final bool scrollable;
  final bool horizontalPadding;
  final bool safeArea;
  final Widget? bottomNavigationBar;
  final Color? background;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final horizontalInset =
        horizontalPadding ? AppSpacing.screenHorizontal : 0.0;
    final effectiveBody = body ?? child!;
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: AppSpacing.md,
      ),
      child: effectiveBody,
    );
    final bodyContent = scrollable
        ? SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: bottom != null || bottomNavigationBar != null
                  ? AppSpacing.xxl
                  : AppSpacing.md,
            ),
            child: content,
          )
        : content;

    return Scaffold(
      backgroundColor: background ?? AppColors.background,
      extendBody: true,
      appBar: _buildAppBar(context),
      body: safeArea ? SafeArea(top: false, child: bodyContent) : bodyContent,
      bottomNavigationBar: bottomNavigationBar ?? _buildBottom(),
      floatingActionButton: floatingActionButton,
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    final hasBar = title != null || subtitle != null || showBackButton || actions != null;
    if (!hasBar && heroSlot == null) {
      return null;
    }

    final height = (hasBar ? AppSpacing.appBarHeight : 0.0) +
        (heroSlot == null ? 0.0 : 56.0);

    return PreferredSize(
      preferredSize: Size.fromHeight(height),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.86),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.8),
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasBar) _buildToolbar(context),
                  if (heroSlot != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenHorizontal,
                        0,
                        AppSpacing.screenHorizontal,
                        AppSpacing.sm,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: heroSlot,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return SizedBox(
      height: AppSpacing.appBarHeight,
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: showBackButton
                ? IconButton(
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.chevron_left,
                      color: AppColors.textPrimary,
                    ),
                  )
                : null,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (title != null)
                  Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleSm,
                  ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            child: actions == null
                ? null
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: actions!,
                  ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottom() {
    if (bottom == null) {
      return null;
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
        ),
        child: bottom,
      ),
    );
  }
}
