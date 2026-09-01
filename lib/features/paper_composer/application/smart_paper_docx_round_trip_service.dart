import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:xml/xml.dart' as xml;

/// Result of inspecting/importing a Word package for EduSheet round-trip data.
enum SmartPaperDocxImportStatus {
  /// The package is byte-for-byte equivalent (for EduSheet-owned parts) to the
  /// file we exported, so the canonical snapshot can be restored directly.
  exactEduSheetRoundTrip,

  /// The Word body changed only inside EduSheet-tagged editable regions and
  /// those edits were merged back into the canonical Paper model.
  safeMergedEduSheetRoundTrip,

  /// The package was exported by EduSheet but changed in an area that EduSheet
  /// cannot map back without risking data loss.
  modifiedOutsideEduSheet,

  /// The package is not a supported EduSheet round-trip document.
  unsupportedExternalDocument,
}

class SmartPaperDocxImportResult {
  final SmartPaperDocxImportStatus status;
  final Paper? paper;
  final String message;
  final int mergedFieldCount;

  const SmartPaperDocxImportResult({
    required this.status,
    required this.message,
    this.paper,
    this.mergedFieldCount = 0,
  });

  bool get canRestoreExactly =>
      status == SmartPaperDocxImportStatus.exactEduSheetRoundTrip &&
      paper != null;

  bool get canApplySafely =>
      (status == SmartPaperDocxImportStatus.exactEduSheetRoundTrip ||
          status == SmartPaperDocxImportStatus.safeMergedEduSheetRoundTrip) &&
      paper != null;
}

/// Lossless bridge between EduSheet's canonical [Paper] and exported DOCX.
///
/// DOCX stays an interoperability format, never a second source of truth.
/// EduSheet-generated files contain an exact canonical Paper snapshot plus
/// integrity fingerprints. Editable Word runs are wrapped in invisible
/// WordprocessingML content controls (`w:sdt`) carrying deterministic EduSheet
/// tags. When a user edits only those supported regions in Word, the service
/// can merge the changed text/formatting back into the canonical model while
/// preserving marks semantics, math/geometry metadata, tables, images, page
/// layout and every unsupported field from the snapshot.
///
/// If the Word package changes outside tagged regions (table structure, image
/// relationships, page layout, arbitrary new paragraphs, etc.), import is
/// deliberately refused instead of silently producing a lossy conversion.
class SmartPaperDocxRoundTripService {
  const SmartPaperDocxRoundTripService._();

  static const customXmlPartName = 'customXml/edusheet-smart-paper.xml';
  static const relationshipType =
      'https://edusheet.app/relationships/smart-paper-roundtrip';
  static const namespace = 'https://edusheet.app/smart-paper/roundtrip/v2';
  static const envelopeVersion = 2;

  static const _editableTagPrefix = 'es:';
  static const _questionTextPrefix = 'es:q:';
  static const _questionMarksPrefix = 'es:m:';
  static const _optionPrefix = 'es:o:';
  static const _sectionTitlePrefix = 'es:st:';
  static const _sectionInstructionPrefix = 'es:si:';
  static const paperInstructionTag = 'es:paper:instruction';
  static const paperTitleTag = 'es:paper:title';
  static const schoolNameTag = 'es:paper:school';

  /// Deterministic short tag suitable for Word's content-control tag value.
  static String questionTextTag(String questionId) =>
      '$_questionTextPrefix${documentFingerprint(questionId)}';

  static String questionMarksTag(String questionId) =>
      '$_questionMarksPrefix${documentFingerprint(questionId)}';

  static String questionOptionTag(String questionId, String optionId) =>
      '$_optionPrefix${documentFingerprint('$questionId\u0000$optionId')}';

  static String sectionTitleTag(String sectionId) =>
      '$_sectionTitlePrefix${documentFingerprint(sectionId)}';

  static String sectionInstructionTag(String sectionId) =>
      '$_sectionInstructionPrefix${documentFingerprint(sectionId)}';

  static String buildEnvelopeXml({
    required Paper paper,
    required String documentXml,
    String? headerXml,
    String? footerXml,
    String? stylesXml,
  }) {
    final encodedPaper = base64Encode(utf8.encode(jsonEncode(paper.toJson())));
    final documentHash = documentFingerprint(documentXml);
    final skeletonHash = editableSkeletonFingerprint(documentXml);
    final headerHash = headerXml == null ? '' : _xmlPartFingerprint(headerXml);
    final footerHash = footerXml == null ? '' : _xmlPartFingerprint(footerXml);
    final stylesHash = stylesXml == null ? '' : _xmlPartFingerprint(stylesXml);
    final editableManifest = base64Encode(
      utf8.encode(jsonEncode(_editableManifest(documentXml))),
    );
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<edusheet:smartPaper xmlns:edusheet="$namespace" version="$envelopeVersion">'
        '<edusheet:documentFingerprint>$documentHash</edusheet:documentFingerprint>'
        '<edusheet:editableSkeletonFingerprint>$skeletonHash</edusheet:editableSkeletonFingerprint>'
        '<edusheet:headerFingerprint>$headerHash</edusheet:headerFingerprint>'
        '<edusheet:footerFingerprint>$footerHash</edusheet:footerFingerprint>'
        '<edusheet:stylesFingerprint>$stylesHash</edusheet:stylesFingerprint>'
        '<edusheet:editableManifestBase64>$editableManifest</edusheet:editableManifestBase64>'
        '<edusheet:paperJsonBase64>$encodedPaper</edusheet:paperJsonBase64>'
        '</edusheet:smartPaper>';
  }

  static Future<SmartPaperDocxImportResult> importFromFile(File file) async {
    return importFromBytes(await file.readAsBytes());
  }

  static SmartPaperDocxImportResult importFromBytes(List<int> bytes) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return const SmartPaperDocxImportResult(
        status: SmartPaperDocxImportStatus.unsupportedExternalDocument,
        message: 'This file is not a valid .docx package.',
      );
    }

    final documentPart = _entry(archive, 'word/document.xml');
    if (documentPart == null) {
      return const SmartPaperDocxImportResult(
        status: SmartPaperDocxImportStatus.unsupportedExternalDocument,
        message: 'The Word file does not contain word/document.xml.',
      );
    }

    final envelopePart = _entry(archive, customXmlPartName);
    if (envelopePart == null) {
      return const SmartPaperDocxImportResult(
        status: SmartPaperDocxImportStatus.unsupportedExternalDocument,
        message:
            'This Word file was not exported by the current EduSheet round-trip format.',
      );
    }

    try {
      final documentXml = utf8.decode(_bytes(documentPart));
      final envelope = xml.XmlDocument.parse(utf8.decode(_bytes(envelopePart)));
      final root = envelope.rootElement;
      final version = int.tryParse(root.getAttribute('version') ?? '');
      if (version != 1 && version != envelopeVersion) {
        return SmartPaperDocxImportResult(
          status: SmartPaperDocxImportStatus.unsupportedExternalDocument,
          message: 'Unsupported EduSheet Word round-trip version: $version.',
        );
      }

      final expectedFingerprint = _firstText(root, 'documentFingerprint');
      final encodedPaper = _firstText(root, 'paperJsonBase64');
      if (expectedFingerprint == null || encodedPaper == null) {
        return const SmartPaperDocxImportResult(
          status: SmartPaperDocxImportStatus.unsupportedExternalDocument,
          message: 'EduSheet round-trip metadata is incomplete.',
        );
      }

      final paper = _decodePaper(encodedPaper);
      final bodyExact = documentFingerprint(documentXml) == expectedFingerprint;
      final companionExact = _companionPartsStillMatch(archive, root);

      if (bodyExact && companionExact) {
        return SmartPaperDocxImportResult(
          status: SmartPaperDocxImportStatus.exactEduSheetRoundTrip,
          paper: paper,
          message: 'Restored the exact EduSheet Smart Paper from Word.',
        );
      }

      // V1 files had no tagged editable skeleton. They remain exact-restorable,
      // but edited V1 files cannot be merged safely.
      if (version == 1) {
        return const SmartPaperDocxImportResult(
          status: SmartPaperDocxImportStatus.modifiedOutsideEduSheet,
          message:
              'This older EduSheet Word file was edited outside EduSheet. Its embedded snapshot may be stale, so EduSheet will not replace the current paper.',
        );
      }

      if (!companionExact) {
        return const SmartPaperDocxImportResult(
          status: SmartPaperDocxImportStatus.modifiedOutsideEduSheet,
          message:
              'This Word file changed page styles or header/footer content outside EduSheet. Those edits cannot be merged safely without risking document loss.',
        );
      }

      final expectedSkeleton = _firstText(root, 'editableSkeletonFingerprint');
      if (expectedSkeleton == null || expectedSkeleton.isEmpty) {
        return const SmartPaperDocxImportResult(
          status: SmartPaperDocxImportStatus.modifiedOutsideEduSheet,
          message:
              'This EduSheet Word file changed outside EduSheet and has no safe-edit manifest.',
        );
      }

      final actualSkeleton = editableSkeletonFingerprint(documentXml);
      if (actualSkeleton != expectedSkeleton) {
        return const SmartPaperDocxImportResult(
          status: SmartPaperDocxImportStatus.modifiedOutsideEduSheet,
          message:
              'Word changed content or layout outside EduSheet-tagged editable fields. EduSheet kept the current paper unchanged rather than performing a lossy import.',
        );
      }

      final baselineManifest = _decodeEditableManifest(
        _firstText(root, 'editableManifestBase64'),
      );
      if (baselineManifest == null) {
        return const SmartPaperDocxImportResult(
          status: SmartPaperDocxImportStatus.modifiedOutsideEduSheet,
          message:
              'This EduSheet Word file has no editable-field baseline, so external edits cannot be merged safely.',
        );
      }
      final merged = _mergeTaggedEdits(paper, documentXml, baselineManifest);
      if (!merged.safe) {
        return SmartPaperDocxImportResult(
          status: SmartPaperDocxImportStatus.modifiedOutsideEduSheet,
          message: merged.message,
        );
      }

      return SmartPaperDocxImportResult(
        status: SmartPaperDocxImportStatus.safeMergedEduSheetRoundTrip,
        paper: merged.paper,
        mergedFieldCount: merged.changedFields,
        message: merged.changedFields == 0
            ? 'The Word package was rewritten, but no supported EduSheet content changed. The canonical Smart Paper is safe to restore.'
            : 'Safely merged ${merged.changedFields} Word edit${merged.changedFields == 1 ? '' : 's'} into the Smart Paper.',
      );
    } catch (_) {
      return const SmartPaperDocxImportResult(
        status: SmartPaperDocxImportStatus.unsupportedExternalDocument,
        message: 'EduSheet round-trip metadata could not be read safely.',
      );
    }
  }

  static Paper _decodePaper(String encodedPaper) {
    final decoded = jsonDecode(utf8.decode(base64Decode(encodedPaper)));
    if (decoded is! Map) {
      throw const FormatException('Invalid embedded paper JSON.');
    }
    return Paper.fromJson(Map<String, dynamic>.from(decoded));
  }

  static bool _companionPartsStillMatch(Archive archive, xml.XmlElement root) {
    final checks = <(String, String)>[
      ('headerFingerprint', 'word/header1.xml'),
      ('footerFingerprint', 'word/footer1.xml'),
      ('stylesFingerprint', 'word/styles.xml'),
    ];
    for (final check in checks) {
      final expected = _firstText(root, check.$1) ?? '';
      if (expected.isEmpty) continue;
      final part = _entry(archive, check.$2);
      if (part == null) return false;
      final actual = _xmlPartFingerprint(utf8.decode(_bytes(part)));
      if (actual != expected) return false;
    }
    return true;
  }

  static Map<String, String> _editableManifest(String documentXml) {
    final document = xml.XmlDocument.parse(documentXml);
    final result = <String, String>{};
    for (final sdt in document.descendants.whereType<xml.XmlElement>()) {
      if (sdt.name.local != 'sdt') continue;
      final tag = _contentControlTag(sdt);
      if (tag == null || !tag.startsWith(_editableTagPrefix)) continue;
      result[tag] = _editableContentFingerprint(sdt);
    }
    return result;
  }

  static Map<String, String>? _decodeEditableManifest(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(base64Decode(encoded)));
      if (decoded is! Map) return null;
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return null;
    }
  }

  static String _editableContentFingerprint(xml.XmlElement sdt) {
    final content = _sdtContent(sdt);
    if (content == null) return documentFingerprint('');
    final buffer = StringBuffer();

    void visit(xml.XmlNode node) {
      if (node is xml.XmlText) {
        buffer.write(node.value);
        return;
      }
      if (node is! xml.XmlElement) return;
      final local = node.name.local;
      if (local == 'proofErr' ||
          local == 'bookmarkStart' ||
          local == 'bookmarkEnd') {
        return;
      }
      buffer.write('<$local');
      final attrs =
          node.attributes
              .where((attribute) {
                final name = attribute.name.local;
                final prefix = attribute.name.prefix;
                return prefix != 'xmlns' &&
                    name != 'xmlns' &&
                    !name.startsWith('rsid') &&
                    name != 'paraId' &&
                    name != 'textId';
              })
              .map((attribute) => '${attribute.name.local}=${attribute.value}')
              .toList()
            ..sort();
      for (final attr in attrs) {
        buffer.write('|$attr');
      }
      buffer.write('>');
      for (final child in node.children) {
        visit(child);
      }
      buffer.write('</$local>');
    }

    visit(content);
    return documentFingerprint(buffer.toString());
  }

  static _MergeResult _mergeTaggedEdits(
    Paper paper,
    String documentXml,
    Map<String, String> baselineManifest,
  ) {
    final document = xml.XmlDocument.parse(documentXml);
    final tagged = <String, xml.XmlElement>{};
    for (final sdt in document.descendants.whereType<xml.XmlElement>()) {
      if (sdt.name.local != 'sdt') continue;
      final tag = _contentControlTag(sdt);
      if (tag == null || !tag.startsWith(_editableTagPrefix)) continue;
      if (tagged.containsKey(tag)) {
        return _MergeResult.unsafe(
          'The Word file contains duplicate EduSheet editable fields. Import was cancelled to avoid ambiguous changes.',
        );
      }
      tagged[tag] = sdt;
    }

    bool changedControl(String tag, xml.XmlElement? control) {
      if (control == null) return false;
      final baseline = baselineManifest[tag];
      if (baseline == null) return true;
      return _editableContentFingerprint(control) != baseline;
    }

    var changed = 0;
    var nextPaper = paper;

    final paperInstruction = tagged[paperInstructionTag];
    if (changedControl(paperInstructionTag, paperInstruction)) {
      final value = _plainTextOfSdt(paperInstruction!).trim();
      if (value != nextPaper.instruction.trim()) {
        nextPaper = nextPaper.copyWith(instruction: value);
        changed++;
      } else {
        return _MergeResult.unsafe(
          'Word formatting changed the paper instruction, but that field has no rich-text model in EduSheet. Import was cancelled rather than discarding the formatting edit.',
        );
      }
    }

    final paperTitle = tagged[paperTitleTag];
    if (changedControl(paperTitleTag, paperTitle)) {
      final value = _plainTextOfSdt(paperTitle!).trim();
      if (value.isEmpty) {
        return _MergeResult.unsafe('The paper title cannot be empty.');
      }
      if (value != nextPaper.title.trim()) {
        nextPaper = nextPaper.copyWith(title: value);
        changed++;
      } else {
        return _MergeResult.unsafe(
          'Word formatting changed the paper title, but title formatting is controlled by the EduSheet template. Import was cancelled rather than silently ignoring the change.',
        );
      }
    }

    final school = tagged[schoolNameTag];
    if (changedControl(schoolNameTag, school)) {
      final value = _plainTextOfSdt(school!).trim();
      if (value != nextPaper.schoolName.trim()) {
        nextPaper = nextPaper.copyWith(schoolName: value);
        changed++;
      } else {
        return _MergeResult.unsafe(
          'Word formatting changed the school name, but school-name formatting is controlled by the EduSheet template.',
        );
      }
    }

    final newSections = <PaperSection>[];
    for (final section in nextPaper.sections) {
      var nextSection = section;
      final titleTag = sectionTitleTag(section.id);
      final titleControl = tagged[titleTag];
      if (changedControl(titleTag, titleControl)) {
        final value = _plainTextOfSdt(titleControl!).trim();
        if (value.isEmpty) {
          return _MergeResult.unsafe('A section title cannot be empty.');
        }
        if (value != section.title.trim()) {
          nextSection = nextSection.copyWith(title: value);
          changed++;
        } else {
          return _MergeResult.unsafe(
            'Word formatting changed a section title, but section-title formatting is controlled by EduSheet.',
          );
        }
      }

      final instructionTag = sectionInstructionTag(section.id);
      final instructionControl = tagged[instructionTag];
      if (changedControl(instructionTag, instructionControl)) {
        final value = _plainTextOfSdt(instructionControl!).trim();
        if (value != (section.instruction ?? '').trim()) {
          nextSection = nextSection.copyWith(instruction: value);
          changed++;
        } else {
          return _MergeResult.unsafe(
            'Word formatting changed a section instruction, but that field has no rich-text model in EduSheet.',
          );
        }
      }

      final questions = <Question>[];
      for (final question in nextSection.questions) {
        final merged = _mergeQuestion(question, tagged, baselineManifest);
        if (!merged.safe) return _MergeResult.unsafe(merged.message);
        questions.add(merged.paperQuestion!);
        changed += merged.changedFields;
      }
      newSections.add(nextSection.copyWith(questions: questions));
    }

    nextPaper = nextPaper.copyWith(sections: newSections);
    return _MergeResult.safe(nextPaper, changed);
  }

  static _QuestionMergeResult _mergeQuestion(
    Question question,
    Map<String, xml.XmlElement> tagged,
    Map<String, String> baselineManifest,
  ) {
    bool changedControl(String tag, xml.XmlElement? control) {
      if (control == null) return false;
      final baseline = baselineManifest[tag];
      if (baseline == null) return true;
      return _editableContentFingerprint(control) != baseline;
    }

    var changed = 0;
    var nextQuestion = question;
    final textTag = questionTextTag(question.id);
    final textControl = tagged[textTag];
    if (changedControl(textTag, textControl)) {
      final importedPlain = _plainTextOfSdt(textControl!).trim();
      final importedRich = _quillDeltaFromSdt(textControl);
      if (_containsNonTextEmbed(question.text)) {
        return _QuestionMergeResult.unsafe(
          'A Word edit touched question text that contains an EduSheet Math/Geometry embed. Re-open that question in EduSheet so the embed position is not lost.',
        );
      }
      if (importedRich == null) {
        return _QuestionMergeResult.unsafe(
          'EduSheet could not safely decode an edited Word question field.',
        );
      }
      nextQuestion = nextQuestion.copyWith(
        text: importedRich,
        plainTextAccessibility: importedPlain,
      );
      changed++;
    }

    final marksTag = questionMarksTag(question.id);
    final marksControl = tagged[marksTag];
    if (!question.isWordContentBlock &&
        changedControl(marksTag, marksControl)) {
      final raw = _plainTextOfSdt(
        marksControl!,
      ).replaceAll('[', '').replaceAll(']', '').trim();
      final value = double.tryParse(raw);
      if (value == null || value < 0) {
        return _QuestionMergeResult.unsafe(
          'A question mark value in Word is not a valid non-negative number. Import was cancelled.',
        );
      }
      if (value != nextQuestion.marks) {
        nextQuestion = nextQuestion.copyWith(marks: value);
        changed++;
      }
    }

    if (nextQuestion.options.isNotEmpty) {
      final options = <QuestionOption>[];
      var optionChanges = 0;
      for (final option in nextQuestion.options) {
        final tag = questionOptionTag(question.id, option.id);
        final control = tagged[tag];
        if (!changedControl(tag, control)) {
          options.add(option);
          continue;
        }
        final visible = _plainTextOfSdt(control!).trim();
        if (visible == option.text.trim()) {
          return _QuestionMergeResult.unsafe(
            'Word formatting changed an answer option, but option formatting is not represented by EduSheet yet.',
          );
        }
        options.add(option.copyWith(text: visible));
        optionChanges++;
      }
      if (optionChanges > 0) {
        nextQuestion = nextQuestion.copyWith(options: options);
        changed += optionChanges;
      }
    }

    final subQuestions = <Question>[];
    var nestedChanges = 0;
    for (final child in nextQuestion.subQuestions) {
      final merged = _mergeQuestion(child, tagged, baselineManifest);
      if (!merged.safe) return merged;
      subQuestions.add(merged.paperQuestion!);
      nestedChanges += merged.changedFields;
    }

    final choices = <Question>[];
    for (final child in nextQuestion.internalChoices) {
      final merged = _mergeQuestion(child, tagged, baselineManifest);
      if (!merged.safe) return merged;
      choices.add(merged.paperQuestion!);
      nestedChanges += merged.changedFields;
    }

    if (nestedChanges > 0) {
      nextQuestion = nextQuestion.copyWith(
        subQuestions: subQuestions,
        internalChoices: choices,
      );
      changed += nestedChanges;
    }
    return _QuestionMergeResult.safe(nextQuestion, changed);
  }

  static bool _containsNonTextEmbed(String persistedRichText) {
    try {
      final decoded = jsonDecode(persistedRichText);
      if (decoded is! List) return false;
      for (final operation in decoded.whereType<Map>()) {
        if (operation['insert'] is Map) return true;
      }
    } catch (_) {
      // Legacy plain text has no structured embeds.
    }
    return false;
  }

  /// Converts the tagged Word runs into EduSheet's persisted Quill delta.
  /// Basic Word run formatting is retained; unsupported Word run properties
  /// remain safely outside EduSheet's merge surface.
  static String? _quillDeltaFromSdt(xml.XmlElement sdt) {
    final content = _sdtContent(sdt);
    if (content == null) return null;
    final operations = <Map<String, dynamic>>[];

    for (final run in content.descendants.whereType<xml.XmlElement>()) {
      if (run.name.local != 'r') continue;
      final text = StringBuffer();
      for (final node in run.descendants.whereType<xml.XmlElement>()) {
        if (node.name.local == 't') text.write(node.innerText);
        if (node.name.local == 'tab') text.write('\t');
        if (node.name.local == 'br') text.write('\n');
      }
      if (text.isEmpty) continue;

      final attributes = <String, dynamic>{};
      final rPr = run.children
          .whereType<xml.XmlElement>()
          .where((element) => element.name.local == 'rPr')
          .firstOrNull;
      if (rPr != null) {
        if (_hasOnProperty(rPr, 'b')) attributes['bold'] = true;
        if (_hasOnProperty(rPr, 'i')) attributes['italic'] = true;
        final underline = _child(rPr, 'u');
        if (underline != null && _attr(underline, 'val') != 'none') {
          attributes['underline'] = true;
        }
        if (_hasOnProperty(rPr, 'strike')) attributes['strike'] = true;
        final vert = _child(rPr, 'vertAlign');
        final vertValue = vert == null ? null : _attr(vert, 'val');
        if (vertValue == 'superscript') attributes['script'] = 'super';
        if (vertValue == 'subscript') attributes['script'] = 'sub';
      }

      final operation = <String, dynamic>{'insert': text.toString()};
      if (attributes.isNotEmpty) operation['attributes'] = attributes;
      operations.add(operation);
    }

    if (operations.isEmpty) operations.add({'insert': ''});
    final lastInsert = operations.last['insert']?.toString() ?? '';
    if (!lastInsert.endsWith('\n')) operations.add({'insert': '\n'});
    return jsonEncode(operations);
  }

  static bool _hasOnProperty(xml.XmlElement parent, String localName) {
    final node = _child(parent, localName);
    if (node == null) return false;
    final value = _attr(node, 'val');
    return value == null || value != '0' && value != 'false' && value != 'off';
  }

  static xml.XmlElement? _child(xml.XmlElement parent, String localName) {
    for (final child in parent.children.whereType<xml.XmlElement>()) {
      if (child.name.local == localName) return child;
    }
    return null;
  }

  static String? _attr(xml.XmlElement element, String localName) {
    for (final attribute in element.attributes) {
      if (attribute.name.local == localName) return attribute.value;
    }
    return null;
  }

  static String _plainTextOfSdt(xml.XmlElement sdt) {
    final content = _sdtContent(sdt);
    if (content == null) return '';
    final buffer = StringBuffer();
    for (final element in content.descendants.whereType<xml.XmlElement>()) {
      if (element.name.local == 't') buffer.write(element.innerText);
      if (element.name.local == 'tab') buffer.write('\t');
      if (element.name.local == 'br') buffer.write('\n');
    }
    return buffer.toString();
  }

  static xml.XmlElement? _sdtContent(xml.XmlElement sdt) {
    for (final child in sdt.children.whereType<xml.XmlElement>()) {
      if (child.name.local == 'sdtContent') return child;
    }
    return null;
  }

  static String? _contentControlTag(xml.XmlElement sdt) {
    for (final element in sdt.descendants.whereType<xml.XmlElement>()) {
      if (element.name.local != 'tag') continue;
      return _attr(element, 'val');
    }
    return null;
  }

  static String _xmlPartFingerprint(String source) {
    final document = xml.XmlDocument.parse(source);
    final buffer = StringBuffer();

    void visit(xml.XmlNode node) {
      if (node is xml.XmlText) {
        final value = node.value.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (value.isNotEmpty) buffer.write('#$value');
        return;
      }
      if (node is! xml.XmlElement) return;
      final local = node.name.local;
      if (local == 'proofErr' ||
          local == 'bookmarkStart' ||
          local == 'bookmarkEnd') {
        return;
      }
      buffer.write('<$local');
      final attrs =
          node.attributes
              .where((attribute) {
                final name = attribute.name.local;
                final prefix = attribute.name.prefix;
                return prefix != 'xmlns' &&
                    name != 'xmlns' &&
                    !name.startsWith('rsid') &&
                    name != 'paraId' &&
                    name != 'textId' &&
                    name != 'Ignorable';
              })
              .map((attribute) => '${attribute.name.local}=${attribute.value}')
              .toList()
            ..sort();
      for (final attr in attrs) {
        buffer.write('|$attr');
      }
      buffer.write('>');
      for (final child in node.children) {
        visit(child);
      }
      buffer.write('</$local>');
    }

    visit(document.rootElement);
    return documentFingerprint(buffer.toString());
  }

  /// Structural signature used to decide whether external edits are confined
  /// to EduSheet's tagged merge surface. The contents of EduSheet `w:sdt`
  /// controls are replaced by a stable placeholder while the rest of the Word
  /// body remains part of the signature.
  static String editableSkeletonFingerprint(String documentXml) {
    final document = xml.XmlDocument.parse(documentXml);
    final buffer = StringBuffer();

    void visit(xml.XmlNode node) {
      if (node is xml.XmlText) {
        final normalized = node.value.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (normalized.isNotEmpty) buffer.write('#$normalized');
        return;
      }
      if (node is! xml.XmlElement) return;

      final local = node.name.local;
      if (local == 'proofErr' ||
          local == 'bookmarkStart' ||
          local == 'bookmarkEnd') {
        return;
      }

      if (local == 'sdt') {
        final tag = _contentControlTag(node);
        if (tag != null && tag.startsWith(_editableTagPrefix)) {
          buffer.write('<sdt:$tag/>');
          return;
        }
      }

      buffer.write('<$local');
      final attributes =
          node.attributes
              .where((attribute) {
                final name = attribute.name.local;
                final prefix = attribute.name.prefix;
                return prefix != 'xmlns' &&
                    name != 'xmlns' &&
                    !name.startsWith('rsid') &&
                    name != 'paraId' &&
                    name != 'textId' &&
                    name != 'Ignorable';
              })
              .map((attribute) => '${attribute.name.local}=${attribute.value}')
              .toList()
            ..sort();
      for (final attribute in attributes) {
        buffer.write('|$attribute');
      }
      buffer.write('>');
      for (final child in node.children) {
        visit(child);
      }
      buffer.write('</$local>');
    }

    visit(document.rootElement);
    return documentFingerprint(buffer.toString());
  }

  /// Stable, dependency-free 64-bit FNV-1a fingerprint.
  /// This is an integrity/change detector, not a cryptographic signature.
  static String documentFingerprint(String value) {
    const offsetBasis = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    const mask = 0xffffffffffffffff;
    var hash = offsetBasis;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  static ArchiveFile? _entry(Archive archive, String name) {
    for (final entry in archive.files) {
      if (entry.name == name) return entry;
    }
    return null;
  }

  static List<int> _bytes(ArchiveFile entry) {
    return List<int>.from(entry.content);
  }

  static String? _firstText(xml.XmlElement root, String localName) {
    for (final element in root.descendants.whereType<xml.XmlElement>()) {
      if (element.name.local == localName) return element.innerText.trim();
    }
    return null;
  }
}

class _MergeResult {
  final bool safe;
  final Paper? paper;
  final int changedFields;
  final String message;

  const _MergeResult._({
    required this.safe,
    required this.paper,
    required this.changedFields,
    required this.message,
  });

  factory _MergeResult.safe(Paper paper, int changedFields) => _MergeResult._(
    safe: true,
    paper: paper,
    changedFields: changedFields,
    message: '',
  );

  factory _MergeResult.unsafe(String message) => _MergeResult._(
    safe: false,
    paper: null,
    changedFields: 0,
    message: message,
  );
}

class _QuestionMergeResult {
  final bool safe;
  final Question? paperQuestion;
  final int changedFields;
  final String message;

  const _QuestionMergeResult._({
    required this.safe,
    required this.paperQuestion,
    required this.changedFields,
    required this.message,
  });

  factory _QuestionMergeResult.safe(Question question, int changedFields) =>
      _QuestionMergeResult._(
        safe: true,
        paperQuestion: question,
        changedFields: changedFields,
        message: '',
      );

  factory _QuestionMergeResult.unsafe(String message) => _QuestionMergeResult._(
    safe: false,
    paperQuestion: null,
    changedFields: 0,
    message: message,
  );
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
