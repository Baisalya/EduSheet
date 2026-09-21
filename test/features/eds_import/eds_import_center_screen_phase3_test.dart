import 'package:edusheet/features/eds_import/presentation/screens/eds_import_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Import Center starts read-only with one .eds chooser', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: EdsImportCenterScreen()),
      ),
    );

    expect(find.text('Import EduSheet File'), findsOneWidget);
    expect(find.text('One .eds file, the correct destination'), findsOneWidget);
    expect(find.text('Choose .eds file'), findsOneWidget);
    expect(find.text('Import safety'), findsOneWidget);
    expect(find.textContaining('Import to '), findsNothing);
  });

  testWidgets('Import Center remains overflow-safe on a wide Windows viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: EdsImportCenterScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Choose .eds file'), findsOneWidget);
  });
}
