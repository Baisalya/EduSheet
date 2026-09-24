import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:edusheet/features/document_reader/domain/services/word_visual_compatibility_profile.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';

class WordVisualCertificationSnapshot {
  const WordVisualCertificationSnapshot({
    required this.profileId,
    required this.sectionCount,
    required this.pageGeometry,
    required this.signature,
    required this.structuralFingerprint,
    required this.visualTolerancePoints,
    required this.preferCompactTableFlow,
  });

  final String profileId;
  final int sectionCount;
  final List<String> pageGeometry;
  final WordDocumentFeatureSignature signature;
  final String structuralFingerprint;
  final double visualTolerancePoints;
  final bool preferCompactTableFlow;

  factory WordVisualCertificationSnapshot.fromDocument(
    ConversionDocument document,
  ) {
    final profile = WordVisualCompatibilityProfile.analyze(document);
    final geometry = <String>[];
    for (final section in document.sections) {
      final page = section.page;
      geometry.add(
        '${_fixed(page.widthPoints)}x${_fixed(page.heightPoints)}'
        ':${_fixed(page.marginTopPoints)},${_fixed(page.marginRightPoints)},'
        '${_fixed(page.marginBottomPoints)},${_fixed(page.marginLeftPoints)}'
        ':c${section.columns.count}:${section.breakType.name}',
      );
    }

    final canonical = StringBuffer()
      ..write('profile=${profile.id}|')
      ..write('sections=${document.sections.length}|')
      ..write('evenodd=${document.evenAndOddHeaders}|')
      ..write('mirror=${document.mirrorMargins}|')
      ..write('gutterTop=${document.gutterAtTop}|')
      ..write('bg=${document.backgroundColorHex ?? ''}|');
    for (final item in geometry) {
      canonical.write('page=$item|');
    }
    for (final section in document.sections) {
      canonical.write('BODY|');
      _appendBlocks(canonical, section.blocks);
      canonical.write('HEADER|');
      _appendBlocks(canonical, section.headerBlocks);
      canonical.write('FIRST_HEADER|');
      _appendBlocks(canonical, section.firstPageHeaderBlocks);
      canonical.write('EVEN_HEADER|');
      _appendBlocks(canonical, section.evenPageHeaderBlocks);
      canonical.write('FOOTER|');
      _appendBlocks(canonical, section.footerBlocks);
      canonical.write('FIRST_FOOTER|');
      _appendBlocks(canonical, section.firstPageFooterBlocks);
      canonical.write('EVEN_FOOTER|');
      _appendBlocks(canonical, section.evenPageFooterBlocks);
    }

    return WordVisualCertificationSnapshot(
      profileId: profile.id,
      sectionCount: document.sections.length,
      pageGeometry: List<String>.unmodifiable(geometry),
      signature: profile.signature,
      structuralFingerprint: _stableFingerprint(canonical.toString()),
      visualTolerancePoints: profile.visualTolerancePoints,
      preferCompactTableFlow: profile.preferCompactTableFlow,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
        'profileId': profileId,
        'sectionCount': sectionCount,
        'pageGeometry': pageGeometry,
        'structuralFingerprint': structuralFingerprint,
        'visualTolerancePoints': visualTolerancePoints,
        'preferCompactTableFlow': preferCompactTableFlow,
        'features': <String, Object>{
          'paragraphs': signature.paragraphs,
          'shortParagraphs': signature.shortParagraphs,
          'textCharacters': signature.textCharacters,
          'tables': signature.tables,
          'tableRows': signature.tableRows,
          'tableCells': signature.tableCells,
          'images': signature.images,
          'floatingObjects': signature.floatingObjects,
          'shapes': signature.shapes,
          'textBoxes': signature.textBoxes,
          'mathRuns': signature.mathRuns,
          'noteReferences': signature.noteReferences,
          'fields': signature.fields,
          'opaqueBlocks': signature.opaqueBlocks,
          'multiColumnSections': signature.multiColumnSections,
          'advancedParagraphs': signature.advancedParagraphs,
          'decoratedParagraphs': signature.decoratedParagraphs,
          'latinCharacters': signature.latinCharacters,
          'complexScriptCharacters': signature.complexScriptCharacters,
        },
      };
}

String _fixed(double value) => value.toStringAsFixed(2);

void _appendBlocks(StringBuffer buffer, Iterable<ConversionBlock> blocks) {
  for (final block in blocks) {
    if (block is ConversionParagraph) {
      buffer
        ..write('P[')
        ..write(block.styleId ?? '')
        ..write(':${block.alignment.name}')
        ..write(':${_fixed(block.spaceBeforePoints)}')
        ..write(':${_fixed(block.spaceAfterPoints)}')
        ..write(':${block.keepWithNext}:${block.keepLines}')
        ..write(']');
      for (final inline in block.inlines) {
        _appendInline(buffer, inline);
      }
      buffer.write('|');
    } else if (block is ConversionTable) {
      buffer.write(
        'TB[${block.rows.length}:${block.layout.name}:'
        '${_fixed(block.widthPoints ?? -1.0)}:${_fixed(block.widthPercent ?? -1.0)}]|',
      );
      for (final row in block.rows) {
        buffer.write(
          'R[${row.cells.length}:${row.isHeader}:${row.cantSplit}:'
          '${row.heightRule.name}:${_fixed(row.heightPoints ?? -1.0)}]|',
        );
        for (final cell in row.cells) {
          buffer.write(
            'C[${cell.gridSpan}:${_fixed(cell.widthPoints ?? -1.0)}:'
            '${_fixed(cell.widthPercent ?? -1.0)}:${cell.verticalAlignment.name}]|',
          );
          _appendBlocks(buffer, cell.blocks);
        }
      }
    } else if (block is ConversionOpaqueOoxmlBlock) {
      buffer.write('O[${block.featureKind}:${block.relationshipIds.length}]|');
      _appendBlocks(buffer, block.fallbackBlocks);
    }
  }
}

void _appendInline(StringBuffer buffer, ConversionInline inline) {
  if (inline is ConversionTextRun) {
    buffer.write('T(${inline.text})');
  } else if (inline is ConversionDynamicFieldRun) {
    buffer.write('D(${inline.field.name})');
  } else if (inline is ConversionFieldRun) {
    buffer.write('F(${inline.instruction}:${inline.resultText})');
  } else if (inline is ConversionMathRun) {
    buffer.write('M(${inline.plainText})');
  } else if (inline is ConversionNoteReferenceRun) {
    buffer.write('N(${inline.type.name}:${inline.noteId})');
    _appendBlocks(buffer, inline.blocks);
  } else if (inline is ConversionImageRun) {
    buffer.write(
      'I(${_fixed(inline.widthPoints)}x${_fixed(inline.heightPoints)}:'
      '${_placement(inline.placement)}:${inline.sourcePartPath ?? ''})',
    );
  } else if (inline is ConversionShapeRun) {
    buffer.write(
      'S(${inline.kind.name}:${_fixed(inline.widthPoints)}x'
      '${_fixed(inline.heightPoints)}:${_placement(inline.placement)})',
    );
    _appendBlocks(buffer, inline.blocks);
  } else if (inline is ConversionTextBoxRun) {
    buffer.write(
      'X(${_fixed(inline.widthPoints ?? -1.0)}x'
      '${_fixed(inline.heightPoints ?? -1.0)}:${_placement(inline.placement)})',
    );
    _appendBlocks(buffer, inline.blocks);
  } else if (inline is ConversionOpaqueOoxmlRun) {
    buffer.write('OI(${inline.featureKind}:${inline.fallbackText})');
  } else if (inline is ConversionCommentMarkerRun) {
    buffer.write('CM(${inline.kind.name}:${inline.commentId})');
  } else if (inline is ConversionBookmarkMarkerRun) {
    buffer.write('BM(${inline.kind.name}:${inline.bookmarkId})');
  }
}

String _placement(ConversionObjectPlacement placement) {
  if (!placement.floating) {
    return 'inline';
  }
  return '${placement.horizontalRelativeFrom ?? ''}/'
      '${placement.verticalRelativeFrom ?? ''}/'
      '${_fixed(placement.horizontalOffsetPoints ?? 0.0)}/'
      '${_fixed(placement.verticalOffsetPoints ?? 0.0)}/'
      '${placement.wrapStyle ?? ''}/${placement.relativeHeight}';
}

String _stableFingerprint(String value) {
  return sha256.convert(utf8.encode(value)).toString().substring(0, 16);
}
