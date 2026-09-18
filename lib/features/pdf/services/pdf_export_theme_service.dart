import 'dart:convert';
import 'dart:io';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Resolves a deterministic PDF font theme for release builds.
///
/// RC1 prefers fonts already installed by the operating system so question
/// paper export keeps working when the device is offline. Basic-Latin exports
/// may still use [PdfGoogleFonts] as a compatibility fallback; Unicode release
/// exports require a complete local/system script font set.
class PdfExportThemeService {
  PdfExportThemeService._();

  static Future<pw.ThemeData>? _themeFuture;
  static Future<pw.ThemeData>? _unicodeThemeFuture;
  static final Map<String, Future<List<String>>> _shapingPathFutures =
      <String, Future<List<String>>>{};

  static Future<pw.ThemeData> loadTheme({bool requireUnicode = false}) {
    if (requireUnicode) {
      return _unicodeThemeFuture ??= _buildUnicodeTheme();
    }
    return _themeFuture ??= _buildStandardTheme();
  }

  /// Allows deterministic tests to rebuild the resolver after changing a
  /// mocked environment. Production code should not normally call this.
  static void resetForTesting() {
    _themeFuture = null;
    _unicodeThemeFuture = null;
    _shapingPathFutures.clear();
  }

  /// Resolves actual local TrueType files that can be used by HarfBuzz for
  /// complex-script shaping. The result is offline-only and restricted to
  /// standalone glyf-based TTFs that are also accepted by package:pdf.
  static Future<List<String>> resolvedUnicodeShapingFontPaths({
    bool bold = false,
    bool italic = false,
  }) {
    final key = '${bold ? 1 : 0}${italic ? 1 : 0}';
    return _shapingPathFutures.putIfAbsent(
      key,
      () => _resolveUnicodeShapingFontPaths(bold: bold, italic: italic),
    );
  }

  static Future<List<String>> _resolveUnicodeShapingFontPaths({
    required bool bold,
    required bool italic,
  }) async {
    final plan = _planForCurrentPlatform();
    if (plan == null) {
      return const <String>[];
    }

    final preferred = bold && italic
        ? plan.boldItalic
        : bold
        ? plan.bold
        : italic
        ? plan.italic
        : plan.base;
    final discovered = Platform.isWindows
        ? await _discoverWindowsTeacherFontPaths()
        : const <String>[];
    final candidates = <String>[
      ...preferred,
      ...plan.base,
      ...plan.fallback,
      ...discovered,
    ];

    final result = <String>[];
    final seen = <String>{};
    for (final path in candidates) {
      for (final candidate in _platformPathVariants(
        path,
        Platform.operatingSystem,
      )) {
        final normalized = candidate.toLowerCase();
        if (!seen.add(normalized)) {
          continue;
        }
        try {
          final file = File(candidate);
          if (!await file.exists()) {
            continue;
          }
          final bytes = await file.readAsBytes();
          if (!_isPdfTtfCompatible(bytes)) {
            continue;
          }
          result.add(candidate);
        } catch (_) {
          // Continue through optional host font candidates.
        }
      }
    }
    return List<String>.unmodifiable(result);
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

  static Future<pw.ThemeData> _buildStandardTheme() async {
    final localFonts = await _loadLocalFonts();
    if (localFonts != null) {
      return _themeFromLocalFonts(localFonts, includeSymbolFallback: true);
    }

    final notoTheme = await _tryBuildNotoTheme();
    if (notoTheme != null) {
      return notoTheme;
    }

    // Last-resort ASCII-safe theme for papers that genuinely contain only
    // basic Latin text. Unicode papers never use this branch.
    return pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
      boldItalic: pw.Font.helveticaBoldOblique(),
      fontFallback: [pw.Font.symbol()],
    );
  }

  static Future<pw.ThemeData> _buildUnicodeTheme() async {
    final localFonts = await _loadLocalFonts();
    if (localFonts != null && localFonts.hasCoreTeacherUnicodeCoverage) {
      return _themeFromLocalFonts(localFonts, includeSymbolFallback: false);
    }

    // Unicode export is deliberately offline-first. PdfGoogleFonts may fall
    // back to Helvetica when HTTP is unavailable, which looks like a successful
    // theme load but silently drops Indic glyphs. Never use that network path
    // as the authority for a Unicode paper.
    throw StateError(
      'Unicode PDF export needs local/system fonts with Devanagari and Odia '
      'coverage. EduSheet could not load a complete local font set. On Windows '
      'install/restore Nirmala UI (or Devanagari + Odia language fonts); on '
      'Android keep the system Noto Indic fonts available.',
    );
  }

  static pw.ThemeData _themeFromLocalFonts(
    _LocalFontSet fonts, {
    required bool includeSymbolFallback,
  }) {
    return pw.ThemeData.withFont(
      base: fonts.base,
      bold: fonts.bold,
      italic: fonts.italic,
      boldItalic: fonts.boldItalic,
      fontFallback: [
        ...fonts.fallback,
        if (includeSymbolFallback) pw.Font.symbol(),
      ],
    );
  }

  static Future<pw.ThemeData?> _tryBuildNotoTheme() async {
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
      return null;
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
    final loadedFallbackPaths = <String>[];
    final seen = <String>{};
    final discoveredFallbacks = Platform.isWindows
        ? await _discoverWindowsTeacherFontPaths()
        : const <String>[];
    for (final path in <String>[...plan.fallback, ...discoveredFallbacks]) {
      if (!seen.add(path)) {
        continue;
      }
      final font = await _loadFont(path);
      if (font != null) {
        fallback.add(font);
        loadedFallbackPaths.add(path);
      }
    }

    return _LocalFontSet(
      base: base,
      bold: bold ?? base,
      italic: italic ?? base,
      boldItalic: boldItalic ?? bold ?? italic ?? base,
      fallback: fallback,
      loadedFallbackPaths: loadedFallbackPaths,
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
        if (!_isPdfTtfCompatible(bytes)) {
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

  /// package:pdf's TTF parser expects a standalone TrueType sfnt. Windows
  /// font discovery may also surface TTC collections, WOFF files, or CFF OTF
  /// fonts; [pw.Font.ttf] accepts their bytes lazily and only fails later while
  /// laying out a page. Reject unsupported containers before they enter the
  /// cached theme so one optional system font cannot break the whole export.
  static bool _isPdfTtfCompatible(List<int> bytes) {
    if (bytes.length < 12) {
      return false;
    }

    final isVersionOne =
        bytes[0] == 0x00 &&
        bytes[1] == 0x01 &&
        bytes[2] == 0x00 &&
        bytes[3] == 0x00;
    final isAppleTrueType =
        bytes[0] == 0x74 && // t
        bytes[1] == 0x72 && // r
        bytes[2] == 0x75 && // u
        bytes[3] == 0x65; // e
    if (!isVersionOne && !isAppleTrueType) {
      return false;
    }

    final tableCount = (bytes[4] << 8) | bytes[5];
    final directoryEnd = 12 + (tableCount * 16);
    if (tableCount <= 0 || directoryEnd > bytes.length) {
      return false;
    }

    final requiredTables = <String>{
      'head',
      'cmap',
      'maxp',
      'hhea',
      'hmtx',
      'loca',
      'glyf',
    };
    final found = <String>{};
    for (var index = 0; index < tableCount; index++) {
      final offset = 12 + (index * 16);
      final tag = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      if (requiredTables.contains(tag)) {
        found.add(tag);
      }
    }
    return found.length == requiredTables.length;
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
    final variants = <String>[path];

    if (lowerPath.startsWith('$defaultPrefix\\')) {
      final windowsRoot = Platform.environment['WINDIR']?.trim();
      if (windowsRoot != null && windowsRoot.isNotEmpty) {
        final relative = path.substring(defaultWindowsRoot.length);
        variants.insert(0, '$windowsRoot$relative');
      }

      // Windows also supports fonts installed for the current user. Those
      // files live outside C:\Windows\Fonts and are therefore invisible to
      // a resolver that only probes the system font directory.
      final localAppData = Platform.environment['LOCALAPPDATA']?.trim();
      if (localAppData != null && localAppData.isNotEmpty) {
        final fileName = path.replaceAll('\\', '/').split('/').last;
        variants.insert(
          0,
          '$localAppData\\Microsoft\\Windows\\Fonts\\$fileName',
        );
      }
    }

    final seen = <String>{};
    return variants
        .where((candidate) => seen.add(candidate.toLowerCase()))
        .toList(growable: false);
  }

  static Future<List<String>> _discoverWindowsTeacherFontPaths() async {
    final directories = <String>[];
    final windowsRoot = Platform.environment['WINDIR']?.trim();
    if (windowsRoot != null && windowsRoot.isNotEmpty) {
      directories.add('$windowsRoot\\Fonts');
    } else {
      directories.add(r'C:\Windows\Fonts');
    }

    final localAppData = Platform.environment['LOCALAPPDATA']?.trim();
    if (localAppData != null && localAppData.isNotEmpty) {
      directories.add('$localAppData\\Microsoft\\Windows\\Fonts');
    }

    for (final programFilesKey in const ['ProgramFiles', 'ProgramFiles(x86)']) {
      final programFiles = Platform.environment[programFilesKey]?.trim();
      if (programFiles == null || programFiles.isEmpty) {
        continue;
      }
      directories.add('$programFiles\\Microsoft Office\\root\\vfs\\Fonts');
      directories.add(
        '$programFiles\\Microsoft Office\\root\\vfs\\Fonts\\private',
      );
    }

    final found = <String>[];
    final seen = <String>{};
    for (final directoryPath in directories) {
      try {
        final directory = Directory(directoryPath);
        if (!await directory.exists()) {
          continue;
        }
        await for (final entity in directory.list(followLinks: false)) {
          if (entity is! File) {
            continue;
          }
          final fileName = entity.path
              .replaceAll('\\', '/')
              .split('/')
              .last
              .toLowerCase();
          if (!fileName.endsWith('.ttf') ||
              !_looksLikeTeacherUnicodeFont(fileName)) {
            continue;
          }
          if (seen.add(entity.path.toLowerCase())) {
            found.add(entity.path);
          }
        }
      } catch (_) {
        // A protected or unavailable font directory is not fatal. The fixed
        // candidate plan still runs before these discovery results.
      }
    }

    for (final path in await _discoverWindowsRegistryFontPaths()) {
      if (seen.add(path.toLowerCase())) {
        found.add(path);
      }
    }
    return found;
  }

  static Future<List<String>> _discoverWindowsRegistryFontPaths() async {
    const registryKey =
        r'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts';
    final results = <String>[];
    for (final hive in const ['HKLM', 'HKCU']) {
      try {
        final query = await Process.run(
          'reg.exe',
          ['query', '$hive\\$registryKey'],
          runInShell: false,
        );
        if (query.exitCode != 0) {
          continue;
        }
        final text = query.stdout?.toString() ?? '';
        for (final line in const LineSplitter().convert(text)) {
          final upper = line.toUpperCase();
          final marker = upper.indexOf('REG_SZ');
          if (marker < 0) {
            continue;
          }
          final displayName = line.substring(0, marker).trim().toLowerCase();
          final value = line.substring(marker + 'REG_SZ'.length).trim();
          if (value.isEmpty || !_looksLikeTeacherUnicodeFont(displayName)) {
            continue;
          }
          final resolved = _resolveWindowsRegistryFontValue(value, hive);
          if (resolved != null && resolved.toLowerCase().endsWith('.ttf')) {
            results.add(resolved);
          }
        }
      } catch (_) {
        // Registry discovery is optional; filesystem discovery remains active.
      }
    }
    return results;
  }

  static String? _resolveWindowsRegistryFontValue(String value, String hive) {
    final normalized = value.replaceAll('/', '\\').trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (RegExp(r'^[A-Za-z]:\\').hasMatch(normalized)) {
      return normalized;
    }

    if (hive == 'HKCU') {
      final localAppData = Platform.environment['LOCALAPPDATA']?.trim();
      if (localAppData != null && localAppData.isNotEmpty) {
        return '$localAppData\\Microsoft\\Windows\\Fonts\\$normalized';
      }
    }

    final windowsRoot = Platform.environment['WINDIR']?.trim();
    final root = windowsRoot == null || windowsRoot.isEmpty
        ? r'C:\Windows'
        : windowsRoot;
    return '$root\\Fonts\\$normalized';
  }

  static bool _looksLikeTeacherUnicodeFont(String fileName) {
    return fileName.contains('nirmala') ||
        fileName.contains('mangal') ||
        fileName.contains('aparaj') ||
        fileName.contains('kokila') ||
        fileName.contains('utsaah') ||
        fileName.contains('kalinga') ||
        fileName.contains('devanagari') ||
        fileName.contains('oriya') ||
        fileName.contains('odia') ||
        fileName.contains('notosansmath') ||
        fileName.contains('notosanssymbols');
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
      r'C:\Windows\Fonts\Nirmalab.ttf',
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
      r'C:\Windows\Fonts\NirmalaS.ttf',

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
    required this.loadedFallbackPaths,
  });

  final pw.Font base;
  final pw.Font bold;
  final pw.Font italic;
  final pw.Font boldItalic;
  final List<pw.Font> fallback;
  final List<String> loadedFallbackPaths;

  bool get hasCoreTeacherUnicodeCoverage {
    final names = loadedFallbackPaths
        .map((path) => path.replaceAll('\\', '/').split('/').last.toLowerCase())
        .toSet();

    bool hasFragment(String fragment) =>
        names.any((name) => name.contains(fragment));

    final hasBroadIndic =
        hasFragment('nirmala') || hasFragment('arialuni');
    final hasDevanagari = hasBroadIndic ||
        hasFragment('mangal') ||
        hasFragment('aparaj') ||
        hasFragment('kokila') ||
        hasFragment('utsaah') ||
        hasFragment('devanagari');
    final hasOdia = hasBroadIndic ||
        hasFragment('kalinga') ||
        hasFragment('oriya') ||
        hasFragment('odia');
    // Do not require a dedicated symbol font here. The configured base fonts
    // (Segoe UI/Arial/Noto Sans/DejaVu Sans) already cover the Phase 9 math
    // characters such as √, θ and π on supported hosts. Requiring Segoe UI
    // Symbol specifically caused valid Nirmala/Mangal+Kalinga Windows setups to
    // be rejected and then sent down an unreliable network-font path.
    return hasDevanagari && hasOdia;
  }
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
