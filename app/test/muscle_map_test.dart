import 'package:flutter_test/flutter_test.dart';
import 'package:imo/domain/models/muscle_map.dart';

void main() {
  test('resolves activation ratio into display level', () {
    expect(resolveMuscleActivationLevel(0), MuscleActivationLevel.inactive);
    expect(resolveMuscleActivationLevel(0.2), MuscleActivationLevel.low);
    expect(resolveMuscleActivationLevel(0.5), MuscleActivationLevel.normal);
    expect(resolveMuscleActivationLevel(0.8), MuscleActivationLevel.high);
    expect(resolveMuscleActivationLevel(0.95), MuscleActivationLevel.danger);
  });

  test('maps pushup muscle key to Korean display name', () {
    final state = MuscleMapState.fromValues(
      exerciseId: 'pushup',
      values: const {'left_chest': 0.68},
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
      values: const {'unknown_muscle': 0.42},
      includeMissingKeys: false,
    );

    expect(state.entries, hasLength(1));
    expect(state.entries.first.key, 'unknown_muscle');
    expect(state.entries.first.displayName, 'unknown_muscle');
    expect(state.entries.first.isKnownKey, isFalse);
    expect(state.entries.first.level, MuscleActivationLevel.normal);
  });
}
