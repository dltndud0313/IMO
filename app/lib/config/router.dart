import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../ui/core/layouts/bottom_nav_shell.dart';
import '../ui/history/widgets/history_screen.dart';
import '../ui/home/view_model/home_viewmodel.dart';
import '../ui/home/widgets/home_screen.dart';
import '../ui/mypage/widgets/mypage_screen.dart';
import '../ui/onboarding/widgets/onboarding_screen.dart';
import '../ui/session_result/widgets/session_result_screen.dart';
import '../ui/stats/widgets/stats_screen.dart';
import '../ui/workout/widgets/workout_screen.dart';
import '../ui/workout_setup/widgets/exercise_select_screen.dart';
import 'dependencies.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => BottomNavShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => ChangeNotifierProvider(
              create: (_) => getIt<HomeViewModel>(),
              child: const HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/stats',
            builder: (context, state) => const StatsScreen(),
          ),
          GoRoute(
            path: '/mypage',
            builder: (context, state) => const MyPageScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/workout-setup',
        builder: (context, state) => const ExerciseSelectScreen(),
      ),
      GoRoute(
        path: '/workout',
        builder: (context, state) => const WorkoutScreen(),
      ),
      GoRoute(
        path: '/session-result',
        builder: (context, state) => const SessionResultScreen(),
      ),
    ],
  );
}
