import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../themes/design_tokens.dart';

class BottomNavShell extends StatelessWidget {
  const BottomNavShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _NavTab(label: '홈', icon: Icons.home_rounded, path: '/home'),
    _NavTab(label: '기록', icon: Icons.history_rounded, path: '/history'),
    _NavTab(label: '통계', icon: Icons.bar_chart_rounded, path: '/stats'),
    _NavTab(label: '마이', icon: Icons.person_rounded, path: '/mypage'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex =
        _tabs.indexWhere((tab) => location.startsWith(tab.path));

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: _BlurBottomNavigationBar(
        selectedIndex: currentIndex < 0 ? 0 : currentIndex,
        onDestinationSelected: (index) => context.go(_tabs[index].path),
        tabs: _tabs,
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.label,
    required this.icon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final String path;
}

class _BlurBottomNavigationBar extends StatelessWidget {
  const _BlurBottomNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.tabs,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<_NavTab> tabs;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: 0.76),
            border: Border(
              top: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: AppSpacing.bottomNavHeight,
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Expanded(
                      child: _BottomNavItem(
                        tab: tabs[i],
                        selected: i == selectedIndex,
                        onTap: () => onDestinationSelected(i),
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
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _NavTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryStrong : AppColors.textTertiary;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 48,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            ),
            child: Icon(tab.icon, size: 20, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            tab.label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
