import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imo/ui/stats/widgets/trunk_posture_indicator.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)));

void main() {
  testWidgets('null → 측정 데이터 없음', (tester) async {
    await tester.pumpWidget(_wrap(const TrunkPostureIndicator(stability: null)));
    expect(find.text('측정 데이터 없음'), findsOneWidget);
    expect(find.text('-'), findsOneWidget);
  });

  testWidgets('0.85 → 안정', (tester) async {
    await tester.pumpWidget(_wrap(const TrunkPostureIndicator(stability: 0.85)));
    expect(find.text('안정'), findsOneWidget);
    expect(find.text('85%'), findsOneWidget);
  });

  testWidgets('0.5 → 보통', (tester) async {
    await tester.pumpWidget(_wrap(const TrunkPostureIndicator(stability: 0.5)));
    expect(find.text('보통'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('0.3 → 불안정', (tester) async {
    await tester.pumpWidget(_wrap(const TrunkPostureIndicator(stability: 0.3)));
    expect(find.text('불안정'), findsOneWidget);
    expect(find.text('30%'), findsOneWidget);
  });

  testWidgets('경계값 0.0 → 불안정', (tester) async {
    await tester.pumpWidget(_wrap(const TrunkPostureIndicator(stability: 0.0)));
    expect(find.text('불안정'), findsOneWidget);
  });

  testWidgets('경계값 1.0 → 안정', (tester) async {
    await tester.pumpWidget(_wrap(const TrunkPostureIndicator(stability: 1.0)));
    expect(find.text('안정'), findsOneWidget);
  });
}
