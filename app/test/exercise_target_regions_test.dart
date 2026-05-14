import 'package:flutter_test/flutter_test.dart';
import 'package:imo/ui/workout_setup/widgets/exercise_target_regions.dart';

void main() {
  group('exerciseTargetMap', () {
    test('covers all MVP exercises (pushup, lateral_raise, bicep_curl)', () {
      expect(exerciseTargetMap.keys, containsAll([
        'pushup',
        'lateral_raise',
        'bicep_curl',
      ]));
    });

    test('pushup primary muscles include chest, triceps, anterior deltoid '
        '(both sides) per v3 mapping', () {
      final target = findExerciseTargetMap('pushup')!;
      expect(target.primary, containsAll([
        'left_chest', 'right_chest',
        'left_triceps', 'right_triceps',
        'left_anterior_deltoid', 'right_anterior_deltoid',
      ]));
      expect(target.supporting, containsAll([
        'left_biceps', 'right_biceps',
      ]));
    });

    test('lateral_raise primary is lateral deltoid, supporting is upper '
        'trapezius', () {
      final target = findExerciseTargetMap('lateral_raise')!;
      expect(target.primary, [
        'left_lateral_deltoid',
        'right_lateral_deltoid',
      ]);
      expect(target.supporting, [
        'left_upper_trapezius',
        'right_upper_trapezius',
      ]);
    });

    test('bicep_curl primary is biceps, supporting includes forearm and '
        'anterior deltoid', () {
      final target = findExerciseTargetMap('bicep_curl')!;
      expect(target.primary, ['left_biceps', 'right_biceps']);
      expect(target.supporting, containsAll([
        'left_forearm', 'right_forearm',
        'left_anterior_deltoid', 'right_anterior_deltoid',
      ]));
    });

    test('returns null for unknown exercise id', () {
      expect(findExerciseTargetMap('unknown_exercise'), isNull);
    });
  });

  group('ExerciseTargetMap', () {
    test('toIntensityMap maps primary to 95 and supporting to 50 by default', () {
      final target = findExerciseTargetMap('pushup')!;
      final intensities = target.toIntensityMap();
      // primary
      expect(intensities['left_chest'], 95.0);
      expect(intensities['left_triceps'], 95.0);
      // supporting
      expect(intensities['left_biceps'], 50.0);
    });

    test('frontKeys / backKeys partition correctly for pushup', () {
      final target = findExerciseTargetMap('pushup')!;
      // Front: chest, anterior_deltoid, biceps
      expect(target.frontKeys, containsAll([
        'left_chest', 'right_chest',
        'left_anterior_deltoid', 'right_anterior_deltoid',
        'left_biceps', 'right_biceps',
      ]));
      // Back: triceps
      expect(target.backKeys, containsAll([
        'left_triceps', 'right_triceps',
      ]));
      // No triceps in front
      expect(target.frontKeys, isNot(contains('left_triceps')));
    });

    test('bicep_curl has no back targets', () {
      final target = findExerciseTargetMap('bicep_curl')!;
      expect(target.hasBackTargets, isFalse);
      expect(target.hasFrontTargets, isTrue);
    });

    test('lateral_raise has back target (upper_trapezius)', () {
      final target = findExerciseTargetMap('lateral_raise')!;
      expect(target.hasBackTargets, isTrue);
      expect(target.backKeys, [
        'left_upper_trapezius',
        'right_upper_trapezius',
      ]);
    });
  });
}
