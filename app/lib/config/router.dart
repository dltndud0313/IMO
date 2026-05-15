import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/repositories/auth_repository.dart';
import '../domain/models/workout_session.dart';
import '../ui/core/layouts/bottom_nav_shell.dart';
import '../ui/auth/screens/login_screen.dart';
import '../ui/auth/screens/profile_setup_screen.dart';
import '../ui/auth/screens/signup_screen.dart';
import '../ui/chat/view_model/chat_viewmodel.dart';
import '../ui/chat/widgets/chat_screen.dart';
import '../ui/history/widgets/history_screen.dart';
import '../ui/history/widgets/history_detail_screen.dart';
import '../ui/home/view_model/home_viewmodel.dart';
import '../ui/home/widgets/home_screen.dart';
import '../ui/mypage/widgets/mypage_screen.dart';
import '../ui/mypage/widgets/profile_edit_screen.dart';
import '../ui/mypage/widgets/wearable_settings_screen.dart';
import '../ui/onboarding/screens/onboarding_screen.dart';
import '../ui/onboarding/screens/splash_screen.dart';
import '../ui/session_result/widgets/session_result_screen.dart';
import '../ui/smartglass_display/widgets/smartglass_display_screen.dart';
import '../ui/stats/widgets/stats_screen.dart';
import '../ui/workout_setup/widgets/exercise_catalog_screen.dart';
import '../ui/workout_setup/widgets/exercise_guide_screen.dart';
import '../ui/workout_setup/widgets/exercise_select_screen.dart';
import '../ui/workout_setup/widgets/plan_setting_screen.dart';
import '../ui/workout_setup/widgets/calibration_screen_app_version.dart';
import '../ui/workout_setup/widgets/sensor_guide_screen.dart';
import 'dependencies.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() {
  final initialLocation =
      getIt<AuthRepository>().currentStatus == AuthStatus.authenticated
      ? '/home'
      : '/splash';

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) {
          final extra = state.extra;
          String? email;
          String? password;
          if (extra is Map) {
            email = extra['email'] as String?;
            password = extra['password'] as String?;
          }
          return ProfileSetupScreen(email: email, password: password);
        },
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => BottomNavShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => ChangeNotifierProvider(
              create: (_) => getIt<HomeViewModel>()..loadProfile(),
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
        path: '/workout-exercises',
        builder: (context, state) => ExerciseCatalogScreen(
          categoryId: state.uri.queryParameters['category'] ?? 'upper',
        ),
      ),
      GoRoute(
        path: '/workout-guide',
        builder: (context, state) => ExerciseGuideScreen(
          exerciseId: state.uri.queryParameters['exercise'] ?? 'pushup',
          categoryId: state.uri.queryParameters['category'],
        ),
      ),
      GoRoute(
        path: '/workout-plan',
        builder: (context, state) => PlanSettingScreen(
          exerciseId: state.uri.queryParameters['exercise'] ?? 'pushup',
        ),
      ),
      GoRoute(
        path: '/sensor-guide',
        builder: (context, state) => SensorGuideScreen(
          exerciseId: state.uri.queryParameters['exercise'] ?? 'pushup',
        ),
      ),
      GoRoute(
        path: '/workout-calibration',
        builder: (context, state) => CalibrationScreenAppVersion(
          exerciseId: state.uri.queryParameters['exercise'] ?? 'pushup',
          autoStart: state.uri.queryParameters['autoStart'] == 'true',
        ),
      ),
      GoRoute(
        path: '/workout',
        builder: (context, state) => const SmartglassDisplayScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => ChangeNotifierProvider(
          create: (_) => getIt<ChatViewModel>()..loadHistory(),
          child: const ChatScreen(),
        ),
      ),
      GoRoute(
        path: '/session-result',
        builder: (context, state) => SessionResultScreen(
          sessionId: state.uri.queryParameters['sessionId'] ?? '',
          initialSession:
              state.extra is WorkoutSession ? state.extra as WorkoutSession : null,
        ),
      ),
      GoRoute(
        path: '/history-detail',
        builder: (context, state) => HistoryDetailScreen(
          date: state.uri.queryParameters['date'] ?? '',
        ),
      ),
      GoRoute(
        path: '/profile-edit',
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/wearable-settings',
        builder: (context, state) => const WearableSettingsScreen(),
      ),
    ],
  );
}
