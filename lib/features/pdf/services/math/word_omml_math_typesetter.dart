import 'package:edusheet/features/math_keyboard/domain/services/math_export_typesetting.dart';

/// Converts the Phase 8 export-neutral math tree into native Word OMML.
///
/// The returned XML is intended to be embedded inside a `<w:p>` and requires
/// the document root to declare the Office Math namespace as `m`.
class WordOmmlMathTypesetter {
  const WordOmmlMathTypesetter();

  String? inlineSource(String source) {
    final node = MathExportTypesettingCache.shared.compile(source);
    if (node == null) return null;
    return '<m:oMath>${_node(node)}</m:oMath>';
  }

  String? displaySource(String source) {
    final inline = inlineSource(source);
    if (inline == null) return null;
    return '<m:oMathPara>$inline</m:oMathPara>';
  }

  String _node(MathExportNode node) {
    return switch (node) {
      MathExportText() => _run(
        node.value,
        upright: node.upright,
        bold: node.bold,
      ),
      MathExportSequence() => node.children.map(_node).join(),
      MathExportFraction() =>
        '<m:f><m:fPr/><m:num>${_node(node.numerator)}</m:num>'
            '<m:den>${_node(node.denominator)}</m:den></m:f>',
      MathExportBinomial() => _delimiter(
        '(',
        _matrix([
          [node.top],
          [node.bottom],
        ]),
        ')',
      ),
      MathExportRoot() => _root(node),
      MathExportScript() => _script(node),
      MathExportAccent() => _accent(node),
      MathExportDelimited() => _delimiter(
        node.left,
        _node(node.body),
        node.right,
      ),
      MathExportMatrix() => _matrixNode(node),
    };
  }

  String _run(String value, {bool upright = false, bool bold = false}) {
    final properties = StringBuffer();
    if (upright) {
      properties.write('<m:rPr><m:sty m:val="p"/></m:rPr>');
    }
    final wordProperties = bold ? '<w:rPr><w:b/></w:rPr>' : '';
    return '<m:r>$properties$wordProperties<m:t>${_xml(value)}</m:t></m:r>';
  }

  String _root(MathExportRoot node) {
    final hide = node.index == null ? '<m:degHide m:val="1"/>' : '';
    final degree = node.index == null ? '' : _node(node.index!);
    return '<m:rad><m:radPr>$hide</m:radPr><m:deg>$degree</m:deg>'
        '<m:e>${_node(node.radicand)}</m:e></m:rad>';
  }

  String _script(MathExportScript node) {
    final base = '<m:e>${_node(node.base)}</m:e>';
    final sub = node.subscript == null
        ? ''
        : '<m:sub>${_node(node.subscript!)}</m:sub>';
    final sup = node.superscript == null
        ? ''
        : '<m:sup>${_node(node.superscript!)}</m:sup>';
    if (node.subscript != null && node.superscript != null) {
      return '<m:sSubSup><m:sSubSupPr/>$base$sub$sup</m:sSubSup>';
    }
    if (node.subscript != null) {
      return '<m:sSub><m:sSubPr/>$base$sub</m:sSub>';
    }
    return '<m:sSup><m:sSupPr/>$base$sup</m:sSup>';
  }

  String _accent(MathExportAccent node) {
    final character = switch (node.kind) {
      MathExportAccentKind.vector => '→',
      MathExportAccentKind.overline || MathExportAccentKind.bar => '¯',
      MathExportAccentKind.hat => '̂',
      MathExportAccentKind.tilde => '̃',
    };
    return '<m:acc><m:accPr><m:chr m:val="${_xml(character)}"/></m:accPr>'
        '<m:e>${_node(node.body)}</m:e></m:acc>';
  }

  String _delimiter(String left, String body, String right) {
    final begin = left.isEmpty
        ? '<m:begChr m:val=""/>'
        : '<m:begChr m:val="${_xml(left)}"/>';
    final end = right.isEmpty
        ? '<m:endChr m:val=""/>'
        : '<m:endChr m:val="${_xml(right)}"/>';
    return '<m:d><m:dPr>$begin$end<m:grow m:val="1"/></m:dPr>'
        '<m:e>$body</m:e></m:d>';
  }

  String _matrixNode(MathExportMatrix node) {
    final body = _matrix(node.rows);
    if (node.leftDelimiter.isEmpty && node.rightDelimiter.isEmpty) return body;
    return _delimiter(node.leftDelimiter, body, node.rightDelimiter);
  }

  String _matrix(List<List<MathExportNode>> rows) {
    final rowXml = rows.map((row) {
      final cells = row.map((cell) => '<m:e>${_node(cell)}</m:e>').join();
      return '<m:mr>$cells</m:mr>';
    }).join();
    return '<m:m><m:mPr/>$rowXml</m:m>';
  }

  static String _xml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
