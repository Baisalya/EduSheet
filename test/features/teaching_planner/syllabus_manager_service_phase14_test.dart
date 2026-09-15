import 'package:edusheet/features/teaching_planner/application/teaching_planner_service.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_priority.dart';
import 'package:edusheet/features/teaching_planner/domain/models/syllabus_import_package.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('updates syllabus records without changing stable ids', () async {
    final repository = _MemoryPlannerRepository();
    var counter = 0;
    final service = TeachingPlannerService(
      repository,
      idGenerator: () => 'id-${counter++}',
      clock: () => DateTime.utc(2026, 9, 8, 12),
    );

    var workspace = await service.createClass(name: 'Class 10');
    final classId = workspace.classes.single.id;
    workspace = await service.createSubject(classId: classId, name: 'Math');
    final subjectId = workspace.subjects.single.id;
    workspace = await service.createUnit(
      subjectId: subjectId,
      title: 'Unit 1',
      plannedPeriods: 8,
      priority: PlannerPriority.normal,
    );
    final unitId = workspace.units.single.id;
    workspace = await service.createChapter(
      subjectId: subjectId,
      unitId: unitId,
      title: 'Real Numbers',
    );
    final chapterId = workspace.chapters.single.id;
    workspace = await service.createTopic(
      chapterId: chapterId,
      title: 'Euclid',
    );
    final topicId = workspace.topics.single.id;

    workspace = await service.updateClass(
      classId,
      name: 'Class 10 A',
      academicYear: '2026-27',
    );
    workspace = await service.updateSubject(
      subjectId,
      name: 'Mathematics',
      code: 'MATH',
    );
    workspace = await service.updateUnit(
      unitId,
      title: 'Number Systems',
      plannedPeriods: 10,
      priority: PlannerPriority.high,
    );
    workspace = await service.updateChapter(
      chapterId,
      title: 'Real Numbers',
      plannedPeriods: 6,
      priority: PlannerPriority.high,
      unitId: unitId,
    );
    workspace = await service.updateTopic(
      topicId,
      title: 'Euclid Division Lemma',
      plannedPeriods: 2,
      priority: PlannerPriority.high,
    );

    expect(workspace.classes.single.id, classId);
    expect(workspace.subjects.single.id, subjectId);
    expect(workspace.units.single.id, unitId);
    expect(workspace.chapters.single.id, chapterId);
    expect(workspace.topics.single.id, topicId);
    expect(workspace.units.single.priority, PlannerPriority.high);
    expect(workspace.topics.single.plannedPeriods, 2);
  });

  test(
    'imports a syllabus as a new class with fresh ids and planned state',
    () async {
      final repository = _MemoryPlannerRepository();
      var counter = 0;
      final service = TeachingPlannerService(
        repository,
        idGenerator: () => 'import-${counter++}',
        clock: () => DateTime.utc(2026, 9, 8, 12),
      );

      final package = SyllabusImportPackage(
        className: 'Class 9',
        academicYear: '2026-27',
        subjects: [
          SyllabusImportSubject(
            name: 'Mathematics',
            code: 'MATH',
            units: [
              SyllabusImportUnit(
                title: 'Number Systems',
                plannedPeriods: 10,
                priority: PlannerPriority.high,
                chapters: [
                  SyllabusImportChapter(
                    title: 'Real Numbers',
                    plannedPeriods: 6,
                    priority: PlannerPriority.high,
                    topics: [
                      SyllabusImportTopic(
                        title: 'Euclid Division Lemma',
                        plannedPeriods: 2,
                        priority: PlannerPriority.high,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final workspace = await service.importSyllabus(package);

      expect(workspace.classes.single.name, 'Class 9');
      expect(workspace.subjects.single.classId, workspace.classes.single.id);
      expect(workspace.units.single.subjectId, workspace.subjects.single.id);
      expect(workspace.chapters.single.unitId, workspace.units.single.id);
      expect(workspace.topics.single.chapterId, workspace.chapters.single.id);
      expect(workspace.topics.single.actualPeriods, 0);
      expect(workspace.topics.single.priority, PlannerPriority.high);
    },
  );

  test(
    'reordering subjects and units requires the complete active sibling set',
    () async {
      final repository = _MemoryPlannerRepository();
      var counter = 0;
      final service = TeachingPlannerService(
        repository,
        idGenerator: () => 'id-${counter++}',
        clock: () => DateTime.utc(2026, 9, 8),
      );

      var workspace = await service.createClass(name: 'Class 8');
      final classId = workspace.classes.single.id;
      workspace = await service.createSubject(classId: classId, name: 'Math');
      workspace = await service.createSubject(
        classId: classId,
        name: 'Science',
      );
      final subjectIds = workspace.subjects.map((item) => item.id).toList();
      workspace = await service.reorderSubjects(
        classId: classId,
        orderedSubjectIds: subjectIds.reversed.toList(),
      );
      expect(
        workspace.activeSubjectsForClass(classId).map((item) => item.id),
        subjectIds.reversed,
      );

      final subjectId = workspace.subjects.first.id;
      workspace = await service.createUnit(
        subjectId: subjectId,
        title: 'Unit A',
      );
      workspace = await service.createUnit(
        subjectId: subjectId,
        title: 'Unit B',
      );
      final unitIds = workspace
          .activeUnitsForSubject(subjectId)
          .map((item) => item.id)
          .toList();
      await expectLater(
        service.reorderUnits(
          subjectId: subjectId,
          orderedUnitIds: [unitIds.first],
        ),
        throwsA(isA<TeachingPlannerOperationException>()),
      );
    },
  );
}

class _MemoryPlannerRepository implements TeachingPlannerRepository {
  TeachingPlannerWorkspace workspace = TeachingPlannerWorkspace.empty();

  @override
  Future<TeachingPlannerWorkspace> load() async => workspace;

  @override
  Future<void> save(TeachingPlannerWorkspace workspace) async {
    this.workspace = workspace;
  }

  @override
  Future<TeachingPlannerWorkspace> update(
    TeachingPlannerMutation mutation,
  ) async {
    workspace = mutation(workspace);
    return workspace;
  }
}
