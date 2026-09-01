import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/question_option_layout.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('option layout round-trips through existing question metadata', () {
    final seed = Question(
      id: 'q1',
      text: 'Choose one',
      type: QuestionType.mcq,
      options: [
        QuestionOption(id: 'a', text: 'A'),
        QuestionOption(id: 'b', text: 'B'),
      ],
    );

    final draft = QuestionDraft.fromQuestion(
      seed,
    ).copyWith(optionLayout: QuestionOptionLayout.twoColumn);
    final saved = draft.toQuestion(plainTextAccessibility: 'Choose one');

    expect(
      saved.metadata[QuestionOptionLayoutCodec.metadataKey],
      QuestionOptionLayout.twoColumn.name,
    );
    expect(
      QuestionOptionLayoutCodec.fromQuestion(saved),
      QuestionOptionLayout.twoColumn,
    );
  });

  test(
    'vertical option layout stays storage-compatible without metadata noise',
    () {
      final saved = QuestionDraft.create(type: QuestionType.mcq)
          .copyWith(optionLayout: QuestionOptionLayout.vertical)
          .toQuestion(plainTextAccessibility: 'Question');

      expect(
        saved.metadata.containsKey(QuestionOptionLayoutCodec.metadataKey),
        isFalse,
      );
    },
  );
}
