import 'package:edusheet/features/premium/presentation/screens/premium_screen.dart';
import 'package:edusheet/shared/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('release settings surface fits a compact phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump();

    expect(find.text('Free access release'), findsOneWidget);
    expect(find.text('Enjoying EduSheet?'), findsOneWidget);
    expect(find.text('Workspace colour'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('premium purchase surface fits a compact phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PremiumScreen())),
    );
    await tester.pump();

    expect(find.text('FREE ACCESS'), findsOneWidget);
    expect(find.text('Premium colour styles'), findsOneWidget);
    expect(find.text('Core tools remain free'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
