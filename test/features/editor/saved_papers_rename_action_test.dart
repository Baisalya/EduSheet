import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:edusheet/features/editor/presentation/screens/saved_papers_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saved paper Rename dialog can cancel without lifecycle errors', (
    tester,
  ) async {
    final repository = _MemoryPaperRepository([_paper()]);

    await _pumpSavedPapers(tester, repository);

    expect(find.text('Class 8 Test'), findsOneWidget);
    expect(find.text('Rename'), findsOneWidget);

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(find.text('Rename paper'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Rename'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Rename paper'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved paper Rename persists the new paper name', (tester) async {
    final repository = _MemoryPaperRepository([_paper()]);

    await _pumpSavedPapers(tester, repository);

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Class 8 Final Test');
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();

    expect(repository.papers.single.title, 'Class 8 Final Test');
    expect(find.text('Class 8 Final Test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Paper _paper() => Paper(
  id: 'paper-1',
  title: 'Class 8 Test',
  schoolName: 'EduSheet School',
  createdAt: DateTime.utc(2026, 9, 17),
);

Future<void> _pumpSavedPapers(
  WidgetTester tester,
  PaperRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [paperRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: SavedPapersScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _MemoryPaperRepository implements PaperRepository {
  _MemoryPaperRepository(this.papers);

  final List<Paper> papers;

  @override
  Future<void> deletePaper(String id) async {
    papers.removeWhere((paper) => paper.id == id);
  }

  @override
  Future<List<Paper>> getAllPapers() async => List<Paper>.unmodifiable(papers);

  @override
  Future<void> savePaper(Paper paper) async {
    papers.removeWhere((item) => item.id == paper.id);
    papers.add(paper);
  }
}
