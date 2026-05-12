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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Colors.blue : (isDark ? Colors.white24 : Colors.grey[300]!),
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected ? Colors.blue : (isDark ? const Color(0xFF2A2D30) : Colors.white),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getIconForType(template.type),
                        color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]),
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
                            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.grey[800]),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _showSaveCustomDialog(context, ref, state),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? Colors.white24 : Colors.grey[300]!, 
              style: BorderStyle.solid
          ),
          color: isDark ? const Color(0xFF2A2D30) : Colors.grey[50],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: isDark ? Colors.grey[500] : Colors.grey, size: 32),
            const SizedBox(height: 8),
            Text(
              'Save Current\nas Custom',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveCustomDialog(BuildContext context, WidgetRef ref, TemplateState state) {
    final currentTemplateId = selectedTemplateId;
    final currentTemplate = state.all.firstWhere((t) => t.id == currentTemplateId, orElse: () => state.all.first);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: const Text('Save Custom Template', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Template Name', 
            hintText: 'My School Style',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(templateProvider.notifier).saveAsCustom(currentTemplate, controller.text);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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
