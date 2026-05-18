import 'package:flutter_test/flutter_test.dart';
import 'package:imo/domain/models/muscle_map.dart';

void main() {
  test('resolves activation percent into display level', () {
    // 스케일 계약(2026-05-18 통일): 활성도 값은 0~100 percent.
    expect(resolveMuscleActivationLevel(0), MuscleActivationLevel.inactive);
    expect(resolveMuscleActivationLevel(20), MuscleActivationLevel.low);
    expect(resolveMuscleActivationLevel(50), MuscleActivationLevel.normal);
    expect(resolveMuscleActivationLevel(80), MuscleActivationLevel.high);
    expect(resolveMuscleActivationLevel(95), MuscleActivationLevel.danger);
  });

  test('maps pushup muscle key to Korean display name', () {
    final state = MuscleMapState.fromValues(
      exerciseId: 'pushup',
      values: const {'left_chest': 68.0},
      includeMissingKeys: false,
    );

    expect(state.entries, hasLength(1));
    expect(state.entries.first.key, 'left_chest');
    expect(state.entries.first.displayName, '왼쪽 대흉근');
    expect(state.entries.first.percentValue, 68);
  });

  test('keeps unknown key without throwing', () {
    final state = MuscleMapState.fromValues(
      exerciseId: 'pushup',
      values: const {'unknown_muscle': 42.0},
      includeMissingKeys: false,
    );

    expect(state.entries, hasLength(1));
    expect(state.entries.first.key, 'unknown_muscle');
    expect(state.entries.first.displayName, 'unknown_muscle');
    expect(state.entries.first.isKnownKey, isFalse);
    expect(state.entries.first.level, MuscleActivationLevel.normal);
  });
}
