import 'dart:io';

import 'package:edusheet/features/word_converter/presentation/screens/word_converter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('converter uses honest professional mode naming', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    await tester.pumpWidget(
      const MaterialApp(home: WordConverterScreen()),
    );

    expect(find.text('Word to PDF'), findsOneWidget);
    expect(
      find.text('Convert documents without hidden content changes'),
      findsOneWidget,
    );
    expect(find.text('PDF to Word: Preserve Appearance'), findsOneWidget);
    expect(find.text('PDF to Word: Editable Document'), findsOneWidget);
    expect(
      find.textContaining('Text may not be directly editable.'),
      (Platform.isAndroid || Platform.isWindows)
          ? findsOneWidget
          : findsNothing,
    );

    if (Platform.isAndroid || Platform.isWindows) {
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Choose PDF File').first,
      );
      expect(button.onPressed, isNotNull);
    } else {
      expect(
        find.textContaining('not available on this platform'),
        findsOneWidget,
      );
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Unavailable on this platform'),
      );
      expect(button.onPressed, isNull);
    }
  });
}
