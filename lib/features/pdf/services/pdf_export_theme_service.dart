import 'dart:io';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Resolves a deterministic PDF font theme for release builds.
///
/// RC1 prefers fonts already installed by the operating system so question
/// paper export keeps working when the device is offline. The previous direct
/// [PdfGoogleFonts] path remains as a compatibility fallback for platforms
/// where a suitable local font set cannot be found.
class PdfExportThemeService {
  PdfExportThemeService._();

  static Future<pw.ThemeData>? _themeFuture;

  static Future<pw.ThemeData> loadTheme() {
    return _themeFuture ??= _buildTheme();
  }

  /// Allows deterministic tests to rebuild the resolver after changing a
  /// mocked environment. Production code should not normally call this.
  static void resetForTesting() {
    _themeFuture = null;
  }

  static List<String> candidatePathsForOperatingSystem(String operatingSystem) {
    final plan = _planForOperatingSystem(operatingSystem);
    if (plan == null) {
      return const <String>[];
    }
    return <String>[
      ...plan.base,
      ...plan.bold,
      ...plan.italic,
      ...plan.boldItalic,
      ...plan.fallback,
    ];
  }

  /// Returns the configured font candidates that actually exist on the host.
  ///
  /// Windows installations are not guaranteed to expose every optional script
  /// font under one fixed file name. RC1 therefore treats Nirmala UI as a
  /// preferred font, not a release prerequisite, and accepts stable Windows
  /// base fonts such as Segoe UI/Arial plus any available Indic fallbacks.
  static Future<List<String>> existingCandidatePathsForOperatingSystem(
    String operatingSystem,
  ) async {
    final existing = <String>[];
    final seen = <String>{};
    for (final path in candidatePathsForOperatingSystem(operatingSystem)) {
      for (final candidate in _platformPathVariants(path, operatingSystem)) {
        final normalized = candidate.toLowerCase();
        if (!seen.add(normalized)) {
          continue;
        }
        try {
          if (await File(candidate).exists()) {
            existing.add(candidate);
          }
        } catch (_) {
          // A protected/missing system font path is simply unavailable.
        }
      }
    }
    return existing;
  }

  static Future<pw.ThemeData> _buildTheme() async {
    final localFonts = await _loadLocalFonts();
    if (localFonts != null) {
      return pw.ThemeData.withFont(
        base: localFonts.base,
        bold: localFonts.bold,
        italic: localFonts.italic,
        boldItalic: localFonts.boldItalic,
        fontFallback: localFonts.fallback,
      );
    }

    try {
      final fonts = await Future.wait([
        PdfGoogleFonts.notoSansRegular(),
        PdfGoogleFonts.notoSansBold(),
        PdfGoogleFonts.notoSansItalic(),
        PdfGoogleFonts.notoSansBoldItalic(),
        PdfGoogleFonts.notoSansMathRegular(),
        PdfGoogleFonts.notoSansSymbols2Regular(),
        PdfGoogleFonts.notoSansDevanagariRegular(),
        PdfGoogleFonts.notoSansOriyaRegular(),
        PdfGoogleFonts.notoSansBengaliRegular(),
        PdfGoogleFonts.notoSansTamilRegular(),
        PdfGoogleFonts.notoSansTeluguRegular(),
        PdfGoogleFonts.notoSansKannadaRegular(),
        PdfGoogleFonts.notoSansGujaratiRegular(),
        PdfGoogleFonts.notoSansMalayalamRegular(),
        PdfGoogleFonts.notoSansGurmukhiRegular(),
        PdfGoogleFonts.notoSansArabicRegular(),
        PdfGoogleFonts.notoSansJPRegular(),
      ]);

      return pw.ThemeData.withFont(
        base: fonts[0],
        bold: fonts[1],
        italic: fonts[2],
        boldItalic: fonts[3],
        fontFallback: fonts.sublist(4),
      );
    } catch (_) {
      // Last-resort deterministic theme. This intentionally avoids turning an
      // offline export into an exception. Unicode-heavy documents should use
      // one of the local/system or Google-font paths above.
      return pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
        boldItalic: pw.Font.helveticaBoldOblique(),
        fontFallback: [pw.Font.symbol()],
      );
    }
  }

  static Future<_LocalFontSet?> _loadLocalFonts() async {
    final plan = _planForCurrentPlatform();
    if (plan == null) {
      return null;
    }

    final base = await _loadFirst(plan.base);
    if (base == null) {
      return null;
    }

    final bold = await _loadFirst(plan.bold);
    final italic = await _loadFirst(plan.italic);
    final boldItalic = await _loadFirst(plan.boldItalic);

    final fallback = <pw.Font>[];
    final seen = <String>{};
    for (final path in plan.fallback) {
      if (!seen.add(path)) {
        continue;
      }
      final font = await _loadFont(path);
      if (font != null) {
        fallback.add(font);
      }
    }

    // The built-in Symbol face gives a deterministic last line of defence for
    // common mathematical glyphs without requiring a network request.
    fallback.add(pw.Font.symbol());

    return _LocalFontSet(
      base: base,
      bold: bold ?? base,
      italic: italic ?? base,
      boldItalic: boldItalic ?? bold ?? italic ?? base,
      fallback: fallback,
    );
  }

  static _FontPlan? _planForCurrentPlatform() {
    if (Platform.isWindows) {
      return _windowsPlan;
    }
    if (Platform.isAndroid) {
      return _androidPlan;
    }
    if (Platform.isLinux) {
      return _linuxPlan;
    }
    if (Platform.isMacOS) {
      return _macosPlan;
    }
    return null;
  }

  static _FontPlan? _planForOperatingSystem(String operatingSystem) {
    return switch (operatingSystem.toLowerCase()) {
      'windows' => _windowsPlan,
      'android' => _androidPlan,
      'linux' => _linuxPlan,
      'macos' => _macosPlan,
      _ => null,
    };
  }

  static Future<pw.Font?> _loadFirst(List<String> paths) async {
    for (final path in paths) {
      final font = await _loadFont(path);
      if (font != null) {
        return font;
      }
    }
    return null;
  }

  static Future<pw.Font?> _loadFont(String path) async {
    for (final candidate in _platformPathVariants(
      path,
      Platform.operatingSystem,
    )) {
      try {
        final file = File(candidate);
        if (!await file.exists()) {
          continue;
        }
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          continue;
        }
        return pw.Font.ttf(
          bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes),
        );
      } catch (_) {
        // Try the next candidate/Windows-directory variant.
      }
    }
    return null;
  }

  static List<String> _platformPathVariants(
    String path,
    String operatingSystem,
  ) {
    if (operatingSystem.toLowerCase() != 'windows') {
      return <String>[path];
    }

    const defaultWindowsRoot = r'C:\Windows';
    final lowerPath = path.toLowerCase();
    final defaultPrefix = defaultWindowsRoot.toLowerCase();
    if (!lowerPath.startsWith('$defaultPrefix\\')) {
      return <String>[path];
    }

    final windowsRoot = Platform.environment['WINDIR']?.trim();
    if (windowsRoot == null || windowsRoot.isEmpty) {
      return <String>[path];
    }

    final relative = path.substring(defaultWindowsRoot.length);
    final resolved = '$windowsRoot$relative';
    if (resolved.toLowerCase() == lowerPath) {
      return <String>[path];
    }
    return <String>[resolved, path];
  }

  static const _windowsPlan = _FontPlan(
    // Nirmala UI is preferred when available because of its Indic coverage.
    // Some Windows installations do not expose it, so Segoe UI/Arial are
    // stable offline base fallbacks instead of forcing a Google-font request.
    base: [
      r'C:\Windows\Fonts\Nirmala.ttf',
      r'C:\Windows\Fonts\segoeui.ttf',
      r'C:\Windows\Fonts\arial.ttf',
    ],
    bold: [
      r'C:\Windows\Fonts\NirmalaB.ttf',
      r'C:\Windows\Fonts\segoeuib.ttf',
      r'C:\Windows\Fonts\arialbd.ttf',
    ],
    italic: [r'C:\Windows\Fonts\segoeuii.ttf', r'C:\Windows\Fonts\ariali.ttf'],
    boldItalic: [
      r'C:\Windows\Fonts\segoeuiz.ttf',
      r'C:\Windows\Fonts\arialbi.ttf',
    ],
    fallback: [
      // Preferred broad Indian-script face on modern Windows.
      r'C:\Windows\Fonts\Nirmala.ttf',

      // Common Windows script fonts. These are optional OS components, so the
      // resolver loads whichever are actually present.
      r'C:\Windows\Fonts\mangal.ttf',
      r'C:\Windows\Fonts\aparaj.ttf',
      r'C:\Windows\Fonts\kokila.ttf',
      r'C:\Windows\Fonts\utsaah.ttf',
      r'C:\Windows\Fonts\kalinga.ttf',
      r'C:\Windows\Fonts\vrinda.ttf',
      r'C:\Windows\Fonts\latha.ttf',
      r'C:\Windows\Fonts\vijaya.ttf',
      r'C:\Windows\Fonts\gautami.ttf',
      r'C:\Windows\Fonts\tunga.ttf',
      r'C:\Windows\Fonts\shruti.ttf',
      r'C:\Windows\Fonts\kartika.ttf',
      r'C:\Windows\Fonts\raavi.ttf',

      // Math/symbol and general Unicode/Latin fallbacks.
      r'C:\Windows\Fonts\seguisym.ttf',
      r'C:\Windows\Fonts\arialuni.ttf',
      r'C:\Windows\Fonts\segoeui.ttf',
      r'C:\Windows\Fonts\arial.ttf',
    ],
  );

  static const _androidPlan = _FontPlan(
    base: [
      '/system/fonts/NotoSans-Regular.ttf',
      '/system/fonts/Roboto-Regular.ttf',
    ],
    bold: ['/system/fonts/NotoSans-Bold.ttf', '/system/fonts/Roboto-Bold.ttf'],
    italic: [
      '/system/fonts/NotoSans-Italic.ttf',
      '/system/fonts/Roboto-Italic.ttf',
    ],
    boldItalic: [
      '/system/fonts/NotoSans-BoldItalic.ttf',
      '/system/fonts/Roboto-BoldItalic.ttf',
    ],
    fallback: [
      '/system/fonts/NotoSansMath-Regular.ttf',
      '/system/fonts/NotoSansSymbols2-Regular.ttf',
      '/system/fonts/NotoSansDevanagari-Regular.ttf',
      '/system/fonts/NotoSansDevanagari-VF.ttf',
      '/system/fonts/NotoSansOriya-Regular.ttf',
      '/system/fonts/NotoSansOriya-VF.ttf',
      '/system/fonts/NotoSansBengali-Regular.ttf',
      '/system/fonts/NotoSansBengali-VF.ttf',
      '/system/fonts/NotoSansTamil-Regular.ttf',
      '/system/fonts/NotoSansTamil-VF.ttf',
      '/system/fonts/NotoSansTelugu-Regular.ttf',
      '/system/fonts/NotoSansTelugu-VF.ttf',
      '/system/fonts/NotoSansKannada-Regular.ttf',
      '/system/fonts/NotoSansKannada-VF.ttf',
      '/system/fonts/NotoSansGujarati-Regular.ttf',
      '/system/fonts/NotoSansGujarati-VF.ttf',
      '/system/fonts/NotoSansMalayalam-Regular.ttf',
      '/system/fonts/NotoSansMalayalam-VF.ttf',
      '/system/fonts/NotoSansGurmukhi-Regular.ttf',
      '/system/fonts/NotoSansGurmukhi-VF.ttf',
      '/system/fonts/NotoNaskhArabic-Regular.ttf',
      '/system/fonts/NotoSansArabic-Regular.ttf',
    ],
  );

  static const _linuxPlan = _FontPlan(
    base: [
      '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ],
    bold: [
      '/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    ],
    italic: [
      '/usr/share/fonts/truetype/noto/NotoSans-Italic.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans-Oblique.ttf',
    ],
    boldItalic: [
      '/usr/share/fonts/truetype/noto/NotoSans-BoldItalic.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans-BoldOblique.ttf',
    ],
    fallback: [
      '/usr/share/fonts/truetype/noto/NotoSansMath-Regular.ttf',
      '/usr/share/fonts/truetype/noto/NotoSansSymbols2-Regular.ttf',
      '/usr/share/fonts/truetype/noto/NotoSansDevanagari-Regular.ttf',
      '/usr/share/fonts/truetype/noto/NotoSansOriya-Regular.ttf',
      '/usr/share/fonts/truetype/noto/NotoSansBengali-Regular.ttf',
      '/usr/share/fonts/truetype/noto/NotoSansTamil-Regular.ttf',
      '/usr/share/fonts/truetype/noto/NotoSansTelugu-Regular.ttf',
      '/usr/share/fonts/truetype/noto/NotoSansKannada-Regular.ttf',
      '/usr/share/fonts/truetype/noto/NotoSansGujarati-Regular.ttf',
      '/usr/share/fonts/truetype/noto/NotoSansMalayalam-Regular.ttf',
      '/usr/share/fonts/truetype/noto/NotoSansGurmukhi-Regular.ttf',
      '/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ],
  );

  static const _macosPlan = _FontPlan(
    base: [
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/Library/Fonts/Arial.ttf',
    ],
    bold: [
      '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
      '/Library/Fonts/Arial Bold.ttf',
    ],
    italic: [
      '/System/Library/Fonts/Supplemental/Arial Italic.ttf',
      '/Library/Fonts/Arial Italic.ttf',
    ],
    boldItalic: [
      '/System/Library/Fonts/Supplemental/Arial Bold Italic.ttf',
      '/Library/Fonts/Arial Bold Italic.ttf',
    ],
    fallback: [
      '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
      '/Library/Fonts/Arial Unicode.ttf',
    ],
  );
}

class _LocalFontSet {
  const _LocalFontSet({
    required this.base,
    required this.bold,
    required this.italic,
    required this.boldItalic,
    required this.fallback,
  });

  final pw.Font base;
  final pw.Font bold;
  final pw.Font italic;
  final pw.Font boldItalic;
  final List<pw.Font> fallback;
}

class _FontPlan {
  const _FontPlan({
    required this.base,
    required this.bold,
    required this.italic,
    required this.boldItalic,
    required this.fallback,
  });

  final List<String> base;
  final List<String> bold;
  final List<String> italic;
  final List<String> boldItalic;
  final List<String> fallback;
}
