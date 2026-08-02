import 'package:edusheet/features/pdf/domain/models/paper_export_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('export config survives JSON round trip', () {
    const original = PaperExportConfig(
      outputMode: PaperOutputMode.teacherSolution,
      pageSize: ExportPageSize.letter,
      orientation: ExportOrientation.landscape,
      colourMode: ExportColourMode.grayscale,
      marginPoints: 36,
      setLabel: 'B',
      booklet: BookletSettings(
        enabled: true,
        gutterPoints: 24,
        signatureSize: 8,
      ),
    );

    final restored = PaperExportConfig.fromJson(original.toJson());

    expect(restored.outputMode, PaperOutputMode.teacherSolution);
    expect(restored.pageSize, ExportPageSize.letter);
    expect(restored.orientation, ExportOrientation.landscape);
    expect(restored.booklet.signatureSize, 8);
    expect(restored.validate(), isEmpty);
  });

  test('invalid margins and missing set labels are rejected', () {
    const config = PaperExportConfig(
      outputMode: PaperOutputMode.multipleSet,
      marginPoints: 4,
    );

    expect(config.validate(), hasLength(2));
  });
}
