import 'package:flutter_test/flutter_test.dart';
import 'package:imo/ui/stats/widgets/svg_body_heatmap_view.dart';

void main() {
  group('bodyGenderFromCode', () {
    test('FEMALE → female', () {
      expect(bodyGenderFromCode('FEMALE'), BodyGender.female);
    });

    test('female 소문자도 female', () {
      expect(bodyGenderFromCode('female'), BodyGender.female);
    });

    test('MALE → male', () {
      expect(bodyGenderFromCode('MALE'), BodyGender.male);
    });

    test('OTHER → male (default)', () {
      expect(bodyGenderFromCode('OTHER'), BodyGender.male);
    });

    test('빈 문자열 → male (default)', () {
      expect(bodyGenderFromCode(''), BodyGender.male);
    });
  });

  group('SvgBodyHeatmapView._assetPath', () {
    test('male + front', () {
      expect(
        SvgBodyHeatmapView.assetPathFor(BodyGender.male, false),
        'assets/svg/male_front_body.svg',
      );
    });

    test('male + back', () {
      expect(
        SvgBodyHeatmapView.assetPathFor(BodyGender.male, true),
        'assets/svg/male_back_body.svg',
      );
    });

    test('female + front', () {
      expect(
        SvgBodyHeatmapView.assetPathFor(BodyGender.female, false),
        'assets/svg/female_front_body.svg',
      );
    });

    test('female + back', () {
      expect(
        SvgBodyHeatmapView.assetPathFor(BodyGender.female, true),
        'assets/svg/female_back_body.svg',
      );
    });
  });
}
