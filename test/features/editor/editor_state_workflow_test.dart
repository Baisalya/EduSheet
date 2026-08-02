import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/presentation/providers/editor_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('moves a question between sections and restores it with undo', () {
    final repository = _MemoryPaperRepository();
    final container = ProviderContainer(
      overrides: [paperRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final editor = container.read(editorStateProvider.notifier);
    editor.loadPaper(_paper());

    editor.moveQuestion(
      fromSectionId: 'a',
      toSectionId: 'b',
      questionId: 'q1',
    );

    var paper = container.read(editorStateProvider);
    expect(paper.sections[0].questions, isEmpty);
    expect(paper.sections[1].questions.single.id, 'q1');
    expect(editor.canUndo, isTrue);

    editor.undo();

    paper = container.read(editorStateProvider);
    expect(paper.sections[0].questions.single.id, 'q1');
    expect(paper.sections[1].questions, isEmpty);
    expect(editor.canRedo, isTrue);
  });

  test('section duplication creates independent section and question IDs', () {
    final container = ProviderContainer(
      overrides: [
        paperRepositoryProvider.overrideWithValue(_MemoryPaperRepository()),
      ],
    );
    addTearDown(container.dispose);
    final editor = container.read(editorStateProvider.notifier);
    editor.loadPaper(_paper());

    editor.duplicateSection('a');

    final sections = container.read(editorStateProvider).sections;
    expect(sections, hasLength(3));
    expect(sections[1].id, isNot(sections[0].id));
    expect(sections[1].questions.single.id, isNot('q1'));
    expect(sections[1].questions.single.text, 'Question one');
  });

  test('inserts, duplicates, reorders, updates and redoes questions', () {
    final container = ProviderContainer(
      overrides: [
        paperRepositoryProvider.overrideWithValue(_MemoryPaperRepository()),
      ],
    );
    addTearDown(container.dispose);
    final editor = container.read(editorStateProvider.notifier);
    editor.loadPaper(_paper());

    editor.addQuestion('a', 'Inserted first', insertAt: 0, marks: 3);
    var questions = container.read(editorStateProvider).sections.first.questions;
    expect(
      questions.map((item) => item.text),
      ['Inserted first', 'Question one'],
    );

    final insertedId = questions.first.id;
    editor.duplicateQuestion('a', insertedId);
    questions = container.read(editorStateProvider).sections.first.questions;
    expect(questions, hasLength(3));
    expect(questions[1].id, isNot(insertedId));

    editor.bulkUpdateQuestions('a', [
      questions.last,
      questions.first,
      questions[1],
    ]);
    editor.updateQuestion('a', insertedId, text: 'Edited', marks: 4);
    expect(
      container
          .read(editorStateProvider)
          .sections
          .first
          .questions
          .firstWhere((item) => item.id == insertedId)
          .text,
      'Edited',
    );

    editor.undo();
    expect(editor.canRedo, isTrue);
    editor.redo();
    expect(
      container
          .read(editorStateProvider)
          .sections
          .first
          .questions
          .firstWhere((item) => item.id == insertedId)
          .marks,
      4,
    );
  });
}

Paper _paper() {
  return Paper(
    id: 'paper',
    title: 'Paper',
    createdAt: DateTime.utc(2026, 7, 19),
    sections: [
      PaperSection(
        id: 'a',
        title: 'A',
        questions: [Question(id: 'q1', text: 'Question one')],
      ),
      PaperSection(id: 'b', title: 'B'),
    ],
  );
}

class _MemoryPaperRepository implements PaperRepository {
  final List<Paper> papers = [];

  @override
  Future<void> deletePaper(String id) async {
    papers.removeWhere((paper) => paper.id == id);
  }

  @override
  Future<List<Paper>> getAllPapers() async => [...papers];

  @override
  Future<void> savePaper(Paper paper) async {
    final index = papers.indexWhere((item) => item.id == paper.id);
    if (index == -1) {
      papers.add(paper);
    } else {
      papers[index] = paper;
    }
  }
}
