import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';

enum WordVisualCompatibilityCategory {
  resumeTable,
  formInvoice,
  proseReport,
  imageFloatingHeavy,
  multiColumnEditorial,
  academicTechnical,
  multilingualMixedScript,
}

class WordDocumentFeatureSignature {
  const WordDocumentFeatureSignature({
    required this.paragraphs,
    required this.shortParagraphs,
    required this.textCharacters,
    required this.tables,
    required this.tableRows,
    required this.tableCells,
    required this.images,
    required this.floatingObjects,
    required this.shapes,
    required this.textBoxes,
    required this.mathRuns,
    required this.noteReferences,
    required this.fields,
    required this.opaqueBlocks,
    required this.multiColumnSections,
    required this.advancedParagraphs,
    required this.decoratedParagraphs,
    required this.latinCharacters,
    required this.complexScriptCharacters,
  });

  final int paragraphs;
  final int shortParagraphs;
  final int textCharacters;
  final int tables;
  final int tableRows;
  final int tableCells;
  final int images;
  final int floatingObjects;
  final int shapes;
  final int textBoxes;
  final int mathRuns;
  final int noteReferences;
  final int fields;
  final int opaqueBlocks;
  final int multiColumnSections;
  final int advancedParagraphs;
  final int decoratedParagraphs;
  final int latinCharacters;
  final int complexScriptCharacters;

  double get shortParagraphRatio =>
      paragraphs == 0 ? 0.0 : shortParagraphs / paragraphs;

  bool get hasMixedScripts => latinCharacters >= 12 && complexScriptCharacters >= 12;

  int get visualObjectCount => images + shapes + textBoxes;
}

class WordVisualCompatibilityProfile {
  const WordVisualCompatibilityProfile({
    required this.category,
    required this.signature,
    required this.paragraphFragmentTargetFraction,
    required this.tableContinuationTargetFraction,
    required this.visualTolerancePoints,
    required this.preferCompactTableFlow,
  });

  final WordVisualCompatibilityCategory category;
  final WordDocumentFeatureSignature signature;

  /// Viewer-only pagination tuning. Canonical OOXML semantics always win over
  /// these hints; profiles only choose safer visual fragmentation targets.
  final double paragraphFragmentTargetFraction;
  final double tableContinuationTargetFraction;
  final double visualTolerancePoints;
  final bool preferCompactTableFlow;

  String get id => category.name;

  static WordVisualCompatibilityProfile analyze(ConversionDocument document) {
    final signature = _FeatureCollector.collect(document);
    final category = _categoryFor(signature);

    return switch (category) {
      WordVisualCompatibilityCategory.resumeTable => WordVisualCompatibilityProfile(
          category: category,
          signature: signature,
          paragraphFragmentTargetFraction: 0.40,
          tableContinuationTargetFraction: 0.46,
          visualTolerancePoints: 4,
          preferCompactTableFlow: true,
        ),
      WordVisualCompatibilityCategory.formInvoice => WordVisualCompatibilityProfile(
          category: category,
          signature: signature,
          paragraphFragmentTargetFraction: 0.40,
          tableContinuationTargetFraction: 0.43,
          visualTolerancePoints: 4,
          preferCompactTableFlow: true,
        ),
      WordVisualCompatibilityCategory.multiColumnEditorial => WordVisualCompatibilityProfile(
          category: category,
          signature: signature,
          paragraphFragmentTargetFraction: 0.38,
          tableContinuationTargetFraction: 0.45,
          visualTolerancePoints: 4,
          preferCompactTableFlow: true,
        ),
      WordVisualCompatibilityCategory.imageFloatingHeavy => WordVisualCompatibilityProfile(
          category: category,
          signature: signature,
          paragraphFragmentTargetFraction: 0.40,
          tableContinuationTargetFraction: 0.46,
          visualTolerancePoints: 5,
          preferCompactTableFlow: false,
        ),
      WordVisualCompatibilityCategory.academicTechnical => WordVisualCompatibilityProfile(
          category: category,
          signature: signature,
          paragraphFragmentTargetFraction: 0.42,
          tableContinuationTargetFraction: 0.46,
          visualTolerancePoints: 4,
          preferCompactTableFlow: false,
        ),
      WordVisualCompatibilityCategory.multilingualMixedScript => WordVisualCompatibilityProfile(
          category: category,
          signature: signature,
          paragraphFragmentTargetFraction: 0.42,
          tableContinuationTargetFraction: 0.46,
          visualTolerancePoints: 5,
          preferCompactTableFlow: false,
        ),
      WordVisualCompatibilityCategory.proseReport => WordVisualCompatibilityProfile(
          category: category,
          signature: signature,
          paragraphFragmentTargetFraction: 0.44,
          tableContinuationTargetFraction: 0.46,
          visualTolerancePoints: 4,
          preferCompactTableFlow: false,
        ),
    };
  }

  static WordVisualCompatibilityCategory _categoryFor(
    WordDocumentFeatureSignature signature,
  ) {
    if (signature.multiColumnSections > 0 && signature.paragraphs >= 3) {
      return WordVisualCompatibilityCategory.multiColumnEditorial;
    }
    if (signature.mathRuns + signature.noteReferences >= 2) {
      return WordVisualCompatibilityCategory.academicTechnical;
    }
    if (signature.floatingObjects >= 2 || signature.visualObjectCount >= 4) {
      return WordVisualCompatibilityCategory.imageFloatingHeavy;
    }
    if (signature.tables >= 2 ||
        (signature.tableCells >= 8 && signature.decoratedParagraphs >= 2)) {
      return WordVisualCompatibilityCategory.formInvoice;
    }
    if (signature.tables >= 1 &&
        signature.tableCells >= 2 &&
        signature.paragraphs >= 4 &&
        signature.shortParagraphRatio >= 0.58) {
      return WordVisualCompatibilityCategory.resumeTable;
    }
    if (signature.hasMixedScripts) {
      return WordVisualCompatibilityCategory.multilingualMixedScript;
    }
    return WordVisualCompatibilityCategory.proseReport;
  }
}

class _FeatureCollector {
  var paragraphs = 0;
  var shortParagraphs = 0;
  var textCharacters = 0;
  var tables = 0;
  var tableRows = 0;
  var tableCells = 0;
  var images = 0;
  var floatingObjects = 0;
  var shapes = 0;
  var textBoxes = 0;
  var mathRuns = 0;
  var noteReferences = 0;
  var fields = 0;
  var opaqueBlocks = 0;
  var multiColumnSections = 0;
  var advancedParagraphs = 0;
  var decoratedParagraphs = 0;
  var latinCharacters = 0;
  var complexScriptCharacters = 0;

  static WordDocumentFeatureSignature collect(ConversionDocument document) {
    final collector = _FeatureCollector();
    for (final section in document.sections) {
      if (section.columns.isMultiColumn) {
        collector.multiColumnSections++;
      }
      collector._visitBlocks(section.blocks);
      collector._visitBlocks(section.headerBlocks);
      collector._visitBlocks(section.footerBlocks);
      collector._visitBlocks(section.firstPageHeaderBlocks);
      collector._visitBlocks(section.firstPageFooterBlocks);
      collector._visitBlocks(section.evenPageHeaderBlocks);
      collector._visitBlocks(section.evenPageFooterBlocks);
    }
    return WordDocumentFeatureSignature(
      paragraphs: collector.paragraphs,
      shortParagraphs: collector.shortParagraphs,
      textCharacters: collector.textCharacters,
      tables: collector.tables,
      tableRows: collector.tableRows,
      tableCells: collector.tableCells,
      images: collector.images,
      floatingObjects: collector.floatingObjects,
      shapes: collector.shapes,
      textBoxes: collector.textBoxes,
      mathRuns: collector.mathRuns,
      noteReferences: collector.noteReferences,
      fields: collector.fields,
      opaqueBlocks: collector.opaqueBlocks,
      multiColumnSections: collector.multiColumnSections,
      advancedParagraphs: collector.advancedParagraphs,
      decoratedParagraphs: collector.decoratedParagraphs,
      latinCharacters: collector.latinCharacters,
      complexScriptCharacters: collector.complexScriptCharacters,
    );
  }

  void _visitBlocks(List<ConversionBlock> blocks) {
    for (final block in blocks) {
      if (block is ConversionParagraph) {
        _visitParagraph(block);
      } else if (block is ConversionTable) {
        tables++;
        tableRows += block.rows.length;
        for (final row in block.rows) {
          tableCells += row.cells.length;
          for (final cell in row.cells) {
            _visitBlocks(cell.blocks);
          }
        }
      } else if (block is ConversionOpaqueOoxmlBlock) {
        opaqueBlocks++;
        _visitBlocks(block.fallbackBlocks);
      }
    }
  }

  void _visitParagraph(ConversionParagraph paragraph) {
    paragraphs++;
    if (paragraph.hasAdvancedLayout) {
      advancedParagraphs++;
    }
    if (paragraph.shadingHex != null || !paragraph.borders.isEmpty) {
      decoratedParagraphs++;
    }
    final buffer = StringBuffer();
    for (final inline in paragraph.inlines) {
      if (inline is ConversionTextRun) {
        buffer.write(inline.text);
        _countScripts(inline.text);
      } else if (inline is ConversionFieldRun) {
        fields++;
        buffer.write(inline.resultText);
        _countScripts(inline.resultText);
      } else if (inline is ConversionDynamicFieldRun) {
        fields++;
      } else if (inline is ConversionMathRun) {
        mathRuns++;
        buffer.write(inline.plainText);
      } else if (inline is ConversionNoteReferenceRun) {
        noteReferences++;
        _visitBlocks(inline.blocks);
      } else if (inline is ConversionImageRun) {
        images++;
        if (inline.placement.floating) {
          floatingObjects++;
        }
      } else if (inline is ConversionShapeRun) {
        shapes++;
        if (inline.placement.floating) {
          floatingObjects++;
        }
        _visitBlocks(inline.blocks);
      } else if (inline is ConversionTextBoxRun) {
        textBoxes++;
        if (inline.placement.floating) {
          floatingObjects++;
        }
        _visitBlocks(inline.blocks);
      } else if (inline is ConversionOpaqueOoxmlRun) {
        buffer.write(inline.fallbackText);
        _countScripts(inline.fallbackText);
      }
    }
    final text = buffer.toString().trim();
    textCharacters += text.length;
    if (text.isNotEmpty && text.length <= 84) {
      shortParagraphs++;
    }
  }

  void _countScripts(String text) {
    for (final rune in text.runes) {
      if ((rune >= 0x0041 && rune <= 0x024F)) {
        latinCharacters++;
      } else if (_isComplexScript(rune)) {
        complexScriptCharacters++;
      }
    }
  }

  bool _isComplexScript(int rune) {
    return (rune >= 0x0900 && rune <= 0x0DFF) ||
        (rune >= 0x0E00 && rune <= 0x0FFF) ||
        (rune >= 0x1780 && rune <= 0x17FF) ||
        (rune >= 0x0600 && rune <= 0x06FF) ||
        (rune >= 0x0750 && rune <= 0x077F) ||
        (rune >= 0x4E00 && rune <= 0x9FFF);
  }
}
