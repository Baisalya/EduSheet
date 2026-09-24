import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';

class WordVisualRealWordFixture {
  const WordVisualRealWordFixture({
    required this.reference,
    required this.file,
    required this.sourceBytes,
    required this.document,
    required this.producerMetadata,
  });

  final Map<String, dynamic> reference;
  final File file;
  final List<int> sourceBytes;
  final ConversionDocument document;
  final String producerMetadata;

  String get actualSha256 => sha256.convert(sourceBytes).toString();

  static Future<WordVisualRealWordFixture> load() async {
    final manifest = jsonDecode(
      await File(
        'test/fixtures/word_visual_fidelity/certification_manifest.json',
      ).readAsString(),
    ) as Map<String, dynamic>;
    final references = manifest['realWordReferences'] as List<dynamic>;
    if (references.isEmpty) {
      throw StateError('VF8 real Word reference manifest is empty.');
    }
    final reference = references.first as Map<String, dynamic>;
    final file = File(reference['path'] as String);
    if (!file.existsSync()) {
      throw StateError('VF8 real Word reference not found: ${file.path}');
    }

    final sourceBytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(sourceBytes);
    final producerMetadata = _entryText(archive, 'docProps/app.xml');
    final document = await DocxConversionParser.parse(file);
    return WordVisualRealWordFixture(
      reference: reference,
      file: file,
      sourceBytes: sourceBytes,
      document: document,
      producerMetadata: producerMetadata,
    );
  }
}

class WordVisualRealWordRiskProbe {
  const WordVisualRealWordRiskProbe({
    required this.document,
    required this.blockCount,
    required this.hasProse,
    required this.hasTable,
    required this.hasVisualRisk,
    required this.summary,
  });

  final ConversionDocument document;
  final int blockCount;
  final bool hasProse;
  final bool hasTable;
  final bool hasVisualRisk;
  final String summary;
}

class _SelectedBlock {
  const _SelectedBlock({
    required this.sectionIndex,
    required this.blockIndex,
    required this.block,
    required this.kind,
  });

  final int sectionIndex;
  final int blockIndex;
  final ConversionBlock block;
  final String kind;
}

WordVisualRealWordRiskProbe buildWordVisualRealWordRiskProbe(
  ConversionDocument document,
) {
  _SelectedBlock? longestProse;
  _SelectedBlock? heaviestTable;
  _SelectedBlock? visualRisk;
  var longestProseLength = -1;
  var heaviestTableScore = -1;

  for (var sectionIndex = 0;
      sectionIndex < document.sections.length;
      sectionIndex++) {
    final section = document.sections[sectionIndex];
    for (var blockIndex = 0;
        blockIndex < section.blocks.length;
        blockIndex++) {
      final block = section.blocks[blockIndex];
      if (block is ConversionParagraph) {
        final length = _paragraphTextLength(block);
        if (length > longestProseLength) {
          longestProseLength = length;
          longestProse = _SelectedBlock(
            sectionIndex: sectionIndex,
            blockIndex: blockIndex,
            block: block,
            kind: 'prose',
          );
        }
      }
      if (block is ConversionTable && block.rows.isNotEmpty) {
        final score = _tableRiskScore(block);
        if (score > heaviestTableScore) {
          heaviestTableScore = score;
          heaviestTable = _SelectedBlock(
            sectionIndex: sectionIndex,
            blockIndex: blockIndex,
            block: _heaviestTextTableRowSlice(block),
            kind: 'table',
          );
        }
      }
      if (visualRisk == null && _blockContainsVisualRisk(block)) {
        visualRisk = _SelectedBlock(
          sectionIndex: sectionIndex,
          blockIndex: blockIndex,
          block: _boundedVisualRiskBlock(block),
          kind: 'visual',
        );
      }
    }
  }

  if (longestProse == null || heaviestTable == null || visualRisk == null) {
    throw StateError(
      'VF8 real Word reference must contain prose, table and visual risks.',
    );
  }

  final selected = <_SelectedBlock>[
    longestProse,
    heaviestTable,
    visualRisk,
  ];
  final bySection = <int, List<ConversionBlock>>{};
  final seenSource = <String>{};
  for (final entry in selected) {
    final sourceKey = '${entry.sectionIndex}:${entry.blockIndex}:${entry.kind}';
    if (!seenSource.add(sourceKey)) continue;
    bySection.putIfAbsent(entry.sectionIndex, () => <ConversionBlock>[]).add(
          entry.block,
        );
  }

  final probeSections = <ConversionSection>[];
  final sortedSectionIndexes = bySection.keys.toList()..sort();
  for (final sectionIndex in sortedSectionIndexes) {
    final source = document.sections[sectionIndex];
    probeSections.add(
      _copySectionWithBlocks(
        source,
        bySection[sectionIndex]!,
        includeStories: probeSections.isEmpty,
      ),
    );
  }

  final probeDocument = ConversionDocument(
    sections: List<ConversionSection>.unmodifiable(probeSections),
    evenAndOddHeaders: document.evenAndOddHeaders,
    mirrorMargins: document.mirrorMargins,
    gutterAtTop: document.gutterAtTop,
    backgroundColorHex: document.backgroundColorHex,
  );

  return WordVisualRealWordRiskProbe(
    document: probeDocument,
    blockCount: probeSections.fold<int>(
      0,
      (sum, section) => sum + section.blocks.length,
    ),
    hasProse: true,
    hasTable: true,
    hasVisualRisk: true,
    summary: 'proseChars=$longestProseLength; '
        'tableScore=$heaviestTableScore; '
        'visual=section-${visualRisk.sectionIndex}-block-${visualRisk.blockIndex}',
  );
}

int _paragraphTextLength(ConversionParagraph paragraph) => paragraph.inlines
    .whereType<ConversionTextRun>()
    .fold<int>(0, (sum, run) => sum + run.text.length);

int _tableRiskScore(ConversionTable table) {
  var score = table.rows.length * 10;
  for (final row in table.rows) {
    score += row.cells.length * 4;
    for (final cell in row.cells) {
      score += cell.blocks.length;
      for (final block in cell.blocks) {
        if (block is ConversionParagraph) {
          score += _paragraphTextLength(block) ~/ 80;
        }
      }
    }
  }
  return score;
}

ConversionTable _heaviestTextTableRowSlice(ConversionTable table) {
  var bestIndex = 0;
  var bestScore = -1;
  for (var index = 0; index < table.rows.length; index++) {
    final row = table.rows[index];
    var score = row.cells.length * 4;
    for (final cell in row.cells) {
      score += cell.blocks.length;
      for (final block in cell.blocks) {
        if (block is ConversionParagraph) {
          score += _paragraphTextLength(block) ~/ 40;
        }
      }
    }
    if (score > bestScore) {
      bestScore = score;
      bestIndex = index;
    }
  }
  return _copyTableWithRows(
    table,
    <ConversionTableRow>[table.rows[bestIndex]],
  );
}

ConversionBlock _boundedVisualRiskBlock(ConversionBlock block) {
  if (block is ConversionTable && block.rows.isNotEmpty) {
    for (final row in block.rows) {
      if (row.cells.any(
        (cell) => cell.blocks.any(_blockContainsVisualRisk),
      )) {
        return _copyTableWithRows(block, <ConversionTableRow>[row]);
      }
    }
    return _copyTableWithRows(
      block,
      <ConversionTableRow>[block.rows.first],
    );
  }
  if (block is ConversionOpaqueOoxmlBlock &&
      block.fallbackBlocks.isNotEmpty) {
    final risky = block.fallbackBlocks.where(_blockContainsVisualRisk).toList();
    return ConversionOpaqueOoxmlBlock(
      featureKind: block.featureKind,
      rawXml: block.rawXml,
      fallbackBlocks: risky.isEmpty
          ? <ConversionBlock>[block.fallbackBlocks.first]
          : <ConversionBlock>[risky.first],
      relationshipIds: block.relationshipIds,
    );
  }
  return block;
}

bool _blockContainsVisualRisk(ConversionBlock block) {
  if (block is ConversionTable) {
    return block.rows.any(
      (row) => row.cells.any(
        (cell) => cell.blocks.any(_blockContainsVisualRisk),
      ),
    );
  }
  if (block is ConversionOpaqueOoxmlBlock) {
    return block.fallbackBlocks.any(_blockContainsVisualRisk);
  }
  if (block is! ConversionParagraph) return false;
  return block.inlines.any(
    (inline) =>
        inline is ConversionImageRun ||
        inline is ConversionTextBoxRun ||
        inline is ConversionShapeRun,
  );
}

ConversionTable _copyTableWithRows(
  ConversionTable table,
  List<ConversionTableRow> rows,
) =>
    ConversionTable(
      rows: List<ConversionTableRow>.unmodifiable(rows),
      showBorders: table.showBorders,
      styleId: table.styleId,
      shadingHex: table.shadingHex,
      borders: table.borders,
      layout: table.layout,
      widthPoints: table.widthPoints,
      widthPercent: table.widthPercent,
      indentPoints: table.indentPoints,
      cellSpacingPoints: table.cellSpacingPoints,
      gridColumnWidths: table.gridColumnWidths,
      alignment: table.alignment,
    );

ConversionSection _copySectionWithBlocks(
  ConversionSection section,
  List<ConversionBlock> blocks, {
  required bool includeStories,
}) =>
    ConversionSection(
      page: section.page,
      blocks: List<ConversionBlock>.unmodifiable(blocks),
      headerBlocks:
          includeStories ? section.headerBlocks : const <ConversionBlock>[],
      footerBlocks:
          includeStories ? section.footerBlocks : const <ConversionBlock>[],
      firstPageHeaderBlocks: includeStories
          ? section.firstPageHeaderBlocks
          : const <ConversionBlock>[],
      firstPageFooterBlocks: includeStories
          ? section.firstPageFooterBlocks
          : const <ConversionBlock>[],
      evenPageHeaderBlocks: includeStories
          ? section.evenPageHeaderBlocks
          : const <ConversionBlock>[],
      evenPageFooterBlocks: includeStories
          ? section.evenPageFooterBlocks
          : const <ConversionBlock>[],
      breakType: section.breakType,
      titlePage: section.titlePage,
      columns: section.columns,
      pageNumberStart: section.pageNumberStart,
      pageNumberFormat: section.pageNumberFormat,
    );

String _entryText(Archive archive, String name) {
  final entry = archive.files.firstWhere((candidate) => candidate.name == name);
  return utf8.decode(entry.content as List<int>);
}
