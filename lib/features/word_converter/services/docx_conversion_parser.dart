import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart' as xml;

class DocxConversionParser {
  static Future<ConversionDocument> parse(File file) async {
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final entries = <String, ArchiveFile>{
      for (final entry in archive.files) entry.name: entry,
    };

    final documentEntry = entries['word/document.xml'];
    if (documentEntry == null) {
      throw const FormatException('Invalid .docx file: word/document.xml is missing.');
    }

    final styles = _StylesCatalog.fromEntry(entries['word/styles.xml']);
    final numbering = _NumberingCatalog.fromEntries(entries);
    final relationships = _RelationshipCatalog.fromEntry(
      entries['word/_rels/document.xml.rels'],
      baseDirectory: 'word',
    );
    final context = _ParseContext(
      entries: entries,
      styles: styles,
      numbering: numbering,
    );

    final document = _parseXml(documentEntry);
    final body = document.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local == 'body')
        .firstOrNull;
    if (body == null) {
      throw const FormatException('Invalid .docx file: document body is missing.');
    }

    final sections = <ConversionSection>[];
    var pendingBlocks = <ConversionBlock>[];
    xml.XmlElement? finalSectionProperties;
    var inheritedHeader = const <ConversionBlock>[];
    var inheritedFooter = const <ConversionBlock>[];

    for (final child in body.childElements) {
      switch (child.name.local) {
        case 'p':
          final paragraph = context.parseParagraph(child, relationships);
          pendingBlocks.add(paragraph);
          final paragraphSection = _directChild(
            _directChild(child, 'pPr'),
            'sectPr',
          );
          if (paragraphSection != null) {
            final section = context.buildSection(
              pendingBlocks,
              paragraphSection,
              relationships,
              inheritedHeader: inheritedHeader,
              inheritedFooter: inheritedFooter,
            );
            sections.add(section);
            inheritedHeader = section.headerBlocks;
            inheritedFooter = section.footerBlocks;
            pendingBlocks = <ConversionBlock>[];
          }
          break;
        case 'tbl':
          pendingBlocks.add(context.parseTable(child, relationships));
          break;
        case 'sectPr':
          finalSectionProperties = child;
          break;
      }
    }

    if (pendingBlocks.isNotEmpty || sections.isEmpty) {
      sections.add(
        context.buildSection(
          pendingBlocks,
          finalSectionProperties,
          relationships,
          inheritedHeader: inheritedHeader,
          inheritedFooter: inheritedFooter,
        ),
      );
    }

    return ConversionDocument(sections: sections);
  }

  static xml.XmlDocument _parseXml(ArchiveFile entry) {
    return xml.XmlDocument.parse(utf8.decode(entry.content));
  }

  static xml.XmlElement? _directChild(xml.XmlElement? parent, String local) {
    if (parent == null) return null;
    for (final child in parent.childElements) {
      if (child.name.local == local) return child;
    }
    return null;
  }
}

class _ParseContext {
  _ParseContext({
    required this.entries,
    required this.styles,
    required this.numbering,
  });

  final Map<String, ArchiveFile> entries;
  final _StylesCatalog styles;
  final _NumberingCatalog numbering;

  ConversionSection buildSection(
    List<ConversionBlock> blocks,
    xml.XmlElement? sectionProperties,
    _RelationshipCatalog documentRelationships, {
    List<ConversionBlock> inheritedHeader = const [],
    List<ConversionBlock> inheritedFooter = const [],
  }) {
    final settings = _pageSettings(sectionProperties);
    final headerBlocks = _relatedStoryBlocks(
      sectionProperties,
      relationshipLocalName: 'headerReference',
      documentRelationships: documentRelationships,
    );
    final footerBlocks = _relatedStoryBlocks(
      sectionProperties,
      relationshipLocalName: 'footerReference',
      documentRelationships: documentRelationships,
    );
    return ConversionSection(
      page: settings,
      blocks: List<ConversionBlock>.unmodifiable(blocks),
      headerBlocks: headerBlocks.isEmpty ? inheritedHeader : headerBlocks,
      footerBlocks: footerBlocks.isEmpty ? inheritedFooter : footerBlocks,
    );
  }

  List<ConversionBlock> _relatedStoryBlocks(
    xml.XmlElement? sectionProperties, {
    required String relationshipLocalName,
    required _RelationshipCatalog documentRelationships,
  }) {
    if (sectionProperties == null) return const [];
    final refs = sectionProperties.childElements.where(
      (element) => element.name.local == relationshipLocalName,
    );
    xml.XmlElement? preferred;
    for (final ref in refs) {
      final type = _attribute(ref, 'type');
      if (preferred == null || type == 'default') preferred = ref;
      if (type == 'default') break;
    }
    if (preferred == null) return const [];

    final relationshipId = _attribute(preferred, 'id');
    final relationship = documentRelationships.byId(relationshipId);
    if (relationship == null || relationship.isExternal) return const [];
    final entry = entries[relationship.target];
    if (entry == null) return const [];

    final relPath = _relationshipPartPath(relationship.target);
    final storyRelationships = _RelationshipCatalog.fromEntry(
      entries[relPath],
      baseDirectory: p.posix.dirname(relationship.target),
    );
    final story = _parseXml(entry);
    final blocks = <ConversionBlock>[];
    for (final child in story.rootElement.childElements) {
      if (child.name.local == 'p') {
        final paragraph = parseParagraph(child, storyRelationships);
        blocks.add(paragraph);
      } else if (child.name.local == 'tbl') {
        blocks.add(parseTable(child, storyRelationships));
      }
    }
    return blocks;
  }

  ConversionParagraph parseParagraph(
    xml.XmlElement element,
    _RelationshipCatalog relationships,
  ) {
    final pPr = _directChild(element, 'pPr');
    final paragraphStyleId = _attribute(_directChild(pPr, 'pStyle'), 'val');
    final paragraphStyle = styles.resolveParagraph(paragraphStyleId);
    final directParagraph = _parseParagraphProperties(pPr);
    final mergedParagraph = paragraphStyle.merge(directParagraph);

    final paragraphRunBase = styles.resolveRun(paragraphStyleId).merge(
      _parseRunProperties(_directChild(pPr, 'rPr')),
    );
    final inlines = <ConversionInline>[];
    var insideField = false;
    var fieldSeparated = false;
    var fieldRendered = false;
    final fieldInstruction = StringBuffer();

    for (final child in element.childElements) {
      if (child.name.local == 'r') {
        final fieldChars = child.descendants
            .whereType<xml.XmlElement>()
            .where((element) => element.name.local == 'fldChar')
            .toList(growable: false);
        final instructionPieces = child.descendants
            .whereType<xml.XmlElement>()
            .where((element) => element.name.local == 'instrText')
            .map((element) => element.innerText);

        for (final fieldChar in fieldChars) {
          final type = _attribute(fieldChar, 'fldCharType');
          if (type == 'begin') {
            insideField = true;
            fieldSeparated = false;
            fieldRendered = false;
            fieldInstruction.clear();
          } else if (type == 'separate') {
            fieldSeparated = true;
          }
        }
        for (final piece in instructionPieces) {
          fieldInstruction.write(piece);
        }

        final dynamicField = _dynamicField(fieldInstruction.toString());
        final parsedRun = _parseRun(
          child,
          relationships,
          paragraphRunBase: paragraphRunBase,
        );
        final containsResultText = parsedRun.any(
          (inline) => inline is ConversionTextRun && inline.text.isNotEmpty,
        );

        if (insideField && fieldSeparated && dynamicField != null) {
          if (!fieldRendered && containsResultText) {
            final resultStyle = parsedRun
                .whereType<ConversionTextRun>()
                .firstOrNull
                ?.style ??
                paragraphRunBase.toModel();
            inlines.add(
              ConversionDynamicFieldRun(
                field: dynamicField,
                style: resultStyle,
              ),
            );
            fieldRendered = true;
          }
        } else {
          inlines.addAll(parsedRun);
        }

        if (fieldChars.any(
          (fieldChar) => _attribute(fieldChar, 'fldCharType') == 'end',
        )) {
          insideField = false;
          fieldSeparated = false;
          fieldRendered = false;
          fieldInstruction.clear();
        }
      } else if (child.name.local == 'hyperlink') {
        final relationshipId = _attribute(child, 'id');
        final target = relationships.byId(relationshipId)?.externalTarget;
        for (final run in child.childElements.where((e) => e.name.local == 'r')) {
          inlines.addAll(
            _parseRun(
              run,
              relationships,
              paragraphRunBase: paragraphRunBase,
              hyperlink: target,
            ),
          );
        }
      } else if (child.name.local == 'fldSimple') {
        final dynamicField = _dynamicField(_attribute(child, 'instr'));
        final runs = child.descendants
            .whereType<xml.XmlElement>()
            .where((element) => element.name.local == 'r')
            .toList(growable: false);
        if (dynamicField != null) {
          final parsed = runs.isEmpty
              ? const <ConversionInline>[]
              : _parseRun(
                  runs.first,
                  relationships,
                  paragraphRunBase: paragraphRunBase,
                );
          final style = parsed.whereType<ConversionTextRun>().firstOrNull?.style ??
              paragraphRunBase.toModel();
          inlines.add(ConversionDynamicFieldRun(field: dynamicField, style: style));
        } else {
          for (final run in runs) {
            inlines.addAll(
              _parseRun(run, relationships, paragraphRunBase: paragraphRunBase),
            );
          }
        }
      }
    }

    final numPr = _directChild(pPr, 'numPr');
    final numId = _attribute(_directChild(numPr, 'numId'), 'val');
    final level = int.tryParse(_attribute(_directChild(numPr, 'ilvl'), 'val') ?? '') ?? 0;
    final listLabel = numbering.nextLabel(numId, level);
    final hasExplicitPageBreak = element.descendants
        .whereType<xml.XmlElement>()
        .any(
          (element) =>
              element.name.local == 'br' && _attribute(element, 'type') == 'page',
        );

    return ConversionParagraph(
      inlines: inlines,
      alignment: mergedParagraph.alignment,
      spaceBeforePoints: mergedParagraph.spaceBeforePoints,
      spaceAfterPoints: mergedParagraph.spaceAfterPoints,
      leftIndentPoints: mergedParagraph.leftIndentPoints,
      rightIndentPoints: mergedParagraph.rightIndentPoints,
      firstLineIndentPoints: mergedParagraph.firstLineIndentPoints,
      pageBreakBefore: mergedParagraph.pageBreakBefore || hasExplicitPageBreak,
      keepWithNext: mergedParagraph.keepWithNext,
      listLabel: listLabel,
    );
  }

  ConversionTable parseTable(
    xml.XmlElement table,
    _RelationshipCatalog relationships,
  ) {
    final rows = <ConversionTableRow>[];
    final tblPr = _directChild(table, 'tblPr');
    final tableStyleId = _attribute(_directChild(tblPr, 'tblStyle'), 'val');
    final borders = _directChild(tblPr, 'tblBorders');
    final hasDirectBorders = borders?.childElements.any(
          (border) {
            final value = _attribute(border, 'val');
            return value != null && value != 'nil' && value != 'none';
          },
        ) ??
        false;
    final showBorders = hasDirectBorders || tableStyleId == 'TableGrid';
    for (final tr in table.childElements.where((e) => e.name.local == 'tr')) {
      final cells = <ConversionTableCell>[];
      for (final tc in tr.childElements.where((e) => e.name.local == 'tc')) {
        final tcPr = _directChild(tc, 'tcPr');
        final widthTwips = double.tryParse(
          _attribute(_directChild(tcPr, 'tcW'), 'w') ?? '',
        );
        final shading = _attribute(_directChild(tcPr, 'shd'), 'fill');
        final blocks = <ConversionBlock>[];
        for (final child in tc.childElements) {
          if (child.name.local == 'p') {
            final paragraph = parseParagraph(child, relationships);
            blocks.add(paragraph);
          } else if (child.name.local == 'tbl') {
            blocks.add(parseTable(child, relationships));
          }
        }
        cells.add(
          ConversionTableCell(
            blocks: blocks,
            shadingHex: _normalizeColor(shading),
            widthPoints: widthTwips == null ? null : widthTwips / 20,
          ),
        );
      }
      if (cells.isNotEmpty) {
        final trPr = _directChild(tr, 'trPr');
        final isHeader = _directChild(trPr, 'tblHeader') != null;
        rows.add(ConversionTableRow(cells: cells, isHeader: isHeader));
      }
    }
    return ConversionTable(rows: rows, showBorders: showBorders);
  }

  List<ConversionInline> _parseRun(
    xml.XmlElement run,
    _RelationshipCatalog relationships, {
    required _RunProperties paragraphRunBase,
    String? hyperlink,
  }) {
    final rPr = _directChild(run, 'rPr');
    final runStyleId = _attribute(_directChild(rPr, 'rStyle'), 'val');
    final effective = paragraphRunBase
        .merge(styles.resolveRunStyleOverride(runStyleId))
        .merge(_parseRunProperties(rPr));
    final style = effective.toModel();
    final result = <ConversionInline>[];
    final textBuffer = StringBuffer();

    void flushText() {
      if (textBuffer.isEmpty) return;
      result.add(
        ConversionTextRun(
          text: textBuffer.toString(),
          style: style,
          hyperlink: hyperlink,
        ),
      );
      textBuffer.clear();
    }

    for (final descendant in run.descendants.whereType<xml.XmlElement>()) {
      switch (descendant.name.local) {
        case 't':
        case 'delText':
          textBuffer.write(descendant.innerText);
          break;
        case 'tab':
          textBuffer.write('\t');
          break;
        case 'br':
        case 'cr':
          final breakType = _attribute(descendant, 'type');
          if (breakType != 'page') {
            textBuffer.write('\n');
          }
          break;
        case 'blip':
          final embed = _attribute(descendant, 'embed');
          final relationship = relationships.byId(embed);
          if (relationship == null || relationship.isExternal) break;
          final entry = entries[relationship.target];
          if (entry == null) break;
          final content = entry.content;
          flushText();
          final extent = _nearestDrawingExtent(descendant);
          result.add(
            ConversionImageRun(
              bytes: content,
              widthPoints: extent.$1,
              heightPoints: extent.$2,
              altText: _nearestDrawingAltText(descendant),
              hyperlink: hyperlink,
            ),
          );
          break;
      }
    }
    flushText();
    return result;
  }

  ConversionDynamicField? _dynamicField(String? instruction) {
    final normalized = instruction?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) return null;
    final fieldName = normalized.split(RegExp(r'\s+')).first;
    return switch (fieldName) {
      'PAGE' => ConversionDynamicField.pageNumber,
      'NUMPAGES' => ConversionDynamicField.pageCount,
      _ => null,
    };
  }

  ConversionPageSettings _pageSettings(xml.XmlElement? sectPr) {
    if (sectPr == null) return const ConversionPageSettings();
    final pgSz = _directChild(sectPr, 'pgSz');
    final pgMar = _directChild(sectPr, 'pgMar');
    final width = _twips(_attribute(pgSz, 'w'), fallback: 11906 / 20);
    final height = _twips(_attribute(pgSz, 'h'), fallback: 16838 / 20);
    return ConversionPageSettings(
      widthPoints: width,
      heightPoints: height,
      marginTopPoints: _twips(_attribute(pgMar, 'top'), fallback: 72),
      marginRightPoints: _twips(_attribute(pgMar, 'right'), fallback: 72),
      marginBottomPoints: _twips(_attribute(pgMar, 'bottom'), fallback: 72),
      marginLeftPoints: _twips(_attribute(pgMar, 'left'), fallback: 72),
      headerDistancePoints: _twips(_attribute(pgMar, 'header'), fallback: 36),
      footerDistancePoints: _twips(_attribute(pgMar, 'footer'), fallback: 36),
    );
  }

  (double, double) _nearestDrawingExtent(xml.XmlElement blip) {
    xml.XmlElement? current = blip.parentElement;
    while (current != null && current.name.local != 'r') {
      if (current.name.local == 'inline' || current.name.local == 'anchor') {
        final extent = current.childElements
            .where((element) => element.name.local == 'extent')
            .firstOrNull;
        final cx = double.tryParse(_attribute(extent, 'cx') ?? '');
        final cy = double.tryParse(_attribute(extent, 'cy') ?? '');
        if (cx != null && cy != null && cx > 0 && cy > 0) {
          return (cx / 12700, cy / 12700);
        }
      }
      current = current.parentElement;
    }
    return (160, 120);
  }

  String? _nearestDrawingAltText(xml.XmlElement blip) {
    xml.XmlElement? current = blip.parentElement;
    while (current != null && current.name.local != 'r') {
      final docPr = current.childElements
          .where((element) => element.name.local == 'docPr')
          .firstOrNull;
      final description = _attribute(docPr, 'descr');
      if (description != null && description.trim().isNotEmpty) {
        return description.trim();
      }
      current = current.parentElement;
    }
    return null;
  }

  static xml.XmlDocument _parseXml(ArchiveFile entry) {
    return xml.XmlDocument.parse(utf8.decode(entry.content));
  }

  static String _relationshipPartPath(String target) {
    final directory = p.posix.dirname(target);
    final fileName = p.posix.basename(target);
    return p.posix.join(directory, '_rels', '$fileName.rels');
  }

  static xml.XmlElement? _directChild(xml.XmlElement? parent, String local) {
    if (parent == null) return null;
    for (final child in parent.childElements) {
      if (child.name.local == local) return child;
    }
    return null;
  }

  static String? _attribute(xml.XmlElement? element, String local) {
    if (element == null) return null;
    for (final attribute in element.attributes) {
      if (attribute.name.local == local) return attribute.value;
    }
    return null;
  }

  static double _twips(String? value, {required double fallback}) {
    final parsed = double.tryParse(value ?? '');
    return parsed == null ? fallback : parsed / 20;
  }

  static String? _normalizeColor(String? value) {
    if (value == null) return null;
    final normalized = value.replaceAll('#', '').trim().toUpperCase();
    if (normalized == 'AUTO' || !RegExp(r'^[0-9A-F]{6}$').hasMatch(normalized)) {
      return null;
    }
    return normalized;
  }
}

class _StylesCatalog {
  _StylesCatalog({
    required this.styles,
    required this.defaultParagraph,
    required this.defaultRun,
  });

  final Map<String, _StyleDefinition> styles;
  final _ParagraphProperties defaultParagraph;
  final _RunProperties defaultRun;

  factory _StylesCatalog.fromEntry(ArchiveFile? entry) {
    if (entry == null) {
      return _StylesCatalog(
        styles: const {},
        defaultParagraph: const _ParagraphProperties(),
        defaultRun: const _RunProperties(),
      );
    }
    final document = xml.XmlDocument.parse(
      utf8.decode(entry.content),
    );
    final root = document.rootElement;
    final docDefaults = root.childElements
        .where((element) => element.name.local == 'docDefaults')
        .firstOrNull;
    final pPrDefault = docDefaults?.childElements
        .where((element) => element.name.local == 'pPrDefault')
        .firstOrNull;
    final rPrDefault = docDefaults?.childElements
        .where((element) => element.name.local == 'rPrDefault')
        .firstOrNull;
    final defaultParagraph = _parseParagraphProperties(
      pPrDefault?.childElements
          .where((element) => element.name.local == 'pPr')
          .firstOrNull,
    );
    final defaultRun = _parseRunProperties(
      rPrDefault?.childElements
          .where((element) => element.name.local == 'rPr')
          .firstOrNull,
    );

    final styles = <String, _StyleDefinition>{};
    for (final element in root.childElements.where(
      (element) => element.name.local == 'style',
    )) {
      final id = _attribute(element, 'styleId');
      if (id == null || id.isEmpty) continue;
      styles[id] = _StyleDefinition(
        basedOn: _attribute(_directChild(element, 'basedOn'), 'val'),
        paragraph: _parseParagraphProperties(_directChild(element, 'pPr')),
        run: _parseRunProperties(_directChild(element, 'rPr')),
      );
    }
    return _StylesCatalog(
      styles: styles,
      defaultParagraph: defaultParagraph,
      defaultRun: defaultRun,
    );
  }

  _ParagraphProperties resolveParagraph(String? styleId) {
    var result = defaultParagraph;
    for (final definition in _styleChain(styleId)) {
      result = result.merge(definition.paragraph);
    }
    return result;
  }

  _RunProperties resolveRun(String? styleId) {
    var result = defaultRun;
    for (final definition in _styleChain(styleId)) {
      result = result.merge(definition.run);
    }
    return result;
  }

  _RunProperties resolveRunStyleOverride(String? styleId) {
    var result = const _RunProperties();
    for (final definition in _styleChain(styleId)) {
      result = result.merge(definition.run);
    }
    return result;
  }

  List<_StyleDefinition> _styleChain(String? styleId) {
    if (styleId == null || styleId.isEmpty) return const [];
    final chain = <_StyleDefinition>[];
    final visited = <String>{};
    String? currentId = styleId;
    while (currentId != null && visited.add(currentId)) {
      final definition = styles[currentId];
      if (definition == null) break;
      chain.add(definition);
      currentId = definition.basedOn;
    }
    return chain.reversed.toList(growable: false);
  }
}

class _StyleDefinition {
  const _StyleDefinition({
    required this.basedOn,
    required this.paragraph,
    required this.run,
  });

  final String? basedOn;
  final _ParagraphProperties paragraph;
  final _RunProperties run;
}

class _ParagraphProperties {
  const _ParagraphProperties({
    this.alignment = ConversionTextAlignment.left,
    this.spaceBeforePoints = 0,
    this.spaceAfterPoints = 6,
    this.leftIndentPoints = 0,
    this.rightIndentPoints = 0,
    this.firstLineIndentPoints = 0,
    this.pageBreakBefore = false,
    this.keepWithNext = false,
    this.hasAlignment = false,
    this.hasSpaceBefore = false,
    this.hasSpaceAfter = false,
    this.hasLeftIndent = false,
    this.hasRightIndent = false,
    this.hasFirstLineIndent = false,
    this.hasPageBreakBefore = false,
    this.hasKeepWithNext = false,
  });

  final ConversionTextAlignment alignment;
  final double spaceBeforePoints;
  final double spaceAfterPoints;
  final double leftIndentPoints;
  final double rightIndentPoints;
  final double firstLineIndentPoints;
  final bool pageBreakBefore;
  final bool keepWithNext;
  final bool hasAlignment;
  final bool hasSpaceBefore;
  final bool hasSpaceAfter;
  final bool hasLeftIndent;
  final bool hasRightIndent;
  final bool hasFirstLineIndent;
  final bool hasPageBreakBefore;
  final bool hasKeepWithNext;

  _ParagraphProperties merge(_ParagraphProperties other) {
    return _ParagraphProperties(
      alignment: other.hasAlignment ? other.alignment : alignment,
      spaceBeforePoints: other.hasSpaceBefore
          ? other.spaceBeforePoints
          : spaceBeforePoints,
      spaceAfterPoints: other.hasSpaceAfter
          ? other.spaceAfterPoints
          : spaceAfterPoints,
      leftIndentPoints: other.hasLeftIndent
          ? other.leftIndentPoints
          : leftIndentPoints,
      rightIndentPoints: other.hasRightIndent
          ? other.rightIndentPoints
          : rightIndentPoints,
      firstLineIndentPoints: other.hasFirstLineIndent
          ? other.firstLineIndentPoints
          : firstLineIndentPoints,
      pageBreakBefore: other.hasPageBreakBefore
          ? other.pageBreakBefore
          : pageBreakBefore,
      keepWithNext: other.hasKeepWithNext ? other.keepWithNext : keepWithNext,
      hasAlignment: hasAlignment || other.hasAlignment,
      hasSpaceBefore: hasSpaceBefore || other.hasSpaceBefore,
      hasSpaceAfter: hasSpaceAfter || other.hasSpaceAfter,
      hasLeftIndent: hasLeftIndent || other.hasLeftIndent,
      hasRightIndent: hasRightIndent || other.hasRightIndent,
      hasFirstLineIndent: hasFirstLineIndent || other.hasFirstLineIndent,
      hasPageBreakBefore: hasPageBreakBefore || other.hasPageBreakBefore,
      hasKeepWithNext: hasKeepWithNext || other.hasKeepWithNext,
    );
  }
}

class _RunProperties {
  const _RunProperties({
    this.fontFamily,
    this.fontSizePoints = 11,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.colorHex,
    this.highlightHex,
    this.hasFontFamily = false,
    this.hasFontSize = false,
    this.hasBold = false,
    this.hasItalic = false,
    this.hasUnderline = false,
    this.hasStrike = false,
    this.hasColor = false,
    this.hasHighlight = false,
  });

  final String? fontFamily;
  final double fontSizePoints;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final String? colorHex;
  final String? highlightHex;
  final bool hasFontFamily;
  final bool hasFontSize;
  final bool hasBold;
  final bool hasItalic;
  final bool hasUnderline;
  final bool hasStrike;
  final bool hasColor;
  final bool hasHighlight;

  _RunProperties merge(_RunProperties other) {
    return _RunProperties(
      fontFamily: other.hasFontFamily ? other.fontFamily : fontFamily,
      fontSizePoints: other.hasFontSize ? other.fontSizePoints : fontSizePoints,
      bold: other.hasBold ? other.bold : bold,
      italic: other.hasItalic ? other.italic : italic,
      underline: other.hasUnderline ? other.underline : underline,
      strike: other.hasStrike ? other.strike : strike,
      colorHex: other.hasColor ? other.colorHex : colorHex,
      highlightHex: other.hasHighlight ? other.highlightHex : highlightHex,
      hasFontFamily: hasFontFamily || other.hasFontFamily,
      hasFontSize: hasFontSize || other.hasFontSize,
      hasBold: hasBold || other.hasBold,
      hasItalic: hasItalic || other.hasItalic,
      hasUnderline: hasUnderline || other.hasUnderline,
      hasStrike: hasStrike || other.hasStrike,
      hasColor: hasColor || other.hasColor,
      hasHighlight: hasHighlight || other.hasHighlight,
    );
  }

  ConversionTextStyle toModel() {
    return ConversionTextStyle(
      fontFamily: fontFamily,
      fontSizePoints: fontSizePoints,
      bold: bold,
      italic: italic,
      underline: underline,
      strike: strike,
      colorHex: colorHex,
      highlightHex: highlightHex,
    );
  }
}

_ParagraphProperties _parseParagraphProperties(xml.XmlElement? pPr) {
  if (pPr == null) return const _ParagraphProperties();
  final jc = _attribute(_directChild(pPr, 'jc'), 'val');
  final alignment = switch (jc) {
    'center' => ConversionTextAlignment.center,
    'right' || 'end' => ConversionTextAlignment.right,
    'both' || 'distribute' => ConversionTextAlignment.justify,
    _ => ConversionTextAlignment.left,
  };
  final spacing = _directChild(pPr, 'spacing');
  final indentation = _directChild(pPr, 'ind');
  final before = double.tryParse(_attribute(spacing, 'before') ?? '');
  final after = double.tryParse(_attribute(spacing, 'after') ?? '');
  final left = double.tryParse(
    _attribute(indentation, 'left') ?? _attribute(indentation, 'start') ?? '',
  );
  final right = double.tryParse(
    _attribute(indentation, 'right') ?? _attribute(indentation, 'end') ?? '',
  );
  final firstLine = double.tryParse(_attribute(indentation, 'firstLine') ?? '');
  final hanging = double.tryParse(_attribute(indentation, 'hanging') ?? '');
  final pageBreak = _directChild(pPr, 'pageBreakBefore');
  final keepWithNext = _directChild(pPr, 'keepNext');
  return _ParagraphProperties(
    alignment: alignment,
    spaceBeforePoints: (before ?? 0) / 20,
    spaceAfterPoints: (after ?? 0) / 20,
    leftIndentPoints: (left ?? 0) / 20,
    rightIndentPoints: (right ?? 0) / 20,
    firstLineIndentPoints: ((firstLine ?? 0) - (hanging ?? 0)) / 20,
    pageBreakBefore: _toggleValue(pageBreak),
    keepWithNext: _toggleValue(keepWithNext),
    hasAlignment: jc != null,
    hasSpaceBefore: before != null,
    hasSpaceAfter: after != null,
    hasLeftIndent: left != null,
    hasRightIndent: right != null,
    hasFirstLineIndent: firstLine != null || hanging != null,
    hasPageBreakBefore: pageBreak != null,
    hasKeepWithNext: keepWithNext != null,
  );
}

_RunProperties _parseRunProperties(xml.XmlElement? rPr) {
  if (rPr == null) return const _RunProperties();
  final fonts = _directChild(rPr, 'rFonts');
  final fontFamily = _attribute(fonts, 'ascii') ??
      _attribute(fonts, 'hAnsi') ??
      _attribute(fonts, 'eastAsia') ??
      _attribute(fonts, 'cs');
  final sizeHalfPoints = double.tryParse(
    _attribute(_directChild(rPr, 'sz'), 'val') ?? '',
  );
  final bold = _directChild(rPr, 'b');
  final italic = _directChild(rPr, 'i');
  final underline = _directChild(rPr, 'u');
  final strike = _directChild(rPr, 'strike');
  final colorElement = _directChild(rPr, 'color');
  final highlightElement = _directChild(rPr, 'highlight');
  final underlineValue = _attribute(underline, 'val');
  return _RunProperties(
    fontFamily: fontFamily,
    fontSizePoints: sizeHalfPoints == null ? 11 : sizeHalfPoints / 2,
    bold: _toggleValue(bold),
    italic: _toggleValue(italic),
    underline: underline != null && underlineValue != 'none',
    strike: _toggleValue(strike),
    colorHex: _normalizeColor(_attribute(colorElement, 'val')),
    highlightHex: _highlightColor(_attribute(highlightElement, 'val')),
    hasFontFamily: fontFamily != null,
    hasFontSize: sizeHalfPoints != null,
    hasBold: bold != null,
    hasItalic: italic != null,
    hasUnderline: underline != null,
    hasStrike: strike != null,
    hasColor: colorElement != null,
    hasHighlight: highlightElement != null,
  );
}

class _NumberingCatalog {
  _NumberingCatalog(this.levelsByNumId);

  final Map<String, Map<int, _NumberLevel>> levelsByNumId;
  final Map<String, Map<int, int>> _counters = {};

  factory _NumberingCatalog.fromEntries(Map<String, ArchiveFile> entries) {
    final entry = entries['word/numbering.xml'];
    if (entry == null) {
      return _NumberingCatalog({});
    }
    final document = xml.XmlDocument.parse(
      utf8.decode(entry.content),
    );
    final abstractLevels = <String, Map<int, _NumberLevel>>{};
    for (final abstractNum in document.rootElement.childElements.where(
      (element) => element.name.local == 'abstractNum',
    )) {
      final abstractId = _attribute(abstractNum, 'abstractNumId');
      if (abstractId == null) continue;
      final levels = <int, _NumberLevel>{};
      for (final level in abstractNum.childElements.where(
        (element) => element.name.local == 'lvl',
      )) {
        final ilvl = int.tryParse(_attribute(level, 'ilvl') ?? '') ?? 0;
        final format = _attribute(_directChild(level, 'numFmt'), 'val') ?? 'decimal';
        final text = _attribute(_directChild(level, 'lvlText'), 'val') ?? '%${ilvl + 1}.';
        final start = int.tryParse(
              _attribute(_directChild(level, 'start'), 'val') ?? '',
            ) ??
            1;
        levels[ilvl] = _NumberLevel(format: format, pattern: text, start: start);
      }
      abstractLevels[abstractId] = levels;
    }

    final levelsByNumId = <String, Map<int, _NumberLevel>>{};
    for (final num in document.rootElement.childElements.where(
      (element) => element.name.local == 'num',
    )) {
      final numId = _attribute(num, 'numId');
      final abstractId = _attribute(_directChild(num, 'abstractNumId'), 'val');
      if (numId == null || abstractId == null) continue;
      final levels = abstractLevels[abstractId];
      if (levels != null) levelsByNumId[numId] = levels;
    }
    return _NumberingCatalog(levelsByNumId);
  }

  String? nextLabel(String? numId, int level) {
    if (numId == null) return null;
    final definition = levelsByNumId[numId]?[level];
    if (definition == null) return null;
    if (definition.format == 'bullet') {
      return '${_bulletFromPattern(definition.pattern)} ';
    }
    final counters = _counters.putIfAbsent(numId, () => <int, int>{});
    counters.removeWhere((key, value) => key > level);
    final value = (counters[level] ?? (definition.start - 1)) + 1;
    counters[level] = value;
    var label = definition.pattern;
    for (var i = 0; i <= level; i++) {
      final levelDefinition = levelsByNumId[numId]?[i];
      final levelValue = counters[i] ?? levelDefinition?.start ?? 1;
      label = label.replaceAll('%${i + 1}', _formatNumber(levelValue, levelDefinition?.format));
    }
    return '$label ';
  }

  static String _bulletFromPattern(String pattern) {
    final cleaned = pattern.trim();
    if (cleaned.isEmpty || cleaned.contains('%')) return '•';
    const supported = {'•', '◦', '▪', '▫', '–', '—'};
    return supported.contains(cleaned) ? cleaned : '•';
  }

  static String _formatNumber(int value, String? format) {
    switch (format) {
      case 'lowerLetter':
        return _alpha(value, false);
      case 'upperLetter':
        return _alpha(value, true);
      case 'lowerRoman':
        return _roman(value).toLowerCase();
      case 'upperRoman':
        return _roman(value);
      default:
        return '$value';
    }
  }

  static String _alpha(int value, bool upper) {
    if (value <= 0) return '$value';
    var n = value;
    final buffer = StringBuffer();
    while (n > 0) {
      n--;
      buffer.writeCharCode((upper ? 65 : 97) + (n % 26));
      n ~/= 26;
    }
    return buffer.toString().split('').reversed.join();
  }

  static String _roman(int value) {
    if (value <= 0 || value > 3999) return '$value';
    const values = <int>[1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const symbols = <String>['M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I'];
    var n = value;
    final buffer = StringBuffer();
    for (var i = 0; i < values.length; i++) {
      while (n >= values[i]) {
        n -= values[i];
        buffer.write(symbols[i]);
      }
    }
    return buffer.toString();
  }
}

class _NumberLevel {
  const _NumberLevel({
    required this.format,
    required this.pattern,
    required this.start,
  });

  final String format;
  final String pattern;
  final int start;
}

class _RelationshipCatalog {
  _RelationshipCatalog(this.relationships);

  final Map<String, _Relationship> relationships;

  factory _RelationshipCatalog.fromEntry(
    ArchiveFile? entry, {
    required String baseDirectory,
  }) {
    if (entry == null) {
      return _RelationshipCatalog({});
    }
    final document = xml.XmlDocument.parse(
      utf8.decode(entry.content),
    );
    final relationships = <String, _Relationship>{};
    for (final element in document.rootElement.childElements.where(
      (element) => element.name.local == 'Relationship',
    )) {
      final id = _attribute(element, 'Id');
      final target = _attribute(element, 'Target');
      if (id == null || target == null) continue;
      final targetMode = _attribute(element, 'TargetMode');
      final isExternal = targetMode?.toLowerCase() == 'external';
      relationships[id] = _Relationship(
        target: isExternal
            ? target
            : p.posix.normalize(p.posix.join(baseDirectory, target)),
        isExternal: isExternal,
      );
    }
    return _RelationshipCatalog(relationships);
  }

  _Relationship? byId(String? id) => id == null ? null : relationships[id];
}

class _Relationship {
  const _Relationship({required this.target, required this.isExternal});

  final String target;
  final bool isExternal;

  String? get externalTarget => isExternal ? target : null;
}

xml.XmlElement? _directChild(xml.XmlElement? parent, String local) {
  if (parent == null) return null;
  for (final child in parent.childElements) {
    if (child.name.local == local) return child;
  }
  return null;
}

String? _attribute(xml.XmlElement? element, String local) {
  if (element == null) return null;
  for (final attribute in element.attributes) {
    if (attribute.name.local == local) return attribute.value;
  }
  return null;
}

bool _toggleValue(xml.XmlElement? element) {
  if (element == null) return false;
  final value = _attribute(element, 'val')?.toLowerCase();
  return value != '0' && value != 'false' && value != 'off';
}

String? _normalizeColor(String? value) {
  if (value == null) return null;
  final normalized = value.replaceAll('#', '').trim().toUpperCase();
  if (normalized == 'AUTO' || !RegExp(r'^[0-9A-F]{6}$').hasMatch(normalized)) {
    return null;
  }
  return normalized;
}

String? _highlightColor(String? value) {
  return switch (value?.toLowerCase()) {
    'yellow' => 'FFFF00',
    'green' => '00FF00',
    'cyan' => '00FFFF',
    'magenta' => 'FF00FF',
    'blue' => '0000FF',
    'red' => 'FF0000',
    'darkblue' => '000080',
    'darkcyan' => '008080',
    'darkgreen' => '008000',
    'darkmagenta' => '800080',
    'darkred' => '800000',
    'darkyellow' => '808000',
    'darkgray' => '808080',
    'lightgray' => 'C0C0C0',
    'black' => '000000',
    _ => null,
  };
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
