import 'package:edusheet/shared/design/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EduSheetTheme', () {
    test('light theme keeps strong contrast and visibly applies workspace accent', () {
      const accent = Color(0xFF008F76);
      final theme = EduSheetTheme.light(seedColor: accent);
      final defaultTheme = EduSheetTheme.light();
      final palette = theme.extension<EduSheetSemanticColors>();

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.surface, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.onSurface, const Color(0xFF101828));

      expect(
        _contrastRatio(theme.colorScheme.onSurface, theme.colorScheme.surface),
        greaterThan(7),
      );
      expect(
        _contrastRatio(
          theme.colorScheme.onSurfaceVariant,
          theme.colorScheme.surface,
        ),
        greaterThan(4.5),
      );
      expect(
        theme.colorScheme.primary,
        isNot(equals(defaultTheme.colorScheme.primary)),
      );
      expect(
        theme.scaffoldBackgroundColor,
        isNot(equals(defaultTheme.scaffoldBackgroundColor)),
      );
      expect(palette, isNotNull);
      expect(palette!.workspace, theme.colorScheme.primary);
      expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
    });

    test('dark theme keeps readable dark surfaces and requested accent', () {
      const accent = Color(0xFF7557D5);
      final theme = EduSheetTheme.dark(seedColor: accent);
      final defaultTheme = EduSheetTheme.dark();

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.onSurface, const Color(0xFFF8FAFC));

      expect(
        _contrastRatio(theme.colorScheme.onSurface, theme.colorScheme.surface),
        greaterThan(7),
      );
      expect(
        _contrastRatio(
          theme.colorScheme.onSurfaceVariant,
          theme.colorScheme.surface,
        ),
        greaterThan(4.5),
      );
      expect(
        theme.scaffoldBackgroundColor,
        isNot(equals(defaultTheme.scaffoldBackgroundColor)),
      );
      expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
      expect(theme.bottomSheetTheme.surfaceTintColor, Colors.transparent);
      expect(theme.inputDecorationTheme.filled, isTrue);
    });

    test('workspace accent propagates to shared interactive component themes', () {
      const accent = Color(0xFFE05A3F);
      final theme = EduSheetTheme.light(seedColor: accent);
      final scheme = theme.colorScheme;

      expect(
        theme.switchTheme.trackColor?.resolve({WidgetState.selected}),
        scheme.primary,
      );
      expect(
        theme.checkboxTheme.fillColor?.resolve({WidgetState.selected}),
        scheme.primary,
      );
      expect(theme.floatingActionButtonTheme.backgroundColor, scheme.primaryContainer);
      expect(theme.navigationBarTheme.indicatorColor, scheme.primaryContainer);
      expect(theme.textSelectionTheme.cursorColor, scheme.primary);
      expect(theme.progressIndicatorTheme.color, scheme.primary);
    });
  });
}


double _contrastRatio(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}
