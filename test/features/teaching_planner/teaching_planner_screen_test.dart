import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_capabilities.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_workspace.dart';
import 'package:edusheet/features/teaching_planner/domain/repositories/teaching_planner_repository.dart';
import 'package:edusheet/features/teaching_planner/presentation/providers/teaching_planner_provider.dart';
import 'package:edusheet/features/teaching_planner/presentation/screens/teaching_planner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const [
    Size(360, 800),
    Size(412, 915),
    Size(600, 900),
    Size(900, 700),
    Size(1366, 768),
  ]) {
    testWidgets(
      'planner foundation has no overflow at ${size.width}x${size.height}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              teachingPlannerRepositoryProvider.overrideWithValue(
                _MemoryPlannerRepository(),
              ),
              teachingPlannerCapabilitiesProvider.overrideWithValue(
                TeachingPlannerCapabilities.free(),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(useMaterial3: true),
              home: const TeachingPlannerScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Teaching Planner'), findsOneWidget);
        expect(find.text('My Classes'), findsOneWidget);
        expect(find.text('Manage syllabus'), findsOneWidget);
        expect(find.text('Teaching calendar'), findsOneWidget);
        expect(find.text('No classes yet'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
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
