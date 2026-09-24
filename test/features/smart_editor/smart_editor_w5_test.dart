import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/smart_editor/data/smart_document_repository.dart';
import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/features/smart_editor/presentation/providers/smart_editor_provider.dart';
import 'package:edusheet/features/smart_editor/presentation/screens/smart_editor_library_screen.dart';
import 'package:edusheet/features/smart_editor/presentation/screens/smart_editor_screen.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_interop_embed_builders.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_binary_file_saver.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_service.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('W5 DOCX export emits standard Word content and exact native round trip', () async {
    const expression = MathExpression(
      id: 'w5-equation',
      latex: r'x^2 + y^2 = r^2',
      plainText: 'x squared plus y squared equals r squared',
    );
    final document = _sampleDocument(expression);
    final service = const SmartEditorDocxService();

    final exported = await service.export(document);
    final archive = ZipDecoder().decodeBytes(exported.bytes);
    final documentXml = _textEntry(archive, 'word/document.xml');
    final documentRels = _textEntry(archive, 'word/_rels/document.xml.rels');
    final nativeXml = _textEntry(
      archive,
      SmartEditorDocxService.roundTripPartName,
    );

    expect(exported.bytes, isNotEmpty);
    expect(documentXml, contains('Editable Word text'));
    expect(documentXml, contains('<m:oMath'));
    expect(documentXml, contains('<w:headerReference'));
    expect(documentXml, contains('<w:footerReference'));
    expect(documentXml, contains('<w:hyperlink'));
    expect(documentRels, contains('relationships/hyperlink'));
    expect(documentRels, contains('https://example.com/lesson'));
    expect(nativeXml, contains('documentSha256='));
    expect(nativeXml, contains('payloadSha256='));
    expect(nativeXml, contains('wordContentSha256='));

    final directory = await Directory.systemTemp.createTemp('edusheet-w5-native-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = File('${directory.path}${Platform.pathSeparator}round_trip.docx');
    await file.writeAsBytes(exported.bytes, flush: true);

    final imported = await service.importFile(file);
    expect(imported.nativeRoundTrip, isTrue);
    expect(imported.document.title, document.title);
    expect(imported.document.header.text, document.header.text);
    expect(imported.document.footer.text, document.footer.text);
    expect(_containsToken(imported.document.deltaJson, expression.latex), isTrue);
  });

  test('W5 rejects unknown native metadata versions and falls back safely', () async {
    final document = SmartDocument.blank(title: 'Metadata version').copyWith(
      deltaJson: const <dynamic>[
        <String, dynamic>{'insert': 'Version-safe Word text'},
        <String, dynamic>{'insert': '\n'},
      ],
    );
    final service = const SmartEditorDocxService();
    final exported = await service.export(document);
    final source = ZipDecoder().decodeBytes(exported.bytes);
    final edited = Archive();
    for (final entry in source.files) {
      final bytes = Uint8List.fromList(entry.content as List<int>);
      if (entry.name == SmartEditorDocxService.roundTripPartName) {
        final xml = utf8.decode(bytes).replaceFirst('version="1"', 'version="99"');
        edited.addFile(ArchiveFile.string(entry.name, xml));
      } else {
        edited.addFile(ArchiveFile.bytes(entry.name, bytes));
      }
    }

    final directory = await Directory.systemTemp.createTemp('edusheet-w5-version-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = File('${directory.path}${Platform.pathSeparator}versioned.docx');
    await file.writeAsBytes(ZipEncoder().encode(edited), flush: true);

    final imported = await service.importFile(file);
    expect(imported.nativeRoundTrip, isFalse);
    expect(_plainText(imported.document), contains('Version-safe Word text'));
  });

  test('W5 rejects stale native metadata after external Word content changes', () async {
    final document = SmartDocument.blank(title: 'External edit safety').copyWith(
      deltaJson: const <dynamic>[
        <String, dynamic>{'insert': 'Original Word text'},
        <String, dynamic>{'insert': '\n'},
      ],
    );
    final service = const SmartEditorDocxService();
    final exported = await service.export(document);
    final source = ZipDecoder().decodeBytes(exported.bytes);
    final edited = Archive();

    for (final entry in source.files) {
      final bytes = Uint8List.fromList(entry.content as List<int>);
      if (entry.name == 'word/document.xml') {
        final xml = utf8
            .decode(bytes)
            .replaceFirst('Original Word text', 'Changed in Microsoft Word');
        edited.addFile(ArchiveFile.string(entry.name, xml));
      } else {
        edited.addFile(ArchiveFile.bytes(entry.name, bytes));
      }
    }

    final directory = await Directory.systemTemp.createTemp('edusheet-w5-stale-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = File('${directory.path}${Platform.pathSeparator}edited.docx');
    await file.writeAsBytes(ZipEncoder().encode(edited), flush: true);

    final imported = await service.importFile(file);
    expect(imported.nativeRoundTrip, isFalse);
    expect(_plainText(imported.document), contains('Changed in Microsoft Word'));
    expect(_plainText(imported.document), isNot(contains('Original Word text')));
  });

  test('W5 rejects native restore when Word changes header content', () async {
    const expression = MathExpression(
      id: 'w5-header-equation',
      latex: r'a+b=c',
      plainText: 'a plus b equals c',
    );
    final service = const SmartEditorDocxService();
    final exported = await service.export(_sampleDocument(expression));
    final source = ZipDecoder().decodeBytes(exported.bytes);
    final edited = Archive();

    for (final entry in source.files) {
      final bytes = Uint8List.fromList(entry.content as List<int>);
      if (entry.name == 'word/header1.xml') {
        final xml = utf8
            .decode(bytes)
            .replaceFirst('School header', 'Header changed in Word');
        edited.addFile(ArchiveFile.string(entry.name, xml));
      } else {
        edited.addFile(ArchiveFile.bytes(entry.name, bytes));
      }
    }

    final directory = await Directory.systemTemp.createTemp('edusheet-w5-header-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = File('${directory.path}${Platform.pathSeparator}header-edited.docx');
    await file.writeAsBytes(ZipEncoder().encode(edited), flush: true);

    final imported = await service.importFile(file);
    expect(imported.nativeRoundTrip, isFalse);
    expect(imported.document.header.text, contains('Header changed in Word'));
    expect(imported.document.header.text, isNot(contains('School header')));
  });

  test('W5 rejects native restore when Word changes an exported media part', () async {
    final image = SmartEditorInteropImagePayload(
      bytes: Uint8List.fromList(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/l9vLagAAAABJRU5ErkJggg==',
        ),
      ),
      widthPoints: 72,
      heightPoints: 72,
      altText: 'Tiny image',
    );
    final document = SmartDocument.blank(title: 'Media fingerprint').copyWith(
      deltaJson: <dynamic>[
        <String, dynamic>{
          'insert': <String, dynamic>{
            SmartEditorInteropImageEmbedBuilder.keyName: image.encode(),
          },
        },
        const <String, dynamic>{'insert': '\n'},
      ],
    );
    final service = const SmartEditorDocxService();
    final exported = await service.export(document);
    final source = ZipDecoder().decodeBytes(exported.bytes);
    final edited = Archive();

    for (final entry in source.files) {
      final bytes = Uint8List.fromList(entry.content as List<int>);
      if (entry.name.startsWith('word/media/')) {
        final changed = Uint8List.fromList(bytes);
        changed[changed.length - 1] ^= 0x01;
        edited.addFile(ArchiveFile.bytes(entry.name, changed));
      } else {
        edited.addFile(ArchiveFile.bytes(entry.name, bytes));
      }
    }

    final directory = await Directory.systemTemp.createTemp('edusheet-w5-media-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = File('${directory.path}${Platform.pathSeparator}media-edited.docx');
    await file.writeAsBytes(ZipEncoder().encode(edited), flush: true);

    final imported = await service.importFile(file);
    expect(imported.nativeRoundTrip, isFalse);
    expect(
      _containsToken(
        imported.document.deltaJson,
        SmartEditorInteropImageEmbedBuilder.keyName,
      ),
      isTrue,
    );
  });

  test('W5 standard DOCX compatibility import survives without native metadata', () async {
    final document = SmartDocument.blank(title: 'Standard compatibility').copyWith(
      deltaJson: const <dynamic>[
        <String, dynamic>{
          'insert': 'Styled heading',
          'attributes': <String, dynamic>{'bold': true, 'color': '#336699'},
        },
        <String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'header': 1, 'align': 'center'},
        },
        <String, dynamic>{'insert': 'Body paragraph '},
        <String, dynamic>{
          'insert': 'standard link',
          'attributes': <String, dynamic>{
            'link': 'https://example.com/standard',
          },
        },
        <String, dynamic>{'insert': '\n'},
      ],
    );
    final service = const SmartEditorDocxService();
    final exported = await service.export(document);
    final source = ZipDecoder().decodeBytes(exported.bytes);
    final standardOnly = Archive();
    for (final entry in source.files) {
      if (entry.name == SmartEditorDocxService.roundTripPartName) continue;
      standardOnly.addFile(
        ArchiveFile.bytes(
          entry.name,
          Uint8List.fromList(entry.content as List<int>),
        ),
      );
    }

    final directory = await Directory.systemTemp.createTemp('edusheet-w5-standard-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = File('${directory.path}${Platform.pathSeparator}standard.docx');
    await file.writeAsBytes(ZipEncoder().encode(standardOnly), flush: true);

    final imported = await service.importFile(file);
    expect(imported.nativeRoundTrip, isFalse);
    expect(_plainText(imported.document), contains('Styled heading'));
    expect(_plainText(imported.document), contains('Body paragraph'));
    expect(imported.document.quillOperations, isNotEmpty);
    expect(
      _containsAttribute(
        imported.document.deltaJson,
        key: 'link',
        expected: 'https://example.com/standard',
      ),
      isTrue,
    );
  });

  test('W5 binary saver keeps Android provider bytes and desktop extension safety', () async {
    SmartEditorBinarySaveRequest? androidRequest;
    var androidWrites = 0;
    final androidSaver = SmartEditorBinaryFileSaver(
      isAndroid: true,
      saveFile: (request) async {
        androidRequest = request;
        return 'content://documents/export';
      },
      writeBytes: (_, _) async {
        androidWrites++;
      },
    );
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    final androidPath = await androidSaver.save(
      bytes: bytes,
      fileName: 'Lesson',
      extension: 'docx',
      dialogTitle: 'Save Word',
    );
    expect(androidPath, 'content://documents/export');
    expect(androidRequest?.fileName, 'Lesson.docx');
    expect(androidRequest?.bytes, bytes);
    expect(androidWrites, 0);

    String? desktopWritePath;
    Uint8List? desktopWriteBytes;
    final desktopSaver = SmartEditorBinaryFileSaver(
      isAndroid: false,
      saveFile: (_) async => r'C:\Exports\Lesson',
      writeBytes: (path, data) async {
        desktopWritePath = path;
        desktopWriteBytes = data;
      },
    );
    final desktopPath = await desktopSaver.save(
      bytes: bytes,
      fileName: 'Lesson.pdf',
      extension: 'pdf',
      dialogTitle: 'Save PDF',
    );
    expect(desktopPath, r'C:\Exports\Lesson.pdf');
    expect(desktopWritePath, r'C:\Exports\Lesson.pdf');
    expect(desktopWriteBytes, bytes);
  });

  test('W5 PDF export produces a real PDF for ordinary Smart Editor content', () async {
    final document = SmartDocument.blank(title: 'PDF export').copyWith(
      deltaJson: const <dynamic>[
        <String, dynamic>{'insert': 'Printable Smart Editor document'},
        <String, dynamic>{'insert': '\n'},
      ],
    );
    final result = await const SmartEditorPdfService().export(document);
    expect(result.bytes.length, greaterThan(100));
    expect(utf8.decode(result.bytes.take(4).toList()), '%PDF');
  });

  testWidgets('W5 surfaces Word import and Word/PDF export in Smart Editor UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemorySmartDocumentRepository();
    final document = SmartDocument.blank(title: 'Interop UI');
    await repository.save(document);

    Widget app(Widget home) => ProviderScope(
          overrides: [
            smartDocumentRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en', 'US')],
            home: home,
          ),
        );

    await tester.pumpWidget(app(const SmartEditorLibraryScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('smart-editor-import-docx')), findsOneWidget);

    await tester.pumpWidget(app(SmartEditorScreen(document: document)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('smart-editor-open-docx')), findsOneWidget);
    expect(find.byKey(const Key('smart-editor-export')), findsOneWidget);
    await tester.tap(find.byKey(const Key('smart-editor-export')));
    await tester.pumpAndSettle();
    expect(find.text('Export Word (.docx)'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
  });

  testWidgets('W5 compact Smart Editor keeps export/save inside a More menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _MemorySmartDocumentRepository();
    final document = SmartDocument.blank(title: 'Compact interop');
    await repository.save(document);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smartDocumentRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en', 'US')],
          home: SmartEditorScreen(document: document),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('smart-editor-mobile-more')), findsOneWidget);
    expect(find.byKey(const Key('smart-editor-export')), findsNothing);
    expect(find.byKey(const Key('smart-editor-save')), findsNothing);

    await tester.tap(find.byKey(const Key('smart-editor-mobile-more')));
    await tester.pumpAndSettle();
    expect(find.text('Open / import Word (.docx)'), findsOneWidget);
    expect(find.text('Export Word (.docx)'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
    expect(find.text('Save now'), findsOneWidget);
  });
}

SmartDocument _sampleDocument(MathExpression expression) {
  final now = DateTime.utc(2026, 9, 22);
  return SmartDocument(
    id: 'w5-round-trip',
    title: 'W5 Round Trip',
    deltaJson: <dynamic>[
      const <String, dynamic>{
        'insert': 'Editable Word text with equation ',
        'attributes': <String, dynamic>{'bold': true},
      },
      <String, dynamic>{
        'insert': <String, dynamic>{
          MathExpression.quillEmbedKey: expression.toQuillEmbedData(),
        },
      },
      const <String, dynamic>{'insert': '  '},
      const <String, dynamic>{
        'insert': 'Lesson link',
        'attributes': <String, dynamic>{
          'link': 'https://example.com/lesson',
        },
      },
      const <String, dynamic>{'insert': '\n'},
    ],
    pageLayout: const SmartDocumentPageLayout(
      marginPreset: SmartDocumentMarginPreset.custom,
      customTopMargin: 54,
      customRightMargin: 60,
      customBottomMargin: 54,
      customLeftMargin: 60,
      borderStyle: SmartDocumentPageBorderStyle.solid,
    ),
    header: const SmartDocumentHeaderFooter(
      enabled: true,
      text: 'School header',
      showDivider: true,
    ),
    footer: const SmartDocumentHeaderFooter(
      enabled: true,
      text: 'Teacher footer',
      alignment: SmartDocumentHeaderFooterAlignment.right,
    ),
    createdAt: now,
    updatedAt: now,
  );
}

String _textEntry(Archive archive, String name) {
  final entry = archive.files.firstWhere((file) => file.name == name);
  return utf8.decode(entry.content as List<int>);
}

String _plainText(SmartDocument document) {
  final buffer = StringBuffer();
  for (final operation in document.quillOperations) {
    final insert = operation['insert'];
    if (insert is String) buffer.write(insert);
  }
  return buffer.toString();
}

bool _containsToken(Object? value, String token) {
  if (value is Map) {
    return value.entries.any(
      (entry) =>
          entry.key.toString().contains(token) ||
          _containsToken(entry.value, token),
    );
  }
  if (value is Iterable) {
    return value.any((item) => _containsToken(item, token));
  }
  return value?.toString().contains(token) == true;
}

bool _containsAttribute(
  Object? node, {
  required String key,
  required String expected,
}) {
  if (node is Map) {
    if (node[key]?.toString() == expected) return true;
    for (final nested in node.values) {
      if (_containsAttribute(nested, key: key, expected: expected)) return true;
    }
    return false;
  }
  if (node is Iterable) {
    for (final nested in node) {
      if (_containsAttribute(nested, key: key, expected: expected)) return true;
    }
  }
  return false;
}

class _MemorySmartDocumentRepository implements SmartDocumentRepository {
  final Map<String, SmartDocument> _items = <String, SmartDocument>{};

  @override
  Future<void> delete(String id) async => _items.remove(id);

  @override
  Future<List<SmartDocument>> getAll() async => _items.values.toList();

  @override
  Future<SmartDocument?> getById(String id) async => _items[id];

  @override
  Future<void> save(SmartDocument document) async {
    _items[document.id] = document;
  }
}
