import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/lesson_planner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'teacher can create missing syllabus hierarchy inside lesson draft without losing entered data',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _MemoryPlannerRepository(TeachingPlannerWorkspace.empty());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teachingPlannerRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: const LessonPlannerScreen(openCreateOnStart: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Plan lesson'), findsWidgets);
      expect(find.byKey(const ValueKey('lesson-quick-add-class')), findsOneWidget);

      final periods = find.byKey(const ValueKey('lesson-editor-periods'));
      await tester.ensureVisible(periods);
      await tester.enterText(periods, '2');

      final details = find.byKey(const ValueKey('lesson-editor-more-details'));
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      final title = find.byKey(const ValueKey('lesson-editor-title'));
      await tester.ensureVisible(title);
      await tester.enterText(title, 'My custom lesson title');

      await _tapQuickAdd(tester, 'lesson-quick-add-class');
      await tester.enterText(
        find.byKey(const ValueKey('lesson-quick-add-name')),
        'Class 8A',
      );
      await tester.enterText(
        find.byKey(const ValueKey('lesson-quick-add-secondary')),
        '2026–27',
      );
      await tester.tap(find.byKey(const ValueKey('lesson-quick-add-save')));
      await tester.pumpAndSettle();

      final createdClass = repository.workspace.activeClasses.single;
      expect(createdClass.name, 'Class 8A');
      expect(createdClass.academicYear, '2026–27');

      await _tapQuickAdd(tester, 'lesson-quick-add-subject');
      await tester.enterText(
        find.byKey(const ValueKey('lesson-quick-add-name')),
        'Mathematics',
      );
      await tester.tap(find.byKey(const ValueKey('lesson-quick-add-save')));
      await tester.pumpAndSettle();

      final createdSubject = repository.workspace.subjects.single;
      expect(createdSubject.classId, createdClass.id);

      await _tapQuickAdd(tester, 'lesson-quick-add-unit');
      await tester.enterText(
        find.byKey(const ValueKey('lesson-quick-add-name')),
        'Algebra',
      );
      await tester.tap(find.byKey(const ValueKey('lesson-quick-add-save')));
      await tester.pumpAndSettle();

      final createdUnit = repository.workspace.units.single;
      expect(createdUnit.subjectId, createdSubject.id);

      await _tapQuickAdd(tester, 'lesson-quick-add-chapter');
      await tester.enterText(
        find.byKey(const ValueKey('lesson-quick-add-chapter-name')),
        'Linear Equations',
      );
      await tester.tap(
        find.byKey(const ValueKey('lesson-quick-add-chapter-save')),
      );
      await tester.pumpAndSettle();

      final createdChapter = repository.workspace.chapters.single;
      expect(createdChapter.subjectId, createdSubject.id);
      expect(createdChapter.unitId, createdUnit.id);

      await _tapQuickAdd(tester, 'lesson-quick-add-topic');
      await tester.enterText(
        find.byKey(const ValueKey('lesson-quick-add-name')),
        'One-step equations',
      );
      await tester.tap(find.byKey(const ValueKey('lesson-quick-add-save')));
      await tester.pumpAndSettle();

      final createdTopic = repository.workspace.topics.single;
      expect(createdTopic.chapterId, createdChapter.id);

      expect(
        tester.widget<TextFormField>(title).controller?.text,
        'My custom lesson title',
      );
      expect(tester.widget<TextFormField>(periods).controller?.text, '2');

      final planButton = find.widgetWithText(FilledButton, 'Plan lesson');
      await tester.ensureVisible(planButton);
      await tester.tap(planButton);
      await tester.pumpAndSettle();

      final lesson = repository.workspace.lessonPlans.single;
      expect(lesson.classId, createdClass.id);
      expect(lesson.subjectId, createdSubject.id);
      expect(lesson.chapterId, createdChapter.id);
      expect(lesson.topicIds, contains(createdTopic.id));
      expect(lesson.title, 'My custom lesson title');
      expect(lesson.plannedPeriods, 2);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _tapQuickAdd(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _MemoryPlannerRepository implements TeachingPlannerRepository {
  _MemoryPlannerRepository(this.workspace);

  TeachingPlannerWorkspace workspace;

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
