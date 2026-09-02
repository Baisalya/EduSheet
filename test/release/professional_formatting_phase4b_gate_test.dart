import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/application/word_content_block_service.dart';
import 'package:edusheet/features/paper_composer/application/word_shape_service.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 4B canonical shape state survives Paper JSON round-trip', () {
    var question = Question(id: 'q1', text: 'Explain the diagram', marks: 5);
    for (final entry in WordShapeKind.values.indexed) {
      question = WordShapeService.append(
        question,
        WordShapeObject(
          id: 'shape-${entry.$1}',
          kind: entry.$2,
          x: 0.05 + entry.$1 * 0.03,
          y: 0.04 + entry.$1 * 0.02,
          width: 0.28,
          height: 0.20,
          wrapMode: WordTextWrapMode
              .values[entry.$1 % WordTextWrapMode.values.length],
          zIndex: entry.$1 - 3,
          text:
              entry.$2 == WordShapeKind.textBox ||
                  entry.$2 == WordShapeKind.callout
              ? 'Editable ${entry.$2.name}'
              : '',
        ),
      );
    }
    final paper = Paper(
      id: 'phase4b',
      title: 'Phase 4B Gate',
      createdAt: DateTime.utc(2026, 9, 1),
      sections: [
        PaperSection(id: 's1', title: 'Section A', questions: [question]),
      ],
    );

    final restored = Paper.fromJson(paper.toJson());
    final shapes = WordShapeService.shapesOf(
      restored.sections.single.questions.single,
    );

    expect(shapes, hasLength(WordShapeKind.values.length));
    expect(
      shapes.map((item) => item.kind).toSet(),
      WordShapeKind.values.toSet(),
    );
    expect(
      shapes.any((item) => item.wrapMode == WordTextWrapMode.behindText),
      isTrue,
    );
    expect(
      shapes.any((item) => item.wrapMode == WordTextWrapMode.inFrontOfText),
      isTrue,
    );
    expect(shapes.any((item) => item.text.startsWith('Editable')), isTrue);
  });

  test('Phase 4B free shape remains non-assessment Word content', () {
    final freeShape = WordContentBlockService.shape(
      const WordShapeObject(
        id: 'free-shape',
        kind: WordShapeKind.callout,
        text: 'Note',
        wrapMode: WordTextWrapMode.topAndBottom,
      ),
    );
    final paper = Paper(
      id: 'free',
      title: 'Free Shape',
      createdAt: DateTime.utc(2026, 9, 1),
      sections: [
        PaperSection(id: 's1', title: 'Section A', questions: [freeShape]),
      ],
    );

    expect(freeShape.isWordContentBlock, isTrue);
    expect(
      WordContentBlockService.kindOf(freeShape),
      WordContentBlockKind.shape,
    );
    expect(
      paper.sections.single.questions.where((item) => !item.isWordContentBlock),
      isEmpty,
    );
    expect(paper.totalMarks, 0);
  });
}
