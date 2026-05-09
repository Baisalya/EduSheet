import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../providers/question_count_provider.dart';

class QuestionBankScreen extends ConsumerWidget {
  const QuestionBankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(questionCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.questionBankTitle),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Questions in your bank:',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PrimaryButton(
                  label: 'Remove',
                  icon: Icons.remove,
                  onPressed: () => ref.read(questionCountProvider.notifier).decrement(),
                ),
                const SizedBox(width: 16),
                PrimaryButton(
                  label: 'Add',
                  icon: Icons.add,
                  onPressed: () => ref.read(questionCountProvider.notifier).increment(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
