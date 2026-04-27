import 'package:flutter_test/flutter_test.dart';
import 'package:imo/config/dependencies.dart';
import 'package:imo/main.dart';

void main() {
  testWidgets('renders home route', (tester) async {
    await setupDependencies();
    await tester.pumpWidget(const ImoApp());
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Start workout setup'), findsOneWidget);
  });
}
