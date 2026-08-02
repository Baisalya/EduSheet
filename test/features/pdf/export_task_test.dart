import 'package:edusheet/features/pdf/services/export_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancellation token stops work at a cooperative checkpoint', () {
    final token = ExportCancellationToken()..cancel();

    expect(token.throwIfCancelled, throwsA(isA<ExportCancelledException>()));
  });

  test('failure classifier provides actionable storage messages', () {
    const classifier = ExportFailureClassifier();

    expect(
      classifier.classify(Exception('No space left on device')),
      ExportFailureKind.lowStorage,
    );
    expect(
      classifier.userMessage(Exception('Permission denied')),
      contains('Storage access was denied'),
    );
  });
}
