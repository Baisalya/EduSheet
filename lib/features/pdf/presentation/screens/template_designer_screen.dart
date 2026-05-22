import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class TemplateDesignerScreen extends ConsumerStatefulWidget {
  final PaperTemplate? existingTemplate;

  const TemplateDesignerScreen({super.key, this.existingTemplate});

  @override
  ConsumerState<TemplateDesignerScreen> createState() =>
      _TemplateDesignerScreenState();
}

class _TemplateDesignerScreenState
    extends ConsumerState<TemplateDesignerScreen> {
  late PaperTemplate _template;
  late List<TemplateElement> _elements;
  String? _selectedElementId;
  double _canvasHeight = 250;

  // Page size constants in points
  double get _pageWidth => _getPageDimensions(_template.paperSize).width;
  double get _pageHeight => _getPageDimensions(_template.paperSize).height;

  Size _getPageDimensions(PaperSize size) {
    switch (size) {
      case PaperSize.a4:
        return const Size(595.27, 841.89);
      case PaperSize.a5:
        return const Size(419.53, 595.27);
      case PaperSize.a3:
        return const Size(841.89, 1190.55);
      case PaperSize.letter:
        return const Size(612.0, 792.0);
      case PaperSize.legal:
        return const Size(612.0, 1008.0);
    }
  }

  bool _showGrid = true;
  bool _snapToGrid = true;
  final double _snapSize = 5.0;
  bool _isFullPageView = true;
  final FocusNode _keyboardFocusNode = FocusNode();
  final TransformationController _transformationController =
      TransformationController();

  double get _contentWidth => _pageWidth - 64;
  double get _editingHeight =>
      _isFullPageView ? (_pageHeight - 64) : _canvasHeight;

  TemplateElement? get _selectedElement {
    final selectedId = _selectedElementId;
    if (selectedId == null) return null;
    for (final element in _elements) {
      if (element.id == selectedId) return element;
    }
    return null;
  }

  double _defaultElementWidth(TemplateElement el) {
    return switch (el.type) {
      ElementType.logo => 80,
      ElementType.rectangular => 40,
      ElementType.horizontalLine => 200,
      ElementType.headerFieldsBlock => 300,
      _ => _contentWidth,
    };
  }

  double _defaultElementHeight(TemplateElement el) {
    return switch (el.type) {
      ElementType.logo => 80,
      ElementType.rectangular => 30,
      ElementType.horizontalLine => 1,
      _ => 24,
    };
  }

  double _clampX(double x, double width) {
    return x
        .clamp(0.0, (_contentWidth - width).clamp(0.0, _contentWidth))
        .toDouble();
  }

  double _clampY(double y, double height) {
    return y
        .clamp(0.0, (_editingHeight - height).clamp(0.0, _editingHeight))
        .toDouble();
  }

  @override
  void initState() {
    super.initState();
    if (widget.existingTemplate != null) {
      _template = widget.existingTemplate!;
      _elements = List.from(_template.customLayout?.elements ?? []);
      _canvasHeight = _template.customLayout?.canvasHeight ?? 250;
      // If we are opening an existing template, we still want to default to full page view
      _isFullPageView = true;
    } else {
      _template = PaperTemplate(
        id: const Uuid().v4(),
        name: 'New Custom Template',
        type: TemplateType.school,
        headerLayout: HeaderLayout.custom,
        hasBorder: true,
      );
      _canvasHeight = _pageHeight; // Default new templates to full page height
      _isFullPageView = true;
      _elements = [
        TemplateElement(
          id: const Uuid().v4(),
          type: ElementType.schoolName,
          x: 0,
          y: 20,
          width: CustomLayout.designWidth,
          properties: {'fontSize': 20.0, 'bold': true, 'alignment': 'center'},
        ),
      ];
    }
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _centerElement(String id) {
    setState(() {
      final index = _elements.indexWhere((e) => e.id == id);
      if (index != -1) {
        final el = _elements[index];
        final w = el.width ?? _defaultElementWidth(el);
        _elements[index] = el.copyWith(x: _clampX((_contentWidth - w) / 2, w));
      }
    });
  }

  void _addElement(ElementType type) async {
    String content = '';
    Map<String, dynamic> extraProps = {};

    if (type == ElementType.staticText) {
      final result = await _showTextEntryDialog(
        'Enter Text',
        'Add some text to your template',
      );
      if (result == null || result.isEmpty) return;
      content = result;
    } else if (type == ElementType.logo) {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      content = image.path;
    } else if (type == ElementType.headerFieldsBlock) {
      final result = await _showFieldsDialog();
      if (result == null) return;
      extraProps['fieldLabels'] = result;
    }

    setState(() {
      final newElement = TemplateElement(
        id: const Uuid().v4(),
        type: type,
        x: 50,
        y: 50,
        width: type == ElementType.logo
            ? 80
            : (type == ElementType.horizontalLine
                  ? 200
                  : (type == ElementType.rectangular ? 40 : _contentWidth)),
        height: type == ElementType.logo
            ? 80
            : (type == ElementType.horizontalLine
                  ? 1
                  : (type == ElementType.rectangular ? 30 : null)),
        content: content,
        properties: {
          'fontSize': 14.0,
          'bold':
              type == ElementType.schoolName || type == ElementType.paperTitle,
          'alignment': 'left',
          'color': 0xFF000000,
          if (type == ElementType.rectangular) ...{
            'borderColor': 0xFF000000,
            'borderWidth': 1.0,
          },
          ...extraProps,
        },
      );
      _elements.add(newElement);
      _selectedElementId = newElement.id;
    });
  }

  Future<String?> _showTextEntryDialog(
    String title,
    String hint, {
    String? initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<List<String>?> _showFieldsDialog({
    List<String>? initialSelected,
  }) async {
    final List<String> available = [
      'Roll No',
      'Name',
      'Section',
      'Date',
      'Subject',
      'Time',
      'Class',
    ];
    final List<String> selected = initialSelected != null
        ? List.from(initialSelected)
        : ['Subject', 'Date'];
    final customController = TextEditingController();

    // Ensure all initially selected are in available list
    for (var s in selected) {
      if (!available.contains(s)) available.add(s);
    }

    return showDialog<List<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Select Fields to Include'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ...available.map(
                        (f) => CheckboxListTile(
                          title: Text(f),
                          dense: true,
                          value: selected.contains(f),
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                selected.add(f);
                              } else {
                                selected.remove(f);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customController,
                          decoration: const InputDecoration(
                            hintText: 'Custom Field...',
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.blue),
                        onPressed: () {
                          if (customController.text.isNotEmpty) {
                            setModalState(() {
                              available.add(customController.text);
                              selected.add(customController.text);
                              customController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Add Block'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateElement(
    String id, {
    double? x,
    double? y,
    double? width,
    double? height,
    Map<String, dynamic>? props,
  }) {
    setState(() {
      final index = _elements.indexWhere((e) => e.id == id);
      if (index != -1) {
        final current = _elements[index];
        final newWidth = width ?? current.width;
        final newHeight = height ?? current.height;
        final effectiveWidth = newWidth ?? _defaultElementWidth(current);
        final effectiveHeight = newHeight ?? _defaultElementHeight(current);
        double newX = x ?? current.x;
        double newY = y ?? current.y;

        if (_snapToGrid && _snapSize > 0) {
          newX = (newX / _snapSize).round() * _snapSize;
          newY = (newY / _snapSize).round() * _snapSize;
        }

        newX = _clampX(newX, effectiveWidth);
        newY = _clampY(newY, effectiveHeight);

        _elements[index] = current.copyWith(
          x: newX,
          y: newY,
          width: width,
          height: height,
          properties: props != null ? {...current.properties, ...props} : null,
        );
      }
    });
  }

  void _resizeElement(String id, {double? deltaWidth, double? deltaHeight}) {
    final el = _elements.firstWhere((e) => e.id == id);
    final minWidth = el.type == ElementType.horizontalLine ? 20.0 : 16.0;
    final minHeight = el.type == ElementType.horizontalLine ? 1.0 : 12.0;
    final nextWidth =
        ((el.width ?? _defaultElementWidth(el)) + (deltaWidth ?? 0)).clamp(
          minWidth,
          _contentWidth - el.x,
        );
    final shouldResizeHeight =
        el.type == ElementType.logo || el.type == ElementType.rectangular;
    final nextHeight = shouldResizeHeight
        ? ((el.height ?? _defaultElementHeight(el)) + (deltaHeight ?? 0))
              .clamp(minHeight, _editingHeight - el.y)
              .toDouble()
        : el.height;

    _updateElement(id, width: nextWidth.toDouble(), height: nextHeight);
  }

  void _nudgeSelected(double dx, double dy) {
    final el = _selectedElement;
    if (el == null) return;
    _updateElement(el.id, x: el.x + dx, y: el.y + dy);
  }

  void _adjustSelectedFont(double delta) {
    final el = _selectedElement;
    if (el == null) return;
    final current = el.properties['fontSize']?.toDouble() ?? 14.0;
    _updateElement(
      el.id,
      props: {'fontSize': (current + delta).clamp(6.0, 72.0)},
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && _selectedElementId != null) {
      if (event.logicalKey == LogicalKeyboardKey.delete ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        _deleteElement(_selectedElementId!);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        final el = _elements.firstWhere((e) => e.id == _selectedElementId);
        _updateElement(el.id, y: el.y - 1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final el = _elements.firstWhere((e) => e.id == _selectedElementId);
        _updateElement(el.id, y: el.y + 1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        final el = _elements.firstWhere((e) => e.id == _selectedElementId);
        _updateElement(el.id, x: el.x - 1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        final el = _elements.firstWhere((e) => e.id == _selectedElementId);
        _updateElement(el.id, x: el.x + 1);
      }
    }
  }

  void _deleteElement(String id) {
    setState(() {
      _elements.removeWhere((e) => e.id == id);
      if (_selectedElementId == id) _selectedElementId = null;
    });
  }

  void _showPageSettingsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Page Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Page Border'),
                value: _template.hasBorder,
                onChanged: (val) {
                  setState(
                    () => _template = _template.copyWith(hasBorder: val),
                  );
                  setModalState(() {});
                },
              ),
              ListTile(
                title: const Text('Paper Layout'),
                trailing: DropdownButton<PaperLayout>(
                  value: _template.paperLayout,
                  items: PaperLayout.values
                      .map(
                        (l) => DropdownMenuItem(
                          value: l,
                          child: Text(l.name.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(
                        () => _template = _template.copyWith(paperLayout: val),
                      );
                      setModalState(() {});
                    }
                  },
                ),
              ),
              ListTile(
                title: const Text('Paper Size'),
                trailing: DropdownButton<PaperSize>(
                  value: _template.paperSize,
                  items: PaperSize.values
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.name.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _template = _template.copyWith(paperSize: val);
                        if (_isFullPageView) _canvasHeight = _pageHeight;
                      });
                      setModalState(() {});
                    }
                  },
                ),
              ),
              const Divider(),
              const Text(
                'Colors',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildColorTile('Primary Color', _template.primaryColor, (color) {
                setState(
                  () => _template = _template.copyWith(primaryColor: color),
                );
                setModalState(() {});
              }),
              _buildColorTile('Secondary Color', _template.secondaryColor, (
                color,
              ) {
                setState(
                  () => _template = _template.copyWith(secondaryColor: color),
                );
                setModalState(() {});
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorTile(
    String title,
    PdfColor color,
    ValueChanged<PdfColor> onSelected,
  ) {
    final colors = [
      PdfColors.black,
      PdfColors.blue900,
      PdfColors.red900,
      PdfColors.green900,
      PdfColors.purple900,
      PdfColors.pink900,
      PdfColors.blue100,
      PdfColors.grey300,
      PdfColors.yellow100,
    ];

    return ListTile(
      title: Text(title),
      subtitle: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: colors
              .map(
                (c) => GestureDetector(
                  onTap: () => onSelected(c),
                  child: Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(right: 8, top: 8),
                    decoration: BoxDecoration(
                      color: Color(c.toInt()),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                      boxShadow: color == c
                          ? [const BoxShadow(color: Colors.blue, blurRadius: 4)]
                          : null,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _showSaveDialog() async {
    final controller = TextEditingController(text: _template.name);
    final String? name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Template'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Template Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final updatedTemplate = _template.copyWith(
        name: name,
        customLayout: CustomLayout(
          elements: _elements,
          canvasHeight: _canvasHeight,
        ),
      );
      final navigator = Navigator.of(context);
      await ref.read(templateProvider.notifier).saveTemplate(updatedTemplate);
      if (mounted) {
        navigator.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final selectedElement = _selectedElement;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFF5F5F5),
        appBar: AppBar(
          elevation: 0,
          title: Text(_template.name, style: const TextStyle(fontSize: 14)),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.save_outlined, size: 20),
              label: const Text('Save'),
              onPressed: _showSaveDialog,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            _buildConsolidatedRibbon(isCompact: isMobile),
            Expanded(
              child: Stack(children: [_buildCanvas(), _buildCanvasControls()]),
            ),
            if (isMobile) _buildMobileInspector(selectedElement),
          ],
        ),
      ),
    );
  }

  Widget _buildConsolidatedRibbon({bool isCompact = false}) {
    final el = _selectedElement;

    return Container(
      height: isCompact ? 92 : 140,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8 : 16,
          vertical: 8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _RibbonGroup(
              label: 'INSERT',
              children: [
                _RibbonButton(
                  icon: Icons.text_fields,
                  label: 'School',
                  onTap: () => _addElement(ElementType.schoolName),
                ),
                _RibbonButton(
                  icon: Icons.title,
                  label: 'Title',
                  onTap: () => _addElement(ElementType.paperTitle),
                ),
                _RibbonButton(
                  icon: Icons.image,
                  label: 'Logo',
                  onTap: () => _addElement(ElementType.logo),
                ),
                _RibbonButton(
                  icon: Icons.grid_view,
                  label: 'Fields',
                  onTap: () => _addElement(ElementType.headerFieldsBlock),
                ),
                _RibbonButton(
                  icon: Icons.horizontal_rule,
                  label: 'Line',
                  onTap: () => _addElement(ElementType.horizontalLine),
                ),
                _RibbonButton(
                  icon: Icons.check_box_outline_blank,
                  label: 'Box',
                  onTap: () => _addElement(ElementType.rectangular),
                ),
              ],
            ),
            _VerticalDivider(),
            if (el != null && !isCompact) ...[
              _RibbonGroup(
                label: 'FORMATTING',
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          _buildMiniDropDown<double>(
                            value:
                                el.properties['fontSize']?.toDouble() ?? 14.0,
                            items: [
                              8,
                              9,
                              10,
                              11,
                              12,
                              14,
                              16,
                              18,
                              20,
                              24,
                              28,
                              32,
                            ],
                            onChanged: (v) =>
                                _updateElement(el.id, props: {'fontSize': v}),
                          ),
                          const SizedBox(width: 4),
                          _ToggleButton(
                            icon: Icons.format_bold,
                            isActive: el.properties['bold'] == true,
                            onTap: () => _updateElement(
                              el.id,
                              props: {'bold': !(el.properties['bold'] == true)},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _AlignmentButton(
                            icon: Icons.format_align_left,
                            isActive: el.properties['alignment'] == 'left',
                            onTap: () => _updateElement(
                              el.id,
                              props: {'alignment': 'left'},
                            ),
                          ),
                          _AlignmentButton(
                            icon: Icons.format_align_center,
                            isActive: el.properties['alignment'] == 'center',
                            onTap: () => _updateElement(
                              el.id,
                              props: {'alignment': 'center'},
                            ),
                          ),
                          _AlignmentButton(
                            icon: Icons.format_align_right,
                            isActive: el.properties['alignment'] == 'right',
                            onTap: () => _updateElement(
                              el.id,
                              props: {'alignment': 'right'},
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              _VerticalDivider(),
              if (el.type == ElementType.headerFieldsBlock) ...[
                _RibbonGroup(
                  label: 'FIELDS',
                  children: [
                    _RibbonButton(
                      icon: Icons.edit_note,
                      label: 'Edit Fields',
                      onTap: () async {
                        final current = List<String>.from(
                          el.properties['fieldLabels'] ?? [],
                        );
                        final result = await _showFieldsDialog(
                          initialSelected: current,
                        );
                        if (result != null) {
                          _updateElement(el.id, props: {'fieldLabels': result});
                        }
                      },
                    ),
                  ],
                ),
                _VerticalDivider(),
              ],
              if (el.type == ElementType.staticText) ...[
                _RibbonGroup(
                  label: 'CONTENT',
                  children: [
                    SizedBox(
                      width: 150,
                      child: TextField(
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: 'Enter text...',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.all(8),
                        ),
                        onChanged: (val) => setState(() {
                          final idx = _elements.indexWhere(
                            (e) => e.id == el.id,
                          );
                          _elements[idx] = _elements[idx].copyWith(
                            content: val,
                          );
                        }),
                        controller: TextEditingController(text: el.content),
                      ),
                    ),
                  ],
                ),
                _VerticalDivider(),
              ],
              _RibbonGroup(
                label: 'SIZE',
                children: [
                  SizedBox(
                    width: 120,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'W',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 5,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 10,
                                  ),
                                ),
                                child: Slider(
                                  value: (el.width ?? _defaultElementWidth(el))
                                      .clamp(10.0, _contentWidth),
                                  min: 10,
                                  max: _contentWidth,
                                  onChanged: (val) =>
                                      _updateElement(el.id, width: val),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (el.type == ElementType.logo ||
                            el.type == ElementType.rectangular)
                          Row(
                            children: [
                              const Text(
                                'H',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 5,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 10,
                                    ),
                                  ),
                                  child: Slider(
                                    value:
                                        (el.height ?? _defaultElementHeight(el))
                                            .clamp(10.0, 300.0),
                                    min: 10,
                                    max: 300,
                                    onChanged: (val) =>
                                        _updateElement(el.id, height: val),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              _VerticalDivider(),
              _RibbonGroup(
                label: 'ACTIONS',
                children: [
                  _RibbonButton(
                    icon: Icons.align_horizontal_center,
                    label: 'Center',
                    onTap: () => _centerElement(el.id),
                  ),
                  _RibbonButton(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    iconColor: Colors.red,
                    onTap: () => _deleteElement(el.id),
                  ),
                ],
              ),
            ] else if (!isCompact)
              _RibbonGroup(
                label: 'SELECTION',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Select an element\nto format it',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            _VerticalDivider(),
            _RibbonGroup(
              label: 'PAGE',
              children: [
                _RibbonToggle(
                  icon: Icons.grid_on,
                  label: 'Grid',
                  value: _showGrid,
                  onChanged: (v) => setState(() => _showGrid = v),
                ),
                _RibbonToggle(
                  icon: Icons.edgesensor_low,
                  label: 'Snap',
                  value: _snapToGrid,
                  onChanged: (v) => setState(() => _snapToGrid = v),
                ),
                _RibbonToggle(
                  icon: Icons.fullscreen,
                  label: 'Full Page',
                  value: _isFullPageView,
                  onChanged: (v) => setState(() {
                    _isFullPageView = v;
                    if (v) _canvasHeight = _pageHeight;
                  }),
                ),
                _RibbonButton(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: _showPageSettingsDialog,
                ),
                _RibbonButton(
                  icon: Icons.height,
                  label: 'Height',
                  onTap: _showCanvasHeightDialog,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniDropDown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    final menuItems = <T>[];
    for (final item in [...items, value]) {
      if (!menuItems.contains(item)) {
        menuItems.add(item);
      }
    }

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          style: const TextStyle(fontSize: 11, color: Colors.black),
          items: menuItems
              .map((i) => DropdownMenuItem(value: i, child: Text(i.toString())))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildMobileInspector(TemplateElement? el) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.12)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: el == null
            ? SizedBox(
                height: 76,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  children: [
                    _MobileActionButton(
                      icon: Icons.text_fields,
                      label: 'School',
                      onTap: () => _addElement(ElementType.schoolName),
                    ),
                    _MobileActionButton(
                      icon: Icons.title,
                      label: 'Title',
                      onTap: () => _addElement(ElementType.paperTitle),
                    ),
                    _MobileActionButton(
                      icon: Icons.image_outlined,
                      label: 'Logo',
                      onTap: () => _addElement(ElementType.logo),
                    ),
                    _MobileActionButton(
                      icon: Icons.grid_view,
                      label: 'Fields',
                      onTap: () => _addElement(ElementType.headerFieldsBlock),
                    ),
                    _MobileActionButton(
                      icon: Icons.horizontal_rule,
                      label: 'Line',
                      onTap: () => _addElement(ElementType.horizontalLine),
                    ),
                    _MobileActionButton(
                      icon: Icons.check_box_outline_blank,
                      label: 'Box',
                      onTap: () => _addElement(ElementType.rectangular),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _elementTitle(el),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.align_horizontal_center,
                            size: 20,
                          ),
                          onPressed: () => _centerElement(el.id),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () =>
                              setState(() => _selectedElementId = null),
                        ),
                      ],
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _NudgePad(onNudge: _nudgeSelected),
                          const SizedBox(width: 10),
                          _StepControl(
                            label: 'Font',
                            value:
                                '${(el.properties['fontSize']?.toDouble() ?? 14.0).toStringAsFixed(1)}',
                            onMinus: () => _adjustSelectedFont(-0.5),
                            onPlus: () => _adjustSelectedFont(0.5),
                          ),
                          const SizedBox(width: 8),
                          _StepControl(
                            label: 'Width',
                            value:
                                '${(el.width ?? _defaultElementWidth(el)).round()}',
                            onMinus: () =>
                                _resizeElement(el.id, deltaWidth: -5),
                            onPlus: () => _resizeElement(el.id, deltaWidth: 5),
                          ),
                          if (el.type == ElementType.logo ||
                              el.type == ElementType.rectangular) ...[
                            const SizedBox(width: 8),
                            _StepControl(
                              label: 'Height',
                              value:
                                  '${(el.height ?? _defaultElementHeight(el)).round()}',
                              onMinus: () =>
                                  _resizeElement(el.id, deltaHeight: -5),
                              onPlus: () =>
                                  _resizeElement(el.id, deltaHeight: 5),
                            ),
                          ],
                          const SizedBox(width: 8),
                          _MobileActionButton(
                            icon: Icons.format_bold,
                            label: 'Bold',
                            selected: el.properties['bold'] == true,
                            onTap: () => _updateElement(
                              el.id,
                              props: {'bold': !(el.properties['bold'] == true)},
                            ),
                          ),
                          _MobileActionButton(
                            icon: Icons.delete_outline,
                            label: 'Delete',
                            color: Colors.redAccent,
                            onTap: () => _deleteElement(el.id),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  String _elementTitle(TemplateElement el) {
    return switch (el.type) {
      ElementType.schoolName => 'School name',
      ElementType.paperTitle => 'Paper title',
      ElementType.logo => 'Logo',
      ElementType.maxMarks => 'Max marks',
      ElementType.headerFieldsBlock => 'Header fields',
      ElementType.staticText => 'Text',
      ElementType.horizontalLine => 'Line',
      ElementType.rectangular => 'Box',
    };
  }

  void _showCanvasHeightDialog() {
    final controller = TextEditingController(text: _canvasHeight.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust Header Height'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Height in points (e.g. 250)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _canvasHeight =
                    double.tryParse(controller.text) ?? _canvasHeight;
                if (_canvasHeight < _pageHeight) _isFullPageView = false;
              });
              Navigator.pop(context);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate auto-scale to fit screen width exactly
        final double availableWidth = constraints.maxWidth;
        final double autoScale = availableWidth / _pageWidth;

        // We use a slightly smaller scale to give a tiny breathing room (e.g. 0.95)
        final double baseScale = autoScale * 0.95;

        return InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.2,
          maxScale: 5.0,
          // Set boundaryMargin to allowing panning slightly beyond the page
          boundaryMargin: EdgeInsets.symmetric(
            horizontal: availableWidth * 0.5,
            vertical: constraints.maxHeight * 0.5,
          ),
          child: Center(
            child: Container(
              width: _pageWidth * baseScale,
              height:
                  (_isFullPageView ? _pageHeight : _canvasHeight) * baseScale,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Grid starting from margins
                  if (_showGrid)
                    Positioned(
                      left: 32 * baseScale,
                      top: 32 * baseScale,
                      right: 32 * baseScale,
                      bottom: 32 * baseScale,
                      child: CustomPaint(
                        painter: GridPainter(scale: baseScale, step: _snapSize),
                      ),
                    ),

                  // Margin indicators (Teacher friendly)
                  Positioned.fill(
                    child: Container(
                      margin: EdgeInsets.all(32 * baseScale),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),

                  if (_template.hasBorder)
                    Positioned.fill(
                      child: Container(
                        margin: EdgeInsets.all(10 * baseScale),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Color(_template.primaryColor.toInt()),
                            width: 1.5 * baseScale,
                          ),
                        ),
                      ),
                    ),

                  Padding(
                    padding: EdgeInsets.all(32 * baseScale),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ..._elements.map(
                          (el) => _buildSmartElement(el, baseScale),
                        ),
                        if (!_isFullPageView)
                          Positioned(
                            bottom: -40 * baseScale,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                Container(
                                  height: 30 * baseScale,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.blue.withValues(alpha: 0.05),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.arrow_downward,
                                          size: 10 * baseScale,
                                          color: Colors.blue[300],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'QUESTION AREA STARTS HERE',
                                          style: TextStyle(
                                            fontSize: 9 * baseScale,
                                            color: Colors.blue[300],
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_downward,
                                          size: 10 * baseScale,
                                          color: Colors.blue[300],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_template.paperLayout ==
                                    PaperLayout.twoColumn)
                                  Container(
                                    height: 150 * baseScale,
                                    width: 1,
                                    color: Colors.blue.withValues(alpha: 0.2),
                                    margin: EdgeInsets.only(
                                      top: 10 * baseScale,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmartElement(TemplateElement el, double scale) {
    final isSelected = _selectedElementId == el.id;
    final handleSize = MediaQuery.sizeOf(context).width < 700 ? 22.0 : 12.0;

    return Positioned(
      left: el.x * scale,
      top: el.y * scale,
      child: GestureDetector(
        onTap: () => setState(() => _selectedElementId = el.id),
        onDoubleTap: () async {
          if (el.type == ElementType.staticText) {
            final result = await _showTextEntryDialog(
              'Edit Text',
              'Enter new text content',
              initialValue: el.content,
            );
            if (result != null) {
              final idx = _elements.indexWhere((e) => e.id == el.id);
              setState(
                () => _elements[idx] = _elements[idx].copyWith(content: result),
              );
            }
          } else if (el.type == ElementType.headerFieldsBlock) {
            final current = List<String>.from(
              el.properties['fieldLabels'] ?? [],
            );
            final result = await _showFieldsDialog(initialSelected: current);
            if (result != null) {
              _updateElement(el.id, props: {'fieldLabels': result});
            }
          }
        },
        onPanUpdate: (details) {
          _updateElement(
            el.id,
            x: el.x + details.delta.dx / scale,
            y: el.y + details.delta.dy / scale,
          );
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          child: Container(
            decoration: BoxDecoration(
              border: isSelected
                  ? Border.all(color: Colors.blue, width: 1)
                  : Border.all(color: Colors.transparent),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _buildElementPreview(el, scale),
                if (isSelected) ...[
                  _buildHandle(0, 0, handleSize),
                  _buildHandle(null, 0, handleSize),
                  _buildHandle(0, null, handleSize),
                  _buildResizeHandle(el, scale, handleSize),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(double? left, double? top, double size) {
    return Positioned(
      left: left == 0 ? -size / 2 : null,
      right: left == null ? -size / 2 : null,
      top: top == 0 ? -size / 2 : null,
      bottom: top == null ? -size / 2 : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.blue),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildResizeHandle(TemplateElement el, double scale, double size) {
    return Positioned(
      right: -size / 2,
      bottom: -size / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => _resizeElement(
          el.id,
          deltaWidth: details.delta.dx / scale,
          deltaHeight: details.delta.dy / scale,
        ),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.blue,
            border: Border.all(color: Colors.white, width: 2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.open_in_full, color: Colors.white, size: 11),
        ),
      ),
    );
  }

  Widget _buildElementPreview(TemplateElement el, double scale) {
    final color = el.properties['color'] != null
        ? Color(el.properties['color'])
        : (el.type == ElementType.schoolName &&
                  _template.type == TemplateType.coaching
              ? Color(_template.primaryColor.toInt())
              : Colors.black);

    final fontSize = (el.properties['fontSize']?.toDouble() ?? 14.0) * scale;
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: el.properties['bold'] == true
          ? FontWeight.bold
          : FontWeight.normal,
      color: color,
    );

    final alignment = _getFlutterAlignment(el.properties['alignment']);

    switch (el.type) {
      case ElementType.schoolName:
        return Container(
          width: (el.width ?? (_pageWidth - 64)) * scale,
          alignment: alignment,
          child: Text('SAMPLE SCHOOL NAME', style: style),
        );
      case ElementType.paperTitle:
        return Container(
          width: (el.width ?? (_pageWidth - 64)) * scale,
          alignment: alignment,
          child: Text('SAMPLE PAPER TITLE', style: style),
        );
      case ElementType.logo:
        return Container(
          width: (el.width ?? 80) * scale,
          height: (el.height ?? 80) * scale,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: el.content.isNotEmpty
              ? Image.file(File(el.content), fit: BoxFit.contain)
              : const Center(child: Icon(Icons.add_a_photo, size: 20)),
        );
      case ElementType.headerFieldsBlock:
        final List<dynamic> labels =
            el.properties['fieldLabels'] ?? ['Subject', 'Date'];
        return Container(
          width: (el.width ?? 300) * scale,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 4,
            children: labels
                .map(
                  (l) => Text(
                    '$l: __________',
                    style: style.copyWith(fontSize: fontSize * 0.85),
                  ),
                )
                .toList(),
          ),
        );
      case ElementType.maxMarks:
        return Container(
          width: (el.width ?? (_pageWidth - 64)) * scale,
          alignment: alignment,
          child: Text('Max Marks: 100', style: style),
        );
      case ElementType.staticText:
        return Container(
          width: (el.width ?? (_pageWidth - 64)) * scale,
          alignment: alignment,
          child: Text(el.content, style: style),
        );
      case ElementType.horizontalLine:
        return Container(
          width: (el.width ?? 200) * scale,
          height: 2,
          color: style.color,
        );
      case ElementType.rectangular:
        return Container(
          width: (el.width ?? 50) * scale,
          height: (el.height ?? 50) * scale,
          decoration: BoxDecoration(
            color: el.properties['fillColor'] != null
                ? Color(el.properties['fillColor'])
                : null,
            border: Border.all(
              color: el.properties['borderColor'] != null
                  ? Color(el.properties['borderColor'])
                  : Colors.black,
              width: (el.properties['borderWidth']?.toDouble() ?? 1.0) * scale,
            ),
            borderRadius: el.properties['borderRadius'] != null
                ? BorderRadius.circular(
                    el.properties['borderRadius'].toDouble() * scale,
                  )
                : null,
          ),
          alignment: alignment,
          child: el.content.isNotEmpty ? Text(el.content, style: style) : null,
        );
      default:
        return const SizedBox();
    }
  }

  Alignment _getFlutterAlignment(String? align) {
    switch (align) {
      case 'center':
        return Alignment.center;
      case 'right':
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }

  Widget _buildCanvasControls() {
    return Positioned(
      bottom: 20,
      left: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Text(
          '120% | A4 Layout',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }
}

class _RibbonGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _RibbonGroup({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(child: Row(children: children)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.grey[400],
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _RibbonButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  const _RibbonButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: iconColor ?? Colors.blue[800]),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _RibbonToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _RibbonToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: value ? Colors.blue[800] : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: value ? Colors.blue[800] : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 60,
      color: Colors.grey.withValues(alpha: 0.15),
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  const _ToggleButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.blue.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: isActive ? Colors.blue : Colors.grey.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? Colors.blue : Colors.grey[700],
        ),
      ),
    );
  }
}

class _AlignmentButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  const _AlignmentButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.blue.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.blue : Colors.grey[600],
          size: 18,
        ),
      ),
    );
  }
}

class _MobileActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color? color;

  const _MobileActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 68,
        height: 58,
        child: Material(
          color: selected
              ? activeColor.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: activeColor),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: activeColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepControl extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _StepControl({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 18),
            onPressed: onMinus,
          ),
          SizedBox(
            width: 54,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18),
            onPressed: onPlus,
          ),
        ],
      ),
    );
  }
}

class _NudgePad extends StatelessWidget {
  final void Function(double dx, double dy) onNudge;

  const _NudgePad({required this.onNudge});

  @override
  Widget build(BuildContext context) {
    Widget nudgeButton(IconData icon, double dx, double dy) {
      return SizedBox(
        width: 30,
        height: 19,
        child: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: 17),
          onPressed: () => onNudge(dx, dy),
        ),
      );
    }

    return Container(
      width: 92,
      height: 58,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          nudgeButton(Icons.keyboard_arrow_up, 0, -5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              nudgeButton(Icons.keyboard_arrow_left, -5, 0),
              nudgeButton(Icons.keyboard_arrow_right, 5, 0),
            ],
          ),
          nudgeButton(Icons.keyboard_arrow_down, 0, 5),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final double scale;
  final double step;
  GridPainter({required this.scale, required this.step});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 0.5;

    for (double i = 0; i < size.width; i += step * scale) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step * scale) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
