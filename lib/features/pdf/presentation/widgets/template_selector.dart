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
                    color: isSelected ? Colors.blue : (isDark ? const Color(0xFF2A2D30) : Colors.white),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        template.headerLayout.name == 'custom' ? Icons.dashboard_customize : _getIconForType(template.type),
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
      customLayout: _convertToCustomLayout(template),
    );
    Navigator.push(context, MaterialPageRoute(builder: (context) => TemplateDesignerScreen(existingTemplate: copy)));
  }

  CustomLayout _convertToCustomLayout(PaperTemplate template) {
    if (template.customLayout != null) return template.customLayout!;

    final elements = <TemplateElement>[];
    const uuid = Uuid();
    const double a4Width = 595.27;
    const double contentWidth = a4Width - 64;

    switch (template.headerLayout) {
      case HeaderLayout.centered:
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.logo,
          x: (contentWidth - 50) / 2,
          y: 0,
          width: 50,
          height: 50,
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.schoolName,
          x: 0,
          y: 58,
          width: contentWidth,
          properties: {'fontSize': 18.0, 'bold': true, 'alignment': 'center'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.paperTitle,
          x: 0,
          y: 80,
          width: contentWidth,
          properties: {'fontSize': template.headerFontSize, 'bold': true, 'alignment': 'center'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.headerFieldsBlock,
          x: 0,
          y: 110,
          width: contentWidth,
          properties: {'fontSize': 12.0, 'alignment': 'center'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.maxMarks,
          x: 0,
          y: 150,
          width: contentWidth,
          properties: {'fontSize': 12.0, 'bold': true, 'alignment': 'right'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.horizontalLine,
          x: 0,
          y: 175,
          width: contentWidth,
          properties: {'color': 0xFF000000},
        ));
        return CustomLayout(elements: elements, canvasHeight: 180);

      case HeaderLayout.logoLeft:
      case HeaderLayout.logoRight:
        final isLeft = template.headerLayout == HeaderLayout.logoLeft;
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.logo,
          x: isLeft ? 0 : contentWidth - 60,
          y: 0,
          width: 60,
          height: 60,
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.schoolName,
          x: isLeft ? 76 : 0,
          y: 5,
          width: contentWidth - 76,
          properties: {'fontSize': 18.0, 'bold': true, 'alignment': isLeft ? 'left' : 'right'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.paperTitle,
          x: isLeft ? 76 : 0,
          y: 28,
          width: contentWidth - 76,
          properties: {'fontSize': template.headerFontSize, 'bold': true, 'alignment': isLeft ? 'left' : 'right'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.maxMarks,
          x: 0,
          y: 70,
          width: contentWidth,
          properties: {'fontSize': 12.0, 'bold': true, 'alignment': isLeft ? 'right' : 'left'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.headerFieldsBlock,
          x: 0,
          y: 95,
          width: contentWidth,
          properties: {'fontSize': 11.0, 'alignment': 'left'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.horizontalLine,
          x: 0,
          y: 135,
          width: contentWidth,
          properties: {'color': 0xFF000000},
        ));
        return CustomLayout(elements: elements, canvasHeight: 140);

      case HeaderLayout.modernCoaching:
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.logo,
          x: 10,
          y: 10,
          width: 60,
          height: 60,
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.schoolName,
          x: 90,
          y: 15,
          width: contentWidth - 200,
          properties: {
            'fontSize': 20.0,
            'bold': true,
            'alignment': 'left',
            'color': template.primaryColor.toInt(),
          },
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.paperTitle,
          x: 90,
          y: 42,
          width: contentWidth - 200,
          properties: {'fontSize': 16.0, 'alignment': 'left'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.maxMarks,
          x: contentWidth - 110,
          y: 30,
          width: 100,
          properties: {'fontSize': 12.0, 'bold': true, 'alignment': 'right'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.headerFieldsBlock,
          x: 10,
          y: 85,
          width: contentWidth - 20,
          properties: {'fontSize': 11.0, 'alignment': 'left'},
        ));
        // Note: Modern coaching has a background container and a bottom border. 
        // We can't easily represent a full-width background box in current ElementType.
        // But we can add a thick line at the bottom.
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.horizontalLine,
          x: 0,
          y: 125,
          width: contentWidth,
          properties: {'color': template.primaryColor.toInt()},
        ));
        return CustomLayout(elements: elements, canvasHeight: 130);

      case HeaderLayout.minimal:
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.schoolName,
          x: 0,
          y: 0,
          width: contentWidth / 2,
          properties: {'fontSize': 10.0, 'bold': true, 'alignment': 'left', 'color': 0xFF9E9E9E},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.maxMarks,
          x: contentWidth / 2,
          y: 0,
          width: contentWidth / 2,
          properties: {'fontSize': 10.0, 'bold': true, 'alignment': 'right'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.paperTitle,
          x: 0,
          y: 15,
          width: contentWidth,
          properties: {'fontSize': 14.0, 'bold': true, 'alignment': 'left'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.headerFieldsBlock,
          x: 0,
          y: 40,
          width: contentWidth,
          properties: {'fontSize': 11.0, 'alignment': 'left'},
        ));
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.horizontalLine,
          x: 0,
          y: 75,
          width: contentWidth,
          properties: {'color': 0xFF000000},
        ));
        return CustomLayout(elements: elements, canvasHeight: 80);

      default:
        elements.add(TemplateElement(
          id: uuid.v4(),
          type: ElementType.schoolName,
          x: 0,
          y: 20,
          width: contentWidth,
          properties: {'fontSize': 20.0, 'bold': true, 'alignment': 'center'},
        ));
        return CustomLayout(elements: elements, canvasHeight: 100);
    }
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
