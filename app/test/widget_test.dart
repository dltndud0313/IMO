import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inside_muscle_out/main.dart';

void main() {
  testWidgets('App boots and shows home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MuscleVisionApp()));
    await tester.pumpAndSettle();

    expect(find.text('Inside Muscle Out'), findsOneWidget);
    expect(find.text('운동 시작'), findsOneWidget);
  });
}
