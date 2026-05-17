import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:edusheet/features/pdf/presentation/screens/template_designer_screen.dart';
import 'package:uuid/uuid.dart';

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
                onLongPress: () => _showTemplateActions(context, ref, template),
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Colors.blue : (isDark ? Colors.white24 : Colors.grey[300]!),
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected ? (isDark ? Colors.blue.withAlpha(50) : Colors.blue.withAlpha(20)) : (isDark ? const Color(0xFF2A2D30) : Colors.white),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 50,
                        width: 70,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withAlpha(50)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Center(
                          child: template.headerLayout == HeaderLayout.custom && template.customLayout != null
                              ? _buildTinyCustomLayout(template.customLayout!)
                              : Icon(
                                  _getIconForType(template.type),
                                  color: isSelected ? Colors.blue : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                  size: 24,
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          template.name,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.blue : (isDark ? Colors.white : Colors.grey[800]),
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

  Widget _buildTinyCustomLayout(CustomLayout layout) {
    const double a4Width = 595.27;
    const double scale = 70 / a4Width; // 70 is container width

    return Stack(
      children: layout.elements.map((el) {
        return Positioned(
          left: el.x * scale,
          top: el.y * scale,
          child: Container(
            width: (el.width ?? (a4Width - 64)) * scale,
            height: (el.height ?? 20) * scale,
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(100),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAddButton(BuildContext context, WidgetRef ref, TemplateState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _showImportSourceDialog(context, ref, state),
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
              'Design New\nTemplate',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showImportSourceDialog(BuildContext context, WidgetRef ref, TemplateState state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Custom Template', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
              title: const Text('Start from Scratch'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TemplateDesignerScreen()));
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Import Layout From:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: state.all.length,
                itemBuilder: (context, index) {
                  final template = state.all[index];
                  return ListTile(
                    leading: Icon(_getIconForType(template.type)),
                    title: Text(template.name),
                    subtitle: Text(template.headerLayout == HeaderLayout.custom ? 'Custom' : 'Standard'),
                    onTap: () {
                      Navigator.pop(context);
                      _duplicateAndEdit(context, template);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTemplateActions(BuildContext context, WidgetRef ref, PaperTemplate template) {
    final isCustom = template.headerLayout == HeaderLayout.custom;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Select Template'),
              onTap: () {
                Navigator.pop(context);
                onTemplateSelected(template.id);
              },
            ),
            if (isCustom)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Design'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => TemplateDesignerScreen(existingTemplate: template)));
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Duplicate & Customize'),
              onTap: () {
                Navigator.pop(context);
                _duplicateAndEdit(context, template);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _duplicateAndEdit(BuildContext context, PaperTemplate template) {
    final copy = template.copyWith(
      id: const Uuid().v4(),
      name: '${template.name} (Copy)',
      headerLayout: HeaderLayout.custom,
      customLayout: template.effectiveLayout,
    );
    Navigator.push(context, MaterialPageRoute(builder: (context) => TemplateDesignerScreen(existingTemplate: copy)));
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
