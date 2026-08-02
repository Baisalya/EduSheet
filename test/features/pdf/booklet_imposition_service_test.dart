import 'package:edusheet/features/pdf/domain/models/paper_export_config.dart';
import 'package:edusheet/features/pdf/services/booklet_imposition_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = BookletImpositionService();

  List<int?> sequence(int pages, {int signatureSize = 0}) {
    return service
        .previewSequence(
          pages,
          settings: BookletSettings(
            enabled: true,
            signatureSize: signatureSize,
          ),
        )
        .map((page) => page.logicalPage)
        .toList();
  }

  test('imposes one four-page sheet', () {
    expect(sequence(4), [4, 1, 2, 3]);
  });

  test('pads five pages to an eight-page signature', () {
    expect(sequence(5), [null, 1, 2, null, null, 3, 4, 5]);
  });

  test('imposes an eight-page signature deterministically', () {
    expect(sequence(8), [8, 1, 2, 7, 6, 3, 4, 5]);
  });

  test('supports multiple fixed-size signatures', () {
    expect(sequence(8, signatureSize: 4), [4, 1, 2, 3, 8, 5, 6, 7]);
  });
}
