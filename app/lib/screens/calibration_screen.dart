import 'dart:async';
import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../theme/app_theme.dart';
import 'remote_screen.dart';

class CalibrationScreen extends StatefulWidget {
  final Exercise exercise;
  const CalibrationScreen({super.key, required this.exercise});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  int _countdown = 3;
  Timer? _timer;
  bool _started = false;

  void _startCountdown() {
    setState(() => _started = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        // 캘리브레이션 완료 → 리모컨 화면으로
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RemoteScreen(exercise: widget.exercise),
          ),
        );
      } else {
        setState(() => _countdown--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.exercise.name} 준비')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              const Text(
                '센서 캘리브레이션',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                '편안한 자세로 가만히 서 있어주세요',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _started ? '$_countdown' : '준비',
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _started ? null : _startCountdown,
                child: Text(_started ? '측정 중...' : '캘리브레이션 시작'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
