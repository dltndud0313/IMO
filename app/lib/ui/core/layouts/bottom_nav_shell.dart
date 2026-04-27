import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BottomNavShell extends StatelessWidget {
  const BottomNavShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _NavTab(label: 'Home', icon: Icons.home_outlined, path: '/home'),
    _NavTab(label: 'History', icon: Icons.history, path: '/history'),
    _NavTab(label: 'Stats', icon: Icons.bar_chart, path: '/stats'),
    _NavTab(label: 'My', icon: Icons.person_outline, path: '/mypage'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _tabs.indexWhere((tab) => location.startsWith(tab.path));

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex < 0 ? 0 : currentIndex,
        onDestinationSelected: (index) => context.go(_tabs[index].path),
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              label: tab.label,
            ),
        ],
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
