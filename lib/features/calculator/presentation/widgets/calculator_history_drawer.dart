import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/calculator_provider.dart';

class CalculatorHistoryDrawer extends ConsumerWidget {
  const CalculatorHistoryDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(calculatorProvider).history;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                const Icon(Icons.history, color: Colors.tealAccent),
                const SizedBox(width: 12),
                const Text(
                  'Calculation History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (history.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => ref.read(calculatorProvider.notifier).clearHistory(),
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  ),
              ],
            ),
          ),
          Expanded(
            child: history.isEmpty
                ? const Center(
                    child: Text(
                      'No history yet',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: history.length,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                    itemBuilder: (context, index) {
                      final entry = history[history.length - 1 - index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          entry,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.replay, color: Colors.tealAccent, size: 20),
                          onPressed: () {
                            ref.read(calculatorProvider.notifier).reuseHistory(entry);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
