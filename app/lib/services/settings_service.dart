import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 전역 설정 관리.
class SettingsService {
  static final SettingsService _instance = SettingsService._();
  SettingsService._();
  factory SettingsService() => _instance;

  static const _kTtsEnabled = 'setting_tts_enabled';
  static const _kHapticEnabled = 'setting_haptic_enabled';
  static const _kUnit = 'setting_unit'; // 'kg' or 'lb'
  static const _kWeeklyRepGoal = 'setting_weekly_rep_goal';
  static const _kWeeklySessionGoal = 'setting_weekly_session_goal';
  static const _kOnboardingIntroSeen = 'setting_intro_seen';
  static const _kThemeMode = 'setting_theme_mode'; // 'system' | 'light' | 'dark'

  // 메모리 캐시
  bool _ttsEnabled = true;
  bool _hapticEnabled = true;
  String _unit = 'kg';
  int _weeklyRepGoal = 100;
  int _weeklySessionGoal = 3;
  bool _introSeen = false;
  bool _loaded = false;

  /// 테마 모드 — MaterialApp이 구독해 바로 재빌드할 수 있도록 ValueNotifier.
  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  bool get ttsEnabled => _ttsEnabled;
  bool get hapticEnabled => _hapticEnabled;
  String get unit => _unit;
  int get weeklyRepGoal => _weeklyRepGoal;
  int get weeklySessionGoal => _weeklySessionGoal;
  bool get introSeen => _introSeen;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _ttsEnabled = prefs.getBool(_kTtsEnabled) ?? true;
    _hapticEnabled = prefs.getBool(_kHapticEnabled) ?? true;
    _unit = prefs.getString(_kUnit) ?? 'kg';
    _weeklyRepGoal = prefs.getInt(_kWeeklyRepGoal) ?? 100;
    _weeklySessionGoal = prefs.getInt(_kWeeklySessionGoal) ?? 3;
    _introSeen = prefs.getBool(_kOnboardingIntroSeen) ?? false;
    themeMode.value = _parseThemeMode(prefs.getString(_kThemeMode));
    _loaded = true;
  }

  ThemeMode _parseThemeMode(String? v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode.name);
  }

  Future<void> setTtsEnabled(bool v) async {
    _ttsEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTtsEnabled, v);
  }

  Future<void> setHapticEnabled(bool v) async {
    _hapticEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHapticEnabled, v);
  }

  Future<void> setUnit(String v) async {
    _unit = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUnit, v);
  }

  Future<void> setWeeklyRepGoal(int v) async {
    _weeklyRepGoal = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kWeeklyRepGoal, v);
  }

  Future<void> setWeeklySessionGoal(int v) async {
    _weeklySessionGoal = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kWeeklySessionGoal, v);
  }

  Future<void> setIntroSeen(bool v) async {
    _introSeen = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingIntroSeen, v);
  }
}
