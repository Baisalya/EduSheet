import 'package:edusheet/features/teaching_planner/application/planner_insights_service.dart';
import 'package:edusheet/features/teaching_planner/data/teaching_planner_backup_codec.dart';
import 'package:edusheet/features/teaching_planner/domain/models/lesson_plan.dart';
import 'package:edusheet/features/teaching_planner/domain/models/planner_topic.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup round-trips canonical workspace safely', () {
    final source = TeachingPlannerWorkspace.empty();
    final text = const TeachingPlannerBackupCodec().encode(
      source,
      exportedAt: DateTime.utc(2026, 9, 8),
    );
    final restored = const TeachingPlannerBackupCodec().decode(text);
    expect(restored.isEmpty, isTrue);
    expect(text, startsWith('${TeachingPlannerBackupCodec.magicHeader}\n'));
    expect(text, contains('edusheet.teaching-planner-backup'));
    expect(text, contains('"schemaVersion": 7'));
  });

  test('backup rejects unrelated json before restore', () {
    expect(
      () => const TeachingPlannerBackupCodec().decode(
        '{"format":"other","version":1}',
      ),
      throwsFormatException,
    );
  });

  test('portable .eds codec still accepts legacy Phase 18 JSON backups', () {
    const legacy = '''{
  "format": "edusheet.teaching-planner-backup",
  "version": 1,
  "exportedAt": "2026-09-08T00:00:00.000Z",
  "document": {
    "schemaVersion": 5,
    "updatedAt": "2026-09-08T00:00:00.000Z",
    "classes": [],
    "subjects": [],
    "units": [],
    "chapters": [],
    "topics": [],
    "lessonPlans": []
  }
}''';
    final restored = const TeachingPlannerBackupCodec().decode(legacy);
    expect(restored.isEmpty, isTrue);
  });

  test('portable .eds codec rejects arbitrary non EduSheet files', () {
    expect(
      () => const TeachingPlannerBackupCodec().decode('hello from another app'),
      throwsFormatException,
    );
  });

  test('insights derive completion, variance, overdue and upcoming counts', () {
    final now = DateTime(2026, 9, 8, 12);
    final workspace = TeachingPlannerWorkspace(
      lessonPlans: [
        LessonPlan(
          id: 'l1',
          classId: 'c1',
          subjectId: 's1',
          chapterId: 'ch1',
          title: 'Done',
          plannedDate: DateTime(2026, 9, 7),
          plannedPeriods: 2,
          objective: 'Learn',
          status: TeachingProgressStatus.completed,
          actualPeriods: 3,
          createdAt: now,
          updatedAt: now,
        ),
        LessonPlan(
          id: 'l2',
          classId: 'c1',
          subjectId: 's1',
          chapterId: 'ch1',
          title: 'Overdue',
          plannedDate: DateTime(2026, 9, 6),
          plannedPeriods: 1,
          objective: 'Learn',
          actualPeriods: 0,
          createdAt: now,
          updatedAt: now,
        ),
        LessonPlan(
          id: 'l3',
          classId: 'c1',
          subjectId: 's1',
          chapterId: 'ch1',
          title: 'Upcoming',
          plannedDate: DateTime(2026, 9, 10),
          plannedPeriods: 2,
          objective: 'Learn',
          actualPeriods: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      topics: [
        PlannerTopic(
          id: 't1',
          chapterId: 'ch1',
          title: 'Topic',
          sortOrder: 0,
          plannedPeriods: 2,
          actualPeriods: 3,
          status: TeachingProgressStatus.completed,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    final insights = const PlannerInsightsService().calculate(
      workspace,
      now: now,
    );
    expect(insights.activeLessons, 3);
    expect(insights.completedLessons, 1);
    expect(insights.overdueLessons, 1);
    expect(insights.upcomingSevenDays, 1);
    expect(insights.lessonPeriodVariance, -2);
    expect(insights.topicPeriodVariance, 1);
    expect(insights.topicCompletionRate, 1);
  });
}
