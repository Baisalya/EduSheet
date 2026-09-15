import 'package:edusheet/features/teaching_planner/data/teaching_planner_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema v2 migrates to phase 15 with empty lessons', () {
    const codec = TeachingPlannerDocumentCodec();
    final workspace = codec.decode({
      'schemaVersion': 2,
      'updatedAt': '2026-09-08T00:00:00.000Z',
      'workspace': {
        'classes': [],
        'subjects': [],
        'units': [],
        'chapters': [],
        'topics': [],
      },
    });
    expect(workspace.lessonPlans, isEmpty);
    expect(codec.encode(workspace)['schemaVersion'], 7);
  });
}
