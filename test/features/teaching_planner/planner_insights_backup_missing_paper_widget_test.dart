import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_capabilities.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_resource_owner.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/planner_insights_backup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'missing linked paper shows recovery warning before any save dialog',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.utc(2026, 9, 21, 11);
      final workspace = TeachingPlannerWorkspace(
        resources: [
          TeachingResource(
            id: 'missing-paper-resource',
            owner: const TeachingResourceOwner.chapter('chapter-1'),
            kind: TeachingResourceKind.paper,
            title: 'Algebra revision paper',
            linkedPaperId: 'paper-not-in-papers-json',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      final plannerRepository = _MemoryPlannerRepository(workspace);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teachingPlannerRepositoryProvider.overrideWithValue(
              plannerRepository,
            ),
            paperRepositoryProvider.overrideWithValue(_EmptyPaperRepository()),
            teachingPlannerCapabilitiesProvider.overrideWithValue(
              TeachingPlannerCapabilities.pro(),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: const PlannerInsightsBackupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveFinder = find.widgetWithText(FilledButton, 'Save .eds file');
      await tester.ensureVisible(saveFinder);
      await tester.tap(saveFinder);
      await tester.pumpAndSettle();

      expect(find.text('Linked Saved Paper is missing'), findsOneWidget);
      expect(find.textContaining('Algebra revision paper'), findsOneWidget);
      expect(
        find.textContaining('Your current planner has not been changed.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Save recovery .eds'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Linked Saved Paper is missing'), findsNothing);
      expect(
        plannerRepository.workspace.resourceById('missing-paper-resource'),
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
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

class _EmptyPaperRepository implements PaperRepository {
  @override
  Future<List<Paper>> getAllPapers() async => const <Paper>[];

  @override
  Future<void> savePaper(Paper paper) async {}

  @override
  Future<void> deletePaper(String id) async {}
}
