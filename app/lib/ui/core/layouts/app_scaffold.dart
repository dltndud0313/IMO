import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    this.verticalPadding = true,
    this.safeArea = true,
    this.bottomNavigationBar,
    this.background,
    this.floatingActionButton,
    this.nested = false,
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
  final bool verticalPadding;
  final bool safeArea;
  final Widget? bottomNavigationBar;
  final Color? background;
  final Widget? floatingActionButton;
  // When true, skips the inner Scaffold so this widget can live inside
  // BottomNavShell's Scaffold without nesting two Scaffolds.
  final bool nested;

  @override
  Widget build(BuildContext context) {
    final horizontalInset =
        horizontalPadding ? AppSpacing.screenHorizontal : 0.0;
    final verticalInset = verticalPadding ? AppSpacing.md : 0.0;
    final effectiveBody = body ?? child!;
    final effectiveContent = heroSlot == null
        ? effectiveBody
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heroSlot!,
              const SizedBox(height: AppSpacing.sectionGap),
              effectiveBody,
            ],
          );
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: verticalInset,
      ),
      child: effectiveContent,
    );
    final bodyContent = scrollable
        ? SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: bottom != null || bottomNavigationBar != null
                  ? AppSpacing.bottomNavHeight + AppSpacing.xl
                  : AppSpacing.bottomNavHeight + AppSpacing.xxl,
            ),
            child: content,
          )
        : content;

    final theme = Theme.of(context);

    if (nested) {
      return _buildNestedLayout(context, bodyContent, theme);
    }

    return Scaffold(
      backgroundColor: background ?? theme.scaffoldBackgroundColor,
      extendBody: true,
      appBar: _buildAppBar(context),
      body: safeArea ? SafeArea(top: false, child: bodyContent) : bodyContent,
      bottomNavigationBar: bottomNavigationBar ?? _buildBottom(),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildNestedLayout(
    BuildContext context,
    Widget bodyContent,
    ThemeData theme,
  ) {
    final hasBar =
        title != null || subtitle != null || showBackButton || actions != null;
    final safeBody =
        safeArea ? SafeArea(top: false, child: bodyContent) : bodyContent;

    return ColoredBox(
      color: background ?? theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasBar)
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.86),
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: AppSpacing.appBarHeight,
                      child: _buildToolbar(context),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(child: safeBody),
        ],
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    final hasBar = title != null || subtitle != null || showBackButton || actions != null;
    if (!hasBar) {
      return null;
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(AppSpacing.appBarHeight),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.86),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.8),
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: _buildToolbar(context),
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
                    onPressed: onBack ??
                        () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/home');
                          }
                        },
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

    return Builder(
      builder: (context) {
        final surface = Theme.of(context).colorScheme.surface;

        return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(
                color: AppColors.border.withValues(alpha: 0.7),
              ),
            ),
          ),
          child: SafeArea(
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
          ),
        ),
      ),
        );
      },
    );
  }
}
