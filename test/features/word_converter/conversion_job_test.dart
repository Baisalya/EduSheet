import 'package:edusheet/features/word_converter/domain/models/conversion_job.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('progress fraction is bounded and cancellation is cooperative', () {
    const progress = ConversionProgress(
      stage: ConversionStage.processingPages,
      message: 'Processing',
      current: 3,
      total: 4,
    );
    expect(progress.fraction, 0.75);

    final token = ConversionCancellationToken();
    expect(token.isCancelled, isFalse);
    token.cancel();
    expect(token.isCancelled, isTrue);
    expect(token.throwIfCancelled, throwsA(isA<ConversionCancelledException>()));
  });
}
