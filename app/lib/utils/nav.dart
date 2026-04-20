import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/home_screen.dart';

/// 네비게이션 헬퍼.
/// 반복되는 Navigator 패턴을 통합.
class Nav {
  Nav._();

  /// 홈으로 이동 (스택 전체 교체).
  static void toHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  /// 로그인으로 이동 (스택 전체 교체).
  static void toLogin(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  /// 새 화면으로 push.
  static Future<T?> push<T>(BuildContext context, Widget screen) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  /// 현재 화면을 교체 (pushReplacement).
  static void replace(BuildContext context, Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}
