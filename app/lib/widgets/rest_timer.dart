import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 세트 간 휴식 원형 카운트다운 타이머.
class RestTimer extends StatefulWidget {
  final int seconds;
  final VoidCallback onComplete;
  const RestTimer({
    super.key,
    required this.seconds,
    required this.onComplete,
  });

  @override
  State<RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<RestTimer> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _timer?.cancel();
        widget.onComplete();
      } else {
        setState(() => _remaining--);
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
    final progress = _remaining / widget.seconds;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '휴식 중',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: AppTheme.border,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.rehab),
                ),
              ),
              Text(
                '$_remaining',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.rehab,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () {
            _timer?.cancel();
            widget.onComplete();
          },
          child: const Text('건너뛰기'),
        ),
      ],
    );
  }
}
