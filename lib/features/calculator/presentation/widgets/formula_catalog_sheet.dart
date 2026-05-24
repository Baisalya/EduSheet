import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/formula_data.dart';
import '../../domain/models/formula_model.dart';
import '../providers/calculator_provider.dart';

class FormulaCatalogSheet extends StatefulWidget {
  const FormulaCatalogSheet({super.key});

  @override
  State<FormulaCatalogSheet> createState() => _FormulaCatalogSheetState();
}

class _FormulaCatalogSheetState extends State<FormulaCatalogSheet> {
  String searchQuery = '';
  ScienceSubject selectedSubject = ScienceSubject.physics;

  @override
  Widget build(BuildContext context) {
    final filteredFormulas = FormulaData.formulas.where((f) {
      final matchesSearch =
          f.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          f.category.toLowerCase().contains(searchQuery.toLowerCase());
      final matchesSubject = f.subject == selectedSubject;
      return matchesSearch && matchesSubject;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text(
                  'Science Formulas',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search formulas...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) => setState(() => searchQuery = value),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SubjectTab(
                label: 'Physics',
                isSelected: selectedSubject == ScienceSubject.physics,
                onTap: () =>
                    setState(() => selectedSubject = ScienceSubject.physics),
              ),
              const SizedBox(width: 12),
              _SubjectTab(
                label: 'Chemistry',
                isSelected: selectedSubject == ScienceSubject.chemistry,
                onTap: () =>
                    setState(() => selectedSubject = ScienceSubject.chemistry),
              ),
            ],
          ),
          const Divider(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: filteredFormulas.length,
              itemBuilder: (context, index) {
                final formula = filteredFormulas[index];
                return Consumer(
                  builder: (context, ref, _) {
                    return ListTile(
                      title: Text(
                        formula.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(formula.expression),
                      trailing: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.teal,
                      ),
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

class _SubjectTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubjectTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
