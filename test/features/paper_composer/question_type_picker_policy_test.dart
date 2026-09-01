import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_type_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'quick start only advertises helpers the focused composer can author',
    () {
      expect(QuestionTypePicker.authorable, contains(QuestionType.mcq));
      expect(QuestionTypePicker.authorable, contains(QuestionType.numerical));
      expect(
        QuestionTypePicker.authorable,
        isNot(contains(QuestionType.imageOrDiagram)),
      );

      // These are structural compositions, not mutually-exclusive quick starts.
      // Existing saved questions remain compatible through QuestionDraft and the
      // UniversalQuestionAdapter instead of pretending the focused UI can fully
      // author them from one enum choice.
      expect(
        QuestionTypePicker.authorable,
        isNot(contains(QuestionType.internalChoice)),
      );
      expect(
        QuestionTypePicker.authorable,
        isNot(contains(QuestionType.subQuestions)),
      );
      expect(
        QuestionTypePicker.authorable,
        isNot(contains(QuestionType.table)),
      );
      expect(
        QuestionTypePicker.authorable,
        isNot(contains(QuestionType.caseStudy)),
      );
      expect(
        QuestionTypePicker.authorable,
        isNot(contains(QuestionType.matching)),
      );
    },
  );
}
