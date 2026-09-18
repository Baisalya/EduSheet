/*
 * EduSheet Phase 9 complex-script PDF shaping adapter.
 *
 * The shaping/rendering architecture is adapted for pdf 3.12 compatibility
 * from pdf_text_shaper (Apache-2.0):
 * https://github.com/ardevcraft/pdf_text_shaper
 * HarfBuzz itself is used through harfbuzz_ffi (MIT). The Apache-2.0
 * license for the adapted reference implementation is retained at
 * third_party/licenses/pdf_text_shaper_APACHE-2.0.txt. No font binaries are
 * bundled or redistributed by this adapter.
 */

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:characters/characters.dart';
import 'package:ffi/ffi.dart';
import 'package:harfbuzz_ffi/harfbuzz_ffi_bindings.dart' as hb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../pdf_export_theme_service.dart';

/// HarfBuzz-backed PDF text for scripts that require GSUB/GPOS shaping.
///
/// `package:pdf` 3.12 can embed Unicode TTFs, but it does not shape Indic
/// scripts before painting. That leaves combining marks/conjuncts visually
/// separated. This service keeps the existing PDF package/version and only
/// replaces the affected text runs:
///
/// * HarfBuzz shapes the source text into glyph ids + advances/offsets.
/// * glyph outlines are replayed into the PDF as vector paths.
/// * the original source string is emitted with PDF invisible-text rendering,
///   preserving copy/search/text extraction semantics.
///
/// The service is intentionally local-font/offline-only. It uses the same
/// deterministic font discovery as [PdfExportThemeService].
class PdfComplexTextService {
  PdfComplexTextService._();

  static Future<void>? _initializing;
  static _ComplexFontCollection? _fonts;

  static bool containsComplexScript(String text) =>
      text.runes.any(_scriptForRuneIsComplex);

  static Future<void> ensureInitialized() {
    if (_fonts != null) return Future<void>.value();
    return _initializing ??= _initialize();
  }

  static Future<void> _initialize() async {
    try {
      final regularPaths = await PdfExportThemeService
          .resolvedUnicodeShapingFontPaths();
      final boldPaths = await PdfExportThemeService
          .resolvedUnicodeShapingFontPaths(bold: true);
      final italicPaths = await PdfExportThemeService
          .resolvedUnicodeShapingFontPaths(italic: true);
      final boldItalicPaths = await PdfExportThemeService
          .resolvedUnicodeShapingFontPaths(bold: true, italic: true);

      final byPath = <String, _ShapedFont>{};

      Future<List<_ShapedFont>> load(List<String> paths) async {
        final result = <_ShapedFont>[];
        for (final path in paths) {
          final key = path.toLowerCase();
          var font = byPath[key];
          if (font == null) {
            try {
              final bytes = await File(path).readAsBytes();
              font = _ShapedFont.fromBytes(
                bytes,
                name: path.replaceAll('\\', '/').split('/').last,
              );
              byPath[key] = font;
            } catch (_) {
              // Font discovery is intentionally permissive. One malformed or
              // unsupported optional face must not block the remaining set.
              continue;
            }
          }
          result.add(font);
        }
        return result;
      }

      final regular = await load(regularPaths);
      final bold = await load(boldPaths);
      final italic = await load(italicPaths);
      final boldItalic = await load(boldItalicPaths);

      if (regular.isEmpty) {
        throw StateError(
          'Complex-script PDF shaping could not load any local TrueType font.',
        );
      }

      const devanagariProbe = 'हिन्दी';
      const odiaProbe = 'ଓଡ଼ିଆ';
      if (!_supportsTextAcrossFonts(regular, devanagariProbe) ||
          !_supportsTextAcrossFonts(regular, odiaProbe)) {
        throw StateError(
          'Complex-script PDF shaping needs local Devanagari and Odia fonts. '
          'EduSheet found local TTF files, but the shaping font set does not '
          'cover both scripts.',
        );
      }

      _fonts = _ComplexFontCollection(
        regular: List<_ShapedFont>.unmodifiable(regular),
        bold: List<_ShapedFont>.unmodifiable(bold.isEmpty ? regular : bold),
        italic:
            List<_ShapedFont>.unmodifiable(italic.isEmpty ? regular : italic),
        boldItalic: List<_ShapedFont>.unmodifiable(
          boldItalic.isEmpty
              ? (bold.isNotEmpty ? bold : regular)
              : boldItalic,
        ),
      );
    } finally {
      _initializing = null;
    }
  }

  static bool _supportsTextAcrossFonts(List<_ShapedFont> fonts, String text) {
    return text.runes.every((rune) {
      if (_isWhitespace(rune)) return true;
      return fonts.any((font) => font.supportsRune(rune));
    });
  }

  /// Preserves an existing package:pdf text style for ordinary text while
  /// routing complex scripts through the HarfBuzz shaping layer. Complex text
  /// currently preserves the core printable style attributes used by EduSheet
  /// (size, color, weight, italic, line height and alignment).
  static pw.Widget styledText(
    String text, {
    pw.TextStyle? style,
    pw.TextAlign textAlign = pw.TextAlign.left,
    int? maxLines,
  }) {
    if (!containsComplexScript(text)) {
      return pw.Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
      );
    }
    final resolved = style ?? pw.TextStyle.defaultStyle();
    return PdfComplexTextService.text(
      text,
      fontSize: resolved.fontSize ?? 12,
      color: resolved.color ?? PdfColors.black,
      textAlign: textAlign,
      fontWeight: resolved.fontWeight,
      fontStyle: resolved.fontStyle,
      lineHeight: resolved.height,
      letterSpacing: resolved.letterSpacing,
      underline: resolved.decoration?.contains(pw.TextDecoration.underline) == true,
      maxLines: maxLines,
    );
  }

  /// Builds normal `pw.Text` for simple scripts and HarfBuzz vector text for
  /// complex Indic runs. Call [ensureInitialized] before building a document
  /// that contains complex script text.
  static pw.Widget text(
    String text, {
    double fontSize = 12,
    PdfColor color = PdfColors.black,
    pw.TextAlign textAlign = pw.TextAlign.left,
    pw.FontWeight? fontWeight,
    pw.FontStyle? fontStyle,
    double? lineHeight,
    double? letterSpacing,
    bool underline = false,
    int? maxLines,
  }) {
    if (!containsComplexScript(text)) {
      return pw.Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        style: pw.TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          height: lineHeight,
          letterSpacing: letterSpacing,
          decoration: underline ? pw.TextDecoration.underline : null,
        ),
      );
    }

    final collection = _fonts;
    if (collection == null) {
      throw StateError(
        'PdfComplexTextService.ensureInitialized() must be awaited before '
        'building complex-script PDF text.',
      );
    }

    final isBold = fontWeight == pw.FontWeight.bold;
    final isItalic = fontStyle == pw.FontStyle.italic;
    final fonts = switch ((isBold, isItalic)) {
      (true, true) => collection.boldItalic,
      (true, false) => collection.bold,
      (false, true) => collection.italic,
      _ => collection.regular,
    };

    return _ShapedText(
      text,
      style: _ShapedTextStyle(
        fonts: fonts,
        fontSize: fontSize,
        color: color,
        lineHeight: lineHeight,
        letterSpacing: letterSpacing ?? 0,
        underline: underline,
        align: switch (textAlign) {
          pw.TextAlign.center => _ShapedTextAlign.center,
          pw.TextAlign.right || pw.TextAlign.end => _ShapedTextAlign.end,
          _ => _ShapedTextAlign.start,
        },
      ),
      maxLines: maxLines,
    );
  }

  static bool _scriptForRuneIsComplex(int rune) =>
      _scriptForRune(rune) != _ScriptGroup.other;

  static _ScriptGroup _scriptForRune(int rune) {
    if (_between(rune, 0x0900, 0x097F)) return _ScriptGroup.devanagari;
    if (_between(rune, 0x0980, 0x09FF)) return _ScriptGroup.bengali;
    if (_between(rune, 0x0A00, 0x0A7F)) return _ScriptGroup.gurmukhi;
    if (_between(rune, 0x0A80, 0x0AFF)) return _ScriptGroup.gujarati;
    if (_between(rune, 0x0B00, 0x0B7F)) return _ScriptGroup.odia;
    if (_between(rune, 0x0B80, 0x0BFF)) return _ScriptGroup.tamil;
    if (_between(rune, 0x0C00, 0x0C7F)) return _ScriptGroup.telugu;
    if (_between(rune, 0x0C80, 0x0CFF)) return _ScriptGroup.kannada;
    if (_between(rune, 0x0D00, 0x0D7F)) return _ScriptGroup.malayalam;
    if (_between(rune, 0x0D80, 0x0DFF)) return _ScriptGroup.sinhala;
    if (_between(rune, 0x0E00, 0x0E7F)) return _ScriptGroup.thai;
    if (_between(rune, 0x0E80, 0x0EFF)) return _ScriptGroup.lao;
    if (_between(rune, 0x1000, 0x109F) ||
        _between(rune, 0xA9E0, 0xA9FF) ||
        _between(rune, 0xAA60, 0xAA7F)) {
      return _ScriptGroup.myanmar;
    }
    if (_between(rune, 0x1780, 0x17FF) || _between(rune, 0x19E0, 0x19FF)) {
      return _ScriptGroup.khmer;
    }
    if (_between(rune, 0x0F00, 0x0FFF)) return _ScriptGroup.tibetan;
    return _ScriptGroup.other;
  }

  static bool _between(int value, int start, int end) =>
      value >= start && value <= end;

  static bool _isWhitespace(int rune) =>
      rune == 0x09 ||
      rune == 0x0A ||
      rune == 0x0D ||
      rune == 0x20 ||
      rune == 0x00A0;

  static bool _isJoinControl(int rune) => rune == 0x200C || rune == 0x200D;
}

enum _ScriptGroup {
  other,
  devanagari,
  bengali,
  gurmukhi,
  gujarati,
  odia,
  tamil,
  telugu,
  kannada,
  malayalam,
  sinhala,
  thai,
  lao,
  myanmar,
  khmer,
  tibetan,
}

class _ComplexFontCollection {
  const _ComplexFontCollection({
    required this.regular,
    required this.bold,
    required this.italic,
    required this.boldItalic,
  });

  final List<_ShapedFont> regular;
  final List<_ShapedFont> bold;
  final List<_ShapedFont> italic;
  final List<_ShapedFont> boldItalic;
}

class _ShapedFontMetrics {
  const _ShapedFontMetrics({
    required this.unitsPerEm,
    required this.ascender,
    required this.descender,
    required this.lineGap,
  });

  final int unitsPerEm;
  final int ascender;
  final int descender;
  final int lineGap;

  double scaleFor(double fontSize) => fontSize / unitsPerEm;

  double lineHeightFor(double fontSize) {
    final raw = (ascender - descender + lineGap) * scaleFor(fontSize);
    return raw > 0 ? raw : fontSize * 1.2;
  }

  double ascentFor(double fontSize) => ascender * scaleFor(fontSize);
}

class _ShapedFont {
  _ShapedFont._({
    required this.name,
    required Uint8List bytes,
    required this.pdfFont,
    required this.blob,
    required this.face,
    required this.harfbuzzFont,
    required this.metrics,
  })  : bytes = Uint8List.fromList(bytes),
        outlineExtractor = _HarfBuzzGlyphOutlineExtractor();

  factory _ShapedFont.fromBytes(Uint8List bytes, {required String name}) {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'Font bytes cannot be empty.');
    }

    final ownedBytes = Uint8List.fromList(bytes);
    final nativeBytes = calloc<Uint8>(ownedBytes.length);
    nativeBytes.asTypedList(ownedBytes.length).setAll(0, ownedBytes);
    final nullDestroy =
        nullptr.cast<NativeFunction<hb.hb_destroy_func_tFunction>>();

    final blob = hb.hb_blob_create(
      nativeBytes.cast<Char>(),
      ownedBytes.length,
      hb.hb_memory_mode_t.HB_MEMORY_MODE_DUPLICATE,
      nullptr,
      nullDestroy,
    );
    calloc.free(nativeBytes);

    if (blob == nullptr) {
      throw StateError('HarfBuzz could not create a font blob for "$name".');
    }

    final face = hb.hb_face_create(blob, 0);
    if (face == nullptr) {
      hb.hb_blob_destroy(blob);
      throw StateError('HarfBuzz could not create a font face for "$name".');
    }

    final hbFont = hb.hb_font_create(face);
    if (hbFont == nullptr) {
      hb.hb_face_destroy(face);
      hb.hb_blob_destroy(blob);
      throw StateError('HarfBuzz could not create a font for "$name".');
    }

    hb.hb_ot_font_set_funcs(hbFont);
    final unitsPerEm = hb.hb_face_get_upem(face);
    if (unitsPerEm <= 0) {
      hb.hb_font_destroy(hbFont);
      hb.hb_face_destroy(face);
      hb.hb_blob_destroy(blob);
      throw StateError('Font "$name" reports invalid units-per-em.');
    }
    hb.hb_font_set_scale(hbFont, unitsPerEm, unitsPerEm);

    final extents = calloc<hb.hb_font_extents_t>();
    final hasExtents = hb.hb_font_get_h_extents(hbFont, extents) != 0;
    final metrics = _ShapedFontMetrics(
      unitsPerEm: unitsPerEm,
      ascender: hasExtents ? extents.ref.ascender : unitsPerEm,
      descender: hasExtents ? extents.ref.descender : -(unitsPerEm ~/ 4),
      lineGap: hasExtents ? extents.ref.line_gap : 0,
    );
    calloc.free(extents);

    return _ShapedFont._(
      name: name,
      bytes: ownedBytes,
      pdfFont: pw.Font.ttf(ByteData.sublistView(ownedBytes)),
      blob: blob,
      face: face,
      harfbuzzFont: hbFont,
      metrics: metrics,
    );
  }

  final String name;
  final Uint8List bytes;
  final pw.Font pdfFont;
  final Pointer<hb.hb_blob_t> blob;
  final Pointer<hb.hb_face_t> face;
  final Pointer<hb.hb_font_t> harfbuzzFont;
  final _HarfBuzzGlyphOutlineExtractor outlineExtractor;
  final _ShapedFontMetrics metrics;
  final Map<int, bool> coverageCache = <int, bool>{};

  bool supportsRune(int rune) {
    return coverageCache.putIfAbsent(rune, () {
      final glyph = calloc<hb.hb_codepoint_t>();
      try {
        return hb.hb_font_get_nominal_glyph(harfbuzzFont, rune, glyph) != 0;
      } finally {
        calloc.free(glyph);
      }
    });
  }

  void paintGlyph(
    PdfGraphics canvas,
    int glyphId, {
    required double originX,
    required double originY,
    required double scale,
  }) {
    final outline = outlineExtractor.outline(harfbuzzFont, glyphId);
    if (outline.isEmpty) return;
    for (final command in outline.commands) {
      command.replay(
        canvas,
        originX: originX,
        originY: originY,
        scale: scale,
      );
    }
    canvas.fillPath();
  }
}

class _ShapedGlyph {
  const _ShapedGlyph({
    required this.glyphId,
    required this.cluster,
    required this.xAdvance,
    required this.yAdvance,
    required this.xOffset,
    required this.yOffset,
  });

  final int glyphId;
  final int cluster;
  final int xAdvance;
  final int yAdvance;
  final int xOffset;
  final int yOffset;
}

class _ShapedRun {
  const _ShapedRun({
    required this.sourceText,
    required this.font,
    required this.glyphs,
  });

  final String sourceText;
  final _ShapedFont font;
  final List<_ShapedGlyph> glyphs;

  int get signedAdvance =>
      glyphs.fold<int>(0, (sum, glyph) => sum + glyph.xAdvance);
  int get advance => signedAdvance.abs();
}

class _HarfBuzzShaper {
  const _HarfBuzzShaper();

  _ShapedRun shape(String text, {required _ShapedFont font}) {
    if (text.isEmpty) {
      return _ShapedRun(
        sourceText: text,
        font: font,
        glyphs: const <_ShapedGlyph>[],
      );
    }

    final utf8Bytes = utf8.encode(text);
    final nativeText = calloc<Uint8>(utf8Bytes.length);
    nativeText.asTypedList(utf8Bytes.length).setAll(0, utf8Bytes);
    final buffer = hb.hb_buffer_create();
    if (buffer == nullptr) {
      calloc.free(nativeText);
      throw StateError('HarfBuzz could not allocate a shaping buffer.');
    }

    try {
      hb.hb_buffer_add_utf8(
        buffer,
        nativeText.cast<Char>(),
        utf8Bytes.length,
        0,
        utf8Bytes.length,
      );
      hb.hb_buffer_guess_segment_properties(buffer);
      hb.hb_shape(
        font.harfbuzzFont,
        buffer,
        nullptr.cast<hb.hb_feature_t>(),
        0,
      );

      final length = hb.hb_buffer_get_length(buffer);
      if (length == 0) {
        return _ShapedRun(
          sourceText: text,
          font: font,
          glyphs: const <_ShapedGlyph>[],
        );
      }

      final infos = hb.hb_buffer_get_glyph_infos(buffer, nullptr);
      final positions = hb.hb_buffer_get_glyph_positions(buffer, nullptr);
      final glyphs = List<_ShapedGlyph>.generate(length, (index) {
        final info = infos[index];
        final position = positions[index];
        return _ShapedGlyph(
          glyphId: info.codepoint,
          cluster: info.cluster,
          xAdvance: position.x_advance,
          yAdvance: position.y_advance,
          xOffset: position.x_offset,
          yOffset: position.y_offset,
        );
      }, growable: false);

      return _ShapedRun(sourceText: text, font: font, glyphs: glyphs);
    } finally {
      hb.hb_buffer_destroy(buffer);
      calloc.free(nativeText);
    }
  }
}

enum _ShapedTextAlign { start, center, end }

class _ShapedTextStyle {
  const _ShapedTextStyle({
    required this.fonts,
    required this.fontSize,
    required this.color,
    required this.align,
    this.lineHeight,
    this.letterSpacing = 0,
    this.underline = false,
  });

  final List<_ShapedFont> fonts;
  final double fontSize;
  final PdfColor color;
  final _ShapedTextAlign align;
  final double? lineHeight;
  final double letterSpacing;
  final bool underline;
}

class _ShapedText extends pw.Widget with pw.SpanningWidget {
  _ShapedText(
    this.text, {
    required this.style,
    this.maxLines,
  }) : assert(maxLines == null || maxLines > 0);

  final String text;
  final _ShapedTextStyle style;
  final int? maxLines;
  final _HarfBuzzShaper shaper = const _HarfBuzzShaper();
  final _ShapedTextContext shapedContext = _ShapedTextContext();

  List<_LayoutLine> allLines = const <_LayoutLine>[];
  List<_LayoutLine> pageLines = const <_LayoutLine>[];
  double lineHeight = 0;
  double ascent = 0;

  @override
  bool get canSpan => true;

  @override
  bool get hasMoreWidgets => shapedContext.lineEnd < allLines.length;

  @override
  pw.WidgetContext saveContext() => shapedContext;

  @override
  void restoreContext(covariant _ShapedTextContext context) {
    shapedContext.lineStart = context.lineEnd;
    shapedContext.lineEnd = context.lineEnd;
  }

  @override
  void layout(
    pw.Context context,
    pw.BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    final widthLimit =
        constraints.hasBoundedWidth ? constraints.maxWidth : double.infinity;

    final naturalLineHeight = style.fonts
        .map((font) => font.metrics.lineHeightFor(style.fontSize))
        .reduce((a, b) => a > b ? a : b);
    lineHeight = naturalLineHeight * (style.lineHeight ?? 1);
    ascent = style.fonts
        .map((font) => font.metrics.ascentFor(style.fontSize))
        .reduce((a, b) => a > b ? a : b);

    final lines = <_LayoutLine>[];
    for (final paragraph in text.split('\n')) {
      if (paragraph.isEmpty) {
        lines.add(const _LayoutLine.empty());
      } else {
        lines.addAll(_wrapParagraph(paragraph, widthLimit));
      }
      if (maxLines != null && lines.length >= maxLines!) break;
    }

    allLines = maxLines == null
        ? List<_LayoutLine>.unmodifiable(lines)
        : List<_LayoutLine>.unmodifiable(lines.take(maxLines!));

    final start = math.min(shapedContext.lineStart, allLines.length);
    final end = constraints.hasBoundedHeight
        ? math.min(
            allLines.length,
            start + math.max(0, (constraints.maxHeight / lineHeight).floor()),
          )
        : allLines.length;

    shapedContext.lineEnd = end.toInt();
    pageLines = List<_LayoutLine>.unmodifiable(
      allLines.sublist(start, end.toInt()),
    );

    final naturalWidth = pageLines.fold<double>(
      0,
      (current, line) => current > line.width ? current : line.width,
    );
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth(naturalWidth);
    final height = constraints.constrainHeight(lineHeight * pageLines.length);
    box = PdfRect(0, 0, width, height);
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);
    final bounds = box;
    if (bounds == null || pageLines.isEmpty) return;

    final canvas = context.canvas;
    canvas.saveContext();
    try {
      canvas.setFillColor(style.color);
      for (var lineIndex = 0; lineIndex < pageLines.length; lineIndex++) {
        final line = pageLines[lineIndex];
        final baseline =
            bounds.bottom + bounds.height - ascent - lineIndex * lineHeight;
        final lineX = bounds.left + _alignedOffset(bounds.width, line.width);
        var runX = lineX;
        for (final run in line.runs) {
          _paintRun(canvas, run, runX, baseline);

          // Keep the logical/original Unicode searchable. The visible layer is
          // vector outlines, so this invisible text is the only semantic text
          // operator for shaped runs and therefore avoids extractor-inserted
          // spaces between Indic combining characters.
          if (run.sourceText.isNotEmpty) {
            final pdfFont = run.font.pdfFont.getFont(context);
            canvas.drawString(
              pdfFont,
              style.fontSize,
              run.sourceText,
              runX,
              baseline,
              mode: PdfTextRenderingMode.invisible,
            );
          }
          runX += _runWidth(run);
        }
        if (style.underline && line.width > 0) {
          canvas
            ..setStrokeColor(style.color)
            ..setLineWidth(
              style.fontSize * 0.05 > 0.4 ? style.fontSize * 0.05 : 0.4,
            )
            ..drawLine(
              lineX,
              baseline - style.fontSize * 0.12,
              lineX + line.width,
              baseline - style.fontSize * 0.12,
            )
            ..strokePath();
        }
      }
    } finally {
      canvas.restoreContext();
    }
  }

  List<_LayoutLine> _wrapParagraph(String paragraph, double widthLimit) {
    if (!widthLimit.isFinite) return <_LayoutLine>[_shapeLine(paragraph)];

    final tokens = RegExp(r'\s+|\S+')
        .allMatches(paragraph)
        .map((match) => match.group(0)!)
        .toList(growable: false);
    final result = <_LayoutLine>[];
    var current = '';

    for (final token in tokens) {
      if (current.isEmpty) {
        final first = _shapeLine(token);
        if (first.width <= widthLimit || token.trim().isEmpty) {
          current = token;
        } else {
          final split = _splitOversizedToken(token, widthLimit);
          result.addAll(split.lines);
          current = split.remainder;
        }
        continue;
      }

      final candidate = current + token;
      if (_shapeLine(candidate).width <= widthLimit) {
        current = candidate;
        continue;
      }

      final completed = current.trimRight();
      if (completed.isNotEmpty) result.add(_shapeLine(completed));
      current = token.trimLeft();
      if (current.isNotEmpty && _shapeLine(current).width > widthLimit) {
        final split = _splitOversizedToken(current, widthLimit);
        result.addAll(split.lines);
        current = split.remainder;
      }
    }

    final completed = current.trimRight();
    if (completed.isNotEmpty || result.isEmpty) {
      result.add(_shapeLine(completed));
    }
    return result;
  }

  _TokenSplit _splitOversizedToken(String token, double widthLimit) {
    final lines = <_LayoutLine>[];
    var current = '';
    for (final character in token.characters) {
      final candidate = current + character;
      if (current.isEmpty || _shapeLine(candidate).width <= widthLimit) {
        current = candidate;
      } else {
        lines.add(_shapeLine(current));
        current = character;
      }
    }
    return _TokenSplit(lines: lines, remainder: current);
  }

  _LayoutLine _shapeLine(String source) {
    if (source.isEmpty) return const _LayoutLine.empty();
    final sourceRuns = _segment(source);
    final runs = sourceRuns
        .map((run) => shaper.shape(run.text, font: run.font))
        .toList(growable: false);
    final width = runs.fold<double>(0, (sum, run) => sum + _runWidth(run));
    return _LayoutLine(runs: runs, width: width);
  }

  List<_SourceRun> _segment(String source) {
    final result = <_SourceRun>[];
    final buffer = StringBuffer();
    _ShapedFont? currentFont;
    hb.hb_script_t? currentScript;
    hb.hb_script_t? inheritedScript;

    void flush() {
      final value = buffer.toString();
      if (value.isNotEmpty && currentFont != null) {
        result.add(_SourceRun(text: value, font: currentFont!));
      }
      buffer.clear();
      currentFont = null;
      currentScript = null;
    }

    final unicodeFunctions = hb.hb_unicode_funcs_get_default();
    for (final rune in source.runes) {
      final rawScript = hb.hb_unicode_script(unicodeFunctions, rune);
      final isCommon = rawScript == hb.hb_script_t.HB_SCRIPT_COMMON ||
          rawScript == hb.hb_script_t.HB_SCRIPT_INHERITED ||
          rawScript == hb.hb_script_t.HB_SCRIPT_UNKNOWN;
      final effectiveScript = isCommon
          ? (inheritedScript ?? rawScript)
          : rawScript;
      if (!isCommon) inheritedScript = rawScript;

      final selectedFont = _fontForRune(rune, currentFont);
      final shouldSplit = buffer.length > 0 &&
          (currentFont != selectedFont ||
              (!isCommon &&
                  currentScript != null &&
                  effectiveScript != currentScript));
      if (shouldSplit) flush();

      currentFont = selectedFont;
      currentScript ??= effectiveScript;
      buffer.writeCharCode(rune);
    }
    flush();
    return result;
  }

  _ShapedFont _fontForRune(int rune, _ShapedFont? current) {
    if (current != null &&
        (PdfComplexTextService._isWhitespace(rune) ||
            PdfComplexTextService._isJoinControl(rune))) {
      return current;
    }
    if (current != null && current.supportsRune(rune)) return current;
    for (final font in style.fonts) {
      if (font.supportsRune(rune)) return font;
    }
    final code = rune.toRadixString(16).toUpperCase().padLeft(4, '0');
    throw StateError(
      'No shaping font supports "${String.fromCharCode(rune)}" (U+$code). '
      'Fonts checked: ${style.fonts.map((font) => font.name).join(', ')}.',
    );
  }

  void _paintRun(
    PdfGraphics canvas,
    _ShapedRun run,
    double originX,
    double baseline,
  ) {
    final scale = style.fontSize / run.font.metrics.unitsPerEm;
    final signedAdvance = run.signedAdvance;
    var cursor = signedAdvance < 0 ? run.advance.toDouble() : 0.0;
    for (var index = 0; index < run.glyphs.length; index++) {
      final glyph = run.glyphs[index];
      final glyphOriginX = originX + (cursor + glyph.xOffset) * scale;
      final glyphOriginY = baseline + glyph.yOffset * scale;
      run.font.paintGlyph(
        canvas,
        glyph.glyphId,
        originX: glyphOriginX,
        originY: glyphOriginY,
        scale: scale,
      );
      cursor += glyph.xAdvance;
      if (style.letterSpacing != 0 &&
          index + 1 < run.glyphs.length &&
          run.glyphs[index + 1].cluster != glyph.cluster) {
        cursor += style.letterSpacing / scale;
      }
    }
  }

  int _clusterGapCount(_ShapedRun run) {
    if (run.glyphs.length < 2) return 0;
    var gaps = 0;
    for (var index = 0; index + 1 < run.glyphs.length; index++) {
      if (run.glyphs[index + 1].cluster != run.glyphs[index].cluster) {
        gaps++;
      }
    }
    return gaps;
  }

  double _runWidth(_ShapedRun run) {
    final scale = style.fontSize / run.font.metrics.unitsPerEm;
    return run.advance * scale + _clusterGapCount(run) * style.letterSpacing;
  }

  double _alignedOffset(double available, double lineWidth) {
    return switch (style.align) {
      _ShapedTextAlign.start => 0,
      _ShapedTextAlign.center => (available - lineWidth) / 2,
      _ShapedTextAlign.end => available - lineWidth,
    };
  }
}

class _ShapedTextContext extends pw.WidgetContext {
  int lineStart = 0;
  int lineEnd = 0;

  @override
  void apply(covariant _ShapedTextContext other) {
    lineStart = other.lineStart;
    lineEnd = other.lineEnd;
  }

  @override
  pw.WidgetContext clone() => _ShapedTextContext()
    ..lineStart = lineStart
    ..lineEnd = lineEnd;
}

class _SourceRun {
  const _SourceRun({required this.text, required this.font});
  final String text;
  final _ShapedFont font;
}

class _LayoutLine {
  const _LayoutLine({required this.runs, required this.width});
  const _LayoutLine.empty() : runs = const <_ShapedRun>[], width = 0;
  final List<_ShapedRun> runs;
  final double width;
}

class _TokenSplit {
  const _TokenSplit({required this.lines, required this.remainder});
  final List<_LayoutLine> lines;
  final String remainder;
}

sealed class _GlyphPathCommand {
  const _GlyphPathCommand();
  void replay(
    PdfGraphics canvas, {
    required double originX,
    required double originY,
    required double scale,
  });
}

class _GlyphMoveTo extends _GlyphPathCommand {
  const _GlyphMoveTo(this.x, this.y);
  final double x;
  final double y;

  @override
  void replay(
    PdfGraphics canvas, {
    required double originX,
    required double originY,
    required double scale,
  }) {
    canvas.moveTo(originX + x * scale, originY + y * scale);
  }
}

class _GlyphLineTo extends _GlyphPathCommand {
  const _GlyphLineTo(this.x, this.y);
  final double x;
  final double y;

  @override
  void replay(
    PdfGraphics canvas, {
    required double originX,
    required double originY,
    required double scale,
  }) {
    canvas.lineTo(originX + x * scale, originY + y * scale);
  }
}

class _GlyphCubicTo extends _GlyphPathCommand {
  const _GlyphCubicTo(
    this.x1,
    this.y1,
    this.x2,
    this.y2,
    this.x3,
    this.y3,
  );
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double x3;
  final double y3;

  @override
  void replay(
    PdfGraphics canvas, {
    required double originX,
    required double originY,
    required double scale,
  }) {
    canvas.curveTo(
      originX + x1 * scale,
      originY + y1 * scale,
      originX + x2 * scale,
      originY + y2 * scale,
      originX + x3 * scale,
      originY + y3 * scale,
    );
  }
}

class _GlyphClosePath extends _GlyphPathCommand {
  const _GlyphClosePath();

  @override
  void replay(
    PdfGraphics canvas, {
    required double originX,
    required double originY,
    required double scale,
  }) {
    canvas.closePath();
  }
}

class _GlyphOutline {
  const _GlyphOutline(this.commands);
  final List<_GlyphPathCommand> commands;
  bool get isEmpty => commands.isEmpty;
}

class _HarfBuzzGlyphOutlineExtractor {
  _HarfBuzzGlyphOutlineExtractor() : drawFuncs = hb.hb_draw_funcs_create() {
    if (drawFuncs == nullptr) {
      throw StateError('HarfBuzz could not create glyph draw callbacks.');
    }
    final noDestroy =
        nullptr.cast<NativeFunction<hb.hb_destroy_func_tFunction>>();
    hb.hb_draw_funcs_set_move_to_func(
      drawFuncs,
      moveToPointer,
      nullptr,
      noDestroy,
    );
    hb.hb_draw_funcs_set_line_to_func(
      drawFuncs,
      lineToPointer,
      nullptr,
      noDestroy,
    );
    hb.hb_draw_funcs_set_quadratic_to_func(
      drawFuncs,
      quadraticToPointer,
      nullptr,
      noDestroy,
    );
    hb.hb_draw_funcs_set_cubic_to_func(
      drawFuncs,
      cubicToPointer,
      nullptr,
      noDestroy,
    );
    hb.hb_draw_funcs_set_close_path_func(
      drawFuncs,
      closePathPointer,
      nullptr,
      noDestroy,
    );
  }

  final Pointer<hb.hb_draw_funcs_t> drawFuncs;
  final Map<int, _GlyphOutline> cache = <int, _GlyphOutline>{};
  static int nextSession = 1;
  static final Map<int, List<_GlyphPathCommand>> sessions =
      <int, List<_GlyphPathCommand>>{};

  _GlyphOutline outline(Pointer<hb.hb_font_t> font, int glyphId) {
    return cache.putIfAbsent(glyphId, () {
      final session = nextSession++;
      final commands = <_GlyphPathCommand>[];
      sessions[session] = commands;
      try {
        hb.hb_font_draw_glyph(
          font,
          glyphId,
          drawFuncs,
          Pointer<Void>.fromAddress(session),
        );
        return _GlyphOutline(List<_GlyphPathCommand>.unmodifiable(commands));
      } finally {
        sessions.remove(session);
      }
    });
  }

  static List<_GlyphPathCommand>? _commands(Pointer<Void> drawData) =>
      sessions[drawData.address];

  static void _moveTo(
    Pointer<hb.hb_draw_funcs_t> funcs,
    Pointer<Void> drawData,
    Pointer<hb.hb_draw_state_t> state,
    double x,
    double y,
    Pointer<Void> userData,
  ) {
    _commands(drawData)?.add(_GlyphMoveTo(x, y));
  }

  static void _lineTo(
    Pointer<hb.hb_draw_funcs_t> funcs,
    Pointer<Void> drawData,
    Pointer<hb.hb_draw_state_t> state,
    double x,
    double y,
    Pointer<Void> userData,
  ) {
    _commands(drawData)?.add(_GlyphLineTo(x, y));
  }

  static void _quadraticTo(
    Pointer<hb.hb_draw_funcs_t> funcs,
    Pointer<Void> drawData,
    Pointer<hb.hb_draw_state_t> state,
    double controlX,
    double controlY,
    double toX,
    double toY,
    Pointer<Void> userData,
  ) {
    final commands = _commands(drawData);
    if (commands == null) return;
    final fromX = state.ref.current_x;
    final fromY = state.ref.current_y;
    final c1X = fromX + (2 / 3) * (controlX - fromX);
    final c1Y = fromY + (2 / 3) * (controlY - fromY);
    final c2X = toX + (2 / 3) * (controlX - toX);
    final c2Y = toY + (2 / 3) * (controlY - toY);
    commands.add(_GlyphCubicTo(c1X, c1Y, c2X, c2Y, toX, toY));
  }

  static void _cubicTo(
    Pointer<hb.hb_draw_funcs_t> funcs,
    Pointer<Void> drawData,
    Pointer<hb.hb_draw_state_t> state,
    double control1X,
    double control1Y,
    double control2X,
    double control2Y,
    double toX,
    double toY,
    Pointer<Void> userData,
  ) {
    _commands(drawData)?.add(
      _GlyphCubicTo(control1X, control1Y, control2X, control2Y, toX, toY),
    );
  }

  static void _closePath(
    Pointer<hb.hb_draw_funcs_t> funcs,
    Pointer<Void> drawData,
    Pointer<hb.hb_draw_state_t> state,
    Pointer<Void> userData,
  ) {
    _commands(drawData)?.add(const _GlyphClosePath());
  }

  static final hb.hb_draw_move_to_func_t moveToPointer =
      Pointer.fromFunction<hb.hb_draw_move_to_func_tFunction>(_moveTo);
  static final hb.hb_draw_line_to_func_t lineToPointer =
      Pointer.fromFunction<hb.hb_draw_line_to_func_tFunction>(_lineTo);
  static final hb.hb_draw_quadratic_to_func_t quadraticToPointer =
      Pointer.fromFunction<hb.hb_draw_quadratic_to_func_tFunction>(
    _quadraticTo,
  );
  static final hb.hb_draw_cubic_to_func_t cubicToPointer =
      Pointer.fromFunction<hb.hb_draw_cubic_to_func_tFunction>(_cubicTo);
  static final hb.hb_draw_close_path_func_t closePathPointer =
      Pointer.fromFunction<hb.hb_draw_close_path_func_tFunction>(_closePath);
}
