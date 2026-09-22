import 'dart:convert';
import 'dart:io';

import 'package:edusheet/features/teaching_planner/data/local_teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_document_codec.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_class.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'repository save/reopen preserves stable ids and schema envelope',
    () async {
      final directory = await Directory.systemTemp.createTemp('planner-repo-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/teaching_planner.json');
      final repository = LocalTeachingPlannerRepository(
        fileResolver: () async => file,
      );
      final now = DateTime.utc(2026, 9, 8, 10);
      final workspace = TeachingPlannerWorkspace(
        classes: [
          PlannerClass(
            id: 'stable-class-id',
            name: 'Class 10',
            academicYear: '2026-27',
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      await repository.save(workspace);
      final reopened = LocalTeachingPlannerRepository(
        fileResolver: () async => file,
      );
      final restored = await reopened.load();
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

      expect(restored.classes.single.id, 'stable-class-id');
      expect(restored.classes.single.academicYear, '2026-27');
      expect(
        raw['schemaVersion'],
        TeachingPlannerDocumentCodec.currentSchemaVersion,
      );
      expect(raw['workspace'], isA<Map>());
    },
  );

  test('semantic corruption recovers from the last valid backup', () async {
    final directory = await Directory.systemTemp.createTemp('planner-repo-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/teaching_planner.json');
    final repository = LocalTeachingPlannerRepository(
      fileResolver: () async => file,
    );
    final first = TeachingPlannerWorkspace(
      classes: [
        PlannerClass(
          id: 'first',
          name: 'Class 9',
          sortOrder: 0,
          createdAt: DateTime.utc(2026, 9, 8),
          updatedAt: DateTime.utc(2026, 9, 8),
        ),
      ],
    );
    final second = TeachingPlannerWorkspace(
      classes: [
        PlannerClass(
          id: 'second',
          name: 'Class 10',
          sortOrder: 0,
          createdAt: DateTime.utc(2026, 9, 8),
          updatedAt: DateTime.utc(2026, 9, 8),
        ),
      ],
    );

    await repository.save(first);
    await repository.save(second);
    final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    (raw['workspace'] as Map<String, dynamic>)['topics'] = [
      {
        'id': 'orphan',
        'chapterId': 'missing',
        'title': 'Broken topic',
        'sortOrder': 0,
        'plannedPeriods': 0,
        'actualPeriods': 0,
        'status': 'planned',
        'createdAt': '2026-09-08T00:00:00.000Z',
        'updatedAt': '2026-09-08T00:00:00.000Z',
      },
    ];
    await file.writeAsString(jsonEncode(raw), flush: true);

    final restored = await repository.load();

    expect(restored.classes.single.id, 'first');
  });

  test(
    'concurrent repository updates are serialized without lost writes',
    () async {
      final directory = await Directory.systemTemp.createTemp('planner-repo-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/teaching_planner.json');
      final repository = LocalTeachingPlannerRepository(
        fileResolver: () async => file,
      );
      final now = DateTime.utc(2026, 9, 8);

      Future<void> addClass(String id) async {
        await repository.update(
          (workspace) => workspace.copyWith(
            classes: [
              ...workspace.classes,
              PlannerClass(
                id: id,
                name: id,
                sortOrder: workspace.classes.length,
                createdAt: now,
                updatedAt: now,
              ),
            ],
          ),
        );
      }

      await Future.wait([addClass('Class A'), addClass('Class B')]);
      final restored = await repository.load();

      expect(restored.classes.map((item) => item.id).toSet(), {
        'Class A',
        'Class B',
      });
    },
  );

  test('phase 13 schema v1 is migrated to phase 14 priority fields', () async {
    final directory = await Directory.systemTemp.createTemp('planner-repo-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/teaching_planner.json');
    await file.writeAsString(
      jsonEncode({
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
      }),
    );

    final repository = LocalTeachingPlannerRepository(
      fileResolver: () async => file,
    );
    final restored = await repository.load();

    expect(restored.units.single.priority.name, 'normal');
    expect(TeachingPlannerDocumentCodec.currentSchemaVersion, 11);
  });

  test('newer unknown schema fails safely', () async {
    final directory = await Directory.systemTemp.createTemp('planner-repo-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/teaching_planner.json');
    await file.writeAsString(
      jsonEncode({
        'schemaVersion': 999,
        'workspace': {
          'classes': [],
          'subjects': [],
          'units': [],
          'chapters': [],
          'topics': [],
        },
      }),
    );
    final repository = LocalTeachingPlannerRepository(
      fileResolver: () async => file,
    );

    await expectLater(
      repository.load(),
      throwsA(isA<TeachingPlannerRepositoryException>()),
    );
  });
}
