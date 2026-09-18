import 'package:edusheet/features/document_reader/domain/models/document_model.dart';
import 'package:edusheet/features/document_reader/presentation/responsive/document_viewport_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 8 release-supported document formats keep honest capabilities', () {
    for (final extension in const [
      '.pdf',
      '.docx',
      '.xlsx',
      '.csv',
      '.pptx',
      '.txt',
    ]) {
      final capability = DocumentFile.capabilityForExtension(extension);
      expect(capability.canPreview, isTrue, reason: extension);
      expect(
        {
          DocumentSupportLevel.externalOnly,
          DocumentSupportLevel.unsupported,
        }.contains(capability.level),
        isFalse,
        reason: extension,
      );
    }

    for (final extension in const [
      '.doc',
      '.rtf',
      '.odt',
      '.xls',
      '.ods',
      '.ppt',
      '.odp',
    ]) {
      final capability = DocumentFile.capabilityForExtension(extension);
      expect(capability.canPreview, isFalse, reason: extension);
      expect(
        capability.level,
        DocumentSupportLevel.externalOnly,
        reason: extension,
      );
    }
  });

  test('Phase 8 phone widths cannot force Word fit-width horizontal overflow', () {
    for (final width in const [320.0, 360.0, 390.0]) {
      final policy = DocumentViewportPolicy(width: width, height: 844);
      final occupied =
          policy.wordFitWidthPageWidth + (policy.wordHorizontalGutter * 2);
      expect(policy.preferWordFitWidth, isTrue);
      expect(occupied, lessThanOrEqualTo(width));
    }
  });
}
