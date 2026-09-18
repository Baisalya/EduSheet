import 'dart:io';

import 'package:edusheet/features/word_converter/domain/models/conversion_history_entry.dart';
import 'package:edusheet/features/word_converter/services/conversion_history_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recent conversions persist, deduplicate and ignore missing files', () async {
    SharedPreferences.setMockInitialValues(const {});
    final directory = await Directory.systemTemp.createTemp('converter_history_');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final output = File('${directory.path}${Platform.pathSeparator}output.docx');
    await output.writeAsString('docx');

    final first = ConversionHistoryEntry(
      outputPath: output.path,
      sourceName: 'source.pdf',
      modeLabel: 'PDF → Word · Editable Document',
      createdAt: DateTime(2026, 9, 17, 20),
      sizeBytes: 4,
    );
    final updated = ConversionHistoryEntry(
      outputPath: output.path,
      sourceName: 'source.pdf',
      modeLabel: 'PDF → Word · Editable Document',
      createdAt: DateTime(2026, 9, 17, 21),
      sizeBytes: 4,
    );

    await ConversionHistoryService.add(first);
    final afterUpdate = await ConversionHistoryService.add(updated);
    expect(afterUpdate, hasLength(1));
    expect(afterUpdate.single.createdAt, updated.createdAt);

    await output.delete();
    expect(await ConversionHistoryService.load(), isEmpty);
  });
}
