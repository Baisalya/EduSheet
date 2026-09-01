import 'dart:io';

import 'package:edusheet/features/pdf/services/pdf_export_theme_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows RC font plan is offline-first without requiring one font', () {
    final candidates = PdfExportThemeService.candidatePathsForOperatingSystem(
      'windows',
    );

    expect(candidates, contains(r'C:\Windows\Fonts\Nirmala.ttf'));
    expect(candidates, contains(r'C:\Windows\Fonts\segoeui.ttf'));
    expect(candidates, contains(r'C:\Windows\Fonts\arial.ttf'));
    expect(candidates, contains(r'C:\Windows\Fonts\mangal.ttf'));
    expect(candidates, contains(r'C:\Windows\Fonts\kalinga.ttf'));
    expect(candidates, contains(r'C:\Windows\Fonts\seguisym.ttf'));
  });

  test('Android RC font plan includes math and teacher language fallbacks', () {
    final candidates = PdfExportThemeService.candidatePathsForOperatingSystem(
      'android',
    );

    expect(candidates, contains('/system/fonts/NotoSans-Regular.ttf'));
    expect(candidates, contains('/system/fonts/NotoSansMath-Regular.ttf'));
    expect(
      candidates.any((path) => path.contains('NotoSansDevanagari')),
      isTrue,
    );
    expect(candidates.any((path) => path.contains('NotoSansOriya')), isTrue);
  });

  test('unknown platform has no unsafe guessed system font path', () {
    expect(
      PdfExportThemeService.candidatePathsForOperatingSystem('unknown'),
      isEmpty,
    );
  });

  test('Windows release host resolves an offline local base font', () async {
    if (!Platform.isWindows) {
      return;
    }

    final existing =
        await PdfExportThemeService.existingCandidatePathsForOperatingSystem(
          'windows',
        );
    final names = existing
        .map((path) => path.replaceAll('\\', '/').split('/').last.toLowerCase())
        .toSet();

    expect(
      names.any(
        (name) =>
            name == 'nirmala.ttf' ||
            name == 'segoeui.ttf' ||
            name == 'arial.ttf',
      ),
      isTrue,
      reason:
          'RC1 needs at least one local Windows base font; Nirmala UI is '
          'preferred for Indic coverage but is not a mandatory host file.',
    );
  });
}
