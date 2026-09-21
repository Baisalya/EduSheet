import 'package:edusheet/features/teaching_planner/data/syllabus_import_codec.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_document_codec.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_priority.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imports the documented syllabus JSON format', () {
    const source = '''
{
  "format": "edusheet.syllabus",
  "version": 1,
  "class": {"name": "Class 10", "academicYear": "2026-27"},
  "subjects": [
    {
      "name": "Mathematics",
      "code": "MATH",
      "units": [
        {
          "title": "Number Systems",
          "plannedPeriods": 10,
          "priority": "high",
          "chapters": [
            {
              "title": "Real Numbers",
              "plannedPeriods": 6,
              "topics": [
                {"title": "Euclid", "plannedPeriods": 2}
              ]
            }
          ]
        }
      ],
      "chapters": []
    }
  ]
}
''';

    final package = const SyllabusImportCodec().decodeString(source);

    expect(package.className, 'Class 10');
    expect(package.subjects.single.name, 'Mathematics');
    expect(package.subjects.single.units.single.priority, PlannerPriority.high);
    expect(
      package.subjects.single.units.single.chapters.single.topics.single.title,
      'Euclid',
    );
  });

  test('rejects unsupported import format before changing planner data', () {
    expect(
      () =>
          const SyllabusImportCodec().decode({'format': 'other', 'version': 1}),
      throwsA(isA<SyllabusImportException>()),
    );
  });

  test('migrates phase 13 schema v1 records to v2 with normal priority', () {
    final document = {
      'schemaVersion': 1,
      'workspace': {
        'classes': [
          {
            'id': 'class-1',
            'name': 'Class 10',
            'sortOrder': 0,
            'createdAt': '2026-09-08T00:00:00.000Z',
            'updatedAt': '2026-09-08T00:00:00.000Z',
          },
        ],
        'subjects': [
          {
            'id': 'subject-1',
            'classId': 'class-1',
            'name': 'Math',
            'sortOrder': 0,
            'createdAt': '2026-09-08T00:00:00.000Z',
            'updatedAt': '2026-09-08T00:00:00.000Z',
          },
        ],
        'units': [
          {
            'id': 'unit-1',
            'subjectId': 'subject-1',
            'title': 'Unit',
            'sortOrder': 0,
            'plannedPeriods': 3,
            'createdAt': '2026-09-08T00:00:00.000Z',
            'updatedAt': '2026-09-08T00:00:00.000Z',
          },
        ],
        'chapters': [],
        'topics': [],
      },
    };

    final codec = const TeachingPlannerDocumentCodec();
    final workspace = codec.decode(document);

    expect(TeachingPlannerDocumentCodec.currentSchemaVersion, 10);
    expect(workspace.units.single.priority, PlannerPriority.normal);
  });
}
