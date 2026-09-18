import 'dart:io';

import 'package:edusheet/features/word_converter/services/word_converter_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows runner owns the PDF renderer platform-channel contract', () async {
    final bridge = await File(
      'windows/runner/pdf_renderer_bridge.cpp',
    ).readAsString();
    final runner = await File(
      'windows/runner/flutter_window.cpp',
    ).readAsString();
    final cmake = await File(
      'windows/runner/CMakeLists.txt',
    ).readAsString();

    expect(bridge, contains('edusheet/pdf_renderer'));
    expect(bridge, contains('renderPagesToImages'));
    expect(bridge, contains('PdfDocument::LoadFromFileAsync'));
    expect(bridge, contains('RenderToStreamAsync'));
    expect(bridge, contains('BitmapEncoder::PngEncoderId'));
    expect(bridge, contains('IsIgnoringHighContrast(true)'));
    expect(bridge, contains('RemoveDirectoryBestEffort'));
    expect(bridge, contains('CleanupStaleRenderDirectories'));
    expect(runner, contains('PdfRendererBridge'));
    expect(cmake, contains('pdf_renderer_bridge.cpp'));
  });

  test('Windows host advertises Preserve Appearance capability', () {
    if (Platform.isWindows) {
      expect(
        WordConverterService.supportsPdfAppearancePreservation,
        isTrue,
      );
    }
  });
}
