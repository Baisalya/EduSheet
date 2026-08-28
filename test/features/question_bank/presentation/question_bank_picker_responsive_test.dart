import 'package:edusheet/features/question_bank/data/repositories/question_bank_repository.dart';
import 'package:edusheet/features/question_bank/domain/models/question_bank_model.dart';
import 'package:edusheet/features/question_bank/presentation/providers/question_bank_provider.dart';
import 'package:edusheet/features/question_bank/presentation/widgets/question_bank_picker_sheet.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_app_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyQuestionBankRepository implements QuestionBankRepository {
  @override
  Future<void> addQuestion(QuestionBankQuestion question) async {}

  @override
  Future<void> deleteQuestion(String id) async {}

  @override
  Future<String> exportToJson() async => '[]';

  @override
  Future<List<QuestionBankQuestion>> getAllQuestions() async => const [];

  @override
  Future<void> importFromJson(String jsonString) async {}

  @override
  Future<void> updateQuestion(QuestionBankQuestion question) async {}
}

void main() {
  for (final size in <Size>[
    const Size(320, 520),
    const Size(366, 720),
    const Size(600, 480),
  ]) {
    testWidgets('question bank picker has no overflow at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            questionBankRepositoryProvider.overrideWithValue(
              _EmptyQuestionBankRepository(),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.windows),
            home: AdaptiveAppViewport(
              child: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => QuestionBankPickerSheet.show(context),
                      child: const Text('Open picker'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();

      expect(find.text('Choose from Question Bank'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
