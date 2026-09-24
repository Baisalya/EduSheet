import 'package:edusheet/features/printing/presentation/screens/print_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty print center exposes a clear device-file entry point', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PrintCenterScreen()),
    );
    await tester.pump();

    expect(find.text('Print Center'), findsOneWidget);
    expect(find.text('Print from EduSheet'), findsOneWidget);
    expect(find.text('Choose file to print'), findsOneWidget);
    expect(find.byKey(const Key('print-center-choose-file')), findsOneWidget);
  });
}
