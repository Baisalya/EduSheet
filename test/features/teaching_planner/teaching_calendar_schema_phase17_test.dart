import 'package:edusheet/features/teaching_planner/data/teaching_planner_document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema v4 migrates lessons to optional unslotted scheduling', () {
    const codec = TeachingPlannerDocumentCodec();
    final workspace = codec.decode({
      'schemaVersion': 4,
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
            'title': 'Numbers',
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
            'plannedDate': '2026-09-10T00:00:00.000Z',
            'plannedPeriods': 2,
            'objective': 'Learn',
            'status': 'planned',
            'actualPeriods': 0,
            'createdAt': '2026-09-08T00:00:00.000Z',
            'updatedAt': '2026-09-08T00:00:00.000Z',
          },
        ],
      },
    });
    expect(workspace.lessonPlans.single.startPeriod, isNull);
    expect(codec.encode(workspace)['schemaVersion'], 7);
  });
}
