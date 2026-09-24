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

    final theme = _ThemeCatalog.fromEntry(entries['word/theme/theme1.xml']);
    final styles = _StylesCatalog.fromEntry(
      entries['word/styles.xml'],
      theme: theme,
    );
    final numbering = _NumberingCatalog.fromEntries(entries, theme: theme);
    final relationships = _RelationshipCatalog.fromEntry(
      entries['word/_rels/document.xml.rels'],
      baseDirectory: 'word',
    );
    final context = _ParseContext(
      entries: entries,
      styles: styles,
      numbering: numbering,
      theme: theme,
    );
    final documentSettings = _documentSettings(entries['word/settings.xml']);

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
    var inheritedFirstHeader = const <ConversionBlock>[];
    var inheritedFirstFooter = const <ConversionBlock>[];
    var inheritedEvenHeader = const <ConversionBlock>[];
    var inheritedEvenFooter = const <ConversionBlock>[];

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
              inheritedFirstHeader: inheritedFirstHeader,
              inheritedFirstFooter: inheritedFirstFooter,
              inheritedEvenHeader: inheritedEvenHeader,
              inheritedEvenFooter: inheritedEvenFooter,
            );
            sections.add(section);
            inheritedHeader = section.headerBlocks;
            inheritedFooter = section.footerBlocks;
            inheritedFirstHeader = section.firstPageHeaderBlocks;
            inheritedFirstFooter = section.firstPageFooterBlocks;
            inheritedEvenHeader = section.evenPageHeaderBlocks;
            inheritedEvenFooter = section.evenPageFooterBlocks;
            pendingBlocks = <ConversionBlock>[];
          }
          break;
        case 'tbl':
          pendingBlocks.add(context.parseTableBlock(child, relationships));
          break;
        case 'sectPr':
          finalSectionProperties = child;
          break;
        default:
          if (_isOpaqueBlockWrapper(child)) {
            pendingBlocks.add(context.parseOpaqueBlock(child, relationships));
          }
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
          inheritedFirstHeader: inheritedFirstHeader,
          inheritedFirstFooter: inheritedFirstFooter,
          inheritedEvenHeader: inheritedEvenHeader,
          inheritedEvenFooter: inheritedEvenFooter,
        ),
      );
    }

    final background = document.rootElement.childElements
        .where((element) => element.name.local == 'background')
        .firstOrNull;
    return ConversionDocument(
      sections: sections,
      evenAndOddHeaders: documentSettings.evenAndOddHeaders,
      mirrorMargins: documentSettings.mirrorMargins,
      gutterAtTop: documentSettings.gutterAtTop,
      backgroundColorHex: _normalizeColor(_attribute(background, 'color')),
    );
  }

  static _DocumentSettings _documentSettings(ArchiveFile? entry) {
    if (entry == null) return const _DocumentSettings();
    final document = _parseXml(entry);
    bool enabled(String local) {
      final element = document.descendants
          .whereType<xml.XmlElement>()
          .where((candidate) => candidate.name.local == local)
          .firstOrNull;
      if (element == null) return false;
      final value = element.attributes
          .where((attribute) => attribute.name.local == 'val')
          .map((attribute) => attribute.value.trim().toLowerCase())
          .firstOrNull;
      return value == null ||
          value.isEmpty ||
          value == '1' ||
          value == 'true' ||
          value == 'on';
    }

    return _DocumentSettings(
      evenAndOddHeaders: enabled('evenAndOddHeaders'),
      mirrorMargins: enabled('mirrorMargins'),
      gutterAtTop: enabled('gutterAtTop'),
    );
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

class _DocumentSettings {
  const _DocumentSettings({
    this.evenAndOddHeaders = false,
    this.mirrorMargins = false,
    this.gutterAtTop = false,
  });

  final bool evenAndOddHeaders;
  final bool mirrorMargins;
  final bool gutterAtTop;
}

class _ParseContext {
  _ParseContext({
    required this.entries,
    required this.styles,
    required this.numbering,
    required this.theme,
  });

  final Map<String, ArchiveFile> entries;
  final _StylesCatalog styles;
  final _NumberingCatalog numbering;
  final _ThemeCatalog theme;

  ConversionSection buildSection(
    List<ConversionBlock> blocks,
    xml.XmlElement? sectionProperties,
    _RelationshipCatalog documentRelationships, {
    List<ConversionBlock> inheritedHeader = const [],
    List<ConversionBlock> inheritedFooter = const [],
    List<ConversionBlock> inheritedFirstHeader = const [],
    List<ConversionBlock> inheritedFirstFooter = const [],
    List<ConversionBlock> inheritedEvenHeader = const [],
    List<ConversionBlock> inheritedEvenFooter = const [],
  }) {
    final settings = _pageSettings(sectionProperties);
    final defaultHeader = _relatedStoryBlocks(
      sectionProperties,
      relationshipLocalName: 'headerReference',
      storyType: 'default',
      documentRelationships: documentRelationships,
    );
    final defaultFooter = _relatedStoryBlocks(
      sectionProperties,
      relationshipLocalName: 'footerReference',
      storyType: 'default',
      documentRelationships: documentRelationships,
    );
    final firstHeader = _relatedStoryBlocks(
      sectionProperties,
      relationshipLocalName: 'headerReference',
      storyType: 'first',
      documentRelationships: documentRelationships,
    );
    final firstFooter = _relatedStoryBlocks(
      sectionProperties,
      relationshipLocalName: 'footerReference',
      storyType: 'first',
      documentRelationships: documentRelationships,
    );
    final evenHeader = _relatedStoryBlocks(
      sectionProperties,
      relationshipLocalName: 'headerReference',
      storyType: 'even',
      documentRelationships: documentRelationships,
    );
    final evenFooter = _relatedStoryBlocks(
      sectionProperties,
      relationshipLocalName: 'footerReference',
      storyType: 'even',
      documentRelationships: documentRelationships,
    );
    final pageNumber = _directChild(sectionProperties, 'pgNumType');
    return ConversionSection(
      page: settings,
      blocks: List<ConversionBlock>.unmodifiable(blocks),
      headerBlocks: defaultHeader ?? inheritedHeader,
      footerBlocks: defaultFooter ?? inheritedFooter,
      firstPageHeaderBlocks: firstHeader ?? inheritedFirstHeader,
      firstPageFooterBlocks: firstFooter ?? inheritedFirstFooter,
      evenPageHeaderBlocks: evenHeader ?? inheritedEvenHeader,
      evenPageFooterBlocks: evenFooter ?? inheritedEvenFooter,
      breakType: _sectionBreakType(sectionProperties),
      titlePage: _toggleElement(_directChild(sectionProperties, 'titlePg')),
      columns: _sectionColumns(sectionProperties),
      pageNumberStart: int.tryParse(_attribute(pageNumber, 'start') ?? ''),
      pageNumberFormat: _attribute(pageNumber, 'fmt'),
    );
  }

  /// Returns null when the requested story is not referenced by this section.
  /// This distinction is important because Word inherits each header/footer
  /// story type independently from the previous section.
  List<ConversionBlock>? _relatedStoryBlocks(
    xml.XmlElement? sectionProperties, {
    required String relationshipLocalName,
    required String storyType,
    required _RelationshipCatalog documentRelationships,
  }) {
    if (sectionProperties == null) return null;
    final reference = sectionProperties.childElements
        .where((element) => element.name.local == relationshipLocalName)
        .where((element) => (_attribute(element, 'type') ?? 'default') == storyType)
        .firstOrNull;
    if (reference == null) return null;

    final relationshipId = _attribute(reference, 'id');
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
        blocks.add(parseParagraph(child, storyRelationships));
      } else if (child.name.local == 'tbl') {
        blocks.add(parseTableBlock(child, storyRelationships));
      } else if (_isOpaqueBlockWrapper(child)) {
        blocks.add(parseOpaqueBlock(child, storyRelationships));
      }
    }
    return List<ConversionBlock>.unmodifiable(blocks);
  }

  List<ConversionBlock> _noteBlocks(
    ConversionWordNoteType type,
    String noteId,
  ) {
    final fileName = type == ConversionWordNoteType.footnote
        ? 'word/footnotes.xml'
        : 'word/endnotes.xml';
    final entry = entries[fileName];
    if (entry == null) return const <ConversionBlock>[];
    final document = _parseXml(entry);
    final noteLocal = type == ConversionWordNoteType.footnote
        ? 'footnote'
        : 'endnote';
    final note = document.rootElement.childElements
        .where((element) => element.name.local == noteLocal)
        .where((element) => _attribute(element, 'id') == noteId)
        .firstOrNull;
    if (note == null) return const <ConversionBlock>[];
    final relationships = _RelationshipCatalog.fromEntry(
      entries[_relationshipPartPath(fileName)],
      baseDirectory: 'word',
    );
    final blocks = <ConversionBlock>[];
    for (final child in note.childElements) {
      if (child.name.local == 'p') {
        blocks.add(parseParagraph(child, relationships));
      } else if (child.name.local == 'tbl') {
        blocks.add(parseTableBlock(child, relationships));
      } else if (_isOpaqueBlockWrapper(child)) {
        blocks.add(parseOpaqueBlock(child, relationships));
      }
    }
    return List<ConversionBlock>.unmodifiable(blocks);
  }

  ConversionCommentInfo? _commentInfo(String commentId) {
    final entry = entries['word/comments.xml'];
    if (entry == null) return null;
    final document = _parseXml(entry);
    final comment = document.rootElement.childElements
        .where((element) => element.name.local == 'comment')
        .where((element) => _attribute(element, 'id') == commentId)
        .firstOrNull;
    if (comment == null) return null;
    final relationships = _RelationshipCatalog.fromEntry(
      entries['word/_rels/comments.xml.rels'],
      baseDirectory: 'word',
    );
    final blocks = <ConversionBlock>[];
    for (final child in comment.childElements) {
      if (child.name.local == 'p') {
        blocks.add(parseParagraph(child, relationships));
      } else if (child.name.local == 'tbl') {
        blocks.add(parseTableBlock(child, relationships));
      } else if (_isOpaqueBlockWrapper(child)) {
        blocks.add(parseOpaqueBlock(child, relationships));
      }
    }
    final text = blocks
        .whereType<ConversionParagraph>()
        .map((paragraph) => paragraph.inlines
            .whereType<ConversionTextRun>()
            .map((run) => run.text)
            .join())
        .where((value) => value.isNotEmpty)
        .join('\n');
    return ConversionCommentInfo(
      commentId: commentId,
      author: _attribute(comment, 'author'),
      initials: _attribute(comment, 'initials'),
      dateIso: _attribute(comment, 'date'),
      text: text,
      blocks: List<ConversionBlock>.unmodifiable(blocks),
    );
  }

  String _noteDisplayLabel(String noteId) {
    final value = int.tryParse(noteId);
    return value == null || value < 1 ? noteId : value.toString();
  }

  ConversionSectionBreakType _sectionBreakType(xml.XmlElement? sectPr) {
    final value = _attribute(_directChild(sectPr, 'type'), 'val');
    return switch (value) {
      'continuous' => ConversionSectionBreakType.continuous,
      'evenPage' => ConversionSectionBreakType.evenPage,
      'oddPage' => ConversionSectionBreakType.oddPage,
      'nextColumn' => ConversionSectionBreakType.nextColumn,
      _ => ConversionSectionBreakType.nextPage,
    };
  }

  ConversionColumns _sectionColumns(xml.XmlElement? sectPr) {
    final cols = _directChild(sectPr, 'cols');
    if (cols == null) return const ConversionColumns();
    final childColumns = cols.childElements
        .where((element) => element.name.local == 'col')
        .map(
          (element) => ConversionColumnSpec(
            widthPoints: _optionalTwips(_attribute(element, 'w')),
            spacingPoints: _optionalTwips(_attribute(element, 'space')),
          ),
        )
        .toList(growable: false);
    final rawCount = int.tryParse(_attribute(cols, 'num') ?? '');
    final count = (rawCount ?? (childColumns.isEmpty ? 1 : childColumns.length))
        .clamp(1, 16)
        .toInt();
    return ConversionColumns(
      count: count,
      equalWidth: !_hasFalseAttribute(cols, 'equalWidth'),
      spacingPoints: _twips(_attribute(cols, 'space'), fallback: 36),
      separator: _boolAttribute(cols, 'sep'),
      columns: List<ConversionColumnSpec>.unmodifiable(childColumns),
    );
  }

  ConversionOpaqueOoxmlBlock parseOpaqueBlock(
    xml.XmlElement element,
    _RelationshipCatalog relationships,
  ) {
    final fallback = <ConversionBlock>[];

    void collect(xml.XmlElement container) {
      for (final child in container.childElements) {
        switch (child.name.local) {
          case 'p':
            fallback.add(parseParagraph(child, relationships));
            break;
          case 'tbl':
            fallback.add(parseTableBlock(child, relationships));
            break;
          default:
            if (child.childElements.isNotEmpty) collect(child);
            break;
        }
      }
    }

    collect(element);
    return ConversionOpaqueOoxmlBlock(
      featureKind: _opaqueFeatureKind(element),
      rawXml: element.toXmlString(),
      fallbackBlocks: List<ConversionBlock>.unmodifiable(fallback),
      relationshipIds: _relationshipIds(element),
    );
  }

  ConversionParagraph parseParagraph(
    xml.XmlElement element,
    _RelationshipCatalog relationships, {
    _ParagraphProperties tableParagraphBase = const _ParagraphProperties(),
    _RunProperties tableRunBase = const _RunProperties(),
  }) {
    final pPr = _directChild(element, 'pPr');
    final paragraphStyleId = _attribute(_directChild(pPr, 'pStyle'), 'val');
    final paragraphStyle = tableParagraphBase.merge(
      styles.resolveParagraph(paragraphStyleId),
    );
    final directParagraph = _parseParagraphProperties(pPr);
    final preliminaryParagraph = paragraphStyle.merge(directParagraph);
    final numberingLevel = numbering.level(
      preliminaryParagraph.numberingNumId,
      preliminaryParagraph.numberingLevel,
    );
    final mergedParagraph = paragraphStyle
        .merge(numberingLevel?.paragraph ?? const _ParagraphProperties())
        .merge(directParagraph);

    final paragraphRunBase = tableRunBase
        .merge(styles.resolveRun(paragraphStyleId))
        .merge(_parseRunProperties(_directChild(pPr, 'rPr'), theme: theme));
    final inlines = <ConversionInline>[];
    var insideField = false;
    var fieldSeparated = false;
    var fieldRendered = false;
    var fieldLocked = false;
    var fieldDirty = false;
    final fieldInstruction = StringBuffer();
    final fieldResult = <ConversionInline>[];

    String inlineText(Iterable<ConversionInline> values) {
      final buffer = StringBuffer();
      for (final inline in values) {
        if (inline is ConversionTextRun) {
          buffer.write(inline.text);
        } else if (inline is ConversionDynamicFieldRun) {
          buffer.write(
            inline.field == ConversionDynamicField.pageNumber
                ? '{PAGE}'
                : '{NUMPAGES}',
          );
        } else if (inline is ConversionFieldRun) {
          buffer.write(inline.resultText);
        } else if (inline is ConversionMathRun) {
          buffer.write(inline.plainText);
        }
      }
      return buffer.toString();
    }

    void finishComplexField() {
      final instruction = fieldInstruction.toString().trim();
      final dynamicField = _dynamicField(instruction);
      if (dynamicField == null && instruction.isNotEmpty) {
        final style = fieldResult.whereType<ConversionTextRun>().firstOrNull?.style ??
            paragraphRunBase.toModel();
        inlines.add(
          ConversionFieldRun(
            instruction: instruction,
            resultText: inlineText(fieldResult),
            style: style,
            locked: fieldLocked,
            dirty: fieldDirty,
          ),
        );
      }
      insideField = false;
      fieldSeparated = false;
      fieldRendered = false;
      fieldLocked = false;
      fieldDirty = false;
      fieldInstruction.clear();
      fieldResult.clear();
    }

    for (final child in element.childElements) {
      switch (child.name.local) {
        case 'bookmarkStart':
          final id = _attribute(child, 'id');
          if (id != null) {
            inlines.add(
              ConversionBookmarkMarkerRun(
                bookmarkId: id,
                name: _attribute(child, 'name'),
                kind: ConversionWordMarkerKind.start,
              ),
            );
          }
          continue;
        case 'bookmarkEnd':
          final id = _attribute(child, 'id');
          if (id != null) {
            inlines.add(
              ConversionBookmarkMarkerRun(
                bookmarkId: id,
                kind: ConversionWordMarkerKind.end,
              ),
            );
          }
          continue;
        case 'commentRangeStart':
        case 'commentRangeEnd':
          final id = _attribute(child, 'id');
          if (id != null) {
            inlines.add(
              ConversionCommentMarkerRun(
                commentId: id,
                kind: child.name.local == 'commentRangeStart'
                    ? ConversionWordMarkerKind.start
                    : ConversionWordMarkerKind.end,
                comment: _commentInfo(id),
              ),
            );
          }
          continue;
      }

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
            fieldLocked = _boolAttribute(fieldChar, 'fldLock');
            fieldDirty = _boolAttribute(fieldChar, 'dirty');
            fieldInstruction.clear();
            fieldResult.clear();
          } else if (type == 'separate') {
            fieldSeparated = true;
          }
        }
        for (final piece in instructionPieces) {
          fieldInstruction.write(piece);
        }

        final parsedRun = _parseRun(
          child,
          relationships,
          paragraphRunBase: paragraphRunBase,
        );
        final dynamicField = _dynamicField(fieldInstruction.toString());
        final containsResultText = parsedRun.any(
          (inline) => inline is ConversionTextRun && inline.text.isNotEmpty,
        );

        if (insideField) {
          if (fieldSeparated && dynamicField != null) {
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
          } else if (fieldSeparated) {
            fieldResult.addAll(parsedRun);
          }
        } else {
          inlines.addAll(parsedRun);
        }

        if (fieldChars.any(
          (fieldChar) => _attribute(fieldChar, 'fldCharType') == 'end',
        )) {
          finishComplexField();
        }
      } else if (child.name.local == 'hyperlink') {
        final relationshipId = _attribute(child, 'id');
        final externalTarget = relationships.byId(relationshipId)?.externalTarget;
        final anchor = _attribute(child, 'anchor')?.trim();
        final target = externalTarget ??
            (anchor == null || anchor.isEmpty ? null : '#$anchor');
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
      } else if (child.name.local == 'oMath' ||
          child.name.local == 'oMathPara') {
        final mathText = child.descendants
            .whereType<xml.XmlElement>()
            .where((element) => element.name.local == 't')
            .map((element) => element.innerText)
            .join();
        inlines.add(
          ConversionMathRun(
            ommlXml: child.toXmlString(),
            plainText: mathText,
            display: child.name.local == 'oMathPara',
            style: paragraphRunBase.toModel().copyWith(fontFamily: 'Cambria Math'),
          ),
        );
      } else if (child.name.local == 'fldSimple') {
        final instruction = (_attribute(child, 'instr') ?? '').trim();
        final dynamicField = _dynamicField(instruction);
        final runs = child.descendants
            .whereType<xml.XmlElement>()
            .where((element) => element.name.local == 'r')
            .toList(growable: false);
        final parsed = <ConversionInline>[
          for (final run in runs)
            ..._parseRun(
              run,
              relationships,
              paragraphRunBase: paragraphRunBase,
            ),
        ];
        final style = parsed.whereType<ConversionTextRun>().firstOrNull?.style ??
            paragraphRunBase.toModel();
        if (dynamicField != null) {
          inlines.add(ConversionDynamicFieldRun(field: dynamicField, style: style));
        } else if (instruction.isNotEmpty) {
          inlines.add(
            ConversionFieldRun(
              instruction: instruction,
              resultText: inlineText(parsed),
              style: style,
              locked: _boolAttribute(child, 'fldLock'),
              dirty: _boolAttribute(child, 'dirty'),
            ),
          );
        } else {
          inlines.addAll(parsed);
        }
      } else if (child.name.local == 'sdt' ||
          child.name.local == 'customXml' ||
          child.name.local == 'object' ||
          child.name.local == 'AlternateContent' ||
          child.name.local == 'ins' ||
          child.name.local == 'del' ||
          child.name.local == 'moveFrom' ||
          child.name.local == 'moveTo' ||
          child.name.local == 'smartTag' ||
          child.name.local == 'dir' ||
          child.name.local == 'bdo') {
        // WM9: keep unsupported/partially-supported paragraph objects as an
        // opaque OOXML capsule. The fallback remains readable, but the raw
        // source is authoritative for preserve-only round trip.
        final fallbackText = child.descendants
            .whereType<xml.XmlElement>()
            .where((element) => element.name.local == 't')
            .map((element) => element.innerText)
            .join();
        inlines.add(
          ConversionOpaqueOoxmlRun(
            featureKind: _opaqueFeatureKind(child),
            rawXml: child.toXmlString(),
            fallbackText: fallbackText,
            relationshipIds: _relationshipIds(child),
            style: paragraphRunBase.toModel(),
          ),
        );
      }
    }

    final marker = numbering.nextMarker(
      mergedParagraph.numberingNumId,
      mergedParagraph.numberingLevel,
    );
    final hasExplicitPageBreak = element.descendants
        .whereType<xml.XmlElement>()
        .any(
          (element) =>
              (element.name.local == 'br' &&
                  _attribute(element, 'type') == 'page') ||
              element.name.local == 'lastRenderedPageBreak',
        );
    final hasExplicitColumnBreak = element.descendants
        .whereType<xml.XmlElement>()
        .any(
          (element) =>
              element.name.local == 'br' &&
              _attribute(element, 'type') == 'column',
        );

    return ConversionParagraph(
      inlines: inlines,
      styleId: paragraphStyleId,
      alignment: mergedParagraph.alignment,
      spaceBeforePoints: mergedParagraph.spaceBeforePoints,
      spaceAfterPoints: mergedParagraph.spaceAfterPoints,
      leftIndentPoints: mergedParagraph.leftIndentPoints,
      rightIndentPoints: mergedParagraph.rightIndentPoints,
      firstLineIndentPoints: mergedParagraph.firstLineIndentPoints,
      lineSpacingMultiple: mergedParagraph.lineSpacingMultiple,
      exactLineSpacingPoints: mergedParagraph.exactLineSpacingPoints,
      pageBreakBefore: mergedParagraph.pageBreakBefore || hasExplicitPageBreak,
      columnBreakBefore: hasExplicitColumnBreak,
      keepWithNext: mergedParagraph.keepWithNext,
      keepLines: mergedParagraph.keepLines,
      widowControl: mergedParagraph.widowControl,
      contextualSpacing: mergedParagraph.contextualSpacing,
      tabStops: mergedParagraph.tabStops,
      shadingHex: mergedParagraph.shadingHex,
      borders: mergedParagraph.borders,
      listLabel: marker?.label,
      listLabelStyle: marker?.style,
    );
  }

  ConversionBlock parseTableBlock(
    xml.XmlElement table,
    _RelationshipCatalog relationships,
  ) {
    final parsed = parseTable(table, relationships);
    if (!_containsOpaqueOoxml(table)) return parsed;
    return ConversionOpaqueOoxmlBlock(
      featureKind: 'tableWithUnsupportedOoxml',
      rawXml: table.toXmlString(),
      fallbackBlocks: <ConversionBlock>[parsed],
      relationshipIds: _relationshipIds(table),
    );
  }

  ConversionTable parseTable(
    xml.XmlElement table,
    _RelationshipCatalog relationships,
  ) {
    final rows = <ConversionTableRow>[];
    final tblPr = _directChild(table, 'tblPr');
    final tableStyleId = _attribute(_directChild(tblPr, 'tblStyle'), 'val');
    final styleBase = styles.resolveTableBase(tableStyleId);

    final directBordersElement = _directChild(tblPr, 'tblBorders');
    final tableBorders = directBordersElement == null
        ? styleBase.tableBorders
        : styleBase.tableBorders.merge(_parseBorders(directBordersElement));
    final showBorders = !tableBorders.isEmpty || tableStyleId == 'TableGrid';

    final directTableShading = _directChild(tblPr, 'shd');
    final tableShadingHex = directTableShading == null
        ? styleBase.shadingHex
        : _normalizeColor(_attribute(directTableShading, 'fill'));

    final directLayoutElement = _directChild(tblPr, 'tblLayout');
    final layoutValue = _attribute(directLayoutElement, 'type');
    final tableLayout = directLayoutElement == null
        ? (styleBase.layout ?? ConversionTableLayout.autoFit)
        : layoutValue == 'fixed'
            ? ConversionTableLayout.fixed
            : ConversionTableLayout.autoFit;

    final tblGrid = _directChild(table, 'tblGrid');
    final gridColumnWidths = tblGrid == null
        ? const <double>[]
        : tblGrid.childElements
            .where((e) => e.name.local == 'gridCol')
            .map((e) => double.tryParse(_attribute(e, 'w') ?? ''))
            .whereType<double>()
            .map((twips) => twips / 20)
            .toList(growable: false);

    final tableWidthElement = _directChild(tblPr, 'tblW');
    final tableWidthType = _attribute(tableWidthElement, 'type');
    final tableWidthRaw = double.tryParse(_attribute(tableWidthElement, 'w') ?? '');
    final directWidthPoints = tableWidthType == 'dxa' &&
            tableWidthRaw != null &&
            tableWidthRaw > 0
        ? tableWidthRaw / 20
        : null;
    final directWidthPercent = tableWidthType == 'pct' &&
            tableWidthRaw != null &&
            tableWidthRaw > 0
        ? (tableWidthRaw / 50).clamp(0, 100).toDouble()
        : null;
    final tableWidthPoints = tableWidthElement == null
        ? styleBase.widthPoints
        : directWidthPoints;
    final tableWidthPercent = tableWidthElement == null
        ? styleBase.widthPercent
        : directWidthPercent;

    final tableIndent = _directChild(tblPr, 'tblInd');
    final tableIndentType = _attribute(tableIndent, 'type');
    final tableIndentRaw = double.tryParse(_attribute(tableIndent, 'w') ?? '');
    final tableIndentPoints = tableIndent == null
        ? styleBase.indentPoints
        : tableIndentType == 'dxa' && tableIndentRaw != null
            ? tableIndentRaw / 20
            : 0.0;

    final tableCellSpacing = _directChild(tblPr, 'tblCellSpacing');
    final cellSpacingType = _attribute(tableCellSpacing, 'type');
    final cellSpacingRaw = double.tryParse(_attribute(tableCellSpacing, 'w') ?? '');
    final cellSpacingPoints = tableCellSpacing == null
        ? styleBase.cellSpacingPoints
        : cellSpacingType == 'dxa' && cellSpacingRaw != null
            ? cellSpacingRaw / 20
            : 0.0;

    final directMarginsElement = _directChild(tblPr, 'tblCellMar');
    var defaultCellMargins = styleBase.cellMargins;
    if (directMarginsElement != null) {
      defaultCellMargins = defaultCellMargins.merge(
        _tableCellMargins(directMarginsElement),
      );
    }

    final directAlignmentElement = _directChild(tblPr, 'jc');
    final tableAlignmentValue = _attribute(directAlignmentElement, 'val');
    final tableAlignment = directAlignmentElement == null
        ? styleBase.alignment
        : switch (tableAlignmentValue) {
            'center' => ConversionTextAlignment.center,
            'right' || 'end' => ConversionTextAlignment.right,
            _ => ConversionTextAlignment.left,
          };

    final rowElements = table.childElements
        .where((e) => e.name.local == 'tr')
        .toList(growable: false);
    final gridColumnCount = gridColumnWidths.isNotEmpty
        ? gridColumnWidths.length
        : rowElements.fold<int>(0, (best, tr) {
            var count = 0;
            for (final tc in tr.childElements.where((e) => e.name.local == 'tc')) {
              final span = int.tryParse(
                    _attribute(_directChild(_directChild(tc, 'tcPr'), 'gridSpan'), 'val') ?? '',
                  ) ??
                  1;
              count += span.clamp(1, 64).toInt();
            }
            return best > count ? best : count;
          });
    final tblLook = _directChild(tblPr, 'tblLook');

    for (var rowIndex = 0; rowIndex < rowElements.length; rowIndex++) {
      final tr = rowElements[rowIndex];
      final cells = <ConversionTableCell>[];
      var gridColumnIndex = 0;
      final cellElements = tr.childElements
          .where((e) => e.name.local == 'tc')
          .toList(growable: false);

      for (var cellIndex = 0; cellIndex < cellElements.length; cellIndex++) {
        final tc = cellElements[cellIndex];
        final tcPr = _directChild(tc, 'tcPr');
        final widthElement = _directChild(tcPr, 'tcW');
        final widthType = _attribute(widthElement, 'type');
        final widthRaw = double.tryParse(_attribute(widthElement, 'w') ?? '');
        final span = int.tryParse(
              _attribute(_directChild(tcPr, 'gridSpan'), 'val') ?? '',
            ) ??
            1;
        final safeSpan = span.clamp(1, 64).toInt();
        final isLastGridColumn = gridColumnCount <= 0 ||
            gridColumnIndex + safeSpan >= gridColumnCount;

        final conditionalTypes = <String>['wholeTable'];
        if (!_tableLookEnabled(tblLook, 'noHBand', 0x0200)) {
          conditionalTypes.add(rowIndex.isEven ? 'band1Horz' : 'band2Horz');
        }
        if (!_tableLookEnabled(tblLook, 'noVBand', 0x0400)) {
          conditionalTypes.add(
            gridColumnIndex.isEven ? 'band1Vert' : 'band2Vert',
          );
        }
        if (_tableLookEnabled(tblLook, 'firstColumn', 0x0080) &&
            gridColumnIndex == 0) {
          conditionalTypes.add('firstCol');
        }
        if (_tableLookEnabled(tblLook, 'lastColumn', 0x0100) &&
            isLastGridColumn) {
          conditionalTypes.add('lastCol');
        }
        if (_tableLookEnabled(tblLook, 'firstRow', 0x0020) && rowIndex == 0) {
          conditionalTypes.add('firstRow');
        }
        if (_tableLookEnabled(tblLook, 'lastRow', 0x0040) &&
            rowIndex == rowElements.length - 1) {
          conditionalTypes.add('lastRow');
        }
        final isFirstRow = rowIndex == 0;
        final isLastRow = rowIndex == rowElements.length - 1;
        final isFirstColumn = gridColumnIndex == 0;
        if (isFirstRow && isFirstColumn) conditionalTypes.add('nwCell');
        if (isFirstRow && isLastGridColumn) conditionalTypes.add('neCell');
        if (isLastRow && isFirstColumn) conditionalTypes.add('swCell');
        if (isLastRow && isLastGridColumn) conditionalTypes.add('seCell');

        final styleCell = styles.resolveTableCell(
          tableStyleId,
          conditionalTypes,
        );

        double? widthPoints;
        double? widthPercent;
        if (widthType == 'dxa' && widthRaw != null && widthRaw > 0) {
          widthPoints = widthRaw / 20;
        } else if (widthType == 'pct' && widthRaw != null && widthRaw > 0) {
          widthPercent = (widthRaw / 50).clamp(0, 100).toDouble();
        }
        if (widthPoints == null && widthPercent == null && gridColumnWidths.isNotEmpty) {
          final end = (gridColumnIndex + safeSpan)
              .clamp(0, gridColumnWidths.length)
              .toInt();
          if (gridColumnIndex < end) {
            widthPoints = gridColumnWidths
                .sublist(gridColumnIndex, end)
                .fold<double>(0, (sum, width) => sum + width);
          }
        }

        final directShadingElement = _directChild(tcPr, 'shd');
        final shading = directShadingElement == null
            ? (styleCell.shadingHex ?? tableShadingHex)
            : _normalizeColor(_attribute(directShadingElement, 'fill'));

        var margins = defaultCellMargins;
        if (styleCell.hasCellMargins) {
          margins = margins.merge(styleCell.cellMargins);
        }
        final directCellMarginsElement = _directChild(tcPr, 'tcMar');
        if (directCellMarginsElement != null) {
          margins = margins.merge(_tableCellMargins(directCellMarginsElement));
        }

        var cellBorders = _cellBordersFromTable(
          tableBorders,
          rowIndex: rowIndex,
          rowCount: rowElements.length,
          gridColumnIndex: gridColumnIndex,
          gridColumnCount: gridColumnCount,
          gridSpan: safeSpan,
        );
        if (styleCell.hasCellBorders) {
          cellBorders = cellBorders.merge(styleCell.cellBorders);
        }
        final directCellBordersElement = _directChild(tcPr, 'tcBorders');
        if (directCellBordersElement != null) {
          cellBorders = cellBorders.merge(_parseBorders(directCellBordersElement));
        }

        final directVerticalAlignmentElement = _directChild(tcPr, 'vAlign');
        final verticalAlignmentValue = _attribute(directVerticalAlignmentElement, 'val');
        final verticalAlignment = directVerticalAlignmentElement == null
            ? (styleCell.verticalAlignment ??
                ConversionTableCellVerticalAlignment.top)
            : switch (verticalAlignmentValue) {
                'center' => ConversionTableCellVerticalAlignment.center,
                'bottom' => ConversionTableCellVerticalAlignment.bottom,
                _ => ConversionTableCellVerticalAlignment.top,
              };
        final directNoWrapElement = _directChild(tcPr, 'noWrap');
        final noWrap = directNoWrapElement == null
            ? (styleCell.hasNoWrap && styleCell.noWrap)
            : _toggleValue(directNoWrapElement);
        final vMerge = _directChild(tcPr, 'vMerge');
        final vMergeValue = _attribute(vMerge, 'val');
        final verticalMerge = vMerge == null
            ? ConversionVerticalMerge.none
            : vMergeValue == 'restart'
                ? ConversionVerticalMerge.restart
                : ConversionVerticalMerge.continuation;

        final blocks = <ConversionBlock>[];
        for (final child in tc.childElements) {
          if (child.name.local == 'p') {
            blocks.add(
              parseParagraph(
                child,
                relationships,
                tableParagraphBase: styleCell.paragraph,
                tableRunBase: styleCell.run,
              ),
            );
          } else if (child.name.local == 'tbl') {
            blocks.add(parseTableBlock(child, relationships));
          } else if (_isOpaqueBlockWrapper(child)) {
            blocks.add(parseOpaqueBlock(child, relationships));
          }
        }

        cells.add(
          ConversionTableCell(
            blocks: blocks,
            shadingHex: shading,
            borders: cellBorders,
            widthPoints: widthPoints,
            widthPercent: widthPercent,
            gridSpan: safeSpan,
            paddingTopPoints: margins.top ?? 4,
            paddingRightPoints: margins.right ?? 4,
            paddingBottomPoints: margins.bottom ?? 4,
            paddingLeftPoints: margins.left ?? 4,
            verticalAlignment: verticalAlignment,
            verticalMerge: verticalMerge,
            noWrap: noWrap,
          ),
        );
        gridColumnIndex += safeSpan;
      }

      if (cells.isNotEmpty) {
        final trPr = _directChild(tr, 'trPr');
        final isHeader = _toggleValue(_directChild(trPr, 'tblHeader'));
        final cantSplit = _toggleValue(_directChild(trPr, 'cantSplit'));
        final heightElement = _directChild(trPr, 'trHeight');
        final heightTwips = double.tryParse(_attribute(heightElement, 'val') ?? '');
        final heightRule = switch (_attribute(heightElement, 'hRule')) {
          'exact' => ConversionTableRowHeightRule.exact,
          'atLeast' => ConversionTableRowHeightRule.atLeast,
          _ => ConversionTableRowHeightRule.auto,
        };
        rows.add(
          ConversionTableRow(
            cells: cells,
            isHeader: isHeader,
            cantSplit: cantSplit,
            heightPoints:
                heightTwips == null || heightTwips <= 0 ? null : heightTwips / 20,
            heightRule: heightRule,
          ),
        );
      }
    }

    return ConversionTable(
      rows: rows,
      showBorders: showBorders,
      styleId: tableStyleId,
      shadingHex: tableShadingHex,
      borders: tableBorders,
      layout: tableLayout,
      widthPoints: tableWidthPoints,
      widthPercent: tableWidthPercent,
      indentPoints: tableIndentPoints,
      cellSpacingPoints: cellSpacingPoints,
      gridColumnWidths: gridColumnWidths,
      alignment: tableAlignment,
    );
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
        .merge(_parseRunProperties(rPr, theme: theme));
    final style = effective.toModel();
    final result = <ConversionInline>[];
    final textBuffer = StringBuffer();
    final opaqueChildren = <xml.XmlElement, String>{};
    for (final child in run.childElements) {
      final feature = _opaqueRunFeature(child);
      if (feature != null) opaqueChildren[child] = feature;
    }

    bool insideOpaqueChild(xml.XmlElement element) {
      xml.XmlElement? current = element;
      while (current != null && !identical(current, run)) {
        if (opaqueChildren.containsKey(current)) return true;
        current = current.parentElement;
      }
      return false;
    }

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
      final opaqueFeature = opaqueChildren[descendant];
      if (opaqueFeature != null) {
        // Preserve source ordering: text before an unsupported object must stay
        // before it, and text after it must stay after it. Older WM9 drafts
        // appended all opaque capsules before normal text, which was lossless
        // at package level but changed the visible reading order.
        flushText();
        result.add(
          ConversionOpaqueOoxmlRun(
            featureKind: opaqueFeature,
            rawXml: descendant.toXmlString(),
            fallbackText: _opaqueFallbackText(descendant),
            relationshipIds: _relationshipIds(descendant),
            style: style,
          ),
        );
        continue;
      }
      if (insideOpaqueChild(descendant) ||
          _isNestedInside(descendant, 'txbxContent', stopAt: run)) {
        continue;
      }
      switch (descendant.name.local) {
        case 'footnoteReference':
        case 'endnoteReference':
          flushText();
          final noteId = _attribute(descendant, 'id');
          if (noteId != null) {
            final type = descendant.name.local == 'footnoteReference'
                ? ConversionWordNoteType.footnote
                : ConversionWordNoteType.endnote;
            result.add(
              ConversionNoteReferenceRun(
                type: type,
                noteId: noteId,
                displayLabel: _noteDisplayLabel(noteId),
                blocks: _noteBlocks(type, noteId),
                style: style,
              ),
            );
          }
          break;
        case 'commentReference':
          flushText();
          final commentId = _attribute(descendant, 'id');
          if (commentId != null) {
            result.add(
              ConversionCommentMarkerRun(
                commentId: commentId,
                kind: ConversionWordMarkerKind.reference,
                comment: _commentInfo(commentId),
                style: style,
              ),
            );
          }
          break;
        case 'footnoteRef':
        case 'endnoteRef':
          // The note label is rendered from the referencing run. Word stores
          // these marker elements inside note stories as layout metadata.
          break;
        case 'txbxContent':
          flushText();
          final blocks = <ConversionBlock>[];
          for (final child in descendant.childElements) {
            if (child.name.local == 'p') {
              blocks.add(parseParagraph(child, relationships));
            } else if (child.name.local == 'tbl') {
              blocks.add(parseTableBlock(child, relationships));
            } else if (_isOpaqueBlockWrapper(child)) {
              blocks.add(parseOpaqueBlock(child, relationships));
            }
          }
          final extent = _nearestTextBoxExtent(descendant);
          final insets = _nearestTextBoxInsets(descendant);
          if (blocks.isNotEmpty) {
            final shape = _shapeRunFromContext(
              descendant,
              blocks: List<ConversionBlock>.unmodifiable(blocks),
            );
            if (shape != null) {
              result.add(shape);
            } else {
              result.add(
                ConversionTextBoxRun(
                  blocks: List<ConversionBlock>.unmodifiable(blocks),
                  widthPoints: extent.$1,
                  heightPoints: extent.$2,
                  paddingTopPoints: insets.top,
                  paddingRightPoints: insets.right,
                  paddingBottomPoints: insets.bottom,
                  paddingLeftPoints: insets.left,
                  placement: _nearestObjectPlacement(descendant),
                ),
              );
            }
          }
          break;
        case 'wsp':
        case 'shape':
        case 'rect':
        case 'roundrect':
        case 'oval':
        case 'line':
          final hasNestedContent = descendant.descendants
              .whereType<xml.XmlElement>()
              .any((element) =>
                  element.name.local == 'txbxContent' ||
                  element.name.local == 'imagedata' ||
                  element.name.local == 'blip');
          if (!hasNestedContent) {
            final shape = _shapeRunFromElement(descendant);
            if (shape != null) {
              flushText();
              result.add(shape);
            }
          }
          break;
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
          if (breakType != 'page' && breakType != 'column') {
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
          final transform = _nearestDrawingTransform(descendant);
          result.add(
            ConversionImageRun(
              bytes: content,
              widthPoints: extent.$1,
              heightPoints: extent.$2,
              altText: _nearestDrawingAltText(descendant),
              hyperlink: hyperlink,
              placement: _nearestObjectPlacement(descendant),
              crop: _nearestDrawingCrop(descendant),
              rotationDegrees: transform.rotationDegrees,
              flipHorizontal: transform.flipHorizontal,
              flipVertical: transform.flipVertical,
              sourceRelationshipId: embed,
              sourcePartPath: relationship.target,
            ),
          );
          break;
        case 'imagedata':
          // Older/compatibility-mode DOCX files can store pictures as VML
          // (<v:shape><v:imagedata r:id=.../>). Supporting only DrawingML
          // makes otherwise valid resume photos disappear or degrade to a
          // placeholder during Smart Editor import.
          final relationshipId = _attribute(descendant, 'id');
          final relationship = relationships.byId(relationshipId);
          if (relationship == null || relationship.isExternal) break;
          final entry = entries[relationship.target];
          if (entry == null) break;
          flushText();
          final extent = _nearestVmlExtent(descendant);
          result.add(
            ConversionImageRun(
              bytes: entry.content,
              widthPoints: extent.$1,
              heightPoints: extent.$2,
              altText: _nearestVmlAltText(descendant),
              hyperlink: hyperlink,
              placement: _nearestVmlPlacement(descendant),
              crop: _nearestVmlCrop(descendant),
              sourceRelationshipId: relationshipId,
              sourcePartPath: relationship.target,
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
    final pgBorders = _directChild(sectPr, 'pgBorders');
    var width = _twips(_attribute(pgSz, 'w'), fallback: 11906 / 20);
    var height = _twips(_attribute(pgSz, 'h'), fallback: 16838 / 20);
    final orientation = (_attribute(pgSz, 'orient') ?? '').toLowerCase();
    if (orientation == 'landscape' && width < height) {
      final swap = width;
      width = height;
      height = swap;
    } else if (orientation == 'portrait' && width > height) {
      final swap = width;
      width = height;
      height = swap;
    }
    return ConversionPageSettings(
      widthPoints: width,
      heightPoints: height,
      marginTopPoints: _twips(_attribute(pgMar, 'top'), fallback: 72),
      marginRightPoints: _twips(_attribute(pgMar, 'right'), fallback: 72),
      marginBottomPoints: _twips(_attribute(pgMar, 'bottom'), fallback: 72),
      marginLeftPoints: _twips(_attribute(pgMar, 'left'), fallback: 72),
      headerDistancePoints: _twips(_attribute(pgMar, 'header'), fallback: 36),
      footerDistancePoints: _twips(_attribute(pgMar, 'footer'), fallback: 36),
      gutterPoints: _twips(_attribute(pgMar, 'gutter'), fallback: 0),
      pageBorders: ConversionPageBorders(
        borders: _parseBorders(pgBorders),
        offsetFrom: _attribute(pgBorders, 'offsetFrom') ?? 'text',
        display: _attribute(pgBorders, 'display') ?? 'allPages',
        zOrder: _attribute(pgBorders, 'zOrder') ?? 'front',
      ),
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


  ConversionImageCrop _nearestDrawingCrop(xml.XmlElement blip) {
    xml.XmlElement? current = blip.parentElement;
    while (current != null && current.name.local != 'r') {
      final srcRect = _directChild(current, 'srcRect');
      if (srcRect != null) {
        double side(String name) {
          final raw = double.tryParse(_attribute(srcRect, name) ?? '');
          if (raw == null) return 0;
          return (raw / 100000).clamp(0.0, 0.999).toDouble();
        }

        return ConversionImageCrop(
          left: side('l'),
          top: side('t'),
          right: side('r'),
          bottom: side('b'),
        );
      }
      current = current.parentElement;
    }
    return const ConversionImageCrop();
  }

  ({
    double rotationDegrees,
    bool flipHorizontal,
    bool flipVertical,
  }) _nearestDrawingTransform(xml.XmlElement blip) {
    xml.XmlElement? current = blip.parentElement;
    while (current != null && current.name.local != 'r') {
      if (current.name.local == 'pic') {
        final shapeProperties = _directChild(current, 'spPr');
        final transform = _directChild(shapeProperties, 'xfrm');
        final rawRotation = double.tryParse(_attribute(transform, 'rot') ?? '');
        return (
          rotationDegrees: rawRotation == null ? 0 : rawRotation / 60000,
          flipHorizontal:
              _toggleValueFromAttribute(_attribute(transform, 'flipH')),
          flipVertical:
              _toggleValueFromAttribute(_attribute(transform, 'flipV')),
        );
      }
      current = current.parentElement;
    }
    return (
      rotationDegrees: 0,
      flipHorizontal: false,
      flipVertical: false,
    );
  }

  ConversionImageCrop _nearestVmlCrop(xml.XmlElement imageData) {
    double side(String name) {
      final raw = _attribute(imageData, name)?.trim();
      if (raw == null || raw.isEmpty) return 0;
      if (raw.endsWith('f')) {
        final fixed = double.tryParse(raw.substring(0, raw.length - 1));
        return fixed == null ? 0 : (fixed / 65536).clamp(0.0, 0.999).toDouble();
      }
      if (raw.endsWith('%')) {
        final percent = double.tryParse(raw.substring(0, raw.length - 1));
        return percent == null ? 0 : (percent / 100).clamp(0.0, 0.999).toDouble();
      }
      final numeric = double.tryParse(raw);
      if (numeric == null) return 0;
      return numeric.clamp(0.0, 0.999).toDouble();
    }

    return ConversionImageCrop(
      left: side('cropleft'),
      top: side('croptop'),
      right: side('cropright'),
      bottom: side('cropbottom'),
    );
  }

  static bool _isNestedInside(
    xml.XmlElement element,
    String ancestorName, {
    required xml.XmlElement stopAt,
  }) {
    var current = element.parentElement;
    while (current != null && !identical(current, stopAt)) {
      if (current.name.local == ancestorName) return true;
      current = current.parentElement;
    }
    return false;
  }

  ConversionShapeRun? _shapeRunFromContext(
    xml.XmlElement element, {
    List<ConversionBlock> blocks = const <ConversionBlock>[],
  }) {
    xml.XmlElement? current = element.parentElement;
    while (current != null && current.name.local != 'r') {
      if (_isShapeElement(current)) {
        final isLegacyTextboxShape = current.name.local == 'shape' &&
            current.descendants
                .whereType<xml.XmlElement>()
                .any((element) => element.name.local == 'textbox') &&
            !current.descendants
                .whereType<xml.XmlElement>()
                .any((element) => element.name.local == 'textpath');
        // Legacy VML text boxes were already a stable structured type before
        // WM5. Do not silently reclassify them as generic shapes; that breaks
        // DF compatibility and loses text-box-specific editing semantics.
        if (isLegacyTextboxShape) return null;
        return _shapeRunFromElement(current, blocks: blocks);
      }
      current = current.parentElement;
    }
    return null;
  }

  ConversionShapeRun? _shapeRunFromElement(
    xml.XmlElement shape, {
    List<ConversionBlock> blocks = const <ConversionBlock>[],
  }) {
    if (!_isShapeElement(shape)) return null;
    final kind = _shapeKind(shape);
    final extent = _shapeExtent(shape);
    if (extent.$1 <= 0 || extent.$2 <= 0) return null;
    final style = _shapeStyle(shape);
    final effectiveBlocks = blocks.isNotEmpty
        ? blocks
        : _vmlTextPathBlocks(shape, style: style, extent: extent);
    return ConversionShapeRun(
      kind: kind,
      widthPoints: extent.$1,
      heightPoints: extent.$2,
      blocks: effectiveBlocks,
      style: style,
      placement: _nearestObjectPlacement(shape),
      altText: _shapeAltText(shape),
    );
  }

  static bool _isShapeElement(xml.XmlElement element) =>
      const <String>{'wsp', 'shape', 'rect', 'roundrect', 'oval', 'line'}
          .contains(element.name.local);

  ConversionShapeKind _shapeKind(xml.XmlElement shape) {
    if (shape.descendants
        .whereType<xml.XmlElement>()
        .any((element) => element.name.local == 'textpath')) {
      return ConversionShapeKind.textPath;
    }
    final local = shape.name.local;
    if (local == 'rect') return ConversionShapeKind.rectangle;
    if (local == 'roundrect') return ConversionShapeKind.roundedRectangle;
    if (local == 'oval') return ConversionShapeKind.ellipse;
    if (local == 'line') return ConversionShapeKind.line;
    final preset = shape.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local == 'prstGeom')
        .map((element) => _attribute(element, 'prst'))
        .whereType<String>()
        .firstOrNull;
    return switch (preset?.toLowerCase()) {
      'rect' => ConversionShapeKind.rectangle,
      'roundrect' || 'round1rect' || 'round2samerect' || 'round2diagrect' =>
        ConversionShapeKind.roundedRectangle,
      'ellipse' => ConversionShapeKind.ellipse,
      'line' || 'straightconnector1' => ConversionShapeKind.line,
      _ => ConversionShapeKind.unknown,
    };
  }

  List<ConversionBlock> _vmlTextPathBlocks(
    xml.XmlElement shape, {
    required ConversionShapeStyle style,
    required (double, double) extent,
  }) {
    final textPath = shape.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local == 'textpath')
        .firstOrNull;
    final text = _attribute(textPath, 'string')?.trim();
    if (text == null || text.isEmpty) return const <ConversionBlock>[];

    final textPathStyle = _attribute(textPath, 'style') ?? '';
    final family = _cssStringValue(textPathStyle, 'font-family')
        ?.replaceAll('"', '')
        .replaceAll("'", '')
        .trim();
    final rawSize = _cssPointValue(textPathStyle, 'font-size');
    // Office watermarks often keep a nominal 1pt VML font and let the shape
    // geometry scale the text. Use the frame height as a readable viewer
    // fallback while retaining the original VML object geometry separately.
    final fontSize = rawSize == null || rawSize <= 2
        ? (extent.$2 * 0.34).clamp(18.0, 72.0).toDouble()
        : rawSize;
    final fill = shape.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local == 'fill')
        .map((element) => _normalizeColor(
              (_attribute(element, 'color') ?? '').replaceFirst('#', ''),
            ))
        .whereType<String>()
        .firstOrNull;
    return <ConversionBlock>[
      ConversionParagraph(
        alignment: ConversionTextAlignment.center,
        spaceAfterPoints: 0,
        inlines: <ConversionInline>[
          ConversionTextRun(
            text: text,
            style: ConversionTextStyle(
              fontFamily: family == null || family.isEmpty ? null : family,
              fontSizePoints: fontSize,
              colorHex: fill ?? style.fillColorHex ?? 'B7B7B7',
            ),
          ),
        ],
      ),
    ];
  }

  (double, double) _shapeExtent(xml.XmlElement shape) {
    final style = _attribute(shape, 'style');
    if (style != null) {
      final width = _cssPointValue(style, 'width');
      final height = _cssPointValue(style, 'height');
      if (width != null && height != null && width > 0 && height > 0) {
        return (width, height);
      }
    }
    xml.XmlElement? current = shape;
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
    return (120, 60);
  }

  ConversionShapeStyle _shapeStyle(xml.XmlElement shape) {
    final transform = shape.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local == 'xfrm')
        .firstOrNull;
    final rawRotation = double.tryParse(_attribute(transform, 'rot') ?? '');
    final vmlRotation = double.tryParse(
      _cssStringValue(_attribute(shape, 'style') ?? '', 'rotation') ?? '',
    );
    final line = shape.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local == 'ln')
        .firstOrNull;

    String? drawingColor(xml.XmlElement? root) {
      if (root == null) return null;
      final color = root.descendants
          .whereType<xml.XmlElement>()
          .where((element) => element.name.local == 'srgbClr')
          .map((element) => _normalizeColor(_attribute(element, 'val')))
          .whereType<String>()
          .firstOrNull;
      return color;
    }

    final solidFills = shape.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local == 'solidFill')
        .toList(growable: false);
    final fill = solidFills.isEmpty ? null : drawingColor(solidFills.first);
    final stroke = line == null
        ? _normalizeColor(_attribute(shape, 'strokecolor'))
        : drawingColor(line);
    final rawStrokeWidth = double.tryParse(_attribute(line, 'w') ?? '');
    final vmlStroke = _cssPointValue(
          'stroke-width:${_attribute(shape, 'strokeweight') ?? ''}',
          'stroke-width',
        ) ??
        1;
    final dash = line?.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local == 'prstDash')
        .map((element) => _attribute(element, 'val'))
        .whereType<String>()
        .firstOrNull;
    final vmlStrokeElement = shape.childElements
        .where((element) => element.name.local == 'stroke')
        .firstOrNull;
    final vmlDash = _attribute(vmlStrokeElement, 'dashstyle') ??
        _attribute(vmlStrokeElement, 'dashStyle');
    final vmlFill = _normalizeColor(
      (_attribute(shape, 'fillcolor') ?? '').replaceFirst('#', ''),
    );
    return ConversionShapeStyle(
      fillColorHex: fill ?? vmlFill,
      strokeColorHex: stroke,
      strokeWidthPoints: rawStrokeWidth == null
          ? vmlStroke
          : (rawStrokeWidth / 12700).clamp(0.25, 24).toDouble(),
      dashStyle: dash ?? vmlDash,
      rotationDegrees:
          rawRotation == null ? (vmlRotation ?? 0) : rawRotation / 60000,
      flipHorizontal: _toggleValueFromAttribute(_attribute(transform, 'flipH')),
      flipVertical: _toggleValueFromAttribute(_attribute(transform, 'flipV')),
    );
  }

  String? _shapeAltText(xml.XmlElement shape) {
    final direct = _attribute(shape, 'alt') ?? _attribute(shape, 'title');
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();
    xml.XmlElement? current = shape;
    while (current != null && current.name.local != 'r') {
      final docPr = current.childElements
          .where((element) => element.name.local == 'docPr')
          .firstOrNull;
      final value = _attribute(docPr, 'descr') ?? _attribute(docPr, 'name');
      if (value != null && value.trim().isNotEmpty) return value.trim();
      current = current.parentElement;
    }
    return null;
  }

  (double?, double?) _nearestTextBoxExtent(xml.XmlElement textBox) {
    xml.XmlElement? current = textBox.parentElement;
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
      if (_isShapeElement(current)) {
        final style = _attribute(current, 'style');
        if (style != null) {
          return (
            _cssPointValue(style, 'width'),
            _cssPointValue(style, 'height'),
          );
        }
      }
      current = current.parentElement;
    }
    return (null, null);
  }

  (double, double) _nearestVmlExtent(xml.XmlElement imageData) {
    xml.XmlElement? current = imageData.parentElement;
    while (current != null && current.name.local != 'r') {
      if (_isShapeElement(current)) {
        final style = _attribute(current, 'style');
        if (style != null) {
          final width = _cssPointValue(style, 'width');
          final height = _cssPointValue(style, 'height');
          if (width != null && height != null && width > 0 && height > 0) {
            return (width, height);
          }
        }
      }
      current = current.parentElement;
    }
    return (160, 120);
  }

  String? _nearestVmlAltText(xml.XmlElement imageData) {
    xml.XmlElement? current = imageData.parentElement;
    while (current != null && current.name.local != 'r') {
      if (_isShapeElement(current)) {
        final alt = _attribute(current, 'alt') ?? _attribute(current, 'title');
        if (alt != null && alt.trim().isNotEmpty) return alt.trim();
      }
      current = current.parentElement;
    }
    return null;
  }


  _CellMargins _tableCellMargins(xml.XmlElement? margins) {
    if (margins == null) return const _CellMargins();

    double? side(String primary, [String? fallback]) {
      final element = _directChild(margins, primary) ??
          (fallback == null ? null : _directChild(margins, fallback));
      if (element == null) return null;
      final type = _attribute(element, 'type');
      final raw = double.tryParse(_attribute(element, 'w') ?? '');
      if (raw == null) return null;
      if (type == null || type == 'dxa') return raw / 20;
      return null;
    }

    return _CellMargins(
      top: side('top'),
      right: side('right', 'end'),
      bottom: side('bottom'),
      left: side('left', 'start'),
    );
  }

  ({double top, double right, double bottom, double left})
      _nearestTextBoxInsets(xml.XmlElement textBox) {
    xml.XmlElement? current = textBox.parentElement;
    while (current != null && current.name.local != 'r') {
      if (current.name.local == 'textbox') {
        final inset = _attribute(current, 'inset');
        if (inset != null && inset.trim().isNotEmpty) {
          double pointValue(String raw) {
            final match = RegExp(r'^\s*(-?[0-9.]+)\s*(pt|px|in|cm|mm)?\s*$',
                    caseSensitive: false)
                .firstMatch(raw);
            if (match == null) return 0;
            final value = double.tryParse(match.group(1) ?? '') ?? 0;
            return switch ((match.group(2) ?? 'pt').toLowerCase()) {
              'px' => value * 72 / 96,
              'in' => value * 72,
              'cm' => value * 72 / 2.54,
              'mm' => value * 72 / 25.4,
              _ => value,
            };
          }

          final values = inset.split(',').map(pointValue).toList(growable: false);
          if (values.length == 4) {
            return (
              top: values[1],
              right: values[2],
              bottom: values[3],
              left: values[0],
            );
          }
        }
      }
      final bodyPr = current.name.local == 'bodyPr'
          ? current
          : current.childElements
              .where((element) => element.name.local == 'bodyPr')
              .firstOrNull;
      if (bodyPr != null) {
        double inset(String name) {
          final raw = double.tryParse(_attribute(bodyPr, name) ?? '');
          return raw == null ? 0 : raw / 12700;
        }

        return (
          top: inset('tIns'),
          right: inset('rIns'),
          bottom: inset('bIns'),
          left: inset('lIns'),
        );
      }
      current = current.parentElement;
    }
    return (top: 0, right: 0, bottom: 0, left: 0);
  }

  ConversionObjectPlacement _nearestObjectPlacement(xml.XmlElement element) {
    xml.XmlElement? current =
        _isShapeElement(element) ? element : element.parentElement;
    while (current != null && current.name.local != 'r') {
      if (current.name.local == 'inline') {
        return const ConversionObjectPlacement.inline();
      }
      if (_isShapeElement(current)) {
        final style = _attribute(current, 'style');
        if (style != null &&
            RegExp(
              r'(?:^|;)\s*position\s*:\s*absolute',
              caseSensitive: false,
            ).hasMatch(style)) {
          final zIndex = int.tryParse(
                _cssStringValue(style, 'z-index')?.trim() ?? '',
              ) ??
              0;
          final vmlWrap = current.childElements
              .where((child) => child.name.local == 'wrap')
              .firstOrNull;
          final rawWrapType = _attribute(vmlWrap, 'type') ??
              _cssStringValue(style, 'mso-wrap-style');
          final wrapStyle = switch (rawWrapType?.toLowerCase()) {
            'none' => 'wrapNone',
            'tight' => 'wrapTight',
            'through' => 'wrapThrough',
            'topandbottom' => 'wrapTopAndBottom',
            'square' => 'wrapSquare',
            _ => rawWrapType,
          };
          return ConversionObjectPlacement.floating(
            horizontalRelativeFrom:
                _normalizeHorizontalRelative(
                  _cssStringValue(style, 'mso-position-horizontal-relative') ??
                      'margin',
                ),
            verticalRelativeFrom:
                _normalizeVerticalRelative(
                  _cssStringValue(style, 'mso-position-vertical-relative') ??
                      'margin',
                ),
            horizontalOffsetPoints: _cssPointValue(style, 'margin-left') ??
                _cssPointValue(style, 'left'),
            verticalOffsetPoints: _cssPointValue(style, 'margin-top') ??
                _cssPointValue(style, 'top'),
            horizontalAlignment:
                _cssStringValue(style, 'mso-position-horizontal'),
            verticalAlignment:
                _cssStringValue(style, 'mso-position-vertical'),
            behindText: zIndex < 0,
            allowOverlap: _attribute(current, 'allowoverlap') != 'f',
            wrapStyle: wrapStyle,
            wrapText: _attribute(vmlWrap, 'side'),
            distanceTopPoints:
                _cssPointValue(style, 'mso-wrap-distance-top') ?? 0,
            distanceBottomPoints:
                _cssPointValue(style, 'mso-wrap-distance-bottom') ?? 0,
            distanceLeftPoints:
                _cssPointValue(style, 'mso-wrap-distance-left') ?? 0,
            distanceRightPoints:
                _cssPointValue(style, 'mso-wrap-distance-right') ?? 0,
            relativeHeight: zIndex.abs(),
          );
        }
      }
      if (current.name.local == 'anchor') {
        final horizontal = current.childElements
            .where((child) => child.name.local == 'positionH')
            .firstOrNull;
        final vertical = current.childElements
            .where((child) => child.name.local == 'positionV')
            .firstOrNull;

        double? positionOffset(xml.XmlElement? position) {
          if (position == null) return null;
          final offset = position.childElements
              .where((child) => child.name.local == 'posOffset')
              .firstOrNull;
          final raw = double.tryParse(offset?.innerText.trim() ?? '');
          return raw == null ? null : raw / 12700;
        }

        String? positionAlignment(xml.XmlElement? position) {
          if (position == null) return null;
          final align = position.childElements
              .where((child) => child.name.local == 'align')
              .firstOrNull
              ?.innerText
              .trim();
          return align == null || align.isEmpty ? null : align;
        }

        final wrapElement = current.childElements
            .where((child) => child.name.local.startsWith('wrap'))
            .firstOrNull;
        double wrapDistance(String name) {
          final raw = double.tryParse(_attribute(current, name) ?? '');
          return raw == null ? 0 : raw / 12700;
        }

        final simplePos = current.childElements
            .where((child) => child.name.local == 'simplePos')
            .firstOrNull;
        final usesSimplePosition = _boolAttribute(current, 'simplePos') &&
            simplePos != null;
        final simpleX = double.tryParse(_attribute(simplePos, 'x') ?? '');
        final simpleY = double.tryParse(_attribute(simplePos, 'y') ?? '');

        return ConversionObjectPlacement.floating(
          horizontalRelativeFrom: usesSimplePosition
              ? 'page'
              : _normalizeHorizontalRelative(
                  _attribute(horizontal, 'relativeFrom'),
                ),
          verticalRelativeFrom: usesSimplePosition
              ? 'page'
              : _normalizeVerticalRelative(
                  _attribute(vertical, 'relativeFrom'),
                ),
          horizontalOffsetPoints: usesSimplePosition && simpleX != null
              ? simpleX / 12700
              : positionOffset(horizontal),
          verticalOffsetPoints: usesSimplePosition && simpleY != null
              ? simpleY / 12700
              : positionOffset(vertical),
          horizontalAlignment: positionAlignment(horizontal),
          verticalAlignment: positionAlignment(vertical),
          behindText: _boolAttribute(current, 'behindDoc'),
          allowOverlap: !_hasFalseAttribute(current, 'allowOverlap'),
          wrapStyle: wrapElement?.name.local,
          wrapText: _attribute(wrapElement, 'wrapText'),
          distanceTopPoints: wrapDistance('distT'),
          distanceBottomPoints: wrapDistance('distB'),
          distanceLeftPoints: wrapDistance('distL'),
          distanceRightPoints: wrapDistance('distR'),
          relativeHeight: int.tryParse(_attribute(current, 'relativeHeight') ?? '') ?? 0,
          layoutInCell: !_hasFalseAttribute(current, 'layoutInCell'),
          locked: _boolAttribute(current, 'locked'),
        );
      }
      current = current.parentElement;
    }
    return const ConversionObjectPlacement.inline();
  }

  ConversionObjectPlacement _nearestVmlPlacement(xml.XmlElement imageData) {
    xml.XmlElement? current = imageData.parentElement;
    while (current != null && current.name.local != 'r') {
      if (current.name.local == 'shape') {
        final style = _attribute(current, 'style');
        if (style == null ||
            !RegExp(r'(?:^|;)\s*position\s*:\s*absolute', caseSensitive: false)
                .hasMatch(style)) {
          return const ConversionObjectPlacement.inline();
        }
        final horizontalRelative =
            _normalizeHorizontalRelative(
              _cssStringValue(style, 'mso-position-horizontal-relative') ??
                  'margin',
            );
        final verticalRelative =
            _normalizeVerticalRelative(
              _cssStringValue(style, 'mso-position-vertical-relative') ??
                  'margin',
            );
        final zIndex = int.tryParse(
              _cssStringValue(style, 'z-index')?.trim() ?? '',
            ) ??
            0;
        final vmlWrap = current.childElements
            .where((child) => child.name.local == 'wrap')
            .firstOrNull;
        final rawWrapType = _attribute(vmlWrap, 'type') ??
            _cssStringValue(style, 'mso-wrap-style');
        final wrapStyle = switch (rawWrapType?.toLowerCase()) {
          'none' => 'wrapNone',
          'tight' => 'wrapTight',
          'through' => 'wrapThrough',
          'topandbottom' => 'wrapTopAndBottom',
          'square' => 'wrapSquare',
          _ => rawWrapType,
        };
        return ConversionObjectPlacement.floating(
          horizontalRelativeFrom: horizontalRelative,
          verticalRelativeFrom: verticalRelative,
          horizontalOffsetPoints:
              _cssPointValue(style, 'margin-left') ??
                  _cssPointValue(style, 'left'),
          verticalOffsetPoints:
              _cssPointValue(style, 'margin-top') ??
                  _cssPointValue(style, 'top'),
          horizontalAlignment: _cssStringValue(style, 'mso-position-horizontal'),
          verticalAlignment: _cssStringValue(style, 'mso-position-vertical'),
          behindText: zIndex < 0,
          allowOverlap: _attribute(current, 'allowoverlap') != 'f',
          wrapStyle: wrapStyle,
          wrapText: _attribute(vmlWrap, 'side'),
          distanceTopPoints:
              _cssPointValue(style, 'mso-wrap-distance-top') ?? 0,
          distanceBottomPoints:
              _cssPointValue(style, 'mso-wrap-distance-bottom') ?? 0,
          distanceLeftPoints:
              _cssPointValue(style, 'mso-wrap-distance-left') ?? 0,
          distanceRightPoints:
              _cssPointValue(style, 'mso-wrap-distance-right') ?? 0,
          relativeHeight: zIndex.abs(),
        );
      }
      current = current.parentElement;
    }
    return const ConversionObjectPlacement.inline();
  }

  static String? _normalizeHorizontalRelative(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    return switch (normalized) {
      'char' => 'character',
      'text' => 'paragraph',
      'left-margin' => 'leftMargin',
      'right-margin' => 'rightMargin',
      'inside-margin' => 'insideMargin',
      'outside-margin' => 'outsideMargin',
      _ => value!.trim(),
    };
  }

  static String? _normalizeVerticalRelative(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    return switch (normalized) {
      'text' => 'paragraph',
      'char' => 'character',
      'top-margin' => 'topMargin',
      'bottom-margin' => 'bottomMargin',
      'inside-margin' => 'insideMargin',
      'outside-margin' => 'outsideMargin',
      _ => value!.trim(),
    };
  }

  static bool _toggleElement(xml.XmlElement? element) {
    if (element == null) return false;
    final value = _attribute(element, 'val')?.trim().toLowerCase();
    return value == null ||
        value.isEmpty ||
        value == '1' ||
        value == 'true' ||
        value == 'on';
  }

  static double? _optionalTwips(String? value) {
    final parsed = double.tryParse(value ?? '');
    return parsed == null ? null : parsed / 20;
  }

  static bool _boolAttribute(xml.XmlElement element, String local) {
    final value = _attribute(element, local)?.trim().toLowerCase();
    return value == '1' || value == 'true' || value == 'on';
  }

  static bool _hasFalseAttribute(xml.XmlElement element, String local) {
    final value = _attribute(element, local)?.trim().toLowerCase();
    return value == '0' || value == 'false' || value == 'off';
  }

  static String? _cssStringValue(String style, String property) {
    final match = RegExp(
      '(?:^|;)\\s*${RegExp.escape(property)}\\s*:\\s*([^;]+)',
      caseSensitive: false,
    ).firstMatch(style);
    final value = match?.group(1)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static double? _cssPointValue(String style, String property) {
    final match = RegExp(
      '(?:^|;)\\s*${RegExp.escape(property)}'
      '\\s*:\\s*(-?[0-9.]+)\\s*(pt|px|in|cm|mm)?',
      caseSensitive: false,
    ).firstMatch(style);
    if (match == null) return null;
    final value = double.tryParse(match.group(1) ?? '');
    if (value == null) return null;
    return switch ((match.group(2) ?? 'pt').toLowerCase()) {
      'px' => value * 72 / 96,
      'in' => value * 72,
      'cm' => value * 72 / 2.54,
      'mm' => value * 72 / 25.4,
      _ => value,
    };
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

class _ThemeCatalog {
  const _ThemeCatalog({
    this.colors = const <String, String>{},
    this.majorLatin,
    this.minorLatin,
    this.majorEastAsia,
    this.minorEastAsia,
    this.majorComplexScript,
    this.minorComplexScript,
  });

  final Map<String, String> colors;
  final String? majorLatin;
  final String? minorLatin;
  final String? majorEastAsia;
  final String? minorEastAsia;
  final String? majorComplexScript;
  final String? minorComplexScript;

  factory _ThemeCatalog.fromEntry(ArchiveFile? entry) {
    if (entry == null) return const _ThemeCatalog();

    final document = xml.XmlDocument.parse(utf8.decode(entry.content));
    final root = document.rootElement;
    final themeElements = root.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local == 'themeElements')
        .firstOrNull;
    if (themeElements == null) return const _ThemeCatalog();

    final colors = <String, String>{};
    final colorScheme = themeElements.childElements
        .where((element) => element.name.local == 'clrScheme')
        .firstOrNull;
    if (colorScheme != null) {
      for (final slot in colorScheme.childElements) {
        final valueElement = slot.childElements.firstOrNull;
        if (valueElement == null) continue;
        final local = valueElement.name.local;
        final raw = switch (local) {
          'srgbClr' => _attribute(valueElement, 'val'),
          'sysClr' =>
            _attribute(valueElement, 'lastClr') ??
                _attribute(valueElement, 'val'),
          _ => null,
        };
        final normalized = _normalizeColor(raw);
        if (normalized != null) {
          colors[slot.name.local.toLowerCase()] = normalized;
        }
      }
    }

    String? family(xml.XmlElement? parent, String local) {
      if (parent == null) return null;
      final element = parent.childElements
          .where((child) => child.name.local == local)
          .firstOrNull;
      final value = _attribute(element, 'typeface')?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    final fontScheme = themeElements.childElements
        .where((element) => element.name.local == 'fontScheme')
        .firstOrNull;
    final majorFont = fontScheme?.childElements
        .where((element) => element.name.local == 'majorFont')
        .firstOrNull;
    final minorFont = fontScheme?.childElements
        .where((element) => element.name.local == 'minorFont')
        .firstOrNull;

    return _ThemeCatalog(
      colors: Map<String, String>.unmodifiable(colors),
      majorLatin: family(majorFont, 'latin'),
      minorLatin: family(minorFont, 'latin'),
      majorEastAsia: family(majorFont, 'ea'),
      minorEastAsia: family(minorFont, 'ea'),
      majorComplexScript: family(majorFont, 'cs'),
      minorComplexScript: family(minorFont, 'cs'),
    );
  }

  String? resolveFont(String? themeToken) {
    final token = themeToken?.trim().toLowerCase();
    if (token == null || token.isEmpty) return null;
    final major = token.startsWith('major');
    final minor = token.startsWith('minor');
    if (!major && !minor) return null;

    if (token.contains('eastasia')) {
      return major ? (majorEastAsia ?? majorLatin) : (minorEastAsia ?? minorLatin);
    }
    if (token.contains('bidi') || token.contains('cs')) {
      return major
          ? (majorComplexScript ?? majorLatin)
          : (minorComplexScript ?? minorLatin);
    }
    return major ? majorLatin : minorLatin;
  }

  String? resolveColor(
    String? themeColor, {
    String? tint,
    String? shade,
  }) {
    if (themeColor == null || themeColor.isEmpty) return null;
    final key = switch (themeColor.toLowerCase()) {
      'text1' => 'dk1',
      'text2' => 'dk2',
      'background1' => 'lt1',
      'background2' => 'lt2',
      final other => other,
    };
    final base = colors[key];
    if (base == null) return null;
    return _applyThemeTintShade(base, tint: tint, shade: shade);
  }
}

String _applyThemeTintShade(
  String color, {
  String? tint,
  String? shade,
}) {
  int channel(int start) {
    var value = start;
    final shadeByte = int.tryParse(shade ?? '', radix: 16);
    if (shadeByte != null) {
      value = (value * shadeByte / 255).round().clamp(0, 255).toInt();
    }
    final tintByte = int.tryParse(tint ?? '', radix: 16);
    if (tintByte != null) {
      value = (value + (255 - value) * tintByte / 255)
          .round()
          .clamp(0, 255)
          .toInt();
    }
    return value;
  }

  final raw = int.tryParse(color, radix: 16);
  if (raw == null) return color;
  final r = channel((raw >> 16) & 0xFF);
  final g = channel((raw >> 8) & 0xFF);
  final b = channel(raw & 0xFF);
  return '${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

class _StylesCatalog {
  _StylesCatalog({
    required this.styles,
    required this.defaultParagraph,
    required this.defaultRun,
    this.defaultParagraphStyleId,
  });

  final Map<String, _StyleDefinition> styles;
  final _ParagraphProperties defaultParagraph;
  final _RunProperties defaultRun;
  final String? defaultParagraphStyleId;

  factory _StylesCatalog.fromEntry(
    ArchiveFile? entry, {
    required _ThemeCatalog theme,
  }) {
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
      theme: theme,
    );

    final styles = <String, _StyleDefinition>{};
    String? defaultParagraphStyleId;
    for (final element in root.childElements.where(
      (element) => element.name.local == 'style',
    )) {
      final id = _attribute(element, 'styleId');
      if (id == null || id.isEmpty) continue;
      final type = (_attribute(element, 'type') ?? '').toLowerCase();
      final isDefault = _toggleValueFromAttribute(
        _attribute(element, 'default'),
      );
      if (type == 'paragraph' && isDefault) {
        defaultParagraphStyleId = id;
      }
      final conditional = <String, _TableStyleProperties>{};
      if (type == 'table') {
        for (final child in element.childElements.where(
          (child) => child.name.local == 'tblStylePr',
        )) {
          final conditionalType = _attribute(child, 'type');
          if (conditionalType == null || conditionalType.isEmpty) continue;
          conditional[conditionalType] = _parseTableStyleProperties(
            child,
            theme: theme,
          );
        }
      }
      styles[id] = _StyleDefinition(
        basedOn: _attribute(_directChild(element, 'basedOn'), 'val'),
        type: type,
        isDefault: isDefault,
        paragraph: _parseParagraphProperties(_directChild(element, 'pPr')),
        run: _parseRunProperties(_directChild(element, 'rPr'), theme: theme),
        table: type == 'table'
            ? _parseTableStyleProperties(element, theme: theme)
            : const _TableStyleProperties(),
        conditionalTable: conditional,
      );
    }
    return _StylesCatalog(
      styles: styles,
      defaultParagraph: defaultParagraph,
      defaultRun: defaultRun,
      defaultParagraphStyleId: defaultParagraphStyleId,
    );
  }

  _ParagraphProperties resolveParagraph(String? styleId) {
    var result = defaultParagraph;
    final effectiveId =
        styleId == null || styleId.isEmpty ? defaultParagraphStyleId : styleId;
    for (final definition in _styleChain(effectiveId)) {
      result = result.merge(definition.paragraph);
    }
    return result;
  }

  _RunProperties resolveRun(String? styleId) {
    var result = defaultRun;
    final effectiveId =
        styleId == null || styleId.isEmpty ? defaultParagraphStyleId : styleId;
    for (final definition in _styleChain(effectiveId)) {
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

  _TableStyleProperties resolveTableBase(String? styleId) {
    var result = const _TableStyleProperties();
    for (final definition in _styleChain(styleId)) {
      if (definition.type == 'table') {
        result = result.merge(definition.table);
      }
    }
    return result;
  }

  _TableStyleProperties resolveTableCell(
    String? styleId,
    List<String> conditionalTypes,
  ) {
    var result = resolveTableBase(styleId);
    for (final definition in _styleChain(styleId)) {
      if (definition.type != 'table') continue;
      for (final type in conditionalTypes) {
        final conditional = definition.conditionalTable[type];
        if (conditional != null) result = result.merge(conditional);
      }
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
    required this.type,
    required this.isDefault,
    required this.paragraph,
    required this.run,
    this.table = const _TableStyleProperties(),
    this.conditionalTable = const <String, _TableStyleProperties>{},
  });

  final String? basedOn;
  final String type;
  final bool isDefault;
  final _ParagraphProperties paragraph;
  final _RunProperties run;
  final _TableStyleProperties table;
  final Map<String, _TableStyleProperties> conditionalTable;
}

class _TableStyleProperties {
  const _TableStyleProperties({
    this.tableBorders = const ConversionBorders(),
    this.cellBorders = const ConversionBorders(),
    this.cellMargins = const _CellMargins(),
    this.shadingHex,
    this.layout,
    this.widthPoints,
    this.widthPercent,
    this.indentPoints = 0,
    this.cellSpacingPoints = 0,
    this.alignment = ConversionTextAlignment.left,
    this.verticalAlignment,
    this.noWrap = false,
    this.paragraph = const _ParagraphProperties(),
    this.run = const _RunProperties(),
    this.hasTableBorders = false,
    this.hasCellBorders = false,
    this.hasCellMargins = false,
    this.hasShading = false,
    this.hasLayout = false,
    this.hasWidth = false,
    this.hasIndent = false,
    this.hasCellSpacing = false,
    this.hasAlignment = false,
    this.hasVerticalAlignment = false,
    this.hasNoWrap = false,
  });

  final ConversionBorders tableBorders;
  final ConversionBorders cellBorders;
  final _CellMargins cellMargins;
  final String? shadingHex;
  final ConversionTableLayout? layout;
  final double? widthPoints;
  final double? widthPercent;
  final double indentPoints;
  final double cellSpacingPoints;
  final ConversionTextAlignment alignment;
  final ConversionTableCellVerticalAlignment? verticalAlignment;
  final bool noWrap;
  final _ParagraphProperties paragraph;
  final _RunProperties run;
  final bool hasTableBorders;
  final bool hasCellBorders;
  final bool hasCellMargins;
  final bool hasShading;
  final bool hasLayout;
  final bool hasWidth;
  final bool hasIndent;
  final bool hasCellSpacing;
  final bool hasAlignment;
  final bool hasVerticalAlignment;
  final bool hasNoWrap;

  _TableStyleProperties merge(_TableStyleProperties other) {
    return _TableStyleProperties(
      tableBorders: other.hasTableBorders
          ? tableBorders.merge(other.tableBorders)
          : tableBorders,
      cellBorders: other.hasCellBorders
          ? cellBorders.merge(other.cellBorders)
          : cellBorders,
      cellMargins:
          other.hasCellMargins ? cellMargins.merge(other.cellMargins) : cellMargins,
      shadingHex: other.hasShading ? other.shadingHex : shadingHex,
      layout: other.hasLayout ? other.layout : layout,
      widthPoints: other.hasWidth ? other.widthPoints : widthPoints,
      widthPercent: other.hasWidth ? other.widthPercent : widthPercent,
      indentPoints: other.hasIndent ? other.indentPoints : indentPoints,
      cellSpacingPoints:
          other.hasCellSpacing ? other.cellSpacingPoints : cellSpacingPoints,
      alignment: other.hasAlignment ? other.alignment : alignment,
      verticalAlignment: other.hasVerticalAlignment
          ? other.verticalAlignment
          : verticalAlignment,
      noWrap: other.hasNoWrap ? other.noWrap : noWrap,
      paragraph: paragraph.merge(other.paragraph),
      run: run.merge(other.run),
      hasTableBorders: hasTableBorders || other.hasTableBorders,
      hasCellBorders: hasCellBorders || other.hasCellBorders,
      hasCellMargins: hasCellMargins || other.hasCellMargins,
      hasShading: hasShading || other.hasShading,
      hasLayout: hasLayout || other.hasLayout,
      hasWidth: hasWidth || other.hasWidth,
      hasIndent: hasIndent || other.hasIndent,
      hasCellSpacing: hasCellSpacing || other.hasCellSpacing,
      hasAlignment: hasAlignment || other.hasAlignment,
      hasVerticalAlignment:
          hasVerticalAlignment || other.hasVerticalAlignment,
      hasNoWrap: hasNoWrap || other.hasNoWrap,
    );
  }
}

_TableStyleProperties _parseTableStyleProperties(
  xml.XmlElement element, {
  required _ThemeCatalog theme,
}) {
  final tblPr = _directChild(element, 'tblPr');
  final tcPr = _directChild(element, 'tcPr');
  final tableBordersElement = _directChild(tblPr, 'tblBorders');
  final cellBordersElement = _directChild(tcPr, 'tcBorders');
  final cellMarginsElement = _directChild(tcPr, 'tcMar') ??
      _directChild(tblPr, 'tblCellMar');
  final shadingElement = _directChild(tcPr, 'shd') ?? _directChild(tblPr, 'shd');

  final layoutElement = _directChild(tblPr, 'tblLayout');
  final layoutValue = _attribute(layoutElement, 'type');
  final widthElement = _directChild(tblPr, 'tblW');
  final widthType = _attribute(widthElement, 'type');
  final widthRaw = double.tryParse(_attribute(widthElement, 'w') ?? '');
  final indentElement = _directChild(tblPr, 'tblInd');
  final indentRaw = double.tryParse(_attribute(indentElement, 'w') ?? '');
  final spacingElement = _directChild(tblPr, 'tblCellSpacing');
  final spacingRaw = double.tryParse(_attribute(spacingElement, 'w') ?? '');
  final alignmentElement = _directChild(tblPr, 'jc');
  final alignmentValue = _attribute(alignmentElement, 'val');
  final verticalAlignmentElement = _directChild(tcPr, 'vAlign');
  final verticalAlignmentValue = _attribute(verticalAlignmentElement, 'val');
  final noWrapElement = _directChild(tcPr, 'noWrap');

  return _TableStyleProperties(
    tableBorders: _parseBorders(tableBordersElement),
    cellBorders: _parseBorders(cellBordersElement),
    cellMargins: _parseCellMarginsElement(cellMarginsElement),
    shadingHex: _normalizeColor(_attribute(shadingElement, 'fill')),
    layout: layoutElement == null
        ? null
        : layoutValue == 'fixed'
            ? ConversionTableLayout.fixed
            : ConversionTableLayout.autoFit,
    widthPoints: widthType == 'dxa' && widthRaw != null && widthRaw > 0
        ? widthRaw / 20
        : null,
    widthPercent: widthType == 'pct' && widthRaw != null && widthRaw > 0
        ? (widthRaw / 50).clamp(0, 100).toDouble()
        : null,
    indentPoints: _attribute(indentElement, 'type') == 'dxa' && indentRaw != null
        ? indentRaw / 20
        : 0,
    cellSpacingPoints:
        _attribute(spacingElement, 'type') == 'dxa' && spacingRaw != null
            ? spacingRaw / 20
            : 0,
    alignment: switch (alignmentValue) {
      'center' => ConversionTextAlignment.center,
      'right' || 'end' => ConversionTextAlignment.right,
      _ => ConversionTextAlignment.left,
    },
    verticalAlignment: verticalAlignmentElement == null
        ? null
        : switch (verticalAlignmentValue) {
            'center' => ConversionTableCellVerticalAlignment.center,
            'bottom' => ConversionTableCellVerticalAlignment.bottom,
            _ => ConversionTableCellVerticalAlignment.top,
          },
    noWrap: _toggleValue(noWrapElement),
    paragraph: _parseParagraphProperties(_directChild(element, 'pPr')),
    run: _parseRunProperties(_directChild(element, 'rPr'), theme: theme),
    hasTableBorders: tableBordersElement != null,
    hasCellBorders: cellBordersElement != null,
    hasCellMargins: cellMarginsElement != null,
    hasShading: shadingElement != null,
    hasLayout: layoutElement != null,
    hasWidth: widthElement != null,
    hasIndent: indentElement != null,
    hasCellSpacing: spacingElement != null,
    hasAlignment: alignmentElement != null,
    hasVerticalAlignment: verticalAlignmentElement != null,
    hasNoWrap: noWrapElement != null,
  );
}

bool _toggleValueFromAttribute(String? value) {
  if (value == null) return false;
  final normalized = value.toLowerCase();
  return normalized != '0' &&
      normalized != 'false' &&
      normalized != 'off' &&
      normalized != 'none';
}

class _ParagraphProperties {
  const _ParagraphProperties({
    this.alignment = ConversionTextAlignment.left,
    this.spaceBeforePoints = 0,
    this.spaceAfterPoints = 6,
    this.leftIndentPoints = 0,
    this.rightIndentPoints = 0,
    this.firstLineIndentPoints = 0,
    this.lineSpacingMultiple,
    this.exactLineSpacingPoints,
    this.pageBreakBefore = false,
    this.keepWithNext = false,
    this.keepLines = false,
    this.widowControl = true,
    this.contextualSpacing = false,
    this.tabStops = const <ConversionTabStop>[],
    this.shadingHex,
    this.borders = const ConversionBorders(),
    this.numberingNumId,
    this.numberingLevel = 0,
    this.hasAlignment = false,
    this.hasSpaceBefore = false,
    this.hasSpaceAfter = false,
    this.hasLeftIndent = false,
    this.hasRightIndent = false,
    this.hasFirstLineIndent = false,
    this.hasLineSpacing = false,
    this.hasPageBreakBefore = false,
    this.hasKeepWithNext = false,
    this.hasKeepLines = false,
    this.hasWidowControl = false,
    this.hasContextualSpacing = false,
    this.hasTabs = false,
    this.hasShading = false,
    this.hasBorders = false,
    this.hasNumbering = false,
  });

  final ConversionTextAlignment alignment;
  final double spaceBeforePoints;
  final double spaceAfterPoints;
  final double leftIndentPoints;
  final double rightIndentPoints;
  final double firstLineIndentPoints;
  final double? lineSpacingMultiple;
  final double? exactLineSpacingPoints;
  final bool pageBreakBefore;
  final bool keepWithNext;
  final bool keepLines;
  final bool widowControl;
  final bool contextualSpacing;
  final List<ConversionTabStop> tabStops;
  final String? shadingHex;
  final ConversionBorders borders;
  final String? numberingNumId;
  final int numberingLevel;

  final bool hasAlignment;
  final bool hasSpaceBefore;
  final bool hasSpaceAfter;
  final bool hasLeftIndent;
  final bool hasRightIndent;
  final bool hasFirstLineIndent;
  final bool hasLineSpacing;
  final bool hasPageBreakBefore;
  final bool hasKeepWithNext;
  final bool hasKeepLines;
  final bool hasWidowControl;
  final bool hasContextualSpacing;
  final bool hasTabs;
  final bool hasShading;
  final bool hasBorders;
  final bool hasNumbering;

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
      lineSpacingMultiple: other.hasLineSpacing
          ? other.lineSpacingMultiple
          : lineSpacingMultiple,
      exactLineSpacingPoints: other.hasLineSpacing
          ? other.exactLineSpacingPoints
          : exactLineSpacingPoints,
      pageBreakBefore: other.hasPageBreakBefore
          ? other.pageBreakBefore
          : pageBreakBefore,
      keepWithNext: other.hasKeepWithNext ? other.keepWithNext : keepWithNext,
      keepLines: other.hasKeepLines ? other.keepLines : keepLines,
      widowControl:
          other.hasWidowControl ? other.widowControl : widowControl,
      contextualSpacing: other.hasContextualSpacing
          ? other.contextualSpacing
          : contextualSpacing,
      tabStops: other.hasTabs ? _mergeTabStops(tabStops, other.tabStops) : tabStops,
      shadingHex: other.hasShading ? other.shadingHex : shadingHex,
      borders: other.hasBorders ? borders.merge(other.borders) : borders,
      numberingNumId:
          other.hasNumbering ? other.numberingNumId : numberingNumId,
      numberingLevel:
          other.hasNumbering ? other.numberingLevel : numberingLevel,
      hasAlignment: hasAlignment || other.hasAlignment,
      hasSpaceBefore: hasSpaceBefore || other.hasSpaceBefore,
      hasSpaceAfter: hasSpaceAfter || other.hasSpaceAfter,
      hasLeftIndent: hasLeftIndent || other.hasLeftIndent,
      hasRightIndent: hasRightIndent || other.hasRightIndent,
      hasFirstLineIndent: hasFirstLineIndent || other.hasFirstLineIndent,
      hasLineSpacing: hasLineSpacing || other.hasLineSpacing,
      hasPageBreakBefore: hasPageBreakBefore || other.hasPageBreakBefore,
      hasKeepWithNext: hasKeepWithNext || other.hasKeepWithNext,
      hasKeepLines: hasKeepLines || other.hasKeepLines,
      hasWidowControl: hasWidowControl || other.hasWidowControl,
      hasContextualSpacing: hasContextualSpacing || other.hasContextualSpacing,
      hasTabs: hasTabs || other.hasTabs,
      hasShading: hasShading || other.hasShading,
      hasBorders: hasBorders || other.hasBorders,
      hasNumbering: hasNumbering || other.hasNumbering,
    );
  }
}

List<ConversionTabStop> _mergeTabStops(
  List<ConversionTabStop> inherited,
  List<ConversionTabStop> overrides,
) {
  final map = <int, ConversionTabStop>{
    for (final stop in inherited) (stop.positionPoints * 100).round(): stop,
  };
  for (final stop in overrides) {
    final key = (stop.positionPoints * 100).round();
    if (stop.alignment == ConversionTabAlignment.clear) {
      map.remove(key);
    } else {
      map[key] = stop;
    }
  }
  final result = map.values.toList(growable: false)
    ..sort((a, b) => a.positionPoints.compareTo(b.positionPoints));
  return result;
}

class _CellMargins {
  const _CellMargins({
    this.top,
    this.right,
    this.bottom,
    this.left,
  });

  final double? top;
  final double? right;
  final double? bottom;
  final double? left;

  _CellMargins merge(_CellMargins other) {
    return _CellMargins(
      top: other.top ?? top,
      right: other.right ?? right,
      bottom: other.bottom ?? bottom,
      left: other.left ?? left,
    );
  }
}

_CellMargins _parseCellMarginsElement(xml.XmlElement? margins) {
  if (margins == null) return const _CellMargins();

  double? side(String primary, [String? fallback]) {
    final element = _directChild(margins, primary) ??
        (fallback == null ? null : _directChild(margins, fallback));
    if (element == null) return null;
    final type = _attribute(element, 'type');
    final raw = double.tryParse(_attribute(element, 'w') ?? '');
    if (raw == null) return null;
    if (type == null || type == 'dxa') return raw / 20;
    return null;
  }

  return _CellMargins(
    top: side('top'),
    right: side('right', 'end'),
    bottom: side('bottom'),
    left: side('left', 'start'),
  );
}

class _RunProperties {
  const _RunProperties({
    this.fontFamily,
    this.fontSizePoints = 11,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.underlineStyle = ConversionUnderlineStyle.none,
    this.strike = false,
    this.doubleStrike = false,
    this.allCaps = false,
    this.smallCaps = false,
    this.letterSpacingPoints = 0,
    this.colorHex,
    this.highlightHex,
    this.hasFontFamily = false,
    this.hasFontSize = false,
    this.hasBold = false,
    this.hasItalic = false,
    this.hasUnderline = false,
    this.hasStrike = false,
    this.hasDoubleStrike = false,
    this.hasAllCaps = false,
    this.hasSmallCaps = false,
    this.hasLetterSpacing = false,
    this.hasColor = false,
    this.hasHighlight = false,
  });

  final String? fontFamily;
  final double fontSizePoints;
  final bool bold;
  final bool italic;
  final bool underline;
  final ConversionUnderlineStyle underlineStyle;
  final bool strike;
  final bool doubleStrike;
  final bool allCaps;
  final bool smallCaps;
  final double letterSpacingPoints;
  final String? colorHex;
  final String? highlightHex;

  final bool hasFontFamily;
  final bool hasFontSize;
  final bool hasBold;
  final bool hasItalic;
  final bool hasUnderline;
  final bool hasStrike;
  final bool hasDoubleStrike;
  final bool hasAllCaps;
  final bool hasSmallCaps;
  final bool hasLetterSpacing;
  final bool hasColor;
  final bool hasHighlight;

  _RunProperties merge(_RunProperties other) {
    return _RunProperties(
      fontFamily: other.hasFontFamily ? other.fontFamily : fontFamily,
      fontSizePoints: other.hasFontSize ? other.fontSizePoints : fontSizePoints,
      bold: other.hasBold ? other.bold : bold,
      italic: other.hasItalic ? other.italic : italic,
      underline: other.hasUnderline ? other.underline : underline,
      underlineStyle:
          other.hasUnderline ? other.underlineStyle : underlineStyle,
      strike: other.hasStrike ? other.strike : strike,
      doubleStrike:
          other.hasDoubleStrike ? other.doubleStrike : doubleStrike,
      allCaps: other.hasAllCaps ? other.allCaps : allCaps,
      smallCaps: other.hasSmallCaps ? other.smallCaps : smallCaps,
      letterSpacingPoints: other.hasLetterSpacing
          ? other.letterSpacingPoints
          : letterSpacingPoints,
      colorHex: other.hasColor ? other.colorHex : colorHex,
      highlightHex: other.hasHighlight ? other.highlightHex : highlightHex,
      hasFontFamily: hasFontFamily || other.hasFontFamily,
      hasFontSize: hasFontSize || other.hasFontSize,
      hasBold: hasBold || other.hasBold,
      hasItalic: hasItalic || other.hasItalic,
      hasUnderline: hasUnderline || other.hasUnderline,
      hasStrike: hasStrike || other.hasStrike,
      hasDoubleStrike: hasDoubleStrike || other.hasDoubleStrike,
      hasAllCaps: hasAllCaps || other.hasAllCaps,
      hasSmallCaps: hasSmallCaps || other.hasSmallCaps,
      hasLetterSpacing: hasLetterSpacing || other.hasLetterSpacing,
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
      underlineStyle: underlineStyle,
      strike: strike,
      doubleStrike: doubleStrike,
      allCaps: allCaps,
      smallCaps: smallCaps,
      letterSpacingPoints: letterSpacingPoints,
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
  final line = double.tryParse(_attribute(spacing, 'line') ?? '');
  final lineRule = _attribute(spacing, 'lineRule');
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
  final keepLines = _directChild(pPr, 'keepLines');
  final widowControl = _directChild(pPr, 'widowControl');
  final contextualSpacing = _directChild(pPr, 'contextualSpacing');
  final tabsElement = _directChild(pPr, 'tabs');
  final tabStops = tabsElement == null
      ? const <ConversionTabStop>[]
      : tabsElement.childElements
          .where((element) => element.name.local == 'tab')
          .map(_parseTabStop)
          .whereType<ConversionTabStop>()
          .toList(growable: false);
  final pBdr = _directChild(pPr, 'pBdr');
  final shadingElement = _directChild(pPr, 'shd');
  final borders = _parseBorders(pBdr);
  final numPr = _directChild(pPr, 'numPr');
  final numId = _attribute(_directChild(numPr, 'numId'), 'val');
  final numLevel = int.tryParse(
        _attribute(_directChild(numPr, 'ilvl'), 'val') ?? '',
      ) ??
      0;

  final automaticLineSpacing =
      line != null && (lineRule == null || lineRule == 'auto')
          ? line / 240
          : null;
  final exactLineSpacing =
      line != null && (lineRule == 'exact' || lineRule == 'atLeast')
          ? line / 20
          : null;

  return _ParagraphProperties(
    alignment: alignment,
    spaceBeforePoints: (before ?? 0) / 20,
    spaceAfterPoints: (after ?? 0) / 20,
    leftIndentPoints: (left ?? 0) / 20,
    rightIndentPoints: (right ?? 0) / 20,
    firstLineIndentPoints: ((firstLine ?? 0) - (hanging ?? 0)) / 20,
    lineSpacingMultiple: automaticLineSpacing,
    exactLineSpacingPoints: exactLineSpacing,
    pageBreakBefore: _toggleValue(pageBreak),
    keepWithNext: _toggleValue(keepWithNext),
    keepLines: _toggleValue(keepLines),
    widowControl: widowControl == null ? true : _toggleValue(widowControl),
    contextualSpacing: _toggleValue(contextualSpacing),
    tabStops: tabStops,
    shadingHex: _normalizeColor(_attribute(shadingElement, 'fill')),
    borders: borders,
    numberingNumId: numId == '0' ? null : numId,
    numberingLevel: numLevel.clamp(0, 8).toInt(),
    hasAlignment: jc != null,
    hasSpaceBefore: before != null,
    hasSpaceAfter: after != null,
    hasLeftIndent: left != null,
    hasRightIndent: right != null,
    hasFirstLineIndent: firstLine != null || hanging != null,
    hasLineSpacing: line != null,
    hasPageBreakBefore: pageBreak != null,
    hasKeepWithNext: keepWithNext != null,
    hasKeepLines: keepLines != null,
    hasWidowControl: widowControl != null,
    hasContextualSpacing: contextualSpacing != null,
    hasTabs: tabsElement != null,
    hasShading: shadingElement != null,
    hasBorders: pBdr != null,
    hasNumbering: numPr != null,
  );
}

ConversionTabStop? _parseTabStop(xml.XmlElement element) {
  final rawPosition = double.tryParse(_attribute(element, 'pos') ?? '');
  if (rawPosition == null) return null;
  final alignment = switch ((_attribute(element, 'val') ?? 'left').toLowerCase()) {
    'center' => ConversionTabAlignment.center,
    'right' => ConversionTabAlignment.right,
    'decimal' => ConversionTabAlignment.decimal,
    'bar' => ConversionTabAlignment.bar,
    'clear' => ConversionTabAlignment.clear,
    _ => ConversionTabAlignment.left,
  };
  final leader = switch ((_attribute(element, 'leader') ?? 'none').toLowerCase()) {
    'dot' => ConversionTabLeader.dot,
    'hyphen' => ConversionTabLeader.hyphen,
    'underscore' => ConversionTabLeader.underscore,
    'heavy' => ConversionTabLeader.heavy,
    'middledot' => ConversionTabLeader.middleDot,
    _ => ConversionTabLeader.none,
  };
  return ConversionTabStop(
    positionPoints: rawPosition / 20,
    alignment: alignment,
    leader: leader,
  );
}

ConversionBorders _parseBorders(xml.XmlElement? borders) {
  if (borders == null) return const ConversionBorders();
  ConversionBorderSide? side(String name) =>
      _parseBorderSide(_directChild(borders, name));
  return ConversionBorders(
    top: side('top'),
    right: side('right') ?? side('end'),
    bottom: side('bottom'),
    left: side('left') ?? side('start'),
    insideHorizontal: side('insideH'),
    insideVertical: side('insideV'),
    between: side('between'),
    bar: side('bar'),
  );
}

ConversionBorderSide? _parseBorderSide(xml.XmlElement? element) {
  if (element == null) return null;
  final rawStyle = (_attribute(element, 'val') ?? 'single').toLowerCase();
  final style = switch (rawStyle) {
    'nil' || 'none' => ConversionBorderStyle.none,
    'double' => ConversionBorderStyle.doubleLine,
    'dotted' => ConversionBorderStyle.dotted,
    'dashed' || 'dashsmallgap' => ConversionBorderStyle.dashed,
    'dotdash' => ConversionBorderStyle.dashDot,
    'dotdotdash' => ConversionBorderStyle.dashDotDot,
    'thick' || 'thickthinlargegap' || 'thinthicklargegap' =>
      ConversionBorderStyle.thick,
    'wave' || 'doublewave' => ConversionBorderStyle.wave,
    _ => ConversionBorderStyle.single,
  };
  final eighthPoints = double.tryParse(_attribute(element, 'sz') ?? '') ?? 4;
  final space = double.tryParse(_attribute(element, 'space') ?? '') ?? 0;
  return ConversionBorderSide(
    style: style,
    widthPoints: style == ConversionBorderStyle.none
        ? 0
        : (eighthPoints / 8).clamp(0.25, 12).toDouble(),
    colorHex: _normalizeColor(_attribute(element, 'color')),
    spacePoints: space,
  );
}

_RunProperties _parseRunProperties(
  xml.XmlElement? rPr, {
  required _ThemeCatalog theme,
}) {
  if (rPr == null) return const _RunProperties();

  final fonts = _directChild(rPr, 'rFonts');
  final themeFontToken = _attribute(fonts, 'asciiTheme') ??
      _attribute(fonts, 'hAnsiTheme') ??
      _attribute(fonts, 'eastAsiaTheme') ??
      _attribute(fonts, 'cstheme');
  final directFontFamily = _attribute(fonts, 'ascii') ??
      _attribute(fonts, 'hAnsi') ??
      _attribute(fonts, 'eastAsia') ??
      _attribute(fonts, 'cs');
  final fontFamily = theme.resolveFont(themeFontToken) ?? directFontFamily;

  final sizeElement = _directChild(rPr, 'sz') ?? _directChild(rPr, 'szCs');
  final sizeHalfPoints = double.tryParse(
    _attribute(sizeElement, 'val') ?? '',
  );
  final bold = _directChild(rPr, 'b') ?? _directChild(rPr, 'bCs');
  final italic = _directChild(rPr, 'i') ?? _directChild(rPr, 'iCs');
  final underline = _directChild(rPr, 'u');
  final strike = _directChild(rPr, 'strike');
  final doubleStrike = _directChild(rPr, 'dstrike');
  final caps = _directChild(rPr, 'caps');
  final smallCaps = _directChild(rPr, 'smallCaps');
  final characterSpacing = double.tryParse(
    _attribute(_directChild(rPr, 'spacing'), 'val') ?? '',
  );

  final colorElement = _directChild(rPr, 'color');
  final themeColor = _attribute(colorElement, 'themeColor');
  final resolvedThemeColor = theme.resolveColor(
    themeColor,
    tint: _attribute(colorElement, 'themeTint'),
    shade: _attribute(colorElement, 'themeShade'),
  );
  final colorHex = resolvedThemeColor ??
      _normalizeColor(_attribute(colorElement, 'val'));

  final highlightElement = _directChild(rPr, 'highlight');
  final shadingElement = _directChild(rPr, 'shd');
  final highlightHex = _highlightColor(_attribute(highlightElement, 'val')) ??
      _normalizeColor(_attribute(shadingElement, 'fill'));

  final underlineValue = (_attribute(underline, 'val') ?? 'single').toLowerCase();
  final underlineEnabled = underline != null && underlineValue != 'none';
  final underlineStyle = switch (underlineValue) {
    'double' => ConversionUnderlineStyle.doubleLine,
    'dotted' || 'dottedheavy' => ConversionUnderlineStyle.dotted,
    'dash' ||
    'dashedheavy' ||
    'dashlong' ||
    'dashlongheavy' ||
    'dotdash' ||
    'dotdotdash' => ConversionUnderlineStyle.dashed,
    'wave' || 'wavydouble' || 'wavyheavy' =>
      ConversionUnderlineStyle.wavy,
    'none' => ConversionUnderlineStyle.none,
    _ => ConversionUnderlineStyle.single,
  };

  return _RunProperties(
    fontFamily: fontFamily,
    fontSizePoints: sizeHalfPoints == null ? 11 : sizeHalfPoints / 2,
    bold: _toggleValue(bold),
    italic: _toggleValue(italic),
    underline: underlineEnabled,
    underlineStyle:
        underlineEnabled ? underlineStyle : ConversionUnderlineStyle.none,
    strike: _toggleValue(strike),
    doubleStrike: _toggleValue(doubleStrike),
    allCaps: _toggleValue(caps),
    smallCaps: _toggleValue(smallCaps),
    letterSpacingPoints: (characterSpacing ?? 0) / 20,
    colorHex: colorHex,
    highlightHex: highlightHex,
    hasFontFamily: fontFamily != null,
    hasFontSize: sizeHalfPoints != null,
    hasBold: bold != null,
    hasItalic: italic != null,
    hasUnderline: underline != null,
    hasStrike: strike != null,
    hasDoubleStrike: doubleStrike != null,
    hasAllCaps: caps != null,
    hasSmallCaps: smallCaps != null,
    hasLetterSpacing: characterSpacing != null,
    hasColor: colorElement != null,
    hasHighlight: highlightElement != null || shadingElement != null,
  );
}

class _NumberingCatalog {
  _NumberingCatalog(this.levelsByNumId);

  final Map<String, Map<int, _NumberLevel>> levelsByNumId;
  final Map<String, Map<int, int>> _counters = {};

  factory _NumberingCatalog.fromEntries(
    Map<String, ArchiveFile> entries, {
    required _ThemeCatalog theme,
  }) {
    final entry = entries['word/numbering.xml'];
    if (entry == null) {
      return _NumberingCatalog({});
    }
    final document = xml.XmlDocument.parse(utf8.decode(entry.content));
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
        final parsed = _parseNumberLevel(level, theme: theme);
        levels[parsed.level] = parsed;
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
      final inherited = abstractLevels[abstractId];
      if (inherited == null) continue;
      final levels = <int, _NumberLevel>{...inherited};
      for (final override in num.childElements.where(
        (element) => element.name.local == 'lvlOverride',
      )) {
        final ilvl = int.tryParse(_attribute(override, 'ilvl') ?? '') ?? 0;
        final embedded = _directChild(override, 'lvl');
        if (embedded != null) {
          levels[ilvl] = _parseNumberLevel(embedded, theme: theme, forcedLevel: ilvl);
          continue;
        }
        final startOverride = int.tryParse(
          _attribute(_directChild(override, 'startOverride'), 'val') ?? '',
        );
        final current = levels[ilvl];
        if (current != null && startOverride != null) {
          levels[ilvl] = current.copyWith(start: startOverride);
        }
      }
      levelsByNumId[numId] = levels;
    }
    return _NumberingCatalog(levelsByNumId);
  }

  _NumberLevel? level(String? numId, int level) {
    if (numId == null) return null;
    return levelsByNumId[numId]?[level];
  }

  _NumberMarker? nextMarker(String? numId, int level) {
    if (numId == null) return null;
    final definition = levelsByNumId[numId]?[level];
    if (definition == null) return null;

    final suffix = switch (definition.suffix) {
      'nothing' => '',
      'tab' => '\t',
      _ => ' ',
    };

    if (definition.format == 'bullet') {
      final glyph = _bulletFromPattern(definition.pattern);
      return _NumberMarker(
        label: '$glyph$suffix',
        style: definition.run.toModel(),
      );
    }

    final counters = _counters.putIfAbsent(numId, () => <int, int>{});
    counters.removeWhere((key, value) => key > level);
    final value = (counters[level] ?? (definition.start - 1)) + 1;
    counters[level] = value;
    var label = definition.pattern;
    for (var i = 0; i <= level; i++) {
      final levelDefinition = levelsByNumId[numId]?[i];
      final levelValue = counters[i] ?? levelDefinition?.start ?? 1;
      label = label.replaceAll(
        '%${i + 1}',
        _formatNumber(levelValue, levelDefinition?.format),
      );
    }
    return _NumberMarker(
      label: '$label$suffix',
      style: definition.run.toModel(),
    );
  }

  static String _bulletFromPattern(String pattern) {
    final cleaned = pattern.trim();
    if (cleaned.isEmpty || cleaned.contains('%')) return '•';
    // Preserve the exact Word glyph. Fonts such as Wingdings/Symbol are kept
    // independently in the numbering run style, which is essential for arrow
    // and decorative bullets used by resumes and worksheets.
    return cleaned;
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
      case 'decimalZero':
        return value.toString().padLeft(2, '0');
      case 'ordinal':
        return _ordinal(value);
      default:
        return '$value';
    }
  }

  static String _ordinal(int value) {
    final mod100 = value % 100;
    if (mod100 >= 11 && mod100 <= 13) return '${value}th';
    return switch (value % 10) {
      1 => '${value}st',
      2 => '${value}nd',
      3 => '${value}rd',
      _ => '${value}th',
    };
  }

  static String _alpha(int value, bool upper) {
    if (value <= 0) return '$value';
    var n = value;
    final chars = <int>[];
    while (n > 0) {
      n--;
      chars.add((upper ? 65 : 97) + (n % 26));
      n ~/= 26;
    }
    return String.fromCharCodes(chars.reversed);
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

_NumberLevel _parseNumberLevel(
  xml.XmlElement element, {
  required _ThemeCatalog theme,
  int? forcedLevel,
}) {
  final ilvl = forcedLevel ?? int.tryParse(_attribute(element, 'ilvl') ?? '') ?? 0;
  return _NumberLevel(
    level: ilvl,
    format: _attribute(_directChild(element, 'numFmt'), 'val') ?? 'decimal',
    pattern: _attribute(_directChild(element, 'lvlText'), 'val') ?? '%${ilvl + 1}.',
    start: int.tryParse(_attribute(_directChild(element, 'start'), 'val') ?? '') ?? 1,
    suffix: _attribute(_directChild(element, 'suff'), 'val') ?? 'space',
    paragraph: _parseParagraphProperties(_directChild(element, 'pPr')),
    run: _parseRunProperties(_directChild(element, 'rPr'), theme: theme),
  );
}

class _NumberLevel {
  const _NumberLevel({
    required this.level,
    required this.format,
    required this.pattern,
    required this.start,
    required this.suffix,
    required this.paragraph,
    required this.run,
  });

  final int level;
  final String format;
  final String pattern;
  final int start;
  final String suffix;
  final _ParagraphProperties paragraph;
  final _RunProperties run;

  _NumberLevel copyWith({int? start}) => _NumberLevel(
        level: level,
        format: format,
        pattern: pattern,
        start: start ?? this.start,
        suffix: suffix,
        paragraph: paragraph,
        run: run,
      );
}

class _NumberMarker {
  const _NumberMarker({required this.label, required this.style});

  final String label;
  final ConversionTextStyle style;
}

bool _tableLookEnabled(xml.XmlElement? tblLook, String attribute, int mask) {
  if (tblLook == null) return !attribute.startsWith('no');
  final explicit = _attribute(tblLook, attribute);
  if (explicit != null) return _toggleValueFromAttribute(explicit);
  final raw = _attribute(tblLook, 'val');
  final parsed = raw == null ? null : int.tryParse(raw, radix: 16);
  if (parsed == null) {
    // Word's default table-look behavior enables first/last row/column and
    // banding unless a `no*Band` bit says otherwise.
    return !attribute.startsWith('no');
  }
  return (parsed & mask) != 0;
}

ConversionBorders _cellBordersFromTable(
  ConversionBorders tableBorders, {
  required int rowIndex,
  required int rowCount,
  required int gridColumnIndex,
  required int gridColumnCount,
  required int gridSpan,
}) {
  final firstRow = rowIndex == 0;
  final lastRow = rowIndex == rowCount - 1;
  final firstColumn = gridColumnIndex == 0;
  final lastColumn = gridColumnCount <= 0 ||
      gridColumnIndex + gridSpan >= gridColumnCount;
  return ConversionBorders(
    // Shared inside borders are painted once (bottom/right) instead of by
    // both adjacent cells, avoiding visually doubled Word grid lines.
    top: firstRow ? tableBorders.top : null,
    bottom: lastRow ? tableBorders.bottom : tableBorders.insideHorizontal,
    left: firstColumn ? tableBorders.left : null,
    right: lastColumn ? tableBorders.right : tableBorders.insideVertical,
  );
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

bool _isOpaqueBlockWrapper(xml.XmlElement element) => const <String>{
      'sdt',
      'altChunk',
      'customXml',
      'ins',
      'del',
      'moveFrom',
      'moveTo',
      'AlternateContent',
      'smartTag',
      'dir',
      'bdo',
    }.contains(element.name.local);

bool _containsOpaqueOoxml(xml.XmlElement element) {
  for (final candidate in <xml.XmlElement>[
    element,
    ...element.descendants.whereType<xml.XmlElement>(),
  ]) {
    if (_isOpaqueBlockWrapper(candidate) || _opaqueRunFeature(candidate) != null) {
      return true;
    }
  }
  return false;
}

String _opaqueFeatureKind(xml.XmlElement element) {
  final local = element.name.local;
  if (local == 'sdt') return 'contentControl';
  if (local == 'object' || local == 'oleObject') return 'embeddedObject';
  if (local == 'altChunk') return 'altChunk';
  if (local == 'customXml') return 'customXml';
  if (local == 'AlternateContent') return 'alternateContent';
  if (local == 'ins' || local == 'del' || local == 'moveFrom' || local == 'moveTo') {
    return 'trackedChange';
  }
  if (local == 'drawing' || local == 'graphic' || local == 'graphicData') {
    final uri = element.descendants
        .whereType<xml.XmlElement>()
        .where((candidate) => candidate.name.local == 'graphicData')
        .map((candidate) => candidate.attributes
            .where((attribute) => attribute.name.local == 'uri')
            .map((attribute) => attribute.value)
            .firstOrNull)
        .whereType<String>()
        .firstOrNull ?? '';
    final normalized = uri.toLowerCase();
    if (normalized.contains('chart')) return 'chart';
    if (normalized.contains('diagram') || normalized.contains('dgm')) {
      return 'smartArt';
    }
    return 'drawing';
  }
  return local.isEmpty ? 'unknownOoxml' : local;
}

String? _opaqueRunFeature(xml.XmlElement element) {
  final local = element.name.local;
  if (const <String>{
    'object',
    'AlternateContent',
    'customXml',
  }.contains(local)) {
    return _opaqueFeatureKind(element);
  }
  if (local != 'drawing') return null;
  final graphicData = element.descendants
      .whereType<xml.XmlElement>()
      .where((candidate) => candidate.name.local == 'graphicData')
      .firstOrNull;
  if (graphicData == null) return 'drawing';
  final uri = graphicData.attributes
      .where((attribute) => attribute.name.local == 'uri')
      .map((attribute) => attribute.value.toLowerCase())
      .firstOrNull ?? '';
  // Pictures and common word-processing shapes have dedicated canonical
  // handlers. Charts/SmartArt/unknown graphicData remain preserve-only.
  if (uri.contains('/picture') || uri.contains('wordprocessingShape')) {
    return null;
  }
  return _opaqueFeatureKind(element);
}

String _opaqueFallbackText(xml.XmlElement element) => element.descendants
    .whereType<xml.XmlElement>()
    .where((candidate) => candidate.name.local == 't')
    .map((candidate) => candidate.innerText)
    .join();

List<String> _relationshipIds(xml.XmlElement element) {
  final ids = <String>{};
  for (final candidate in <xml.XmlElement>[element, ...element.descendants.whereType<xml.XmlElement>()]) {
    for (final attribute in candidate.attributes) {
      final prefix = attribute.name.prefix;
      // Any attribute in the OOXML relationship namespace may carry a
      // relationship id. Pictures commonly use r:embed/r:link, hyperlinks use
      // r:id, while SmartArt uses r:dm/r:lo/r:qs/r:cs. Preserve them all.
      if (prefix == 'r') {
        final value = attribute.value.trim();
        if (value.isNotEmpty) ids.add(value);
      }
    }
  }
  return List<String>.unmodifiable(ids);
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
