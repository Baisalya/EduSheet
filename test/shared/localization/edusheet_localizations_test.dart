import 'package:edusheet/shared/localization/edusheet_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provides Hindi and falls back to English for unsupported locales', () {
    expect(
      const EduSheetLocalizations(Locale('hi')).saveAs,
      'इस रूप में सहेजें',
    );
    expect(
      const EduSheetLocalizations(Locale('fr')).saveFile,
      'Save file',
    );
  });

  testWidgets('localization delegate supplies the active locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hi'),
        supportedLocales: const [Locale('en'), Locale('hi')],
        localizationsDelegates: const [EduSheetLocalizations.delegate],
        home: Builder(
          builder: (context) => Text(EduSheetLocalizations.of(context).saveAs),
        ),
      ),
    );

    expect(find.text('इस रूप में सहेजें'), findsOneWidget);
  });
}
