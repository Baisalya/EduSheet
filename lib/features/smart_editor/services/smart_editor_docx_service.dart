import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:edusheet/features/pdf/services/math/word_omml_math_typesetter.dart';
import 'package:edusheet/features/smart_editor/application/smart_editor_export_projection.dart';
import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_break_embed_builder.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_interop_embed_builders.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_word_advanced_embed_builder.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_geometry_rasterizer.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';
import 'package:edusheet/features/word_converter/services/docx_conversion_parser.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart' as xml;

class SmartEditorDocxImportResult {
  const SmartEditorDocxImportResult({
    required this.document,
    this.warnings = const <String>[],
    this.nativeRoundTrip = false,
  });

  final SmartDocument document;
  final List<String> warnings;
  final bool nativeRoundTrip;
}

class SmartEditorDocxExportResult {
  const SmartEditorDocxExportResult({
    required this.bytes,
    this.warnings = const <String>[],
  });

  final Uint8List bytes;
  final List<String> warnings;
}

/// DOCX bridge for Smart Editor.
///
/// Standard Word content is always emitted for interoperability. An EduSheet
/// custom XML part is also embedded with SHA-256 change-detection hashes for
/// every Word-owned package part (`word/*`), including body, header/footer,
/// styles, relationships and media. Native math, geometry and Smart Editor
/// metadata are restored only for an exact round trip. Any normal external Word
/// edit invalidates the package fingerprint and import falls back to standard
/// DOCX content. These hashes are integrity/change detection, not authentication.
class SmartEditorDocxService {
  const SmartEditorDocxService({
    this.geometryRasterizer = const SmartEditorGeometryRasterizer(),
  });

  static const String roundTripPartName =
      'customXml/itemEduSheetSmartDocument.xml';
  static const String roundTripNamespace =
      'urn:edusheet:smart-document:v1';
  static const String roundTripRelationshipType =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/customXml';
  static const WordOmmlMathTypesetter _omml = WordOmmlMathTypesetter();
  static const double _wordPointToLogical = 96 / 72;
  static const double _logicalToWordPoint = 72 / 96;

  final SmartEditorGeometryRasterizer geometryRasterizer;

  Future<SmartEditorDocxImportResult> importFile(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final entries = <String, ArchiveFile>{
      for (final entry in archive.files) entry.name: entry,
    };
    final hadNativeMetadata = entries.containsKey(roundTripPartName);
    final native = _restoreNative(entries);
    if (native != null) {
      final now = DateTime.now().toUtc();
      final restored = native.copyWith(
        id: SmartDocument.blank().id,
        wordPreservation: _captureWordPreservation(entries),
        createdAt: now,
        updatedAt: now,
      );
      return SmartEditorDocxImportResult(
        document: restored,
        nativeRoundTrip: true,
      );
    }

    final parsed = await DocxConversionParser.parse(file);
    final preservation = _captureWordPreservation(entries);
    final warnings = <String>[
      if (hadNativeMetadata)
        'This EduSheet Word file has changed outside EduSheet (or its native metadata is no longer exact), so it was opened through standard Word compatibility mode. Native Math/Geometry may return as normal Word math or images instead of editable EduSheet objects.',
      'Imported through structured Word compatibility mode. Editable Word features remain structured Smart Editor objects; WM9 preserve-only capsules retain unsupported OOXML/package parts such as SmartArt, charts, embedded objects and content controls when they cannot be edited safely.',
    ];
    final document = _fromConversionDocument(
      parsed,
      title: p.basenameWithoutExtension(file.path),
      warnings: warnings,
      preservation: preservation,
    );
    return SmartEditorDocxImportResult(
      document: document,
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  Future<SmartEditorDocxExportResult> export(SmartDocument document) async {
    final projection = SmartEditorExportProjection.fromDocument(document);
    final advancedParts = _AdvancedWordParts.fromProjection(projection);
    final preservation = document.wordPreservation;
    final warnings = <String>[];
    final media = <String, _MediaPart>{};
    var mediaNumber = 1;
    final preservedRelationshipIds = preservation.documentRelationships
        .map((relationship) => relationship.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    String mediaRelationshipId(int number) => _uniqueRelationshipId(
          'rIdEduSheetImage$number',
          preservedRelationshipIds,
        );

    void collectTableMedia(
      SmartEditorInteropTablePayload table,
      String prefix,
    ) {
      for (var rowIndex = 0; rowIndex < table.rows.length; rowIndex++) {
        final row = table.rows[rowIndex];
        for (var cellIndex = 0; cellIndex < row.cells.length; cellIndex++) {
          final cell = row.cells[cellIndex];
          for (var blockIndex = 0; blockIndex < cell.blocks.length; blockIndex++) {
            final cellBlock = cell.blocks[blockIndex];
            final key = '$prefix/r$rowIndex/c$cellIndex/b$blockIndex';
            if (cellBlock.kind == 'image') {
              final payload = cellBlock.image;
              if (payload == null || payload.bytes.isEmpty) continue;
              final kind = _imageKind(payload.bytes);
              if (kind == null) {
                warnings.add(
                  'One Word table image uses an unsupported format and could not be re-exported.',
                );
                continue;
              }
              media[key] = _MediaPart(
                relationshipId: mediaRelationshipId(mediaNumber),
                fileName: 'table_image_$mediaNumber.${kind.extension}',
                contentType: kind.contentType,
                bytes: payload.bytes,
                widthPoints: payload.widthPoints * _logicalToWordPoint,
                heightPoints: payload.heightPoints * _logicalToWordPoint,
                altText: payload.altText ?? 'Word table image',
                hyperlink: payload.hyperlink,
                placement: payload.placement,
                cropLeft: payload.cropLeft,
                cropTop: payload.cropTop,
                cropRight: payload.cropRight,
                cropBottom: payload.cropBottom,
                rotationDegrees: payload.rotationDegrees,
                flipHorizontal: payload.flipHorizontal,
                flipVertical: payload.flipVertical,
              );
              mediaNumber++;
            } else if (cellBlock.kind == 'table' && cellBlock.table != null) {
              collectTableMedia(cellBlock.table!, key);
            }
          }
        }
      }
    }

    for (var index = 0; index < projection.blocks.length; index++) {
      final block = projection.blocks[index];
      if (block is SmartEditorExportImage) {
        if (block.payload.bytes.isEmpty) continue;
        final kind = _imageKind(block.payload.bytes);
        if (kind == null) {
          warnings.add(
            'One imported image uses an unsupported format and was replaced by a text placeholder in DOCX.',
          );
          continue;
        }
        media['block:$index'] = _MediaPart(
          relationshipId: mediaRelationshipId(mediaNumber),
          fileName: 'smart_image_$mediaNumber.${kind.extension}',
          contentType: kind.contentType,
          bytes: block.payload.bytes,
          widthPoints: block.payload.widthPoints * _logicalToWordPoint,
          heightPoints: block.payload.heightPoints * _logicalToWordPoint,
          altText: block.payload.altText ?? 'Imported Word image',
          hyperlink: block.payload.hyperlink,
          placement: block.payload.placement,
          cropLeft: block.payload.cropLeft,
          cropTop: block.payload.cropTop,
          cropRight: block.payload.cropRight,
          cropBottom: block.payload.cropBottom,
          rotationDegrees: block.payload.rotationDegrees,
          flipHorizontal: block.payload.flipHorizontal,
          flipVertical: block.payload.flipVertical,
        );
        mediaNumber++;
      } else if (block is SmartEditorExportGeometry) {
        final diagram = block.layout.diagram;
        if (diagram == null) {
          warnings.add(
            'One geometry object had no embedded diagram payload and was exported as a placeholder.',
          );
          continue;
        }
        try {
          final png = await geometryRasterizer.toPng(diagram);
          final naturalWidth = diagram.canvasSize.width.clamp(120.0, 520.0).toDouble();
          final width = (naturalWidth * block.layout.widthFactor)
              .clamp(120.0, 520.0)
              .toDouble();
          final height = block.layout.height.clamp(90.0, 520.0).toDouble();
          media['block:$index'] = _MediaPart(
            relationshipId: mediaRelationshipId(mediaNumber),
            fileName: 'geometry_$mediaNumber.png',
            contentType: 'image/png',
            bytes: png,
            widthPoints: width,
            heightPoints: height,
            altText: diagram.name,
          );
          mediaNumber++;
        } catch (_) {
          warnings.add(
            'One geometry object could not be rendered for Word and was exported as a text placeholder.',
          );
        }
      } else if (block is SmartEditorExportTable) {
        collectTableMedia(block.payload, 'block:$index');
      }
    }

    final hyperlinks = _hyperlinkRelationships(
      projection,
      reservedRelationshipIds: preservedRelationshipIds,
    );
    final storyParts = _headerFooterParts(
      document,
      reservedRelationshipIds: preservedRelationshipIds,
    );
    final documentXml = _documentXml(
      document,
      projection,
      media,
      warnings,
      hyperlinks: hyperlinks,
      storyParts: storyParts,
      advancedParts: advancedParts,
      preservation: preservation,
    );
    final archive = Archive();

    void addString(String name, String source) {
      archive.addFile(ArchiveFile.string(name, source));
    }

    addString(
      '[Content_Types].xml',
      _contentTypesXml(
        media.values,
        storyParts: storyParts,
        advancedParts: advancedParts,
        preservation: preservation,
      ),
    );
    addString('_rels/.rels', _rootRelsXml(preservation));
    addString('docProps/core.xml', _coreXml(document));
    addString('docProps/app.xml', _appXml());
    addString('word/styles.xml', _stylesXml());
    addString('word/numbering.xml', _numberingXml());
    addString(
      'word/_rels/document.xml.rels',
      _documentRelsXml(
        media.values,
        hyperlinks: hyperlinks,
        storyParts: storyParts,
        advancedParts: advancedParts,
        preservation: preservation,
      ),
    );
    addString('word/settings.xml', _settingsXml(document));
    for (final story in storyParts) {
      addString(
        'word/${story.fileName}',
        _headerFooterXml(story.config, header: story.header),
      );
    }
    if (advancedParts.footnotes.isNotEmpty) {
      addString('word/footnotes.xml', advancedParts.footnotesXml());
    }
    if (advancedParts.endnotes.isNotEmpty) {
      addString('word/endnotes.xml', advancedParts.endnotesXml());
    }
    if (advancedParts.comments.isNotEmpty) {
      addString('word/comments.xml', advancedParts.commentsXml());
    }
    addString('word/document.xml', documentXml);
    for (final part in media.values) {
      archive.addFile(
        ArchiveFile.bytes('word/media/${part.fileName}', part.bytes),
      );
    }
    final generatedNames = archive.files.map((entry) => entry.name).toSet();
    for (final part in preservation.packageParts) {
      final path = part.path.trim();
      final supersededAdvancedRelationshipPart =
          (advancedParts.footnotes.isNotEmpty &&
              path == 'word/_rels/footnotes.xml.rels') ||
          (advancedParts.endnotes.isNotEmpty &&
              path == 'word/_rels/endnotes.xml.rels') ||
          (advancedParts.comments.isNotEmpty &&
              path == 'word/_rels/comments.xml.rels');
      if (!_isSafeOpcArchivePath(path) ||
          path == roundTripPartName ||
          generatedNames.contains(path) ||
          supersededAdvancedRelationshipPart) {
        continue;
      }
      final bytes = part.bytes;
      if (bytes.isEmpty) continue;
      archive.addFile(ArchiveFile.bytes(path, bytes));
      generatedNames.add(path);
    }
    addString(
      roundTripPartName,
      _roundTripXml(
        document,
        documentXml,
        _wordContentFingerprint(archive.files),
      ),
    );

    return SmartEditorDocxExportResult(
      bytes: Uint8List.fromList(ZipEncoder().encode(archive)),
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  static bool _isSafeOpcArchivePath(String rawPath) {
    final path = rawPath.replaceAll('\\', '/').trim();
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.contains(':') ||
        path.contains('\u0000')) {
      return false;
    }
    final segments = path.split('/');
    return segments.every(
      (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
    );
  }

  static SmartDocumentWordPreservationState _captureWordPreservation(
    Map<String, ArchiveFile> entries,
  ) {
    bool regeneratedPart(String path) {
      if (const <String>{
        '[Content_Types].xml',
        '_rels/.rels',
        'docProps/core.xml',
        'docProps/app.xml',
        'word/document.xml',
        'word/_rels/document.xml.rels',
        'word/styles.xml',
        'word/numbering.xml',
        'word/settings.xml',
        roundTripPartName,
      }.contains(path)) {
        return true;
      }
      if (RegExp(r'^word/(header|footer)\d+\.xml$').hasMatch(path) ||
          RegExp(r'^word/_rels/(header|footer)\d+\.xml\.rels$').hasMatch(path)) {
        return true;
      }
      return false;
    }

    final packageParts = <SmartDocumentPreservedPackagePart>[];
    for (final entry in entries.values) {
      if (entry.isFile == false ||
          !_isSafeOpcArchivePath(entry.name) ||
          regeneratedPart(entry.name)) {
        continue;
      }
      final content = entry.content;
      packageParts.add(
        SmartDocumentPreservedPackagePart(
          path: entry.name,
          base64Data: base64Encode(content),
        ),
      );
    }

    List<SmartDocumentPreservedRelationship> relationships(
      String path, {
      required bool root,
    }) {
      final entry = entries[path];
      if (entry == null) return const <SmartDocumentPreservedRelationship>[];
      try {
        final document = xml.XmlDocument.parse(utf8.decode(entry.content));
        final result = <SmartDocumentPreservedRelationship>[];
        for (final element in document.rootElement.childElements) {
          if (element.name.local != 'Relationship') continue;
          final id = element.getAttribute('Id') ?? '';
          final type = element.getAttribute('Type') ?? '';
          final target = element.getAttribute('Target') ?? '';
          if (id.isEmpty || type.isEmpty || target.isEmpty) continue;
          final suffix = type.split('/').last.toLowerCase();
          final normalizedTarget = target.replaceAll('\\', '/');
          final isEduSheetRoundTripRelationship =
              type == roundTripRelationshipType &&
                  (normalizedTarget == '../$roundTripPartName' ||
                      normalizedTarget == roundTripPartName);
          final structural = root
              ? const <String>{
                  'officedocument',
                  'core-properties',
                  'extended-properties',
                }.contains(suffix)
              : const <String>{
                  'styles',
                  'numbering',
                  'settings',
                  'header',
                  'footer',
                }.contains(suffix) ||
                  isEduSheetRoundTripRelationship;
          if (structural) continue;
          result.add(
            SmartDocumentPreservedRelationship(
              id: id,
              type: type,
              target: target,
              targetMode: element.getAttribute('TargetMode'),
            ),
          );
        }
        return List<SmartDocumentPreservedRelationship>.unmodifiable(result);
      } catch (_) {
        return const <SmartDocumentPreservedRelationship>[];
      }
    }

    final contentTypes = <SmartDocumentPreservedContentType>[];
    final contentTypesEntry = entries['[Content_Types].xml'];
    if (contentTypesEntry != null) {
      try {
        final document = xml.XmlDocument.parse(
          utf8.decode(contentTypesEntry.content),
        );
        for (final element in document.rootElement.childElements) {
          if (element.name.local == 'Default') {
            final extension = element.getAttribute('Extension');
            final contentType = element.getAttribute('ContentType');
            if (extension != null && contentType != null) {
              contentTypes.add(
                SmartDocumentPreservedContentType(
                  extension: extension,
                  contentType: contentType,
                ),
              );
            }
          } else if (element.name.local == 'Override') {
            final partName = element.getAttribute('PartName');
            final contentType = element.getAttribute('ContentType');
            if (partName != null && contentType != null) {
              contentTypes.add(
                SmartDocumentPreservedContentType(
                  partName: partName,
                  contentType: contentType,
                ),
              );
            }
          }
        }
      } catch (_) {
        // A malformed content-type table should not prevent the readable Word
        // document from opening. Preserve-only metadata is best effort here.
      }
    }

    final namespaces = <String, String>{};
    final documentEntry = entries['word/document.xml'];
    if (documentEntry != null) {
      try {
        final source = utf8.decode(documentEntry.content);
        final root = RegExp(r'<w:document\b([^>]*)>', dotAll: true)
            .firstMatch(source)
            ?.group(1);
        if (root != null) {
          final namespacePattern = RegExp(
            r'''xmlns(?::([A-Za-z_][A-Za-z0-9_.-]*))?\s*=\s*["']([^"']+)["']''',
          );
          for (final match in namespacePattern.allMatches(root)) {
            namespaces[match.group(1) ?? ''] = match.group(2)!;
          }
        }
      } catch (_) {
        // Namespace carry-forward is supplementary to the opaque raw payload.
      }
    }

    return SmartDocumentWordPreservationState(
      packageParts: List<SmartDocumentPreservedPackagePart>.unmodifiable(
        packageParts,
      ),
      documentRelationships: relationships(
        'word/_rels/document.xml.rels',
        root: false,
      ),
      rootRelationships: relationships('_rels/.rels', root: true),
      contentTypes: List<SmartDocumentPreservedContentType>.unmodifiable(
        contentTypes,
      ),
      documentNamespaces: Map<String, String>.unmodifiable(namespaces),
    );
  }

  static String _preservedNamespaceXml(
    SmartDocumentWordPreservationState preservation,
  ) {
    const reserved = <String>{'w', 'r', 'm', 'wp', 'a', 'pic', 'v', 'o', 'w10'};
    final buffer = StringBuffer();
    for (final entry in preservation.documentNamespaces.entries) {
      final prefix = entry.key.trim();
      final uri = entry.value.trim();
      if (uri.isEmpty || prefix.isEmpty || reserved.contains(prefix)) continue;
      buffer.write('xmlns:${_xml(prefix)}="${_xml(uri)}" ');
    }
    return buffer.toString();
  }

  static String _preservedRelationshipsXml(
    Iterable<SmartDocumentPreservedRelationship> relationships, {
    required Set<String> reservedIds,
    Set<String> blockedTypes = const <String>{},
  }) {
    final used = <String>{...reservedIds};
    final blocked = blockedTypes.map((value) => value.toLowerCase()).toSet();
    final buffer = StringBuffer();
    for (final relationship in relationships) {
      final id = relationship.id.trim();
      final type = relationship.type.trim();
      final target = relationship.target.trim();
      final typeSuffix = type.split('/').last.toLowerCase();
      if (id.isEmpty ||
          type.isEmpty ||
          target.isEmpty ||
          blocked.contains(type.toLowerCase()) ||
          blocked.contains(typeSuffix) ||
          !used.add(id)) {
        continue;
      }
      buffer.write(
        '<Relationship Id="${_xml(id)}" Type="${_xml(type)}" Target="${_xml(target)}"',
      );
      final mode = relationship.targetMode?.trim();
      if (mode != null && mode.isNotEmpty) {
        buffer.write(' TargetMode="${_xml(mode)}"');
      }
      buffer.write('/>');
    }
    return buffer.toString();
  }

  static String _preservedContentTypesXml(
    SmartDocumentWordPreservationState preservation, {
    required Set<String> generatedExtensions,
    required Set<String> generatedParts,
  }) {
    final extensions = <String>{
      for (final value in generatedExtensions) value.toLowerCase(),
    };
    final parts = <String>{...generatedParts};
    final buffer = StringBuffer();
    for (final entry in preservation.contentTypes) {
      final extension = entry.extension?.trim();
      final partName = entry.partName?.trim();
      final contentType = entry.contentType.trim();
      if (contentType.isEmpty) continue;
      if (extension != null && extension.isNotEmpty) {
        if (!extensions.add(extension.toLowerCase())) continue;
        buffer.write(
          '<Default Extension="${_xml(extension)}" ContentType="${_xml(contentType)}"/>',
        );
      } else if (partName != null && partName.isNotEmpty) {
        if (!parts.add(partName)) continue;
        buffer.write(
          '<Override PartName="${_xml(partName)}" ContentType="${_xml(contentType)}"/>',
        );
      }
    }
    return buffer.toString();
  }

  SmartDocument? _restoreNative(Map<String, ArchiveFile> entries) {
    final metadata = entries[roundTripPartName];
    final documentPart = entries['word/document.xml'];
    if (metadata == null || documentPart == null) return null;
    try {
      final root = xml.XmlDocument.parse(utf8.decode(metadata.content)).rootElement;
      if (root.name.local != 'smartDocument' || root.getAttribute('version') != '1') {
        return null;
      }
      final payloadElement = root.childElements
          .where((element) => element.name.local == 'payload')
          .firstOrNull;
      if (payloadElement == null) return null;
      final encoded = payloadElement.innerText.trim();
      final payloadBytes = base64Decode(encoded);
      final payloadHash = root.getAttribute('payloadSha256');
      final documentHash = root.getAttribute('documentSha256');
      final packageHash = root.getAttribute('wordContentSha256');
      if (payloadHash == null ||
          documentHash == null ||
          packageHash == null ||
          sha256.convert(payloadBytes).toString() != payloadHash ||
          sha256.convert(documentPart.content as List<int>).toString() !=
              documentHash ||
          _wordContentFingerprint(entries.values) != packageHash) {
        return null;
      }
      final decoded = jsonDecode(utf8.decode(payloadBytes));
      if (decoded is! Map) return null;
      return SmartDocument.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  SmartDocument _fromConversionDocument(
    ConversionDocument source, {
    required String title,
    required List<String> warnings,
    SmartDocumentWordPreservationState preservation =
        const SmartDocumentWordPreservationState(),
  }) {
    final operations = <Map<String, dynamic>>[];
    var importedTables = 0;
    var importedImages = 0;
    var importedTextBoxes = 0;
    var importedShapes = 0;
    var importedAdvancedObjects = 0;
    var structuredObjectNumber = 0;

    String nextObjectId(String kind) =>
        'docx-$kind-${structuredObjectNumber++}';

    void insertBreak(String type) {
      operations.add(<String, dynamic>{
        'insert': <String, dynamic>{SmartEditorBreakEmbedBuilder.keyName: type},
      });
      operations.add(const <String, dynamic>{'insert': '\n'});
    }

    for (var sectionIndex = 0; sectionIndex < source.sections.length; sectionIndex++) {
      final section = source.sections[sectionIndex];
      if (sectionIndex > 0) insertBreak('section');
      for (final block in section.blocks) {
        if (block is ConversionParagraph) {
          if (block.pageBreakBefore) {
            insertBreak('page');
          } else if (block.columnBreakBefore) {
            insertBreak('column');
          }
          final blockAttributes = _paragraphAttributes(block);
          var hasTextInCurrentParagraph = false;
          final inferredList = _listType(block.listLabel);
          if (block.listLabel != null && inferredList == null) {
            operations.add(<String, dynamic>{'insert': block.listLabel!});
            hasTextInCurrentParagraph = true;
          }
          for (final inline in block.inlines) {
            if (inline is ConversionTextRun) {
              if (inline.text.isEmpty) continue;
              final attributes = _textAttributes(inline);
              operations.add(<String, dynamic>{
                'insert': inline.text,
                if (attributes.isNotEmpty) 'attributes': attributes,
              });
              hasTextInCurrentParagraph = true;
            } else if (inline is ConversionDynamicFieldRun) {
              final instruction = switch (inline.field) {
                ConversionDynamicField.pageNumber => 'PAGE',
                ConversionDynamicField.pageCount => 'NUMPAGES',
              };
              final payload = SmartEditorWordAdvancedPayload(
                kind: SmartEditorWordAdvancedPayload.fieldKind,
                objectId: nextObjectId('field'),
                instruction: instruction,
                resultText: '1',
              );
              operations.add(<String, dynamic>{
                'insert': <String, dynamic>{
                  SmartEditorWordAdvancedEmbedBuilder.keyName: payload.encode(),
                },
              });
              hasTextInCurrentParagraph = true;
              importedAdvancedObjects++;
            } else if (inline is ConversionFieldRun) {
              final payload = SmartEditorWordAdvancedPayload(
                kind: SmartEditorWordAdvancedPayload.fieldKind,
                objectId: nextObjectId('field'),
                instruction: inline.instruction,
                resultText: inline.resultText,
                locked: inline.locked,
                dirty: inline.dirty,
              );
              operations.add(<String, dynamic>{
                'insert': <String, dynamic>{
                  SmartEditorWordAdvancedEmbedBuilder.keyName: payload.encode(),
                },
                if (_textAttributesFromStyle(inline.style).isNotEmpty)
                  'attributes': _textAttributesFromStyle(inline.style),
              });
              hasTextInCurrentParagraph = true;
              importedAdvancedObjects++;
            } else if (inline is ConversionMathRun) {
              final payload = SmartEditorWordAdvancedPayload(
                kind: SmartEditorWordAdvancedPayload.equationKind,
                objectId: nextObjectId('equation'),
                resultText: inline.plainText,
                rawXml: inline.ommlXml,
                display: inline.display,
              );
              operations.add(<String, dynamic>{
                'insert': <String, dynamic>{
                  SmartEditorWordAdvancedEmbedBuilder.keyName: payload.encode(),
                },
              });
              hasTextInCurrentParagraph = true;
              importedAdvancedObjects++;
            } else if (inline is ConversionNoteReferenceRun) {
              final payload = SmartEditorWordAdvancedPayload(
                kind: inline.type == ConversionWordNoteType.footnote
                    ? SmartEditorWordAdvancedPayload.footnoteKind
                    : SmartEditorWordAdvancedPayload.endnoteKind,
                objectId: nextObjectId('note'),
                referenceId: inline.noteId,
                contentText: _plainText(inline.blocks),
              );
              operations.add(<String, dynamic>{
                'insert': <String, dynamic>{
                  SmartEditorWordAdvancedEmbedBuilder.keyName: payload.encode(),
                },
              });
              hasTextInCurrentParagraph = true;
              importedAdvancedObjects++;
            } else if (inline is ConversionBookmarkMarkerRun) {
              final payload = SmartEditorWordAdvancedPayload(
                kind: inline.kind == ConversionWordMarkerKind.start
                    ? SmartEditorWordAdvancedPayload.bookmarkStartKind
                    : SmartEditorWordAdvancedPayload.bookmarkEndKind,
                objectId: nextObjectId('bookmark'),
                referenceId: inline.bookmarkId,
                name: inline.name,
              );
              operations.add(<String, dynamic>{
                'insert': <String, dynamic>{
                  SmartEditorWordAdvancedEmbedBuilder.keyName: payload.encode(),
                },
              });
              importedAdvancedObjects++;
            } else if (inline is ConversionCommentMarkerRun) {
              final kind = switch (inline.kind) {
                ConversionWordMarkerKind.start =>
                  SmartEditorWordAdvancedPayload.commentStartKind,
                ConversionWordMarkerKind.end =>
                  SmartEditorWordAdvancedPayload.commentEndKind,
                ConversionWordMarkerKind.reference =>
                  SmartEditorWordAdvancedPayload.commentReferenceKind,
              };
              final payload = SmartEditorWordAdvancedPayload(
                kind: kind,
                objectId: nextObjectId('comment'),
                referenceId: inline.commentId,
                contentText: inline.comment?.text ?? '',
                author: inline.comment?.author,
                initials: inline.comment?.initials,
                dateIso: inline.comment?.dateIso,
              );
              operations.add(<String, dynamic>{
                'insert': <String, dynamic>{
                  SmartEditorWordAdvancedEmbedBuilder.keyName: payload.encode(),
                },
              });
              if (inline.kind == ConversionWordMarkerKind.reference) {
                hasTextInCurrentParagraph = true;
              }
              importedAdvancedObjects++;
            } else if (inline is ConversionOpaqueOoxmlRun) {
              final payload = SmartEditorWordAdvancedPayload(
                kind: SmartEditorWordAdvancedPayload.opaqueOoxmlKind,
                objectId: nextObjectId('opaque'),
                contentText: inline.fallbackText,
                rawXml: inline.rawXml,
                featureKind: inline.featureKind,
                relationshipIds: inline.relationshipIds,
              );
              operations.add(<String, dynamic>{
                'insert': <String, dynamic>{
                  SmartEditorWordAdvancedEmbedBuilder.keyName: payload.encode(),
                },
                if (_textAttributesFromStyle(inline.style).isNotEmpty)
                  'attributes': _textAttributesFromStyle(inline.style),
              });
              hasTextInCurrentParagraph = true;
              importedAdvancedObjects++;
            } else if (inline is ConversionTextBoxRun) {
              if (hasTextInCurrentParagraph) {
                operations.add(<String, dynamic>{
                  'insert': '\n',
                  if (blockAttributes.isNotEmpty) 'attributes': blockAttributes,
                });
                hasTextInCurrentParagraph = false;
              }
              final payload = SmartEditorInteropTablePayload(
                showBorders: false,
                objectId: nextObjectId('textbox'),
                sourceKind: 'textBox',
                widthPoints: inline.widthPoints == null
                    ? null
                    : inline.widthPoints! * _wordPointToLogical,
                heightPoints: inline.heightPoints == null
                    ? null
                    : inline.heightPoints! * _wordPointToLogical,
                placement: _placementPayload(inline.placement),
                rows: <SmartEditorInteropTableRow>[
                  SmartEditorInteropTableRow(
                    cells: <SmartEditorInteropTableCell>[
                      SmartEditorInteropTableCell(
                        text: _plainText(inline.blocks),
                        widthPoints: inline.widthPoints == null
                            ? null
                            : inline.widthPoints! * _wordPointToLogical,
                        paddingTopPoints:
                            inline.paddingTopPoints * _wordPointToLogical,
                        paddingRightPoints:
                            inline.paddingRightPoints * _wordPointToLogical,
                        paddingBottomPoints:
                            inline.paddingBottomPoints * _wordPointToLogical,
                        paddingLeftPoints:
                            inline.paddingLeftPoints * _wordPointToLogical,
                        blocks: _cellBlocks(inline.blocks),
                      ),
                    ],
                  ),
                ],
              );
              operations.add(<String, dynamic>{
                'insert': <String, dynamic>{
                  SmartEditorInteropTableEmbedBuilder.keyName: payload.encode(),
                },
              });
              operations.add(const <String, dynamic>{'insert': '\n'});
              importedTextBoxes++;
              importedImages += _imageCountInBlocks(inline.blocks);
            } else if (inline is ConversionShapeRun) {
              if (hasTextInCurrentParagraph) {
                operations.add(<String, dynamic>{
                  'insert': '\n',
                  if (blockAttributes.isNotEmpty) 'attributes': blockAttributes,
                });
                hasTextInCurrentParagraph = false;
              }
              final payload = _shapePayload(
                inline,
                objectId: nextObjectId('shape'),
              );
              operations.add(<String, dynamic>{
                'insert': <String, dynamic>{
                  SmartEditorInteropShapeEmbedBuilder.keyName: payload.encode(),
                },
              });
              operations.add(const <String, dynamic>{'insert': '\n'});
              importedShapes++;
              importedImages += _imageCountInBlocks(inline.blocks);
            } else if (inline is ConversionImageRun) {
              if (hasTextInCurrentParagraph) {
                operations.add(<String, dynamic>{
                  'insert': '\n',
                  if (blockAttributes.isNotEmpty) 'attributes': blockAttributes,
                });
                hasTextInCurrentParagraph = false;
              }
              final payload = SmartEditorInteropImagePayload(
                bytes: Uint8List.fromList(inline.bytes),
                objectId: nextObjectId('image'),
                widthPoints: inline.widthPoints * _wordPointToLogical,
                heightPoints: inline.heightPoints * _wordPointToLogical,
                altText: inline.altText,
                hyperlink: inline.hyperlink,
                placement: _placementPayload(inline.placement),
                cropLeft: inline.crop.left,
                cropTop: inline.crop.top,
                cropRight: inline.crop.right,
                cropBottom: inline.crop.bottom,
                rotationDegrees: inline.rotationDegrees,
                flipHorizontal: inline.flipHorizontal,
                flipVertical: inline.flipVertical,
              );
              operations.add(<String, dynamic>{
                'insert': <String, dynamic>{
                  SmartEditorInteropImageEmbedBuilder.keyName: payload.encode(),
                },
              });
              operations.add(const <String, dynamic>{'insert': '\n'});
              importedImages++;
            }
          }
          if (inferredList != null) blockAttributes['list'] = inferredList;
          if (hasTextInCurrentParagraph || block.inlines.isEmpty) {
            operations.add(<String, dynamic>{
              'insert': '\n',
              if (blockAttributes.isNotEmpty) 'attributes': blockAttributes,
            });
          }
        } else if (block is ConversionOpaqueOoxmlBlock) {
          final payload = SmartEditorWordAdvancedPayload(
            kind: SmartEditorWordAdvancedPayload.opaqueOoxmlKind,
            objectId: nextObjectId('opaque-block'),
            contentText: _plainText(block.fallbackBlocks),
            rawXml: block.rawXml,
            featureKind: block.featureKind,
            ooxmlScope: 'block',
            relationshipIds: block.relationshipIds,
          );
          operations.add(<String, dynamic>{
            'insert': <String, dynamic>{
              SmartEditorWordAdvancedEmbedBuilder.keyName: payload.encode(),
            },
          });
          operations.add(const <String, dynamic>{'insert': '\n'});
          importedAdvancedObjects++;
        } else if (block is ConversionTable) {
          final payload = _tablePayload(
            block,
            objectId: nextObjectId('table'),
          );
          operations.add(<String, dynamic>{
            'insert': <String, dynamic>{
              SmartEditorInteropTableEmbedBuilder.keyName: payload.encode(),
            },
          });
          operations.add(const <String, dynamic>{'insert': '\n'});
          importedTables++;
          importedImages += _imageCountInBlocks(<ConversionBlock>[block]);
        }
      }
    }

    if (operations.isEmpty || operations.last['insert'] != '\n') {
      operations.add(const <String, dynamic>{'insert': '\n'});
    }
    if (importedTables > 0) {
      warnings.add(
        '$importedTables Word table${importedTables == 1 ? '' : 's'} preserved as structured editable table blocks with Word column proportions, cell geometry and rich embedded content.',
      );
    }
    if (importedImages > 0) {
      warnings.add(
        '$importedImages Word image${importedImages == 1 ? '' : 's'} preserved as document image blocks.',
      );
    }
    if (importedTextBoxes > 0) {
      warnings.add(
        '$importedTextBoxes Word text box${importedTextBoxes == 1 ? '' : 'es'} preserved as editable structured text-box blocks.',
      );
    }
    if (importedShapes > 0) {
      warnings.add(
        '$importedShapes Word shape${importedShapes == 1 ? '' : 's'} preserved as structured shape objects with geometry, styling, placement, wrap and z-order metadata.',
      );
    }
    if (importedAdvancedObjects > 0) {
      warnings.add(
        '$importedAdvancedObjects advanced Word inline object${importedAdvancedObjects == 1 ? '' : 's'} preserved structurally for WM7/WM8 editing and round-trip.',
      );
    }
    if (!preservation.isEmpty) {
      warnings.add(
        '${preservation.packageParts.length} unsupported Word package part${preservation.packageParts.length == 1 ? '' : 's'} and related compatibility metadata were retained for WM9 preserve-only round-trip.',
      );
    }
    if (source.sections.length > 1) {
      warnings.add(
        '${source.sections.length} Word sections were preserved as independent section profiles (page geometry, columns, section-start semantics, numbering and first/even/default header-footer stories). The editable canvas displays the primary section profile while DOCX export retains the section map.',
      );
    }

    final firstSection = source.sections.firstOrNull;
    final layout = firstSection == null
        ? const SmartDocumentPageLayout()
        : _pageLayout(firstSection.page);
    final header = firstSection == null
        ? const SmartDocumentHeaderFooter()
        : _headerFooter(firstSection.headerBlocks);
    final footer = firstSection == null
        ? const SmartDocumentHeaderFooter()
        : _headerFooter(firstSection.footerBlocks);
    final wordSections = source.sections
        .map(_wordSectionProfile)
        .toList(growable: false);
    final now = DateTime.now().toUtc();
    return SmartDocument(
      id: SmartDocument.blank().id,
      title: title.trim().isEmpty ? 'Imported Word Document' : title.trim(),
      deltaJson: List<dynamic>.from(operations),
      pageLayout: layout,
      header: header,
      footer: footer,
      wordSections: wordSections,
      wordEvenAndOddHeaders: source.evenAndOddHeaders,
      wordMirrorMargins: source.mirrorMargins,
      wordGutterAtTop: source.gutterAtTop,
      wordBackgroundColorHex: source.backgroundColorHex,
      wordPreservation: preservation,
      createdAt: now,
      updatedAt: now,
    );
  }

  static Map<String, dynamic> _textAttributes(ConversionTextRun run) {
    final style = run.style;
    final result = <String, dynamic>{};
    if (style.bold) result['bold'] = true;
    if (style.italic) result['italic'] = true;
    if (style.underline) result['underline'] = true;
    if (style.strike) result['strike'] = true;
    if (style.fontFamily?.trim().isNotEmpty == true) {
      result['font'] = style.fontFamily!.trim();
    }
    if ((style.fontSizePoints - 11).abs() > 0.2) {
      result['size'] = style.fontSizePoints * _wordPointToLogical;
    }
    if (style.colorHex != null) result['color'] = '#${style.colorHex}';
    if (style.highlightHex != null) {
      result['background'] = '#${style.highlightHex}';
    }
    if (run.hyperlink?.trim().isNotEmpty == true) {
      result['link'] = run.hyperlink!.trim();
    }
    return result;
  }

  static Map<String, dynamic> _textAttributesFromStyle(
    ConversionTextStyle style,
  ) {
    final result = <String, dynamic>{};
    if (style.bold) result['bold'] = true;
    if (style.italic) result['italic'] = true;
    if (style.underline) result['underline'] = true;
    if (style.strike) result['strike'] = true;
    if (style.fontFamily?.trim().isNotEmpty == true) {
      result['font'] = style.fontFamily!.trim();
    }
    if ((style.fontSizePoints - 11).abs() > 0.2) {
      result['size'] = style.fontSizePoints * _wordPointToLogical;
    }
    if (style.colorHex != null) result['color'] = '#${style.colorHex}';
    if (style.highlightHex != null) {
      result['background'] = '#${style.highlightHex}';
    }
    return result;
  }

  static Map<String, dynamic> _paragraphAttributes(ConversionParagraph paragraph) {
    final result = <String, dynamic>{};
    final align = switch (paragraph.alignment) {
      ConversionTextAlignment.left => null,
      ConversionTextAlignment.center => 'center',
      ConversionTextAlignment.right => 'right',
      ConversionTextAlignment.justify => 'justify',
    };
    if (align != null) result['align'] = align;
    if (paragraph.leftIndentPoints >= 18) {
      result['indent'] = (paragraph.leftIndentPoints / 36).round().clamp(1, 8);
    }
    final maxSize = paragraph.inlines
        .whereType<ConversionTextRun>()
        .map((run) => run.style.fontSizePoints)
        .fold<double>(0, math.max);
    final hasBold = paragraph.inlines
        .whereType<ConversionTextRun>()
        .any((run) => run.style.bold);
    if (paragraph.keepWithNext && hasBold && maxSize >= 15) {
      result['header'] = maxSize >= 18 ? 1 : 2;
    }
    return result;
  }

  static String? _listType(String? label) {
    final value = label?.trim();
    if (value == null || value.isEmpty) return null;
    if (RegExp(r'^\d+[.)]$').hasMatch(value) ||
        RegExp(r'^[A-Za-z][.)]$').hasMatch(value)) {
      return 'ordered';
    }
    if (RegExp(r'^[•●○▪◦\-–—]$').hasMatch(value)) return 'bullet';
    return null;
  }

  static SmartEditorInteropTablePayload _tablePayload(
    ConversionTable table, {
    String? objectId,
  }) {
    return SmartEditorInteropTablePayload(
      showBorders: table.showBorders,
      styleId: table.styleId,
      shadingHex: table.shadingHex,
      borders: _borderPayload(table.borders),
      layout: table.layout == ConversionTableLayout.fixed ? 'fixed' : 'autoFit',
      objectId: objectId,
      widthPoints: table.widthPoints == null
          ? null
          : table.widthPoints! * _wordPointToLogical,
      widthPercent: table.widthPercent,
      indentPoints: table.indentPoints * _wordPointToLogical,
      cellSpacingPoints: table.cellSpacingPoints * _wordPointToLogical,
      gridColumnWidths: table.gridColumnWidths
          .map((width) => width * _wordPointToLogical)
          .toList(growable: false),
      alignment: _alignmentName(table.alignment),
      rows: table.rows
          .map(
            (row) => SmartEditorInteropTableRow(
              header: row.isHeader,
              cantSplit: row.cantSplit,
              heightPoints: row.heightPoints == null
                  ? null
                  : row.heightPoints! * _wordPointToLogical,
              heightRule: _rowHeightRuleName(row.heightRule),
              cells: row.cells
                  .map(
                    (cell) => SmartEditorInteropTableCell(
                      text: _plainText(cell.blocks),
                      shadingHex: cell.shadingHex,
                      borders: _borderPayload(cell.borders),
                      widthPoints: cell.widthPoints == null
                          ? null
                          : cell.widthPoints! * _wordPointToLogical,
                      widthPercent: cell.widthPercent,
                      gridSpan: cell.gridSpan,
                      paddingTopPoints:
                          cell.paddingTopPoints * _wordPointToLogical,
                      paddingRightPoints:
                          cell.paddingRightPoints * _wordPointToLogical,
                      paddingBottomPoints:
                          cell.paddingBottomPoints * _wordPointToLogical,
                      paddingLeftPoints:
                          cell.paddingLeftPoints * _wordPointToLogical,
                      verticalAlignment:
                          _cellVerticalAlignmentName(cell.verticalAlignment),
                      verticalMerge: _verticalMergeName(cell.verticalMerge),
                      noWrap: cell.noWrap,
                      blocks: _cellBlocks(cell.blocks),
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  static List<SmartEditorInteropCellBlock> _cellBlocks(
    List<ConversionBlock> blocks,
  ) {
    final result = <SmartEditorInteropCellBlock>[];
    for (final block in blocks) {
      if (block is ConversionParagraph) {
        final paragraphRuns = <SmartEditorInteropTextRun>[];
        if (block.listLabel?.isNotEmpty == true) {
          paragraphRuns.add(
            SmartEditorInteropTextRun(text: block.listLabel!),
          );
        }
        void flushParagraphRuns() {
          if (paragraphRuns.isEmpty) return;
          result.add(
            SmartEditorInteropCellBlock.paragraph(
              runs: List<SmartEditorInteropTextRun>.from(paragraphRuns),
              alignment: _alignmentName(block.alignment),
              spaceBeforePoints:
                  block.spaceBeforePoints * _wordPointToLogical,
              spaceAfterPoints:
                  block.spaceAfterPoints * _wordPointToLogical,
              lineSpacingMultiple: block.lineSpacingMultiple,
              exactLineSpacingPoints: block.exactLineSpacingPoints == null
                  ? null
                  : block.exactLineSpacingPoints! * _wordPointToLogical,
            ),
          );
          paragraphRuns.clear();
        }

        for (final inline in block.inlines) {
          if (inline is ConversionTextRun) {
            final style = inline.style;
            paragraphRuns.add(
              SmartEditorInteropTextRun(
                text: inline.text,
                bold: style.bold,
                italic: style.italic,
                underline: style.underline,
                underlineStyle: switch (style.underlineStyle) {
                  ConversionUnderlineStyle.doubleLine => 'double',
                  ConversionUnderlineStyle.dotted => 'dotted',
                  ConversionUnderlineStyle.dashed => 'dashed',
                  ConversionUnderlineStyle.wavy => 'wavy',
                  _ => 'single',
                },
                strike: style.strike,
                doubleStrike: style.doubleStrike,
                allCaps: style.allCaps,
                smallCaps: style.smallCaps,
                letterSpacingPoints:
                    style.letterSpacingPoints * _wordPointToLogical,
                fontFamily: style.fontFamily,
                fontSizePoints:
                    style.fontSizePoints * _wordPointToLogical,
                colorHex: style.colorHex,
                backgroundHex: style.highlightHex,
                hyperlink: inline.hyperlink,
              ),
            );
          } else if (inline is ConversionDynamicFieldRun) {
            paragraphRuns.add(
              SmartEditorInteropTextRun(
                text: inline.field == ConversionDynamicField.pageNumber
                    ? '{PAGE}'
                    : '{NUMPAGES}',
              ),
            );
          } else if (inline is ConversionOpaqueOoxmlRun) {
            flushParagraphRuns();
            result.add(
              SmartEditorInteropCellBlock.opaqueOoxml(
                rawOoxml: '<w:p><w:r>${inline.rawXml}</w:r></w:p>',
                featureKind: inline.featureKind,
                fallbackText: inline.fallbackText,
                relationshipIds: inline.relationshipIds,
              ),
            );
          } else if (inline is ConversionTextBoxRun) {
            flushParagraphRuns();
            result.add(
              SmartEditorInteropCellBlock.table(
                SmartEditorInteropTablePayload(
                  showBorders: false,
                  sourceKind: 'textBox',
                  widthPoints: inline.widthPoints == null
                      ? null
                      : inline.widthPoints! * _wordPointToLogical,
                  heightPoints: inline.heightPoints == null
                      ? null
                      : inline.heightPoints! * _wordPointToLogical,
                  placement: _placementPayload(inline.placement),
                  rows: <SmartEditorInteropTableRow>[
                    SmartEditorInteropTableRow(
                      cells: <SmartEditorInteropTableCell>[
                        SmartEditorInteropTableCell(
                          text: _plainText(inline.blocks),
                          widthPoints: inline.widthPoints == null
                              ? null
                              : inline.widthPoints! * _wordPointToLogical,
                          paddingTopPoints:
                              inline.paddingTopPoints * _wordPointToLogical,
                          paddingRightPoints:
                              inline.paddingRightPoints * _wordPointToLogical,
                          paddingBottomPoints:
                              inline.paddingBottomPoints * _wordPointToLogical,
                          paddingLeftPoints:
                              inline.paddingLeftPoints * _wordPointToLogical,
                          blocks: _cellBlocks(inline.blocks),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          } else if (inline is ConversionShapeRun) {
            flushParagraphRuns();
            result.add(
              SmartEditorInteropCellBlock.shape(_shapePayload(inline)),
            );
          } else if (inline is ConversionImageRun) {
            // Keep the image in its original table cell instead of degrading
            // it to the old `[image]` placeholder. Text before/after the image
            // remains in separate paragraph blocks, preserving reading order.
            flushParagraphRuns();
            result.add(
              SmartEditorInteropCellBlock.image(
                SmartEditorInteropImagePayload(
                  bytes: Uint8List.fromList(inline.bytes),
                  widthPoints:
                      inline.widthPoints * _wordPointToLogical,
                  heightPoints:
                      inline.heightPoints * _wordPointToLogical,
                  altText: inline.altText,
                  hyperlink: inline.hyperlink,
                  placement: _placementPayload(inline.placement),
                  cropLeft: inline.crop.left,
                  cropTop: inline.crop.top,
                  cropRight: inline.crop.right,
                  cropBottom: inline.crop.bottom,
                  rotationDegrees: inline.rotationDegrees,
                  flipHorizontal: inline.flipHorizontal,
                  flipVertical: inline.flipVertical,
                ),
              ),
            );
          }
        }
        flushParagraphRuns();
        if (block.inlines.isEmpty && block.listLabel == null) {
          result.add(
            SmartEditorInteropCellBlock.paragraph(
              runs: const <SmartEditorInteropTextRun>[],
              alignment: _alignmentName(block.alignment),
              spaceBeforePoints:
                  block.spaceBeforePoints * _wordPointToLogical,
              spaceAfterPoints:
                  block.spaceAfterPoints * _wordPointToLogical,
              lineSpacingMultiple: block.lineSpacingMultiple,
              exactLineSpacingPoints: block.exactLineSpacingPoints == null
                  ? null
                  : block.exactLineSpacingPoints! * _wordPointToLogical,
            ),
          );
        }
      } else if (block is ConversionTable) {
        result.add(SmartEditorInteropCellBlock.table(_tablePayload(block)));
      } else if (block is ConversionOpaqueOoxmlBlock) {
        result.add(
          SmartEditorInteropCellBlock.opaqueOoxml(
            rawOoxml: block.rawXml,
            featureKind: block.featureKind,
            fallbackText: _plainText(block.fallbackBlocks),
            relationshipIds: block.relationshipIds,
          ),
        );
      }
    }
    return List<SmartEditorInteropCellBlock>.unmodifiable(result);
  }

  static SmartEditorInteropShapePayload _shapePayload(
    ConversionShapeRun shape, {
    String? objectId,
  }) {
    return SmartEditorInteropShapePayload(
      kind: switch (shape.kind) {
        ConversionShapeKind.rectangle => 'rectangle',
        ConversionShapeKind.roundedRectangle => 'roundedRectangle',
        ConversionShapeKind.ellipse => 'ellipse',
        ConversionShapeKind.line => 'line',
        ConversionShapeKind.textPath => 'textPath',
        ConversionShapeKind.unknown => 'unknown',
      },
      widthPoints: shape.widthPoints * _wordPointToLogical,
      heightPoints: shape.heightPoints * _wordPointToLogical,
      objectId: objectId,
      text: _plainText(shape.blocks),
      blocks: _cellBlocks(shape.blocks),
      altText: shape.altText,
      fillColorHex: shape.style.fillColorHex,
      strokeColorHex: shape.style.strokeColorHex,
      strokeWidthPoints: shape.style.strokeWidthPoints * _wordPointToLogical,
      dashStyle: shape.style.dashStyle,
      rotationDegrees: shape.style.rotationDegrees,
      flipHorizontal: shape.style.flipHorizontal,
      flipVertical: shape.style.flipVertical,
      placement: _placementPayload(shape.placement),
    );
  }

  static SmartEditorInteropObjectPlacement _placementPayload(
    ConversionObjectPlacement placement,
  ) {
    return SmartEditorInteropObjectPlacement(
      floating: placement.floating,
      horizontalRelativeFrom: placement.horizontalRelativeFrom,
      verticalRelativeFrom: placement.verticalRelativeFrom,
      horizontalOffsetPoints: placement.horizontalOffsetPoints == null
          ? null
          : placement.horizontalOffsetPoints! * _wordPointToLogical,
      verticalOffsetPoints: placement.verticalOffsetPoints == null
          ? null
          : placement.verticalOffsetPoints! * _wordPointToLogical,
      horizontalAlignment: placement.horizontalAlignment,
      verticalAlignment: placement.verticalAlignment,
      behindText: placement.behindText,
      allowOverlap: placement.allowOverlap,
      wrapStyle: placement.wrapStyle,
      wrapText: placement.wrapText,
      distanceTopPoints: placement.distanceTopPoints * _wordPointToLogical,
      distanceBottomPoints: placement.distanceBottomPoints * _wordPointToLogical,
      distanceLeftPoints: placement.distanceLeftPoints * _wordPointToLogical,
      distanceRightPoints: placement.distanceRightPoints * _wordPointToLogical,
      relativeHeight: placement.relativeHeight,
      layoutInCell: placement.layoutInCell,
      locked: placement.locked,
    );
  }

  static Map<String, dynamic> _borderPayload(ConversionBorders borders) {
    Map<String, dynamic>? side(ConversionBorderSide? value) {
      if (value == null || !value.isVisible) return null;
      return <String, dynamic>{
        'style': switch (value.style) {
          ConversionBorderStyle.doubleLine => 'double',
          ConversionBorderStyle.dotted => 'dotted',
          ConversionBorderStyle.dashed => 'dashed',
          ConversionBorderStyle.dashDot => 'dashDot',
          ConversionBorderStyle.dashDotDot => 'dashDotDot',
          ConversionBorderStyle.thick => 'thick',
          ConversionBorderStyle.wave => 'wave',
          ConversionBorderStyle.none => 'none',
          ConversionBorderStyle.single => 'single',
        },
        'widthPoints': value.widthPoints * _wordPointToLogical,
        if (value.colorHex != null) 'colorHex': value.colorHex,
        if (value.spacePoints != 0)
          'spacePoints': value.spacePoints * _wordPointToLogical,
      };
    }

    final result = <String, dynamic>{};
    void add(String key, ConversionBorderSide? value) {
      final encoded = side(value);
      if (encoded != null) result[key] = encoded;
    }

    add('top', borders.top);
    add('right', borders.right);
    add('bottom', borders.bottom);
    add('left', borders.left);
    add('insideH', borders.insideHorizontal);
    add('insideV', borders.insideVertical);
    add('between', borders.between);
    add('bar', borders.bar);
    return result;
  }

  static String _rowHeightRuleName(ConversionTableRowHeightRule value) =>
      switch (value) {
        ConversionTableRowHeightRule.atLeast => 'atLeast',
        ConversionTableRowHeightRule.exact => 'exact',
        ConversionTableRowHeightRule.auto => 'auto',
      };

  static String _cellVerticalAlignmentName(
    ConversionTableCellVerticalAlignment value,
  ) =>
      switch (value) {
        ConversionTableCellVerticalAlignment.center => 'center',
        ConversionTableCellVerticalAlignment.bottom => 'bottom',
        ConversionTableCellVerticalAlignment.top => 'top',
      };

  static String _verticalMergeName(ConversionVerticalMerge value) =>
      switch (value) {
        ConversionVerticalMerge.restart => 'restart',
        ConversionVerticalMerge.continuation => 'continuation',
        ConversionVerticalMerge.none => 'none',
      };

  static String _alignmentName(ConversionTextAlignment alignment) =>
      switch (alignment) {
        ConversionTextAlignment.center => 'center',
        ConversionTextAlignment.right => 'right',
        ConversionTextAlignment.justify => 'justify',
        ConversionTextAlignment.left => 'left',
      };

  static int _imageCountInBlocks(List<ConversionBlock> blocks) {
    var count = 0;
    for (final block in blocks) {
      if (block is ConversionParagraph) {
        count += block.inlines.whereType<ConversionImageRun>().length;
        for (final inline in block.inlines.whereType<ConversionTextBoxRun>()) {
          count += _imageCountInBlocks(inline.blocks);
        }
      } else if (block is ConversionOpaqueOoxmlBlock) {
        count += _imageCountInBlocks(block.fallbackBlocks);
      } else if (block is ConversionTable) {
        for (final row in block.rows) {
          for (final cell in row.cells) {
            count += _imageCountInBlocks(cell.blocks);
          }
        }
      }
    }
    return count;
  }

  static String _plainText(List<ConversionBlock> blocks) {
    final lines = <String>[];
    for (final block in blocks) {
      if (block is ConversionParagraph) {
        final buffer = StringBuffer(block.listLabel ?? '');
        for (final inline in block.inlines) {
          if (inline is ConversionTextRun) {
            buffer.write(inline.text);
          } else if (inline is ConversionDynamicFieldRun) {
            buffer.write(
              inline.field == ConversionDynamicField.pageNumber
                  ? '{PAGE}'
                  : '{NUMPAGES}',
            );
          } else if (inline is ConversionFieldRun) {
            buffer.write(
              inline.resultText.isNotEmpty
                  ? inline.resultText
                  : '{${inline.fieldName.isEmpty ? 'FIELD' : inline.fieldName}}',
            );
          } else if (inline is ConversionMathRun) {
            buffer.write(inline.plainText);
          } else if (inline is ConversionNoteReferenceRun) {
            buffer.write(inline.displayLabel ?? inline.noteId);
          } else if (inline is ConversionCommentMarkerRun &&
              inline.kind == ConversionWordMarkerKind.reference) {
            // The visible comment reference is represented by the annotation
            // marker; comment text itself is stored in the comments story.
          } else if (inline is ConversionOpaqueOoxmlRun) {
            buffer.write(inline.fallbackText);
          } else if (inline is ConversionTextBoxRun) {
            buffer.write(_plainText(inline.blocks));
          } else if (inline is ConversionShapeRun) {
            final nested = _plainText(inline.blocks);
            if (nested.isNotEmpty) {
              buffer.write(nested);
            } else if (inline.altText?.trim().isNotEmpty == true) {
              buffer.write(inline.altText!.trim());
            }
          } else if (inline is ConversionImageRun) {
            // Text-only projections (header/footer/search metadata) should not
            // leak implementation placeholders into the visible document.
            final alt = inline.altText?.trim();
            if (alt != null && alt.isNotEmpty) buffer.write(alt);
          }
        }
        lines.add(buffer.toString());
      } else if (block is ConversionOpaqueOoxmlBlock) {
        lines.add(_plainText(block.fallbackBlocks));
      } else if (block is ConversionTable) {
        for (final row in block.rows) {
          lines.add(row.cells.map((cell) => _plainText(cell.blocks)).join('\t'));
        }
      }
    }
    return lines.join('\n').trimRight();
  }

  static SmartDocumentWordSectionProfile _wordSectionProfile(
    ConversionSection section,
  ) {
    SmartDocumentWordBorderSide? border(ConversionBorderSide? side) {
      if (side == null || !side.isVisible) return null;
      return SmartDocumentWordBorderSide(
        style: switch (side.style) {
          ConversionBorderStyle.none => 'none',
          ConversionBorderStyle.single => 'single',
          ConversionBorderStyle.doubleLine => 'double',
          ConversionBorderStyle.dotted => 'dotted',
          ConversionBorderStyle.dashed => 'dashed',
          ConversionBorderStyle.dashDot => 'dashDot',
          ConversionBorderStyle.dashDotDot => 'dashDotStroked',
          ConversionBorderStyle.thick => 'thick',
          ConversionBorderStyle.wave => 'wave',
        },
        widthPoints: side.widthPoints,
        colorHex: side.colorHex,
        spacePoints: side.spacePoints,
      );
    }

    final pageBorders = section.page.pageBorders;
    return SmartDocumentWordSectionProfile(
      pageLayout: _pageLayout(section.page),
      breakType: switch (section.breakType) {
        ConversionSectionBreakType.nextPage => 'nextPage',
        ConversionSectionBreakType.continuous => 'continuous',
        ConversionSectionBreakType.evenPage => 'evenPage',
        ConversionSectionBreakType.oddPage => 'oddPage',
        ConversionSectionBreakType.nextColumn => 'nextColumn',
      },
      titlePage: section.titlePage,
      columns: SmartDocumentWordColumns(
        count: section.columns.count,
        equalWidth: section.columns.equalWidth,
        spacingPoints: section.columns.spacingPoints,
        separator: section.columns.separator,
        columns: section.columns.columns
            .map(
              (column) => SmartDocumentWordColumn(
                widthPoints: column.widthPoints,
                spacingPoints: column.spacingPoints,
              ),
            )
            .toList(growable: false),
      ),
      gutterPoints: section.page.gutterPoints,
      pageBorders: SmartDocumentWordPageBorders(
        top: border(pageBorders.borders.top),
        right: border(pageBorders.borders.right),
        bottom: border(pageBorders.borders.bottom),
        left: border(pageBorders.borders.left),
        offsetFrom: pageBorders.offsetFrom,
        display: pageBorders.display,
        zOrder: pageBorders.zOrder,
      ),
      pageNumberStart: section.pageNumberStart,
      pageNumberFormat: section.pageNumberFormat,
      header: _headerFooter(section.headerBlocks),
      footer: _headerFooter(section.footerBlocks),
      firstHeader: _headerFooter(section.firstPageHeaderBlocks),
      firstFooter: _headerFooter(section.firstPageFooterBlocks),
      evenHeader: _headerFooter(section.evenPageHeaderBlocks),
      evenFooter: _headerFooter(section.evenPageFooterBlocks),
    );
  }

  static SmartDocumentPageLayout _pageLayout(ConversionPageSettings page) {
    final landscape = page.widthPoints > page.heightPoints;
    final shortSide = math.min(page.widthPoints, page.heightPoints);
    final longSide = math.max(page.widthPoints, page.heightPoints);
    final letterDistance = (shortSide - 612).abs() + (longSide - 792).abs();
    final a4Distance = (shortSide - 595.3).abs() + (longSide - 841.9).abs();
    final margins = <double>[
      page.marginTopPoints * _wordPointToLogical,
      page.marginRightPoints * _wordPointToLogical,
      page.marginBottomPoints * _wordPointToLogical,
      page.marginLeftPoints * _wordPointToLogical,
    ];
    SmartDocumentMarginPreset preset;
    if (margins.every((value) => (value - 48).abs() <= 2)) {
      preset = SmartDocumentMarginPreset.narrow;
    } else if (margins.every((value) => (value - 96).abs() <= 2)) {
      preset = SmartDocumentMarginPreset.normal;
    } else if (margins.every((value) => (value - 144).abs() <= 2)) {
      preset = SmartDocumentMarginPreset.wide;
    } else {
      preset = SmartDocumentMarginPreset.custom;
    }
    return SmartDocumentPageLayout(
      pageSize: letterDistance < a4Distance
          ? SmartDocumentPageSize.letter
          : SmartDocumentPageSize.a4,
      orientation: landscape
          ? SmartDocumentOrientation.landscape
          : SmartDocumentOrientation.portrait,
      marginPreset: preset,
      borderStyle: SmartDocumentPageBorderStyle.none,
      customTopMargin: margins[0],
      customRightMargin: margins[1],
      customBottomMargin: margins[2],
      customLeftMargin: margins[3],
      wordPageWidthPoints: page.widthPoints,
      wordPageHeightPoints: page.heightPoints,
      wordMarginTopPoints: page.marginTopPoints,
      wordMarginRightPoints: page.marginRightPoints,
      wordMarginBottomPoints: page.marginBottomPoints,
      wordMarginLeftPoints: page.marginLeftPoints,
      wordHeaderDistancePoints: page.headerDistancePoints,
      wordFooterDistancePoints: page.footerDistancePoints,
    );
  }

  static SmartDocumentHeaderFooter _headerFooter(List<ConversionBlock> blocks) {
    final text = _plainText(blocks);
    return SmartDocumentHeaderFooter(
      enabled: text.trim().isNotEmpty,
      text: text,
      alignment: SmartDocumentHeaderFooterAlignment.center,
    );
  }

  String _documentXml(
    SmartDocument document,
    SmartEditorExportProjection projection,
    Map<String, _MediaPart> media,
    List<String> warnings, {
    required Map<String, String> hyperlinks,
    required List<_HeaderFooterPart> storyParts,
    required _AdvancedWordParts advancedParts,
    required SmartDocumentWordPreservationState preservation,
  }) {
    final body = StringBuffer();
    final drawingIds = _DrawingIdCounter();
    var sectionIndex = 0;
    for (var index = 0; index < projection.blocks.length; index++) {
      final block = projection.blocks[index];
      switch (block) {
        case SmartEditorExportParagraph():
          body.write(
            _paragraphXml(block, warnings, hyperlinks, advancedParts),
          );
        case SmartEditorExportWordOpaqueBlock():
          final raw = block.payload.rawXml?.trim() ?? '';
          body.write(
            raw.isEmpty
                ? _plainParagraphXml(
                    '[Word ${block.payload.featureKind ?? 'object'} preserved]',
                  )
                : raw,
          );
        case SmartEditorExportBreak():
          if (block.type == 'section') {
            final sectionProperties = _sectionProperties(
              document,
              sectionIndex: sectionIndex,
              storyParts: storyParts,
            );
            body.write('<w:p><w:pPr>$sectionProperties</w:pPr></w:p>');
            sectionIndex++;
          } else if (block.type == 'column') {
            body.write('<w:p><w:r><w:br w:type="column"/></w:r></w:p>');
          } else {
            body.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
          }
        case SmartEditorExportImage():
          final part = media['block:$index'];
          body.write(
            part == null
                ? _plainParagraphXml('[Unsupported image]')
                : _drawingParagraphXml(
                    part,
                    drawingIds.take(),
                    hyperlinks: hyperlinks,
                  ),
          );
        case SmartEditorExportGeometry():
          final part = media['block:$index'];
          if (part == null) {
            body.write(_plainParagraphXml('[Geometry diagram]'));
          } else {
            final alignment = block.layout.effectiveAlignmentX < -0.35
                ? 'left'
                : block.layout.effectiveAlignmentX > 0.35
                    ? 'right'
                    : 'center';
            body.write(
              _drawingParagraphXml(
                part,
                drawingIds.take(),
                alignment: alignment,
                hyperlinks: hyperlinks,
              ),
            );
          }
        case SmartEditorExportShape():
          body.write(
            _shapeParagraphXml(
              block.payload,
              drawingIds.take(),
            ),
          );
        case SmartEditorExportTable():
          body.write(
            _tableXml(
              block.payload,
              media: media,
              prefix: 'block:$index',
              drawingIds: drawingIds,
              hyperlinks: hyperlinks,
            ),
          );
      }
    }

    final section = _sectionProperties(
      document,
      sectionIndex: sectionIndex,
      storyParts: storyParts,
    );
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document '
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" '
        'xmlns:v="urn:schemas-microsoft-com:vml" '
        'xmlns:o="urn:schemas-microsoft-com:office:office" '
        'xmlns:w10="urn:schemas-microsoft-com:office:word" '
        '${_preservedNamespaceXml(preservation)}>'
        '${_documentBackgroundXml(document.wordBackgroundColorHex)}'
        '<w:body>${body.toString()}$section</w:body></w:document>';
  }

  String _paragraphXml(
    SmartEditorExportParagraph paragraph,
    List<String> warnings,
    Map<String, String> hyperlinks,
    _AdvancedWordParts advancedParts,
  ) {
    final pPr = StringBuffer('<w:pPr>');
    final attributes = paragraph.attributes;
    final header = _intValue(attributes['header']);
    if (header != null && header >= 1 && header <= 3) {
      pPr.write('<w:pStyle w:val="Heading$header"/>');
    }
    final align = attributes['align']?.toString();
    if (align != null && align != 'left') {
      pPr.write('<w:jc w:val="${align == 'justify' ? 'both' : _xml(align)}"/>');
    }
    final indent = _intValue(attributes['indent']);
    if (indent != null && indent > 0) {
      pPr.write('<w:ind w:left="${indent * 720}"/>');
    }
    final list = attributes['list']?.toString();
    if (list == 'ordered' || list == 'bullet') {
      pPr.write(
        '<w:numPr><w:ilvl w:val="${math.max(0, (indent ?? 1) - 1)}"/>'
        '<w:numId w:val="${list == 'ordered' ? 1 : 2}"/></w:numPr>',
      );
    }
    final lineHeight = double.tryParse(attributes['line-height']?.toString() ?? '');
    if (lineHeight != null && lineHeight > 0) {
      pPr.write('<w:spacing w:line="${(240 * lineHeight).round()}" w:lineRule="auto"/>');
    }
    pPr.write('</w:pPr>');

    final content = StringBuffer();
    for (final inline in paragraph.inlines) {
      if (inline is SmartEditorExportText) {
        final link = inline.attributes['link']?.toString().trim();
        final internalAnchor =
            link != null && link.startsWith('#') ? link.substring(1) : null;
        content.write(
          _runXml(
            inline.text,
            inline.attributes,
            hyperlinkRelationshipId: link == null ||
                    link.isEmpty ||
                    internalAnchor != null
                ? null
                : hyperlinks[link],
            hyperlinkAnchor: internalAnchor,
          ),
        );
      } else if (inline is SmartEditorExportMath) {
        final mathXml = _omml.inlineSource(inline.expression.latex);
        if (mathXml == null) {
          warnings.add(
            'One equation used unsupported Word math syntax and was exported as readable text.',
          );
          content.write(_runXml(inline.plainText, const <String, dynamic>{}));
        } else {
          content.write(mathXml);
        }
      } else if (inline is SmartEditorExportWordAdvanced) {
        content.write(
          _advancedWordInlineXml(inline.payload, advancedParts),
        );
      }
    }
    if (content.isEmpty) content.write('<w:r><w:t/></w:r>');
    return '<w:p>${pPr.toString()}${content.toString()}</w:p>';
  }

  static String _runXml(
    String text,
    Map<String, dynamic> attributes, {
    String? hyperlinkRelationshipId,
    String? hyperlinkAnchor,
  }) {
    if (text.isEmpty) return '';
    final rPr = StringBuffer('<w:rPr>');
    if (hyperlinkRelationshipId != null || hyperlinkAnchor != null) {
      rPr.write('<w:rStyle w:val="Hyperlink"/>');
    }
    if (attributes['bold'] == true) rPr.write('<w:b/><w:bCs/>');
    if (attributes['italic'] == true) rPr.write('<w:i/><w:iCs/>');
    if (attributes['underline'] == true) {
      final underlineValue = switch (attributes['underlineStyle']?.toString()) {
        'double' => 'double',
        'dotted' => 'dotted',
        'dashed' => 'dash',
        'wavy' => 'wave',
        _ => 'single',
      };
      rPr.write('<w:u w:val="$underlineValue"/>');
    }
    if (attributes['strike'] == true) rPr.write('<w:strike/>');
    if (attributes['doubleStrike'] == true) rPr.write('<w:dstrike/>');
    if (attributes['allCaps'] == true) rPr.write('<w:caps/>');
    if (attributes['smallCaps'] == true) rPr.write('<w:smallCaps/>');
    final letterSpacing =
        double.tryParse(attributes['letterSpacing']?.toString() ?? '');
    if (letterSpacing != null && letterSpacing.abs() > 0.0001) {
      rPr.write(
        '<w:spacing w:val="${_twipsFromLogical(letterSpacing)}"/>',
      );
    }
    final font = attributes['font']?.toString().trim();
    if (font != null && font.isNotEmpty) {
      rPr.write('<w:rFonts w:ascii="${_xml(font)}" w:hAnsi="${_xml(font)}" w:cs="${_xml(font)}"/>');
    }
    final size = double.tryParse(attributes['size']?.toString() ?? '');
    if (size != null && size > 0) {
      final halfPoints = (size * _logicalToWordPoint * 2)
          .round()
          .clamp(2, 400);
      rPr.write('<w:sz w:val="$halfPoints"/><w:szCs w:val="$halfPoints"/>');
    }
    final color = _hex(attributes['color']);
    if (color != null) rPr.write('<w:color w:val="$color"/>');
    final background = _hex(attributes['background']);
    if (background != null) rPr.write('<w:shd w:val="clear" w:fill="$background"/>');
    rPr.write('</w:rPr>');
    final runProperties = rPr.toString();
    String textRun(String value) =>
        '<w:r>$runProperties<w:t xml:space="preserve">${_xml(value)}</w:t></w:r>';

    final fieldPattern = RegExp(r'\{(PAGE|NUMPAGES)\}');
    final matches = fieldPattern.allMatches(text).toList(growable: false);
    String content;
    if (matches.isEmpty) {
      content = textRun(text);
    } else {
      final buffer = StringBuffer();
      var start = 0;
      for (final match in matches) {
        if (match.start > start) {
          buffer.write(textRun(text.substring(start, match.start)));
        }
        final field = match.group(1) ?? 'PAGE';
        buffer.write(
          '<w:fldSimple w:instr=" $field ">'
          '<w:r>$runProperties<w:t>1</w:t></w:r>'
          '</w:fldSimple>',
        );
        start = match.end;
      }
      if (start < text.length) buffer.write(textRun(text.substring(start)));
      content = buffer.toString();
    }
    if (hyperlinkRelationshipId != null) {
      return '<w:hyperlink r:id="${_xml(hyperlinkRelationshipId)}" w:history="1">$content</w:hyperlink>';
    }
    if (hyperlinkAnchor != null && hyperlinkAnchor.trim().isNotEmpty) {
      return '<w:hyperlink w:anchor="${_xml(hyperlinkAnchor.trim())}" w:history="1">$content</w:hyperlink>';
    }
    return content;
  }

  static String _documentBackgroundXml(String? colorHex) {
    final color = _hex(colorHex);
    return color == null ? '' : '<w:background w:color="$color"/>';
  }

  static String _advancedWordInlineXml(
    SmartEditorWordAdvancedPayload payload,
    _AdvancedWordParts parts,
  ) {
    switch (payload.kind) {
      case SmartEditorWordAdvancedPayload.fieldKind:
        final instruction = payload.instruction?.trim() ?? '';
        if (instruction.isEmpty) {
          return _runXml(
            payload.resultText,
            const <String, dynamic>{},
          );
        }
        final flags = '${payload.locked ? ' w:fldLock="true"' : ''}'
            '${payload.dirty ? ' w:dirty="true"' : ''}';
        final result = payload.resultText.isEmpty ? ' ' : payload.resultText;
        return '<w:fldSimple w:instr="${_xml(' $instruction ')}"$flags>'
            '<w:r><w:t xml:space="preserve">${_xml(result)}</w:t></w:r>'
            '</w:fldSimple>';
      case SmartEditorWordAdvancedPayload.equationKind:
        final raw = payload.rawXml?.trim();
        if (raw != null &&
            (raw.startsWith('<m:oMath') || raw.startsWith('<m:oMathPara'))) {
          return raw;
        }
        return _runXml(
          payload.resultText.isEmpty ? '[Equation]' : payload.resultText,
          const <String, dynamic>{'font': 'Cambria Math'},
        );
      case SmartEditorWordAdvancedPayload.footnoteKind:
        final id = parts.footnoteId(payload.referenceId);
        return id == null
            ? ''
            : '<w:r><w:footnoteReference w:id="$id"/></w:r>';
      case SmartEditorWordAdvancedPayload.endnoteKind:
        final id = parts.endnoteId(payload.referenceId);
        return id == null
            ? ''
            : '<w:r><w:endnoteReference w:id="$id"/></w:r>';
      case SmartEditorWordAdvancedPayload.bookmarkStartKind:
        final id = parts.bookmarkId(payload.referenceId);
        final name = _bookmarkName(payload.name, id);
        return id == null
            ? ''
            : '<w:bookmarkStart w:id="$id" w:name="${_xml(name)}"/>';
      case SmartEditorWordAdvancedPayload.bookmarkEndKind:
        final id = parts.bookmarkId(payload.referenceId);
        return id == null ? '' : '<w:bookmarkEnd w:id="$id"/>';
      case SmartEditorWordAdvancedPayload.commentStartKind:
        final id = parts.commentId(payload.referenceId);
        return id == null ? '' : '<w:commentRangeStart w:id="$id"/>';
      case SmartEditorWordAdvancedPayload.commentEndKind:
        final id = parts.commentId(payload.referenceId);
        return id == null ? '' : '<w:commentRangeEnd w:id="$id"/>';
      case SmartEditorWordAdvancedPayload.commentReferenceKind:
        final id = parts.commentId(payload.referenceId);
        return id == null
            ? ''
            : '<w:r><w:rPr><w:rStyle w:val="CommentReference"/></w:rPr><w:commentReference w:id="$id"/></w:r>';
      case SmartEditorWordAdvancedPayload.opaqueOoxmlKind:
        final raw = payload.rawXml?.trim();
        return raw == null || raw.isEmpty
            ? _runXml(payload.visibleText, const <String, dynamic>{})
            : raw;
      default:
        return _runXml(payload.visibleText, const <String, dynamic>{});
    }
  }

  static String _bookmarkName(String? rawName, int? id) {
    var name = rawName?.trim() ?? '';
    if (name.isEmpty) name = 'EduSheetBookmark${id ?? 1}';
    name = name.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    if (name.isEmpty || RegExp(r'^[0-9]').hasMatch(name)) {
      name = 'B_$name';
    }
    return name;
  }

  static String _tableXml(
    SmartEditorInteropTablePayload table, {
    required Map<String, _MediaPart> media,
    required String prefix,
    required _DrawingIdCounter drawingIds,
    required Map<String, String> hyperlinks,
  }) {
    if (table.rows.isEmpty) return '';
    if (table.sourceKind == 'textBox') {
      return _textBoxXml(
        table,
        media: media,
        prefix: prefix,
        drawingIds: drawingIds,
        hyperlinks: hyperlinks,
      );
    }

    final tableStyle = table.styleId?.trim().isNotEmpty == true
        ? '<w:tblStyle w:val="${_xml(table.styleId!.trim())}"/>'
        : '';
    final modeledBorders = _wordBordersXml('tblBorders', table.borders);
    final border = modeledBorders.isNotEmpty
        ? modeledBorders
        : table.showBorders
            ? '<w:tblBorders>'
                '<w:top w:val="single" w:sz="4" w:color="B7B7B7"/>'
                '<w:left w:val="single" w:sz="4" w:color="B7B7B7"/>'
                '<w:bottom w:val="single" w:sz="4" w:color="B7B7B7"/>'
                '<w:right w:val="single" w:sz="4" w:color="B7B7B7"/>'
                '<w:insideH w:val="single" w:sz="4" w:color="D0D0D0"/>'
                '<w:insideV w:val="single" w:sz="4" w:color="D0D0D0"/>'
                '</w:tblBorders>'
            : '';
    final tableShading = _hex(table.shadingHex) == null
        ? ''
        : '<w:shd w:val="clear" w:fill="${_hex(table.shadingHex)}"/>';
    final tableLayout = table.layout == 'fixed'
        ? '<w:tblLayout w:type="fixed"/>'
        : '<w:tblLayout w:type="autofit"/>';
    final tableWidth = table.widthPercent != null
        ? '<w:tblW w:w="${(table.widthPercent!.clamp(1.0, 100.0) * 50).round()}" w:type="pct"/>'
        : table.widthPoints == null
            ? '<w:tblW w:w="0" w:type="auto"/>'
            : '<w:tblW w:w="${_twipsFromLogical(table.widthPoints!)}" w:type="dxa"/>';
    final tableAlignment = switch (table.alignment) {
      'center' => '<w:jc w:val="center"/>',
      'right' => '<w:jc w:val="right"/>',
      _ => '<w:jc w:val="left"/>',
    };
    final indent = table.indentPoints.abs() < 0.01
        ? ''
        : '<w:tblInd w:w="${_twipsFromLogical(table.indentPoints)}" w:type="dxa"/>';
    final cellSpacing = table.cellSpacingPoints <= 0
        ? ''
        : '<w:tblCellSpacing w:w="${_twipsFromLogical(table.cellSpacingPoints)}" w:type="dxa"/>';
    final grid = table.gridColumnWidths.isEmpty
        ? ''
        : '<w:tblGrid>${table.gridColumnWidths.map((width) => '<w:gridCol w:w="${_twipsFromLogical(width)}"/>').join()}</w:tblGrid>';

    final rows = <String>[];
    for (var rowIndex = 0; rowIndex < table.rows.length; rowIndex++) {
      final row = table.rows[rowIndex];
      final rowProperties = StringBuffer('<w:trPr>');
      if (row.header) rowProperties.write('<w:tblHeader/>');
      if (row.cantSplit) rowProperties.write('<w:cantSplit/>');
      if (row.heightPoints != null && row.heightPoints! > 0) {
        final rule = switch (row.heightRule) {
          'exact' => 'exact',
          'atLeast' => 'atLeast',
          _ => 'auto',
        };
        rowProperties.write(
          '<w:trHeight w:val="${_twipsFromLogical(row.heightPoints!)}" w:hRule="$rule"/>',
        );
      }
      rowProperties.write('</w:trPr>');

      final cells = <String>[];
      for (var cellIndex = 0; cellIndex < row.cells.length; cellIndex++) {
        final cell = row.cells[cellIndex];
        final width = cell.widthPercent != null
            ? '<w:tcW w:w="${(cell.widthPercent!.clamp(0.1, 100.0) * 50).round()}" w:type="pct"/>'
            : cell.widthPoints == null
                ? ''
                : '<w:tcW w:w="${_twipsFromLogical(cell.widthPoints!)}" w:type="dxa"/>';
        final span = cell.gridSpan > 1
            ? '<w:gridSpan w:val="${cell.gridSpan}"/>'
            : '';
        final verticalMerge = switch (cell.verticalMerge) {
          'restart' => '<w:vMerge w:val="restart"/>',
          'continuation' => '<w:vMerge/>',
          _ => '',
        };
        final verticalAlignment = switch (cell.verticalAlignment) {
          'center' => '<w:vAlign w:val="center"/>',
          'bottom' => '<w:vAlign w:val="bottom"/>',
          _ => '<w:vAlign w:val="top"/>',
        };
        final shading = _hex(cell.shadingHex);
        final shd = shading == null
            ? ''
            : '<w:shd w:val="clear" w:fill="$shading"/>';
        final cellBorders = _wordBordersXml('tcBorders', cell.borders);
        final noWrap = cell.noWrap ? '<w:noWrap/>' : '';
        String margin(String side, double value) =>
            '<w:$side w:w="${_twipsFromLogical(value)}" w:type="dxa"/>';
        final margins = '<w:tcMar>'
            '${margin('top', cell.paddingTopPoints)}'
            '${margin('right', cell.paddingRightPoints)}'
            '${margin('bottom', cell.paddingBottomPoints)}'
            '${margin('left', cell.paddingLeftPoints)}'
            '</w:tcMar>';

        final content = StringBuffer();
        if (cell.blocks.isEmpty) {
          final bold = row.header
              ? const <String, dynamic>{'bold': true}
              : const <String, dynamic>{};
          content.write(_plainParagraphXml(cell.text, attributes: bold));
        } else {
          for (var blockIndex = 0; blockIndex < cell.blocks.length; blockIndex++) {
            final block = cell.blocks[blockIndex];
            final key = '$prefix/r$rowIndex/c$cellIndex/b$blockIndex';
            if (block.kind == 'image') {
              final part = media[key];
              if (part != null) {
                content.write(
                  _drawingParagraphXml(
                    part,
                    drawingIds.take(),
                    alignment: 'left',
                    hyperlinks: hyperlinks,
                  ),
                );
              }
            } else if (block.kind == 'table' && block.table != null) {
              content.write(
                _tableXml(
                  block.table!,
                  media: media,
                  prefix: key,
                  drawingIds: drawingIds,
                  hyperlinks: hyperlinks,
                ),
              );
            } else if (block.kind == 'shape' && block.shape != null) {
              content.write(
                _shapeParagraphXml(block.shape!, drawingIds.take()),
              );
            } else if (block.kind == 'opaqueOoxml') {
              final raw = block.rawOoxml?.trim();
              if (raw != null && raw.isNotEmpty) {
                content.write(raw);
              } else {
                content.write(_plainParagraphXml(
                  block.fallbackText.isEmpty
                      ? '[Word ${block.featureKind ?? 'object'} preserved]'
                      : block.fallbackText,
                ));
              }
            } else {
              content.write(
                _richCellParagraphXml(
                  block,
                  forceBold: row.header,
                  hyperlinks: hyperlinks,
                ),
              );
            }
          }
        }
        if (content.isEmpty) content.write('<w:p/>');
        cells.add(
          '<w:tc><w:tcPr>$width$span$verticalMerge$verticalAlignment$shd$cellBorders$noWrap$margins</w:tcPr>${content.toString()}</w:tc>',
        );
      }
      rows.add('<w:tr>${rowProperties.toString()}${cells.join()}</w:tr>');
    }
    return '<w:tbl><w:tblPr>$tableStyle$tableWidth$tableAlignment$indent$cellSpacing$tableLayout$tableShading$border</w:tblPr>$grid${rows.join()}</w:tbl>';
  }

  static String _wordBordersXml(
    String containerName,
    Map<String, dynamic> borders,
  ) {
    if (borders.isEmpty) return '';
    final body = StringBuffer();
    const supported = <String>{
      'top',
      'right',
      'bottom',
      'left',
      'insideH',
      'insideV',
      'between',
      'bar',
    };
    for (final entry in borders.entries) {
      if (!supported.contains(entry.key) || entry.value is! Map) continue;
      final side = Map<String, dynamic>.from(entry.value as Map);
      final width = side['widthPoints'] is num
          ? (side['widthPoints'] as num).toDouble()
          : 0.5;
      if (width <= 0) continue;
      final style = switch (side['style']?.toString()) {
        'double' => 'double',
        'dotted' => 'dotted',
        'dashed' => 'dashed',
        'dashDot' => 'dotDash',
        'dashDotDot' => 'dotDotDash',
        'thick' => 'thick',
        'wave' => 'wave',
        _ => 'single',
      };
      final eighthPoints = math.max(2, (width * _logicalToWordPoint * 8).round());
      final color = _hex(side['colorHex']?.toString()) ?? 'auto';
      final space = side['spacePoints'] is num
          ? math.max(0, ((side['spacePoints'] as num) * _logicalToWordPoint).round())
          : 0;
      body.write(
        '<w:${entry.key} w:val="$style" w:sz="$eighthPoints" '
        'w:space="$space" w:color="$color"/>',
      );
    }
    if (body.isEmpty) return '';
    return '<w:$containerName>${body.toString()}</w:$containerName>';
  }

  static String _richCellParagraphXml(
    SmartEditorInteropCellBlock block, {
    required bool forceBold,
    required Map<String, String> hyperlinks,
  }) {
    final pPr = StringBuffer('<w:pPr>');
    switch (block.alignment) {
      case 'center':
        pPr.write('<w:jc w:val="center"/>');
        break;
      case 'right':
        pPr.write('<w:jc w:val="right"/>');
        break;
      case 'justify':
        pPr.write('<w:jc w:val="both"/>');
        break;
    }
    final spacing = StringBuffer();
    if (block.spaceBeforePoints != 0) {
      spacing.write(' w:before="${_twipsFromLogical(block.spaceBeforePoints)}"');
    }
    if (block.spaceAfterPoints != 0) {
      spacing.write(' w:after="${_twipsFromLogical(block.spaceAfterPoints)}"');
    }
    if (block.exactLineSpacingPoints != null &&
        block.exactLineSpacingPoints! > 0) {
      spacing
        ..write(' w:line="${_twipsFromLogical(block.exactLineSpacingPoints!)}"')
        ..write(' w:lineRule="exact"');
    } else if (block.lineSpacingMultiple != null &&
        block.lineSpacingMultiple! > 0) {
      spacing
        ..write(' w:line="${(240 * block.lineSpacingMultiple!).round()}"')
        ..write(' w:lineRule="auto"');
    }
    if (spacing.isNotEmpty) pPr.write('<w:spacing${spacing.toString()}/>');
    pPr.write('</w:pPr>');

    final runs = block.runs.map((run) {
      final attributes = <String, dynamic>{
        if (forceBold || run.bold) 'bold': true,
        if (run.italic) 'italic': true,
        if (run.underline) 'underline': true,
        if (run.underline) 'underlineStyle': run.underlineStyle,
        if (run.strike) 'strike': true,
        if (run.doubleStrike) 'doubleStrike': true,
        if (run.allCaps) 'allCaps': true,
        if (run.smallCaps) 'smallCaps': true,
        if (run.letterSpacingPoints != 0)
          'letterSpacing': run.letterSpacingPoints,
        if (run.fontFamily != null) 'font': run.fontFamily,
        if (run.fontSizePoints != null) 'size': run.fontSizePoints,
        if (run.colorHex != null) 'color': run.colorHex,
        if (run.backgroundHex != null) 'background': run.backgroundHex,
      };
      final target = run.hyperlink?.trim();
      final anchor = target != null && target.startsWith('#')
          ? target.substring(1)
          : null;
      return _runXml(
        run.text,
        attributes,
        hyperlinkRelationshipId: target == null ||
                target.isEmpty ||
                anchor != null
            ? null
            : hyperlinks[target],
        hyperlinkAnchor: anchor,
      );
    }).join();
    return '<w:p>${pPr.toString()}$runs</w:p>';
  }

  static String _textBoxXml(
    SmartEditorInteropTablePayload table, {
    required Map<String, _MediaPart> media,
    required String prefix,
    required _DrawingIdCounter drawingIds,
    required Map<String, String> hyperlinks,
  }) {
    final cell = table.rows.first.cells.firstOrNull;
    if (cell == null) return '';
    final drawingId = drawingIds.take();
    final width = math.max(
      24.0,
      (table.widthPoints ?? cell.widthPoints ?? 180) * _logicalToWordPoint,
    );
    final height = math.max(
      18.0,
      (table.heightPoints ?? 90) * _logicalToWordPoint,
    );
    final placement = table.placement;
    final style = StringBuffer();
    if (placement.floating) {
      style.write('position:absolute;');
      final x = (placement.horizontalOffsetPoints ?? 0) * _logicalToWordPoint;
      final y = (placement.verticalOffsetPoints ?? 0) * _logicalToWordPoint;
      style
        ..write('margin-left:${x.toStringAsFixed(3)}pt;')
        ..write('margin-top:${y.toStringAsFixed(3)}pt;')
        ..write('mso-position-horizontal-relative:${_xml(placement.horizontalRelativeFrom ?? 'margin')};')
        ..write('mso-position-vertical-relative:${_xml(placement.verticalRelativeFrom ?? 'margin')};');
      if (placement.horizontalAlignment != null) {
        style.write('mso-position-horizontal:${_xml(placement.horizontalAlignment!)};');
      }
      if (placement.verticalAlignment != null) {
        style.write('mso-position-vertical:${_xml(placement.verticalAlignment!)};');
      }
      final z = placement.behindText
          ? -math.max(1, placement.relativeHeight)
          : math.max(0, placement.relativeHeight);
      style.write('z-index:$z;');
      style
        ..write('mso-wrap-distance-left:${(placement.distanceLeftPoints * _logicalToWordPoint).toStringAsFixed(3)}pt;')
        ..write('mso-wrap-distance-right:${(placement.distanceRightPoints * _logicalToWordPoint).toStringAsFixed(3)}pt;')
        ..write('mso-wrap-distance-top:${(placement.distanceTopPoints * _logicalToWordPoint).toStringAsFixed(3)}pt;')
        ..write('mso-wrap-distance-bottom:${(placement.distanceBottomPoints * _logicalToWordPoint).toStringAsFixed(3)}pt;');
    } else {
      style.write('position:relative;');
    }
    style
      ..write('width:${width.toStringAsFixed(3)}pt;')
      ..write('height:${height.toStringAsFixed(3)}pt;');

    final content = StringBuffer();
    if (cell.blocks.isEmpty) {
      content.write(_plainParagraphXml(cell.text));
    } else {
      for (var blockIndex = 0; blockIndex < cell.blocks.length; blockIndex++) {
        final block = cell.blocks[blockIndex];
        final key = '$prefix/r0/c0/b$blockIndex';
        if (block.kind == 'image') {
          final part = media[key];
          if (part != null) {
            content.write(
              _drawingParagraphXml(
                part,
                drawingIds.take(),
                alignment: 'left',
                hyperlinks: hyperlinks,
              ),
            );
          }
        } else if (block.kind == 'table' && block.table != null) {
          content.write(
            _tableXml(
              block.table!,
              media: media,
              prefix: key,
              drawingIds: drawingIds,
              hyperlinks: hyperlinks,
            ),
          );
        } else if (block.kind == 'opaqueOoxml') {
          final raw = block.rawOoxml?.trim();
          if (raw != null && raw.isNotEmpty) {
            content.write(raw);
          } else {
            content.write(_plainParagraphXml(
              block.fallbackText.isEmpty
                  ? '[Word ${block.featureKind ?? 'object'} preserved]'
                  : block.fallbackText,
            ));
          }
        } else {
          content.write(
            _richCellParagraphXml(
              block,
              forceBold: false,
              hyperlinks: hyperlinks,
            ),
          );
        }
      }
    }
    if (content.isEmpty) content.write('<w:p/>');

    final inset = '${(cell.paddingLeftPoints * _logicalToWordPoint).toStringAsFixed(3)}pt,'
        '${(cell.paddingTopPoints * _logicalToWordPoint).toStringAsFixed(3)}pt,'
        '${(cell.paddingRightPoints * _logicalToWordPoint).toStringAsFixed(3)}pt,'
        '${(cell.paddingBottomPoints * _logicalToWordPoint).toStringAsFixed(3)}pt';
    final wrapType = switch (placement.wrapStyle) {
      'wrapNone' => 'none',
      'wrapTight' => 'tight',
      'wrapThrough' => 'through',
      'wrapTopAndBottom' => 'topAndBottom',
      _ => 'square',
    };
    final wrapSide = switch (placement.wrapText) {
      'left' => 'left',
      'right' => 'right',
      'largest' => 'largest',
      _ => 'both',
    };
    final wrap = placement.floating
        ? '<w10:wrap type="$wrapType" side="$wrapSide"/>'
        : '';
    return '<w:p><w:r><w:pict>'
        '<v:shape id="EduSheetTextBox$drawingId" '
        'style="${style.toString()}" o:allowoverlap="${placement.allowOverlap ? 't' : 'f'}">'
        '$wrap<v:stroke on="f"/><v:fill on="f"/>'
        '<v:textbox inset="$inset"><w:txbxContent>${content.toString()}</w:txbxContent></v:textbox>'
        '</v:shape></w:pict></w:r></w:p>';
  }

  static String _shapeParagraphXml(
    SmartEditorInteropShapePayload shape,
    int drawingId,
  ) {
    final widthPt = shape.widthPoints * _logicalToWordPoint;
    final heightPt = shape.heightPoints * _logicalToWordPoint;
    final placement = shape.placement;
    final style = StringBuffer();
    if (placement.floating) {
      style.write('position:absolute;');
      if (placement.horizontalOffsetPoints != null) {
        style.write(
          'margin-left:${(placement.horizontalOffsetPoints! * _logicalToWordPoint).toStringAsFixed(3)}pt;',
        );
      }
      if (placement.verticalOffsetPoints != null) {
        style.write(
          'margin-top:${(placement.verticalOffsetPoints! * _logicalToWordPoint).toStringAsFixed(3)}pt;',
        );
      }
      if (placement.horizontalRelativeFrom?.isNotEmpty == true) {
        style.write(
          'mso-position-horizontal-relative:${_xml(placement.horizontalRelativeFrom!)};',
        );
      }
      if (placement.verticalRelativeFrom?.isNotEmpty == true) {
        style.write(
          'mso-position-vertical-relative:${_xml(placement.verticalRelativeFrom!)};',
        );
      }
      if (placement.horizontalAlignment?.isNotEmpty == true) {
        style.write(
          'mso-position-horizontal:${_xml(placement.horizontalAlignment!)};',
        );
      }
      if (placement.verticalAlignment?.isNotEmpty == true) {
        style.write(
          'mso-position-vertical:${_xml(placement.verticalAlignment!)};',
        );
      }
      style
        ..write('mso-wrap-distance-left:${(placement.distanceLeftPoints * _logicalToWordPoint).toStringAsFixed(3)}pt;')
        ..write('mso-wrap-distance-right:${(placement.distanceRightPoints * _logicalToWordPoint).toStringAsFixed(3)}pt;')
        ..write('mso-wrap-distance-top:${(placement.distanceTopPoints * _logicalToWordPoint).toStringAsFixed(3)}pt;')
        ..write('mso-wrap-distance-bottom:${(placement.distanceBottomPoints * _logicalToWordPoint).toStringAsFixed(3)}pt;');
      final z = placement.behindText
          ? -math.max(1, placement.relativeHeight)
          : math.max(0, placement.relativeHeight);
      style.write('z-index:$z;');
    }
    style.write('width:${widthPt.toStringAsFixed(3)}pt;');
    style.write('height:${heightPt.toStringAsFixed(3)}pt;');
    if (shape.rotationDegrees != 0) {
      style.write('rotation:${shape.rotationDegrees.toStringAsFixed(3)};');
    }

    final fill = _hex(shape.fillColorHex);
    final stroke = _hex(shape.strokeColorHex);
    final fillAttributes = fill == null
        ? ' filled="f"'
        : ' filled="t" fillcolor="#$fill"';
    final strokeAttributes = stroke == null
        ? ' stroked="f"'
        : ' stroked="t" strokecolor="#$stroke" '
            'strokeweight="${(shape.strokeWidthPoints * _logicalToWordPoint).toStringAsFixed(3)}pt"';
    final flip = <String>[
      if (shape.flipHorizontal) 'x',
      if (shape.flipVertical) 'y',
    ].join(' ');
    if (flip.isNotEmpty) style.write('flip:$flip;');

    final tag = switch (shape.kind) {
      'ellipse' => 'oval',
      'roundedRectangle' => 'roundrect',
      'line' => 'line',
      'textPath' => 'shape',
      _ => 'rect',
    };
    final wrapType = switch (placement.wrapStyle) {
      'wrapNone' => 'none',
      'wrapTight' => 'tight',
      'wrapThrough' => 'through',
      'wrapTopAndBottom' => 'topAndBottom',
      _ => 'square',
    };
    final wrapSide = switch (placement.wrapText) {
      'left' => 'left',
      'right' => 'right',
      'largest' => 'largest',
      _ => 'both',
    };
    final wrap = placement.floating
        ? '<w10:wrap type="$wrapType" side="$wrapSide"/>'
        : '';
    final allowOverlap = placement.allowOverlap ? 't' : 'f';
    final text = shape.text.trim();
    final textbox = text.isEmpty || tag == 'line' || shape.kind == 'textPath'
        ? ''
        : '<v:textbox inset="4pt,2pt,4pt,2pt"><w:txbxContent>'
            '${_plainParagraphXml(text)}'
            '</w:txbxContent></v:textbox>';
    final textPath = shape.kind == 'textPath' && text.isNotEmpty
        ? '<v:textpath on="t" fitshape="t" string="${_xml(text)}"/>'
        : '';
    final common = 'id="EduSheetShape$drawingId" style="${style.toString()}" '
        'o:allowoverlap="$allowOverlap"$fillAttributes$strokeAttributes';

    if (tag == 'line') {
      return '<w:p><w:r><w:pict><v:line $common from="0,0" to="${widthPt.toStringAsFixed(3)}pt,${heightPt.toStringAsFixed(3)}pt">'
          '$wrap</v:line></w:pict></w:r></w:p>';
    }
    return '<w:p><w:r><w:pict><v:$tag $common>$wrap$textPath$textbox</v:$tag></w:pict></w:r></w:p>';
  }

  static String _drawingParagraphXml(
    _MediaPart part,
    int drawingId, {
    String alignment = 'center',
    required Map<String, String> hyperlinks,
  }) {
    final cx = (part.widthPoints.clamp(18.0, 720.0) * 12700).round();
    final cy = (part.heightPoints.clamp(18.0, 960.0) * 12700).round();
    final name = _xml(part.altText.isEmpty ? part.fileName : part.altText);
    final linkTarget = part.hyperlink?.trim();
    final hyperlinkId = linkTarget == null || linkTarget.isEmpty
        ? null
        : hyperlinks[linkTarget];
    final docPr = '<wp:docPr id="$drawingId" name="$name" descr="$name">'
        '${hyperlinkId == null ? '' : '<a:hlinkClick r:id="${_xml(hyperlinkId)}"/>'}'
        '</wp:docPr>';
    String cropAttribute(String name, double value) {
      if (value <= 0) return '';
      final normalized = (value.clamp(0.0, 0.999) * 100000).round();
      return ' $name="$normalized"';
    }

    final hasCrop = part.cropLeft > 0 ||
        part.cropTop > 0 ||
        part.cropRight > 0 ||
        part.cropBottom > 0;
    final srcRect = hasCrop
        ? '<a:srcRect'
            '${cropAttribute('l', part.cropLeft)}'
            '${cropAttribute('t', part.cropTop)}'
            '${cropAttribute('r', part.cropRight)}'
            '${cropAttribute('b', part.cropBottom)}/>'
        : '';
    final transformAttributes = StringBuffer()
      ..write(
        part.rotationDegrees == 0
            ? ''
            : ' rot="${(part.rotationDegrees * 60000).round()}"',
      )
      ..write(part.flipHorizontal ? ' flipH="1"' : '')
      ..write(part.flipVertical ? ' flipV="1"' : '');

    final picture = '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic><pic:nvPicPr><pic:cNvPr id="0" name="$name"/><pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill><a:blip r:embed="${part.relationshipId}"/>$srcRect<a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm${transformAttributes.toString()}><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic>';

    final placement = part.placement;
    if (!placement.floating) {
      return '<w:p><w:pPr><w:jc w:val="$alignment"/></w:pPr><w:r><w:drawing>'
          '<wp:inline distT="0" distB="0" distL="0" distR="0">'
          '<wp:extent cx="$cx" cy="$cy"/>$docPr$picture</wp:inline>'
          '</w:drawing></w:r></w:p>';
    }

    String positionXml({
      required String axis,
      required String relativeFrom,
      required double? offset,
      required String? align,
    }) {
      final value = align?.trim();
      final position = value != null && value.isNotEmpty
          ? '<wp:align>${_xml(value)}</wp:align>'
          : '<wp:posOffset>${(((offset ?? 0) * _logicalToWordPoint) * 12700).round()}</wp:posOffset>';
      return '<wp:position$axis relativeFrom="${_xml(relativeFrom)}">$position</wp:position$axis>';
    }

    final wrapText = _xml(
      placement.wrapText?.trim().isNotEmpty == true
          ? placement.wrapText!.trim()
          : 'bothSides',
    );
    const wrapPolygon = '<wp:wrapPolygon edited="0">'
        '<wp:start x="0" y="0"/>'
        '<wp:lineTo x="21600" y="0"/>'
        '<wp:lineTo x="21600" y="21600"/>'
        '<wp:lineTo x="0" y="21600"/>'
        '<wp:lineTo x="0" y="0"/>'
        '</wp:wrapPolygon>';
    final wrap = switch (placement.wrapStyle) {
      'wrapNone' => '<wp:wrapNone/>',
      'wrapTopAndBottom' => '<wp:wrapTopAndBottom/>',
      'wrapSquare' => '<wp:wrapSquare wrapText="$wrapText"/>',
      'wrapTight' => '<wp:wrapTight wrapText="$wrapText">$wrapPolygon</wp:wrapTight>',
      'wrapThrough' =>
        '<wp:wrapThrough wrapText="$wrapText">$wrapPolygon</wp:wrapThrough>',
      _ => '<wp:wrapSquare wrapText="$wrapText"/>',
    };
    final horizontal = positionXml(
      axis: 'H',
      relativeFrom: placement.horizontalRelativeFrom ?? 'margin',
      offset: placement.horizontalOffsetPoints,
      align: placement.horizontalAlignment,
    );
    final vertical = positionXml(
      axis: 'V',
      relativeFrom: placement.verticalRelativeFrom ?? 'margin',
      offset: placement.verticalOffsetPoints,
      align: placement.verticalAlignment,
    );
    int wrapDistance(double logical) =>
        ((math.max(0.0, logical) * _logicalToWordPoint) * 12700).round();
    final relativeHeight = math.max(0, placement.relativeHeight);
    return '<w:p><w:r><w:drawing>'
        '<wp:anchor distT="${wrapDistance(placement.distanceTopPoints)}" '
        'distB="${wrapDistance(placement.distanceBottomPoints)}" '
        'distL="${wrapDistance(placement.distanceLeftPoints)}" '
        'distR="${wrapDistance(placement.distanceRightPoints)}" '
        'simplePos="0" relativeHeight="$relativeHeight" '
        'behindDoc="${placement.behindText ? 1 : 0}" '
        'locked="${placement.locked ? 1 : 0}" '
        'layoutInCell="${placement.layoutInCell ? 1 : 0}" '
        'allowOverlap="${placement.allowOverlap ? 1 : 0}">'
        '<wp:simplePos x="0" y="0"/>$horizontal$vertical'
        '<wp:extent cx="$cx" cy="$cy"/><wp:effectExtent l="0" t="0" r="0" b="0"/>'
        '$wrap$docPr$picture</wp:anchor>'
        '</w:drawing></w:r></w:p>';
  }

  static int _twipsFromLogical(double logicalPoints) =>
      (logicalPoints * _logicalToWordPoint * 20).round();

  static String _plainParagraphXml(
    String text, {
    Map<String, dynamic> attributes = const <String, dynamic>{},
  }) {
    return '<w:p>${_runXml(text, attributes)}</w:p>';
  }

  static String _sectionProperties(
    SmartDocument document, {
    required int sectionIndex,
    required List<_HeaderFooterPart> storyParts,
  }) {
    final profileIndex = document.wordSections.isEmpty
        ? 0
        : sectionIndex.clamp(0, document.wordSections.length - 1).toInt();
    final profile = document.wordSections.isEmpty
        ? null
        : document.wordSections[profileIndex];
    final page = profile == null || profileIndex == 0
        ? document.pageLayout
        : profile.pageLayout;
    final width = page.exportPageWidthPoints;
    final height = page.exportPageHeightPoints;
    final landscape = width > height;
    final buffer = StringBuffer('<w:sectPr>');

    String? storyRel(bool header, String type) => storyParts
        .where(
          (part) =>
              part.sectionIndex == profileIndex &&
              part.header == header &&
              part.storyType == type,
        )
        .map((part) => part.relationshipId)
        .firstOrNull;

    // CT_SectPr groups all header references before footer references. Keep the
    // emitted order schema-friendly instead of interleaving the two story kinds.
    for (final type in const <String>['default', 'first', 'even']) {
      final header = storyRel(true, type);
      if (header != null) {
        buffer.write(
          '<w:headerReference w:type="$type" r:id="${_xml(header)}"/>',
        );
      }
    }
    for (final type in const <String>['default', 'first', 'even']) {
      final footer = storyRel(false, type);
      if (footer != null) {
        buffer.write(
          '<w:footerReference w:type="$type" r:id="${_xml(footer)}"/>',
        );
      }
    }

    final breakType = profile?.breakType;
    if (breakType != null && breakType.isNotEmpty) {
      buffer.write('<w:type w:val="${_xml(breakType)}"/>');
    }
    buffer.write(
      '<w:pgSz w:w="${(width * 20).round()}" w:h="${(height * 20).round()}"'
      '${landscape ? ' w:orient="landscape"' : ''}/>',
    );
    buffer.write(
      '<w:pgMar w:top="${(page.exportTopMarginPoints * 20).round()}" '
      'w:right="${(page.exportRightMarginPoints * 20).round()}" '
      'w:bottom="${(page.exportBottomMarginPoints * 20).round()}" '
      'w:left="${(page.exportLeftMarginPoints * 20).round()}" '
      'w:header="${(page.exportHeaderDistancePoints * 20).round()}" '
      'w:footer="${(page.exportFooterDistancePoints * 20).round()}" '
      'w:gutter="${((profile?.gutterPoints ?? 0) * 20).round()}"/>',
    );

    if (profile != null) {
      if (profileIndex == 0 &&
          page.borderStyle != SmartDocumentPageBorderStyle.none) {
        buffer.write(_pageBorderXml(page.borderStyle));
      } else {
        buffer.write(_wordPageBorderXml(profile.pageBorders));
      }

      if (profile.pageNumberStart != null ||
          profile.pageNumberFormat?.trim().isNotEmpty == true) {
        buffer.write(
          '<w:pgNumType'
          '${profile.pageNumberStart == null ? '' : ' w:start="${profile.pageNumberStart}"'}'
          '${profile.pageNumberFormat?.trim().isNotEmpty == true ? ' w:fmt="${_xml(profile.pageNumberFormat!.trim())}"' : ''}/>',
        );
      }

      final columns = profile.columns;
      final cols = StringBuffer(
        '<w:cols w:num="${math.max(1, columns.count)}" '
        'w:space="${(math.max(0.0, columns.spacingPoints) * 20).round()}" '
        'w:equalWidth="${columns.equalWidth ? 1 : 0}"'
        '${columns.separator ? ' w:sep="1"' : ''}>',
      );
      if (!columns.equalWidth) {
        for (final column in columns.columns) {
          cols.write(
            '<w:col'
            '${column.widthPoints == null ? '' : ' w:w="${(math.max(0.0, column.widthPoints!) * 20).round()}"'}'
            '${column.spacingPoints == null ? '' : ' w:space="${(math.max(0.0, column.spacingPoints!) * 20).round()}"'}/>',
          );
        }
      }
      cols.write('</w:cols>');
      buffer.write(cols.toString());

      if (profile.titlePage) buffer.write('<w:titlePg/>');
    } else {
      buffer.write(_pageBorderXml(page.borderStyle));
    }
    buffer.write('</w:sectPr>');
    return buffer.toString();
  }

  static String _wordPageBorderXml(SmartDocumentWordPageBorders borders) {
    if (borders.isEmpty) return '';
    String edge(String name, SmartDocumentWordBorderSide? side) {
      if (side == null || side.style == 'none' || side.widthPoints <= 0) return '';
      final color = _hex(side.colorHex) ?? 'auto';
      return '<w:$name w:val="${_xml(side.style)}" '
          'w:sz="${(side.widthPoints * 8).round().clamp(1, 255)}" '
          'w:space="${side.spacePoints.round().clamp(0, 31)}" '
          'w:color="$color"/>';
    }

    return '<w:pgBorders w:offsetFrom="${_xml(borders.offsetFrom)}" '
        'w:display="${_xml(borders.display)}" w:zOrder="${_xml(borders.zOrder)}">'
        '${edge('top', borders.top)}${edge('left', borders.left)}'
        '${edge('bottom', borders.bottom)}${edge('right', borders.right)}'
        '</w:pgBorders>';
  }

  static String _pageBorderXml(SmartDocumentPageBorderStyle style) {
    if (style == SmartDocumentPageBorderStyle.none) return '';
    final val = style == SmartDocumentPageBorderStyle.doubleLine ? 'double' : 'single';
    final size = switch (style) {
      SmartDocumentPageBorderStyle.subtle => 4,
      SmartDocumentPageBorderStyle.solid => 8,
      SmartDocumentPageBorderStyle.doubleLine => 6,
      SmartDocumentPageBorderStyle.none => 0,
    };
    final color = style == SmartDocumentPageBorderStyle.subtle
        ? 'A8A8A8'
        : '666666';
    String edge(String name) => '<w:$name w:val="$val" w:sz="$size" w:space="18" w:color="$color"/>';
    return '<w:pgBorders w:offsetFrom="page">'
        '${edge('top')}${edge('left')}${edge('bottom')}${edge('right')}'
        '</w:pgBorders>';
  }

  static List<_HeaderFooterPart> _headerFooterParts(
    SmartDocument document, {
    Set<String> reservedRelationshipIds = const <String>{},
  }) {
    final result = <_HeaderFooterPart>[];
    final usedRelationshipIds = <String>{...reservedRelationshipIds};
    var headerNumber = 1;
    var footerNumber = 1;

    void add({
      required int sectionIndex,
      required bool header,
      required String storyType,
      required SmartDocumentHeaderFooter config,
      String? legacyRelationshipId,
    }) {
      if (!config.enabled || config.text.trim().isEmpty) return;
      final number = header ? headerNumber++ : footerNumber++;
      result.add(
        _HeaderFooterPart(
          sectionIndex: sectionIndex,
          header: header,
          storyType: storyType,
          relationshipId: _uniqueRelationshipId(
            legacyRelationshipId ??
                'rIdEduSheet${header ? 'Header' : 'Footer'}${sectionIndex + 1}${storyType[0].toUpperCase()}${storyType.substring(1)}',
            usedRelationshipIds,
          ),
          fileName: '${header ? 'header' : 'footer'}$number.xml',
          config: config,
        ),
      );
    }

    if (document.wordSections.isEmpty) {
      add(
        sectionIndex: 0,
        header: true,
        storyType: 'default',
        config: document.header,
        legacyRelationshipId: 'rIdHeader',
      );
      add(
        sectionIndex: 0,
        header: false,
        storyType: 'default',
        config: document.footer,
        legacyRelationshipId: 'rIdFooter',
      );
      return List<_HeaderFooterPart>.unmodifiable(result);
    }

    for (var index = 0; index < document.wordSections.length; index++) {
      final section = document.wordSections[index];
      add(
        sectionIndex: index,
        header: true,
        storyType: 'default',
        config: index == 0 ? document.header : section.header,
      );
      add(
        sectionIndex: index,
        header: false,
        storyType: 'default',
        config: index == 0 ? document.footer : section.footer,
      );
      add(sectionIndex: index, header: true, storyType: 'first', config: section.firstHeader);
      add(sectionIndex: index, header: false, storyType: 'first', config: section.firstFooter);
      add(sectionIndex: index, header: true, storyType: 'even', config: section.evenHeader);
      add(sectionIndex: index, header: false, storyType: 'even', config: section.evenFooter);
    }
    return List<_HeaderFooterPart>.unmodifiable(result);
  }

  static String _settingsXml(SmartDocument document) {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '${document.wordEvenAndOddHeaders ? '<w:evenAndOddHeaders/>' : ''}'
        '${document.wordMirrorMargins ? '<w:mirrorMargins/>' : ''}'
        '${document.wordGutterAtTop ? '<w:gutterAtTop/>' : ''}'
        '</w:settings>';
  }

  static String _headerFooterXml(
    SmartDocumentHeaderFooter config, {
    required bool header,
  }) {
    final root = header ? 'hdr' : 'ftr';
    final align = switch (config.alignment) {
      SmartDocumentHeaderFooterAlignment.left => 'left',
      SmartDocumentHeaderFooterAlignment.center => 'center',
      SmartDocumentHeaderFooterAlignment.right => 'right',
    };
    final border = config.showDivider
        ? '<w:pBdr><w:${header ? 'bottom' : 'top'} w:val="single" w:sz="6" w:space="4" w:color="808080"/></w:pBdr>'
        : '';
    final paragraphs = config.text.split('\n').map((line) {
      return '<w:p><w:pPr><w:jc w:val="$align"/>$border</w:pPr>${_runXml(line, const <String, dynamic>{})}</w:p>';
    }).join();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:$root xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">$paragraphs</w:$root>';
  }

  static String _roundTripXml(
    SmartDocument document,
    String documentXml,
    String wordContentFingerprint,
  ) {
    final nativeDocument = document.copyWith(
      wordPreservation: const SmartDocumentWordPreservationState(),
    );
    final payload = Uint8List.fromList(
      utf8.encode(jsonEncode(nativeDocument.toJson())),
    );
    return '<?xml version="1.0" encoding="UTF-8"?>'
        '<smartDocument xmlns="$roundTripNamespace" version="1" '
        'payloadSha256="${sha256.convert(payload)}" '
        'documentSha256="${sha256.convert(utf8.encode(documentXml))}" '
        'wordContentSha256="$wordContentFingerprint">'
        '<payload>${base64Encode(payload)}</payload></smartDocument>';
  }

  static String _wordContentFingerprint(Iterable<ArchiveFile> files) {
    final parts = files
        .where((file) => file.name.startsWith('word/'))
        .toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));
    final canonical = BytesBuilder(copy: false);
    for (final part in parts) {
      final bytes = List<int>.from(part.content as List<int>);
      canonical
        ..add(utf8.encode(part.name))
        ..addByte(0)
        ..add(utf8.encode(sha256.convert(bytes).toString()))
        ..addByte(0);
    }
    return sha256.convert(canonical.takeBytes()).toString();
  }

  static String _uniqueRelationshipId(
    String preferred,
    Set<String> used,
  ) {
    var candidate = preferred;
    var suffix = 2;
    while (used.contains(candidate)) {
      candidate = '${preferred}_$suffix';
      suffix++;
    }
    used.add(candidate);
    return candidate;
  }

  static Map<String, String> _hyperlinkRelationships(
    SmartEditorExportProjection projection, {
    Set<String> reservedRelationshipIds = const <String>{},
  }) {
    final result = <String, String>{};
    final usedRelationshipIds = <String>{...reservedRelationshipIds};
    var next = 1;

    void add(Object? rawTarget) {
      final target = rawTarget?.toString().trim();
      if (target == null ||
          target.isEmpty ||
          target.startsWith('#') ||
          result.containsKey(target)) {
        return;
      }
      result[target] = _uniqueRelationshipId(
        'rIdEduSheetHyperlink${next++}',
        usedRelationshipIds,
      );
    }

    void collectTable(SmartEditorInteropTablePayload table) {
      for (final row in table.rows) {
        for (final cell in row.cells) {
          for (final cellBlock in cell.blocks) {
            if (cellBlock.kind == 'image') {
              add(cellBlock.image?.hyperlink);
            } else if (cellBlock.kind == 'table' && cellBlock.table != null) {
              collectTable(cellBlock.table!);
            } else {
              for (final run in cellBlock.runs) {
                add(run.hyperlink);
              }
            }
          }
        }
      }
    }

    for (final block in projection.blocks) {
      if (block is SmartEditorExportParagraph) {
        for (final inline in block.inlines) {
          if (inline is SmartEditorExportText) add(inline.attributes['link']);
        }
      } else if (block is SmartEditorExportImage) {
        add(block.payload.hyperlink);
      } else if (block is SmartEditorExportTable) {
        collectTable(block.payload);
      }
    }
    return Map<String, String>.unmodifiable(result);
  }

  static String _contentTypesXml(
    Iterable<_MediaPart> media, {
    required List<_HeaderFooterPart> storyParts,
    required _AdvancedWordParts advancedParts,
    required SmartDocumentWordPreservationState preservation,
  }) {
    final imageTypes = <String, String>{};
    for (final part in media) {
      imageTypes[p.extension(part.fileName).replaceFirst('.', '').toLowerCase()] =
          part.contentType;
    }
    final defaults = imageTypes.entries
        .map((entry) => '<Default Extension="${_xml(entry.key)}" ContentType="${_xml(entry.value)}"/>')
        .join();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>$defaults'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
        '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>'
        '<Override PartName="/$roundTripPartName" ContentType="application/xml"/>'
        '<Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>'
        '${storyParts.map((part) => '<Override PartName="/word/${_xml(part.fileName)}" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.${part.header ? 'header' : 'footer'}+xml"/>').join()}'
        '${advancedParts.footnotes.isEmpty ? '' : '<Override PartName="/word/footnotes.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml"/>'}'
        '${advancedParts.endnotes.isEmpty ? '' : '<Override PartName="/word/endnotes.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.endnotes+xml"/>'}'
        '${advancedParts.comments.isEmpty ? '' : '<Override PartName="/word/comments.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml"/>'}'
        '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
        '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
        '${_preservedContentTypesXml(preservation, generatedExtensions: <String>{'rels', 'xml', ...imageTypes.keys}, generatedParts: <String>{'/word/document.xml', '/word/styles.xml', '/word/numbering.xml', '/$roundTripPartName', '/word/settings.xml', '/docProps/core.xml', '/docProps/app.xml', ...storyParts.map((part) => '/word/${part.fileName}'), if (advancedParts.footnotes.isNotEmpty) '/word/footnotes.xml', if (advancedParts.endnotes.isNotEmpty) '/word/endnotes.xml', if (advancedParts.comments.isNotEmpty) '/word/comments.xml'})}'
        '</Types>';
  }

  static String _rootRelsXml(SmartDocumentWordPreservationState preservation) {
    final used = preservation.rootRelationships
        .map((relationship) => relationship.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final officeDocumentId = _uniqueRelationshipId('rId1', used);
    final corePropertiesId = _uniqueRelationshipId('rId2', used);
    final appPropertiesId = _uniqueRelationshipId('rId3', used);
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="${_xml(officeDocumentId)}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '<Relationship Id="${_xml(corePropertiesId)}" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
        '<Relationship Id="${_xml(appPropertiesId)}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
        '${_preservedRelationshipsXml(preservation.rootRelationships, reservedIds: <String>{officeDocumentId, corePropertiesId, appPropertiesId})}'
        '</Relationships>';
  }

  static String _documentRelsXml(
    Iterable<_MediaPart> media, {
    required Map<String, String> hyperlinks,
    required List<_HeaderFooterPart> storyParts,
    required _AdvancedWordParts advancedParts,
    required SmartDocumentWordPreservationState preservation,
  }) {
    final preservedIds = preservation.documentRelationships
        .map((relationship) => relationship.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final generatedIds = <String>{
      ...storyParts.map((part) => part.relationshipId),
      ...media.map((part) => part.relationshipId),
      ...hyperlinks.values,
    };
    final used = <String>{...preservedIds, ...generatedIds};

    final stylesId = _uniqueRelationshipId('rIdStyles', used);
    generatedIds.add(stylesId);
    final numberingId = _uniqueRelationshipId('rIdNumbering', used);
    generatedIds.add(numberingId);
    final settingsId = _uniqueRelationshipId('rIdSettings', used);
    generatedIds.add(settingsId);
    final smartDocumentId = _uniqueRelationshipId('rIdSmartDocument', used);
    generatedIds.add(smartDocumentId);
    final footnotesId = advancedParts.footnotes.isEmpty
        ? null
        : _uniqueRelationshipId('rIdFootnotes', used);
    if (footnotesId != null) generatedIds.add(footnotesId);
    final endnotesId = advancedParts.endnotes.isEmpty
        ? null
        : _uniqueRelationshipId('rIdEndnotes', used);
    if (endnotesId != null) generatedIds.add(endnotesId);
    final commentsId = advancedParts.comments.isEmpty
        ? null
        : _uniqueRelationshipId('rIdComments', used);
    if (commentsId != null) generatedIds.add(commentsId);

    final relationships = StringBuffer()
      ..write(
        '<Relationship Id="${_xml(stylesId)}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>',
      )
      ..write(
        '<Relationship Id="${_xml(numberingId)}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>',
      )
      ..write(
        '<Relationship Id="${_xml(settingsId)}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>',
      )
      ..write(
        '<Relationship Id="${_xml(smartDocumentId)}" Type="$roundTripRelationshipType" Target="../$roundTripPartName"/>',
      );
    for (final story in storyParts) {
      relationships.write(
        '<Relationship Id="${_xml(story.relationshipId)}" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/${story.header ? 'header' : 'footer'}" '
        'Target="${_xml(story.fileName)}"/>',
      );
    }
    if (footnotesId != null) {
      relationships.write(
        '<Relationship Id="${_xml(footnotesId)}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes" Target="footnotes.xml"/>',
      );
    }
    if (endnotesId != null) {
      relationships.write(
        '<Relationship Id="${_xml(endnotesId)}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes" Target="endnotes.xml"/>',
      );
    }
    if (commentsId != null) {
      relationships.write(
        '<Relationship Id="${_xml(commentsId)}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments" Target="comments.xml"/>',
      );
    }
    for (final part in media) {
      relationships.write(
        '<Relationship Id="${_xml(part.relationshipId)}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/${_xml(part.fileName)}"/>',
      );
    }
    for (final entry in hyperlinks.entries) {
      relationships.write(
        '<Relationship Id="${_xml(entry.value)}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="${_xml(entry.key)}" TargetMode="External"/>',
      );
    }
    relationships.write(
      _preservedRelationshipsXml(
        preservation.documentRelationships,
        reservedIds: generatedIds,
        blockedTypes: <String>{
          if (advancedParts.footnotes.isNotEmpty) 'footnotes',
          if (advancedParts.endnotes.isNotEmpty) 'endnotes',
          if (advancedParts.comments.isNotEmpty) 'comments',
        },
      ),
    );
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${relationships.toString()}</Relationships>';
  }

  static String _stylesXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:docDefaults><w:rPrDefault><w:rPr><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr></w:rPrDefault></w:docDefaults>'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>'
        '<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:sz w:val="32"/></w:rPr></w:style>'
        '<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:outlineLvl w:val="1"/></w:pPr><w:rPr><w:b/><w:sz w:val="28"/></w:rPr></w:style>'
        '<w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/><w:basedOn w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:outlineLvl w:val="2"/></w:pPr><w:rPr><w:b/><w:sz w:val="24"/></w:rPr></w:style>'
        '<w:style w:type="character" w:styleId="Hyperlink"><w:name w:val="Hyperlink"/><w:unhideWhenUsed/><w:rPr><w:color w:val="0563C1"/><w:u w:val="single"/></w:rPr></w:style>'
        '<w:style w:type="character" w:styleId="FootnoteReference"><w:name w:val="footnote reference"/><w:rPr><w:vertAlign w:val="superscript"/></w:rPr></w:style>'
        '<w:style w:type="character" w:styleId="EndnoteReference"><w:name w:val="endnote reference"/><w:rPr><w:vertAlign w:val="superscript"/></w:rPr></w:style>'
        '<w:style w:type="character" w:styleId="CommentReference"><w:name w:val="comment reference"/><w:rPr><w:color w:val="2B579A"/></w:rPr></w:style>'
        '</w:styles>';
  }

  static String _numberingXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:abstractNum w:abstractNumId="1"><w:multiLevelType w:val="hybridMultilevel"/>'
        '${_numberingLevels(ordered: true)}</w:abstractNum>'
        '<w:abstractNum w:abstractNumId="2"><w:multiLevelType w:val="hybridMultilevel"/>'
        '${_numberingLevels(ordered: false)}</w:abstractNum>'
        '<w:num w:numId="1"><w:abstractNumId w:val="1"/></w:num>'
        '<w:num w:numId="2"><w:abstractNumId w:val="2"/></w:num>'
        '</w:numbering>';
  }

  static String _numberingLevels({required bool ordered}) {
    final buffer = StringBuffer();
    for (var level = 0; level < 9; level++) {
      final left = 720 * (level + 1);
      if (ordered) {
        buffer.write('<w:lvl w:ilvl="$level"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%${level + 1}."/><w:pPr><w:ind w:left="$left" w:hanging="360"/></w:pPr></w:lvl>');
      } else {
        buffer.write('<w:lvl w:ilvl="$level"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:pPr><w:ind w:left="$left" w:hanging="360"/></w:pPr></w:lvl>');
      }
    }
    return buffer.toString();
  }

  static String _coreXml(SmartDocument document) {
    final created = document.createdAt.toUtc().toIso8601String();
    final modified = document.updatedAt.toUtc().toIso8601String();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>${_xml(document.title)}</dc:title><dc:creator>EduSheet</dc:creator>'
        '<cp:lastModifiedBy>EduSheet</cp:lastModifiedBy>'
        '<dcterms:created xsi:type="dcterms:W3CDTF">$created</dcterms:created>'
        '<dcterms:modified xsi:type="dcterms:W3CDTF">$modified</dcterms:modified>'
        '</cp:coreProperties>';
  }

  static String _appXml() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
        'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
        '<Application>EduSheet Smart Editor</Application></Properties>';
  }

  static _ImageKind? _imageKind(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return const _ImageKind('png', 'image/png');
    }
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return const _ImageKind('jpg', 'image/jpeg');
    }
    if (bytes.length >= 6 && ascii.decode(bytes.take(6).toList(), allowInvalid: true).startsWith('GIF8')) {
      return const _ImageKind('gif', 'image/gif');
    }
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return const _ImageKind('bmp', 'image/bmp');
    }
    return null;
  }

  static String? _hex(Object? value) {
    final raw = value?.toString().replaceAll('#', '').trim();
    if (raw == null || !RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(raw)) return null;
    return raw.toUpperCase();
  }

  static int? _intValue(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
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


class _AdvancedWordParts {
  _AdvancedWordParts._({
    required this.footnotes,
    required this.endnotes,
    required this.comments,
    required this.footnoteIds,
    required this.endnoteIds,
    required this.commentIds,
    required this.bookmarkIds,
  });

  final Map<String, SmartEditorWordAdvancedPayload> footnotes;
  final Map<String, SmartEditorWordAdvancedPayload> endnotes;
  final Map<String, SmartEditorWordAdvancedPayload> comments;
  final Map<String, int> footnoteIds;
  final Map<String, int> endnoteIds;
  final Map<String, int> commentIds;
  final Map<String, int> bookmarkIds;

  factory _AdvancedWordParts.fromProjection(
    SmartEditorExportProjection projection,
  ) {
    final footnotes = <String, SmartEditorWordAdvancedPayload>{};
    final endnotes = <String, SmartEditorWordAdvancedPayload>{};
    final comments = <String, SmartEditorWordAdvancedPayload>{};
    final bookmarkKeys = <String>[];

    String keyFor(SmartEditorWordAdvancedPayload payload) =>
        payload.referenceId?.trim().isNotEmpty == true
            ? payload.referenceId!.trim()
            : payload.objectId;

    void rememberBest(
      Map<String, SmartEditorWordAdvancedPayload> target,
      SmartEditorWordAdvancedPayload payload,
    ) {
      final key = keyFor(payload);
      final previous = target[key];
      if (previous == null ||
          (previous.contentText.isEmpty && payload.contentText.isNotEmpty)) {
        target[key] = payload;
      }
    }

    for (final block in projection.blocks) {
      if (block is! SmartEditorExportParagraph) continue;
      for (final inline in block.inlines) {
        if (inline is! SmartEditorExportWordAdvanced) continue;
        final payload = inline.payload;
        final key = keyFor(payload);
        switch (payload.kind) {
          case SmartEditorWordAdvancedPayload.footnoteKind:
            rememberBest(footnotes, payload);
          case SmartEditorWordAdvancedPayload.endnoteKind:
            rememberBest(endnotes, payload);
          case SmartEditorWordAdvancedPayload.commentStartKind:
          case SmartEditorWordAdvancedPayload.commentEndKind:
            rememberBest(comments, payload);
          case SmartEditorWordAdvancedPayload.commentReferenceKind:
            // The visible reference is the WM8 edit surface for a comment, so
            // its author/text must win over the preserved range markers.
            comments[key] = payload;
          case SmartEditorWordAdvancedPayload.bookmarkStartKind:
          case SmartEditorWordAdvancedPayload.bookmarkEndKind:
            if (!bookmarkKeys.contains(key)) bookmarkKeys.add(key);
        }
      }
    }

    Map<String, int> sequential(Iterable<String> keys, int start) {
      final result = <String, int>{};
      var next = start;
      for (final key in keys) {
        result[key] = next++;
      }
      return Map<String, int>.unmodifiable(result);
    }

    return _AdvancedWordParts._(
      footnotes: Map<String, SmartEditorWordAdvancedPayload>.unmodifiable(
        footnotes,
      ),
      endnotes: Map<String, SmartEditorWordAdvancedPayload>.unmodifiable(
        endnotes,
      ),
      comments: Map<String, SmartEditorWordAdvancedPayload>.unmodifiable(
        comments,
      ),
      footnoteIds: sequential(footnotes.keys, 1),
      endnoteIds: sequential(endnotes.keys, 1),
      commentIds: sequential(comments.keys, 0),
      bookmarkIds: sequential(bookmarkKeys, 0),
    );
  }

  int? footnoteId(String? referenceId) =>
      _idFor(footnoteIds, referenceId);
  int? endnoteId(String? referenceId) => _idFor(endnoteIds, referenceId);
  int? commentId(String? referenceId) => _idFor(commentIds, referenceId);
  int? bookmarkId(String? referenceId) => _idFor(bookmarkIds, referenceId);

  int? _idFor(Map<String, int> ids, String? referenceId) {
    final key = referenceId?.trim();
    if (key != null && key.isNotEmpty) return ids[key];
    if (ids.length == 1) return ids.values.first;
    return null;
  }

  String footnotesXml() => _notesXml(
        footnotes: true,
        notes: footnotes,
        ids: footnoteIds,
      );

  String endnotesXml() => _notesXml(
        footnotes: false,
        notes: endnotes,
        ids: endnoteIds,
      );

  static String _notesXml({
    required bool footnotes,
    required Map<String, SmartEditorWordAdvancedPayload> notes,
    required Map<String, int> ids,
  }) {
    final root = footnotes ? 'footnotes' : 'endnotes';
    final note = footnotes ? 'footnote' : 'endnote';
    final ref = footnotes ? 'footnoteRef' : 'endnoteRef';
    final refStyle = footnotes ? 'FootnoteReference' : 'EndnoteReference';
    final buffer = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:$root xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
    );
    buffer
      ..write(
        '<w:$note w:type="separator" w:id="-1"><w:p><w:r><w:separator/></w:r></w:p></w:$note>',
      )
      ..write(
        '<w:$note w:type="continuationSeparator" w:id="0"><w:p><w:r><w:continuationSeparator/></w:r></w:p></w:$note>',
      );
    for (final entry in notes.entries) {
      final id = ids[entry.key];
      if (id == null) continue;
      final text = entry.value.contentText;
      buffer.write(
        '<w:$note w:id="$id"><w:p>'
        '<w:r><w:rPr><w:rStyle w:val="$refStyle"/></w:rPr><w:$ref/></w:r>'
        '<w:r><w:t xml:space="preserve">${SmartEditorDocxService._xml(text)}</w:t></w:r>'
        '</w:p></w:$note>',
      );
    }
    buffer.write('</w:$root>');
    return buffer.toString();
  }

  String commentsXml() {
    final buffer = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
    );
    for (final entry in comments.entries) {
      final id = commentIds[entry.key];
      if (id == null) continue;
      final payload = entry.value;
      final author = SmartEditorDocxService._xml(payload.author ?? 'EduSheet');
      final initials = SmartEditorDocxService._xml(payload.initials ?? 'ES');
      final date = payload.dateIso?.trim();
      final dateAttribute = date == null || date.isEmpty
          ? ''
          : ' w:date="${SmartEditorDocxService._xml(date)}"';
      buffer.write(
        '<w:comment w:id="$id" w:author="$author" w:initials="$initials"$dateAttribute>'
        '<w:p><w:r><w:t xml:space="preserve">${SmartEditorDocxService._xml(payload.contentText)}</w:t></w:r></w:p>'
        '</w:comment>',
      );
    }
    buffer.write('</w:comments>');
    return buffer.toString();
  }
}

class _DrawingIdCounter {
  _DrawingIdCounter();

  int _next = 1;

  int take() => _next++;
}

class _HeaderFooterPart {
  const _HeaderFooterPart({
    required this.sectionIndex,
    required this.header,
    required this.storyType,
    required this.relationshipId,
    required this.fileName,
    required this.config,
  });

  final int sectionIndex;
  final bool header;
  final String storyType;
  final String relationshipId;
  final String fileName;
  final SmartDocumentHeaderFooter config;
}

class _MediaPart {
  const _MediaPart({
    required this.relationshipId,
    required this.fileName,
    required this.contentType,
    required this.bytes,
    required this.widthPoints,
    required this.heightPoints,
    required this.altText,
    this.hyperlink,
    this.placement = const SmartEditorInteropObjectPlacement(),
    this.cropLeft = 0,
    this.cropTop = 0,
    this.cropRight = 0,
    this.cropBottom = 0,
    this.rotationDegrees = 0,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });

  final String relationshipId;
  final String fileName;
  final String contentType;
  final Uint8List bytes;
  final double widthPoints;
  final double heightPoints;
  final String altText;
  final String? hyperlink;
  final SmartEditorInteropObjectPlacement placement;
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;
  final double rotationDegrees;
  final bool flipHorizontal;
  final bool flipVertical;
}

class _ImageKind {
  const _ImageKind(this.extension, this.contentType);
  final String extension;
  final String contentType;
}
