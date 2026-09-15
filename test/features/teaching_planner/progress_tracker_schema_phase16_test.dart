import 'package:edusheet/features/teaching_planner/data/teaching_planner_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema v3 migrates lesson tracking fields to phase 16', () {
    const codec = TeachingPlannerDocumentCodec();
    final workspace = codec.decode({
      'schemaVersion': 3,
      'updatedAt': '2026-09-08T00:00:00.000Z',
      'workspace': {
        'classes': [
          {
            'id': 'c',
            'name': 'Class 10',
            'sortOrder': 0,
            'createdAt': '2026-09-08T00:00:00.000Z',
            'updatedAt': '2026-09-08T00:00:00.000Z',
          },
        ],
        'subjects': [
          {
            'id': 's',
            'classId': 'c',
            'name': 'Math',
            'sortOrder': 0,
            'createdAt': '2026-09-08T00:00:00.000Z',
            'updatedAt': '2026-09-08T00:00:00.000Z',
          },
        ],
        'units': [],
        'chapters': [
          {
            'id': 'h',
            'subjectId': 's',
            'title': 'Algebra',
            'sortOrder': 0,
            'plannedPeriods': 2,
            'priority': 'normal',
            'createdAt': '2026-09-08T00:00:00.000Z',
            'updatedAt': '2026-09-08T00:00:00.000Z',
          },
        ],
        'topics': [],
        'lessonPlans': [
          {
            'id': 'l',
            'classId': 'c',
            'subjectId': 's',
            'chapterId': 'h',
            'topicIds': [],
            'title': 'Lesson',
            'plannedDate': '2026-09-09T00:00:00.000Z',
            'plannedPeriods': 2,
            'objective': 'Learn',
            'status': 'planned',
            'createdAt': '2026-09-08T00:00:00.000Z',
            'updatedAt': '2026-09-08T00:00:00.000Z',
          },
        ],
      },
    });
    expect(workspace.lessonPlans.single.actualPeriods, 0);
    expect(codec.encode(workspace)['schemaVersion'], 7);
  });
}
