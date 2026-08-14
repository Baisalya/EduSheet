import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/question_composer_page.dart';
import 'package:edusheet/features/question_bank/domain/models/question_bank_model.dart';
import 'package:edusheet/features/question_bank/presentation/providers/question_bank_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Question Bank authoring now reuses the same rich question composer as paper
/// authoring. Math, Geometry, options, marks, answers and advanced metadata
/// therefore have one editing path instead of two incompatible editors.
class AddEditQuestionScreen extends ConsumerWidget {
  final QuestionBankQuestion? question;

  const AddEditQuestionScreen({super.key, this.question});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return QuestionComposerPage(
      question: question?.question,
      pageTitle: question == null ? 'New bank question' : 'Edit bank question',
      allowSaveAndNext: question == null,
      preserveDetailsOnSaveAndNext: question == null,
      onSaveQuestion: (edited) => _save(context, ref, edited),
    );
  }

  Future<bool> _save(
    BuildContext context,
    WidgetRef ref,
    Question edited,
  ) async {
    final service = ref.read(questionBankApplicationServiceProvider);
    final notifier = ref.read(questionBankProvider.notifier);
    final entry = service.normalizeEditedMaster(
      edited,
      existing: question,
    );

    if (question == null) {
      final duplicate = service.findLikelyDuplicate(
        entry.question,
        ref.read(questionBankProvider).questions,
      );
      if (duplicate != null) {
        final saveAnother =
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Similar question already saved'),
                content: Text(
                  duplicate.question.plainTextAccessibility.trim().isEmpty
                      ? 'A very similar question already exists in the Question Bank.'
                      : duplicate.question.plainTextAccessibility,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep existing'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Save another'),
                  ),
                ],
              ),
            ) ??
            false;
        if (!saveAnother) {
          return false;
        }
      }
    }

    try {
      if (question == null) {
        await notifier.addQuestion(entry);
      } else {
        await notifier.updateQuestion(entry);
      }
      return true;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save question: $error')),
        );
      }
      return false;
    }
  }
}
