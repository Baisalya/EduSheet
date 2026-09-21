import 'dart:io';

import 'package:edusheet/features/document_reader/domain/models/document_open_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop activation queues every supported file once in argument order', () {
    final requests = DocumentOpenRequest.fromCommandLineAll([
      '--some-flag',
      r'C:\School\Math Notes.pdf',
      r'C:\School\Planner Backup.eds',
      r'C:\School\Teaching Pack.edtp',
      r'C:\School\not-supported.bin',
      r'C:\School\Math Notes.pdf',
    ]);

    expect(requests.map((request) => request.effectiveExtension), [
      '.pdf',
      '.eds',
      '.edtp',
    ]);
    expect(requests[1].displayName, 'Planner Backup.eds');
    expect(requests[2].source, DocumentOpenSource.windowsCommandLine);
  });

  test('legacy single command-line helper returns the first supported file', () {
    final request = DocumentOpenRequest.fromCommandLine([
      r'C:\School\ignored.bin',
      r'C:\School\First.eds',
      r'C:\School\Second.edtp',
    ]);

    expect(request, isNotNull);
    expect(request!.effectiveExtension, '.eds');
  });

  test('Windows registration owns portable types but keeps common docs Open-with', () {
    final script = File('REGISTER_WINDOWS_FILE_ASSOCIATIONS.ps1').readAsStringSync();

    expect(script, contains('EduSheet.Package'));
    expect(script, contains('EduSheet.TeachingPack'));
    expect(script, contains('application/vnd.baishalya.edusheet'));
    expect(script, contains('application/vnd.baishalya.edusheet-teaching-pack'));
    expect(script, contains(r'Set-Item -Path $extensionKey -Value $type.ProgId'));
    expect(script, contains(r'$documentExtensions'));
    expect(script, contains('OpenWithProgids'));
  });

  test('Android native bridge recognizes portable EduSheet MIME types', () {
    final source = File(
      'android/app/src/main/java/com/baishalya/edusheet/MainActivity.java',
    ).readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(source, contains('application/vnd.baishalya.edusheet'));
    expect(source, contains('return ".eds"'));
    expect(source, contains('application/vnd.baishalya.edusheet-teaching-pack'));
    expect(source, contains('return ".edtp"'));
    expect(manifest, contains('android:pathPattern=".*\\.eds"'));
    expect(manifest, contains('android:pathPattern=".*\\.edtp"'));
  });
}
