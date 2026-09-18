import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('syllabus paper context is visible but does not create a ghost autosave', () async {
    final repository = _MemoryPaperRepository();
    final container = ProviderContainer(
      overrides: [paperRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final editor = container.read(editorStateProvider.notifier);
    final id = await editor.startNewPaperForSyllabus(
      className: 'Class 8',
      subjectName: 'Mathematics',
    );
    final paper = container.read(editorStateProvider);

    expect(paper.id, id);
    expect(_header(paper, 'Class'), 'Class 8');
    expect(_header(paper, 'Subject'), 'Mathematics');
    expect(editor.isPaperPersisted(id), isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 750));
    expect(repository.papers, isEmpty);

    editor.updateTitle('Class 8 Mathematics Test');
    await editor.flushPendingAutosave();
    expect(editor.isPaperPersisted(id), isFalse);
    expect(repository.papers, isEmpty);

    await editor.savePaper();
    expect(editor.isPaperPersisted(id), isTrue);
    expect(repository.papers.single.id, id);
  });
}

String _header(Paper paper, String label) {
  for (final field in paper.headerFields) {
    if (field.label == label) return field.value;
  }
  return '';
}

class _MemoryPaperRepository implements PaperRepository {
  final List<Paper> papers = [];

  @override
  Future<void> deletePaper(String id) async {
    papers.removeWhere((paper) => paper.id == id);
  }

  @override
  Future<List<Paper>> getAllPapers() async => List.unmodifiable(papers);

  @override
  Future<void> savePaper(Paper paper) async {
    papers.removeWhere((item) => item.id == paper.id);
    papers.add(paper);
  }
}
