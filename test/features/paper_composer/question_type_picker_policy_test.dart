import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_type_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new composer only advertises question types it can fully author', () {
    expect(QuestionTypePicker.authorable, contains(QuestionType.mcq));
    expect(QuestionTypePicker.authorable, contains(QuestionType.numerical));
    expect(
      QuestionTypePicker.authorable,
      contains(QuestionType.imageOrDiagram),
    );

    expect(
      QuestionTypePicker.authorable,
      isNot(contains(QuestionType.internalChoice)),
    );
    expect(
      QuestionTypePicker.authorable,
      isNot(contains(QuestionType.subQuestions)),
    );
    expect(QuestionTypePicker.authorable, isNot(contains(QuestionType.table)));
    expect(
      QuestionTypePicker.authorable,
      isNot(contains(QuestionType.caseStudy)),
    );
    expect(
      QuestionTypePicker.authorable,
      isNot(contains(QuestionType.matching)),
    );
  });
}
