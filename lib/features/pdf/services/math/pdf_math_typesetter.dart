import 'package:edusheet/features/math_keyboard/domain/services/math_export_typesetting.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Native PDF renderer for the export-neutral Phase 8 math tree.
class PdfMathTypesetter {
  const PdfMathTypesetter();

  pw.Widget? buildSource(String source, {required double fontSize}) {
    final node = MathExportTypesettingCache.shared.compile(source);
    if (node == null) return null;
    return buildNode(node, fontSize: fontSize);
  }

  pw.Widget buildNode(MathExportNode node, {required double fontSize}) {
    return switch (node) {
      MathExportText() => _text(node, fontSize),
      MathExportSequence() => _sequence(node, fontSize),
      MathExportFraction() => _fraction(node, fontSize),
      MathExportBinomial() => _binomial(node, fontSize),
      MathExportRoot() => _root(node, fontSize),
      MathExportScript() => _script(node, fontSize),
      MathExportAccent() => _accent(node, fontSize),
      MathExportDelimited() => _delimited(node, fontSize),
      MathExportMatrix() => _matrix(node, fontSize),
    };
  }

  pw.Widget _text(MathExportText node, double fontSize) {
    return pw.Text(
      node.value,
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: node.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        fontStyle: node.upright ? pw.FontStyle.normal : pw.FontStyle.italic,
      ),
    );
  }

  pw.Widget _sequence(MathExportSequence node, double fontSize) {
    if (node.children.isEmpty) return pw.SizedBox();
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisSize: pw.MainAxisSize.min,
      children: node.children
          .map((child) => buildNode(child, fontSize: fontSize))
          .toList(growable: false),
    );
  }

  pw.Widget _fraction(MathExportFraction node, double fontSize) {
    final inner = fontSize * 0.82;
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2),
          child: buildNode(node.numerator, fontSize: inner),
        ),
        pw.Container(height: 0.7, color: PdfColors.black),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 2),
          child: buildNode(node.denominator, fontSize: inner),
        ),
      ],
    );
  }

  pw.Widget _binomial(MathExportBinomial node, double fontSize) {
    return _delimited(
      MathExportDelimited(
        '(',
        MathExportMatrix(
          rows: [
            [node.top],
            [node.bottom],
          ],
        ),
        ')',
      ),
      fontSize,
    );
  }

  pw.Widget _root(MathExportRoot node, double fontSize) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        if (node.index != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 1),
            child: buildNode(node.index!, fontSize: fontSize * 0.55),
          ),
        pw.Text('√', style: pw.TextStyle(fontSize: fontSize * 1.15)),
        pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(width: 0.7)),
          ),
          padding: const pw.EdgeInsets.only(top: 1, left: 1, right: 1),
          child: buildNode(node.radicand, fontSize: fontSize),
        ),
      ],
    );
  }

  pw.Widget _script(MathExportScript node, double fontSize) {
    final scriptSize = fontSize * 0.62;
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        buildNode(node.base, fontSize: fontSize),
        if (node.subscript != null || node.superscript != null)
          pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (node.superscript != null)
                buildNode(node.superscript!, fontSize: scriptSize),
              if (node.subscript != null)
                buildNode(node.subscript!, fontSize: scriptSize),
            ],
          ),
      ],
    );
  }

  pw.Widget _accent(MathExportAccent node, double fontSize) {
    final accent = switch (node.kind) {
      MathExportAccentKind.vector => '→',
      MathExportAccentKind.hat => '^',
      MathExportAccentKind.tilde => '~',
      MathExportAccentKind.bar || MathExportAccentKind.overline => '',
    };
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (accent.isNotEmpty)
          pw.Text(accent, style: pw.TextStyle(fontSize: fontSize * 0.72))
        else
          pw.Container(height: 0.7, color: PdfColors.black),
        buildNode(node.body, fontSize: fontSize),
      ],
    );
  }

  pw.Widget _delimited(MathExportDelimited node, double fontSize) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (node.left.isNotEmpty)
          pw.Text(node.left, style: pw.TextStyle(fontSize: fontSize * 1.25)),
        buildNode(node.body, fontSize: fontSize),
        if (node.right.isNotEmpty)
          pw.Text(node.right, style: pw.TextStyle(fontSize: fontSize * 1.25)),
      ],
    );
  }

  pw.Widget _matrix(MathExportMatrix node, double fontSize) {
    final table = pw.Table(
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: node.rows
          .map(
            (row) => pw.TableRow(
              children: row
                  .map(
                    (cell) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1.5,
                      ),
                      child: buildNode(cell, fontSize: fontSize * 0.9),
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
    if (node.leftDelimiter.isEmpty && node.rightDelimiter.isEmpty) {
      return table;
    }
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (node.leftDelimiter.isNotEmpty)
          pw.Text(
            node.leftDelimiter,
            style: pw.TextStyle(fontSize: fontSize * 1.4),
          ),
        table,
        if (node.rightDelimiter.isNotEmpty)
          pw.Text(
            node.rightDelimiter,
            style: pw.TextStyle(fontSize: fontSize * 1.4),
          ),
      ],
    );
  }
}
