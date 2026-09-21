import 'package:edusheet/shared/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Settings reuses real EduSheet import and export entry points', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump();

    final hub = find.text('Import & Export');
    expect(hub, findsOneWidget);
    await tester.ensureVisible(hub);
    await tester.tap(hub);
    await tester.pumpAndSettle();

    expect(find.text('Import EduSheet File'), findsOneWidget);
    expect(find.text('Backup / Export Teaching Workspace'), findsOneWidget);
    expect(find.text('Export Saved Paper'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Import EduSheet File'));
    await tester.pumpAndSettle();

    expect(find.text('Import EduSheet File'), findsOneWidget);
    expect(
      find.text('One .eds file, the correct destination'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
