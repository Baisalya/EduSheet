import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/formula_data.dart';
import '../../domain/models/formula_model.dart';
import '../providers/calculator_provider.dart';

class FormulaCatalogSheet extends StatefulWidget {
  final bool dialogMode;

  const FormulaCatalogSheet({super.key, this.dialogMode = false});

  @override
  State<FormulaCatalogSheet> createState() => _FormulaCatalogSheetState();
}

class _FormulaCatalogSheetState extends State<FormulaCatalogSheet> {
  String searchQuery = '';
  ScienceSubject selectedSubject = ScienceSubject.physics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = searchQuery.trim().toLowerCase();
    final filteredFormulas = FormulaData.formulas.where((formula) {
      final matchesSearch =
          query.isEmpty ||
          formula.name.toLowerCase().contains(query) ||
          formula.category.toLowerCase().contains(query) ||
          formula.expression.toLowerCase().contains(query);
      return matchesSearch && formula.subject == selectedSubject;
    }).toList();

    return Container(
      height: widget.dialogMode
          ? double.infinity
          : MediaQuery.sizeOf(context).height * 0.72,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: widget.dialogMode
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(20)),
        border: widget.dialogMode
            ? Border.all(color: theme.colorScheme.outlineVariant)
            : null,
      ),
      child: Column(
        children: [
          if (!widget.dialogMode) ...[
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Icon(Icons.science_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Science Formulas',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search formulas',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ScienceSubject>(
              segments: const [
                ButtonSegment(
                  value: ScienceSubject.physics,
                  label: Text('Physics'),
                  icon: Icon(Icons.bolt_rounded),
                ),
                ButtonSegment(
                  value: ScienceSubject.chemistry,
                  label: Text('Chemistry'),
                  icon: Icon(Icons.science_outlined),
                ),
              ],
              selected: {selectedSubject},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() => selectedSubject = selection.first);
              },
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: filteredFormulas.isEmpty
                ? Center(
                    child: Text(
                      'No matching formulas',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredFormulas.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final formula = filteredFormulas[index];
                      return Consumer(
                        builder: (context, ref, _) {
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            tileColor: theme.colorScheme.surfaceContainerLow,
                            title: Text(
                              formula.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(formula.expression),
                            trailing: const Icon(Icons.add_circle_outline),
                            onTap: () {
                              ref
                                  .read(calculatorProvider.notifier)
                                  .insertFormula(formula.expression);
                              Navigator.pop(context);
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
