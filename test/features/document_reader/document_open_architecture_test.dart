import 'dart:io';

import 'package:edusheet/features/document_reader/application/document_open_coordinator.dart';
import 'package:edusheet/features/document_reader/data/repositories/document_repository.dart';
import 'package:edusheet/features/document_reader/domain/models/document_model.dart';
import 'package:edusheet/features/document_reader/domain/models/document_open_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentFile capability policy', () {
    test('distinguishes in-app renderers from recognized external formats', () {
      expect(
        DocumentFile.capabilityForExtension('.pdf').level,
        DocumentSupportLevel.native,
      );
      expect(DocumentFile.capabilityForExtension('.docx').canPreview, isTrue);
      expect(DocumentFile.capabilityForExtension('.xlsx').canPreview, isTrue);
      expect(DocumentFile.capabilityForExtension('.pptx').canPreview, isTrue);
      expect(
        DocumentFile.capabilityForExtension('.ppt').level,
        DocumentSupportLevel.externalOnly,
      );
      expect(
        DocumentFile.capabilityForExtension('.bin').level,
        DocumentSupportLevel.unsupported,
      );
    });
  });

  test('platform request preserves Windows warm activation metadata', () {
    final request = DocumentOpenRequest.fromPlatformMap({
      'path': r'C:\Users\Teacher\Lesson Slides.pptx',
      'source': 'windowsCommandLine',
      'activationId': 'windows:123',
    });

    expect(request.source, DocumentOpenSource.windowsCommandLine);
    expect(request.localPath, r'C:\Users\Teacher\Lesson Slides.pptx');
    expect(request.activationId, 'windows:123');
  });

  test('platform request preserves Android activation metadata', () {
    final request = DocumentOpenRequest.fromPlatformMap({
      'path': '/tmp/report.pdf',
      'uri': 'content://provider/report',
      'name': 'Teacher Report.pdf',
      'mimeType': 'application/pdf',
      'source': 'androidViewIntent',
      'activationId': 'view:content://provider/report',
    });

    expect(request.source, DocumentOpenSource.androidViewIntent);
    expect(request.displayName, 'Teacher Report.pdf');
    expect(request.originalUri, 'content://provider/report');
    expect(request.dedupeKey, 'view:content://provider/report');
  });

  test(
    'coordinator keeps user opens repeatable but suppresses duplicate platform activation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'edusheet-open-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}sample.txt',
      );
      await file.writeAsString('hello');

      final coordinator = DocumentOpenCoordinator(DocumentRepository());
      final userRequest = DocumentOpenRequest.fromFilePicker(file.path);
      final first = await coordinator.resolve(userRequest);
      final secondUserOpen = await coordinator.resolve(userRequest);

      expect(first.isSuccess, isTrue);
      expect(first.session!.document.name, 'sample.txt');
      expect(first.session!.document.canPreview, isTrue);
      expect(secondUserOpen.isSuccess, isTrue);

      final platformRequest = DocumentOpenRequest.fromPlatformMap({
        'path': file.path,
        'name': 'sample.txt',
        'mimeType': 'text/plain',
        'uri': 'content://provider/sample',
        'source': 'androidViewIntent',
        'activationId': 'view:content://provider/sample',
      });
      final platformFirst = await coordinator.resolve(platformRequest);
      final platformDuplicate = await coordinator.resolve(platformRequest);
      expect(platformFirst.isSuccess, isTrue);
      expect(platformDuplicate.duplicate, isTrue);
    },
  );

  test('repository uses the original display extension for cached files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'edusheet-cache-test',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}incoming_cache',
    );
    await file.writeAsString('placeholder');

    final document = await DocumentRepository().getDocumentFromRequest(
      DocumentOpenRequest(
        source: DocumentOpenSource.androidViewIntent,
        localPath: file.path,
        displayName: 'Lesson Slides.pptx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        originalUri: 'content://provider/slides',
      ),
    );

    expect(document, isNotNull);
    expect(document!.extension, '.pptx');
    expect(document.name, 'Lesson Slides.pptx');
    expect(document.originalUri, 'content://provider/slides');
  });

  test('desktop command-line request keeps paths with spaces intact', () {
    final request = DocumentOpenRequest.fromCommandLine([
      '--ignored-flag',
      'C:/Users/Teacher/My Lesson.pdf',
    ]);

    expect(request, isNotNull);
    expect(request!.localPath, 'C:/Users/Teacher/My Lesson.pdf');
    expect(request.displayName, 'My Lesson.pdf');
    expect(request.source, DocumentOpenSource.windowsCommandLine);
  });
}
