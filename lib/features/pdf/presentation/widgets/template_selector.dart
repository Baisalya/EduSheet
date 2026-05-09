import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/paper_template.dart';
import '../providers/template_provider.dart';

class TemplateSelector extends ConsumerWidget {
  final String selectedTemplateId;
  final ValueChanged<String> onTemplateSelected;

  const TemplateSelector({
    super.key,
    required this.selectedTemplateId,
    required this.onTemplateSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(templateProvider);
    final templates = state.all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: templates.length + 1,
            itemBuilder: (context, index) {
              if (index == templates.length) {
                return _buildAddButton(context, ref, state);
              }

              final template = templates[index];
              final isSelected = template.id == selectedTemplateId;

              return GestureDetector(
                onTap: () => onTemplateSelected(template.id),
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.05) : Colors.white,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getIconForType(template.type),
                        color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          template.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton(BuildContext context, WidgetRef ref, TemplateState state) {
    return GestureDetector(
      onTap: () => _showSaveCustomDialog(context, ref, state),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
          color: Colors.grey[50],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: Colors.grey, size: 32),
            SizedBox(height: 8),
            Text(
              'Save Current\nas Custom',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveCustomDialog(BuildContext context, WidgetRef ref, TemplateState state) {
    final currentTemplateId = selectedTemplateId;
    final currentTemplate = state.all.firstWhere((t) => t.id == currentTemplateId, orElse: () => state.all.first);
    
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Custom Template'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Template Name', hintText: 'My School Style'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(templateProvider.notifier).saveAsCustom(currentTemplate, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(TemplateType type) {
    switch (type) {
      case TemplateType.school:
        return Icons.school;
      case TemplateType.coaching:
        return Icons.business;
      case TemplateType.cute:
        return Icons.child_care;
      case TemplateType.board:
        return Icons.assignment;
    }
  }
}
