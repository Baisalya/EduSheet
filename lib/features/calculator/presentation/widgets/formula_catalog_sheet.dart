import 'package:flutter/material.dart';

import '../../data/repositories/formula_data.dart';
import '../../domain/models/formula_model.dart';
import 'formula_solver_panel.dart';

class FormulaCatalogSheet extends StatefulWidget {
  final bool dialogMode;

  const FormulaCatalogSheet({super.key, this.dialogMode = false});

  @override
  State<FormulaCatalogSheet> createState() => _FormulaCatalogSheetState();
}

class _FormulaCatalogSheetState extends State<FormulaCatalogSheet> {
  String searchQuery = '';
  ScienceSubject selectedSubject = ScienceSubject.physics;
  Formula? selectedFormula;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = searchQuery.trim().toLowerCase();
    final filteredFormulas = FormulaData.formulas.where((formula) {
      final matchesSearch =
          query.isEmpty ||
          formula.name.toLowerCase().contains(query) ||
          formula.category.toLowerCase().contains(query) ||
          formula.expression.toLowerCase().contains(query) ||
          formula.targetLabel.toLowerCase().contains(query);
      return matchesSearch && formula.subject == selectedSubject;
    }).toList();

    return Container(
      key: ValueKey(
        widget.dialogMode ? 'formula-catalog-dialog' : 'formula-catalog-sheet',
      ),
      height: widget.dialogMode
          ? double.infinity
          : MediaQuery.sizeOf(context).height * 0.78,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: widget.dialogMode
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(20)),
        border: widget.dialogMode
            ? Border.all(color: theme.colorScheme.outlineVariant)
            : null,
      ),
      child: selectedFormula != null
          ? FormulaSolverPanel(
              formula: selectedFormula!,
              onBack: () => setState(() => selectedFormula = null),
            )
          : _buildCatalog(theme, filteredFormulas),
    );
  }

  Widget _buildCatalog(ThemeData theme, List<Formula> filteredFormulas) {
    return Column(
      children: [
        if (!widget.dialogMode) ...[
          const SizedBox(height: 8),
          Container(
            key: const ValueKey('formula-catalog-drag-handle'),
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
              Expanded(
                child: Text(
                  'Science Formulas',
                  key: ValueKey(
                    widget.dialogMode
                        ? 'formula-catalog-title-dialog'
                        : 'formula-catalog-title-sheet',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 4),
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
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredFormulas.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final formula = filteredFormulas[index];
                    final tileShape = RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    );
                    return Material(
                      key: ValueKey('formula-tile-${formula.name}'),
                      color: theme.colorScheme.surfaceContainerLow,
                      shape: tileShape,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        shape: tileShape,
                        title: Text(
                          formula.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '${formula.expression}\n'
                            'Calculate ${formula.targetLabel} '
                            '(${formula.targetSymbol})',
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => setState(() => selectedFormula = formula),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
