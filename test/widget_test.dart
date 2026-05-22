import 'package:edusheet/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EduSheet home screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('EduSheet'), findsOneWidget);
    expect(find.text('Create Paper'), findsOneWidget);
    expect(find.text('Question Bank'), findsOneWidget);
  });
}
