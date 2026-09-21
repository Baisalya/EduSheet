import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_capabilities.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/planner_insights_backup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const <Size>[
    Size(360, 800),
    Size(412, 915),
    Size(900, 700),
    Size(1366, 768),
  ]) {
    testWidgets(
      'insights and backup lays out safely at ${size.width}x${size.height}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              teachingPlannerRepositoryProvider.overrideWithValue(
                _MemoryRepository(TeachingPlannerWorkspace.empty()),
              ),
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

        expect(find.text('Insights & backup'), findsOneWidget);
        expect(find.text('Progress at a glance'), findsOneWidget);
        expect(find.text('Move or protect your planner'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('free teachers can save and restore their planner backup', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teachingPlannerRepositoryProvider.overrideWithValue(
            _MemoryRepository(TeachingPlannerWorkspace.empty()),
          ),
          teachingPlannerCapabilitiesProvider.overrideWithValue(
            TeachingPlannerCapabilities.free(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const PlannerInsightsBackupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save .eds file'),
    );
    final restore = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Choose .eds file'),
    );
    expect(save.onPressed, isNotNull);
    expect(restore.onPressed, isNotNull);
    expect(find.text('Advanced teaching insights'), findsOneWidget);
    expect(find.text('Progress at a glance'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _MemoryRepository implements TeachingPlannerRepository {
  _MemoryRepository(this.workspace);

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
