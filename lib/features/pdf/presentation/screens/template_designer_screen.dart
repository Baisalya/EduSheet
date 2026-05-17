import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/presentation/providers/template_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

class TemplateDesignerScreen extends ConsumerStatefulWidget {
  final PaperTemplate? existingTemplate;

  const TemplateDesignerScreen({super.key, this.existingTemplate});

  @override
  ConsumerState<TemplateDesignerScreen> createState() => _TemplateDesignerScreenState();
}

class _TemplateDesignerScreenState extends ConsumerState<TemplateDesignerScreen> {
  late PaperTemplate _template;
  late List<TemplateElement> _elements;
  String? _selectedElementId;
  double _canvasHeight = 250;
  
  // Page size constants in points
  double get _pageWidth => _getPageDimensions(_template.paperSize).width;
  double get _pageHeight => _getPageDimensions(_template.paperSize).height;

  Size _getPageDimensions(PaperSize size) {
    switch (size) {
      case PaperSize.a4: return const Size(595.27, 841.89);
      case PaperSize.a5: return const Size(419.53, 595.27);
      case PaperSize.a3: return const Size(841.89, 1190.55);
      case PaperSize.letter: return const Size(612.0, 792.0);
      case PaperSize.legal: return const Size(612.0, 1008.0);
    }
  }

  bool _showGrid = true;
  final double _snapSize = 5.0;
  bool _isFullPageView = false;
  double _zoomScale = 1.0;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    if (widget.existingTemplate != null) {
      _template = widget.existingTemplate!;
      _elements = List.from(_template.customLayout?.elements ?? []);
      _canvasHeight = _template.customLayout?.canvasHeight ?? 250;
    } else {
      _template = PaperTemplate(
        id: const Uuid().v4(),
        name: 'New Custom Template',
        type: TemplateType.school,
        headerLayout: HeaderLayout.custom,
        hasBorder: true,
      );
      _elements = [
        TemplateElement(
          id: const Uuid().v4(),
          type: ElementType.schoolName,
          x: 0,
          y: 20,
          width: 595.27 - 64, // Default A4
          properties: {'fontSize': 20.0, 'bold': true, 'alignment': 'center'},
        ),
      ];
    }
  }

  void _centerElement(String id) {
    setState(() {
      final index = _elements.indexWhere((e) => e.id == id);
      if (index != -1) {
        final el = _elements[index];
        final w = el.width ?? (_pageWidth - 64);
        _elements[index] = el.copyWith(x: ((_pageWidth - 64) - w) / 2);
      }
    });
  }

  void _addElement(ElementType type) {
    setState(() {
      final newElement = TemplateElement(
        id: const Uuid().v4(),
        type: type,
        x: 50,
        y: 50,
        width: type == ElementType.logo ? 60 : (type == ElementType.horizontalLine ? 200 : (_pageWidth - 64)),
        height: type == ElementType.logo ? 60 : (type == ElementType.horizontalLine ? 1 : null),
        content: type == ElementType.staticText ? 'Double click to edit' : '',
        properties: {
          'fontSize': 14.0,
          'bold': type == ElementType.schoolName || type == ElementType.paperTitle,
          'alignment': 'left',
          'color': 0xFF000000,
        },
      );
      _elements.add(newElement);
      _selectedElementId = newElement.id;
    });
  }

  void _updateElement(String id, {double? x, double? y, double? width, double? height, Map<String, dynamic>? props}) {
    setState(() {
      final index = _elements.indexWhere((e) => e.id == id);
      if (index != -1) {
        double newX = x ?? _elements[index].x;
        double newY = y ?? _elements[index].y;

        if (_snapSize > 0) {
          newX = (newX / _snapSize).round() * _snapSize;
          newY = (newY / _snapSize).round() * _snapSize;
        }

        _elements[index] = _elements[index].copyWith(
          x: newX,
          y: newY,
          width: width,
          height: height,
          properties: props != null ? {..._elements[index].properties, ...props} : null,
        );
      }
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && _selectedElementId != null) {
      if (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Page Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Page Border'),
                value: _template.hasBorder,
                onChanged: (val) {
                  setState(() => _template = _template.copyWith(hasBorder: val));
                  setModalState(() {});
                },
              ),
              ListTile(
                title: const Text('Paper Layout'),
                trailing: DropdownButton<PaperLayout>(
                  value: _template.paperLayout,
                  items: PaperLayout.values.map((l) => DropdownMenuItem(value: l, child: Text(l.name.toUpperCase()))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _template = _template.copyWith(paperLayout: val));
                      setModalState(() {});
                    }
                  },
                ),
              ),
              ListTile(
                title: const Text('Paper Size'),
                trailing: DropdownButton<PaperSize>(
                  value: _template.paperSize,
                  items: PaperSize.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name.toUpperCase()))).toList(),
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
              const Text('Colors', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildColorTile('Primary Color', _template.primaryColor, (color) {
                setState(() => _template = _template.copyWith(primaryColor: color));
                setModalState(() {});
              }),
              _buildColorTile('Secondary Color', _template.secondaryColor, (color) {
                setState(() => _template = _template.copyWith(secondaryColor: color));
                setModalState(() {});
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorTile(String title, PdfColor color, ValueChanged<PdfColor> onSelected) {
    final colors = [
      PdfColors.black, PdfColors.blue900, PdfColors.red900, 
      PdfColors.green900, PdfColors.purple900, PdfColors.pink900,
      PdfColors.blue100, PdfColors.grey300, PdfColors.yellow100
    ];

    return ListTile(
      title: Text(title),
      subtitle: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: colors.map((c) => GestureDetector(
            onTap: () => onSelected(c),
            child: Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8, top: 8),
              decoration: BoxDecoration(
                color: Color(c.toInt()),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                boxShadow: color == c ? [const BoxShadow(color: Colors.blue, blurRadius: 4)] : null,
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
        appBar: AppBar(
          elevation: 0,
          title: Text(_template.name, style: const TextStyle(fontSize: 14)),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.save_outlined, size: 20),
              label: const Text('Save'),
              onPressed: () async {
                final updatedTemplate = _template.copyWith(
                  customLayout: CustomLayout(elements: _elements, canvasHeight: _canvasHeight),
                );
                final navigator = Navigator.of(context);
                await ref.read(templateProvider.notifier).saveTemplate(updatedTemplate);
                if (mounted) navigator.pop();
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            _buildConsolidatedRibbon(),
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(50),
                      child: _buildCanvas(),
                    ),
                  ),
                  _buildCanvasControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsolidatedRibbon() {
    final el = _selectedElementId != null 
        ? _elements.firstWhere((e) => e.id == _selectedElementId) 
        : null;

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _RibbonGroup(
              label: 'INSERT',
              children: [
                _RibbonButton(icon: Icons.text_fields, label: 'School', onTap: () => _addElement(ElementType.schoolName)),
                _RibbonButton(icon: Icons.title, label: 'Title', onTap: () => _addElement(ElementType.paperTitle)),
                _RibbonButton(icon: Icons.image, label: 'Logo', onTap: () => _addElement(ElementType.logo)),
                _RibbonButton(icon: Icons.grid_view, label: 'Fields', onTap: () => _addElement(ElementType.headerFieldsBlock)),
                _RibbonButton(icon: Icons.horizontal_rule, label: 'Line', onTap: () => _addElement(ElementType.horizontalLine)),
              ],
            ),
            _VerticalDivider(),
            if (el != null) ...[
              _RibbonGroup(
                label: 'FORMATTING',
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          _buildMiniDropDown<double>(
                            value: el.properties['fontSize']?.toDouble() ?? 14.0,
                            items: [8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 28, 32],
                            onChanged: (v) => _updateElement(el.id, props: {'fontSize': v}),
                          ),
                          const SizedBox(width: 4),
                          _ToggleButton(
                            icon: Icons.format_bold,
                            isActive: el.properties['bold'] == true,
                            onTap: () => _updateElement(el.id, props: {'bold': !(el.properties['bold'] == true)}),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _AlignmentButton(icon: Icons.format_align_left, isActive: el.properties['alignment'] == 'left', onTap: () => _updateElement(el.id, props: {'alignment': 'left'})),
                          _AlignmentButton(icon: Icons.format_align_center, isActive: el.properties['alignment'] == 'center', onTap: () => _updateElement(el.id, props: {'alignment': 'center'})),
                          _AlignmentButton(icon: Icons.format_align_right, isActive: el.properties['alignment'] == 'right', onTap: () => _updateElement(el.id, props: {'alignment': 'right'})),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              _VerticalDivider(),
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
                          final idx = _elements.indexWhere((e) => e.id == el.id);
                          _elements[idx] = _elements[idx].copyWith(content: val);
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
                    width: 100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Width', style: TextStyle(fontSize: 9)),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: el.width ?? (_pageWidth - 64),
                            min: 10,
                            max: (_pageWidth - 64),
                            onChanged: (val) => _updateElement(el.id, width: val),
                          ),
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
            ] else 
              _RibbonGroup(
                label: 'SELECTION',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Select an element\nto format it',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
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

  Widget _buildMiniDropDown<T>({required T value, required List<T> items, required ValueChanged<T?> onChanged}) {
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
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i.toString()))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
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
          decoration: const InputDecoration(labelText: 'Height in points (e.g. 250)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() {
                _canvasHeight = double.tryParse(controller.text) ?? _canvasHeight;
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
        // Calculate auto-scale to fit screen width
        final double availableWidth = constraints.maxWidth - 40;
        final double autoScale = availableWidth / _pageWidth;
        final double finalScale = autoScale * _zoomScale;

        return InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 2.5,
          child: Center(
            child: Container(
              width: _pageWidth * finalScale,
              height: (_isFullPageView ? _pageHeight : _canvasHeight) * finalScale,
              margin: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, spreadRadius: 5),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Grid starting from margins
                  if (_showGrid)
                    Positioned(
                      left: 32 * finalScale,
                      top: 32 * finalScale,
                      right: 32 * finalScale,
                      bottom: 32 * finalScale,
                      child: CustomPaint(painter: GridPainter(scale: finalScale, step: _snapSize)),
                    ),
                  
                  // Margin indicators (Teacher friendly)
                  Positioned.fill(
                    child: Container(
                      margin: EdgeInsets.all(32 * finalScale),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.1), width: 0.5),
                      ),
                    ),
                  ),

                  if (_template.hasBorder)
                    Positioned.fill(
                      child: Container(
                        margin: EdgeInsets.all(10 * finalScale),
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(_template.primaryColor.toInt()), width: 1.5 * finalScale),
                        ),
                      ),
                    ),

                  Padding(
                    padding: EdgeInsets.all(32 * finalScale),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ..._elements.map((el) => _buildSmartElement(el, finalScale)),
                        if (!_isFullPageView)
                          Positioned(
                            bottom: -40 * finalScale,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                Container(
                                  height: 30 * finalScale,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.blue.withValues(alpha: 0.05), Colors.transparent],
                                    ),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.arrow_downward, size: 10 * finalScale, color: Colors.blue[300]),
                                        const SizedBox(width: 8),
                                        Text('QUESTION AREA STARTS HERE', 
                                          style: TextStyle(
                                            fontSize: 9 * finalScale, 
                                            color: Colors.blue[300], 
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          )),
                                        const SizedBox(width: 8),
                                        Icon(Icons.arrow_downward, size: 10 * finalScale, color: Colors.blue[300]),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_template.paperLayout == PaperLayout.twoColumn)
                                  Container(
                                    height: 150 * finalScale,
                                    width: 1,
                                    color: Colors.blue.withValues(alpha: 0.2),
                                    margin: EdgeInsets.only(top: 10 * finalScale),
                                  )
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

    return Positioned(
      left: el.x * scale,
      top: el.y * scale,
      child: GestureDetector(
        onTap: () => setState(() => _selectedElementId = el.id),
        onPanUpdate: (details) {
          _updateElement(el.id, x: el.x + details.delta.dx / scale, y: el.y + details.delta.dy / scale);
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
                  _buildHandle(0, 0),
                  _buildHandle(null, 0),
                  _buildHandle(0, null),
                  _buildHandle(null, null),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(double? left, double? top) {
    return Positioned(
      left: left == 0 ? -4 : null,
      right: left == null ? -4 : null,
      top: top == 0 ? -4 : null,
      bottom: top == null ? -4 : null,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.blue),
        ),
      ),
    );
  }

  Widget _buildElementPreview(TemplateElement el, double scale) {
    final color = el.properties['color'] != null 
        ? Color(el.properties['color']) 
        : (el.type == ElementType.schoolName && _template.type == TemplateType.coaching 
            ? Color(_template.primaryColor.toInt()) 
            : Colors.black);

    final fontSize = (el.properties['fontSize']?.toDouble() ?? 14.0) * scale;
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: el.properties['bold'] == true ? FontWeight.bold : FontWeight.normal,
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
          width: (el.width ?? 60) * scale,
          height: (el.height ?? 60) * scale,
          color: Colors.grey[300],
          child: const Icon(Icons.school, size: 30),
        );
      case ElementType.headerFieldsBlock:
        return Container(
          width: (el.width ?? 300) * scale,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subject: Mathematics', style: style.copyWith(fontSize: fontSize * 0.8)),
              Text('Date: __________', style: style.copyWith(fontSize: fontSize * 0.8)),
            ],
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
          child: Text(el.content.isEmpty ? 'Double click to edit' : el.content, style: style),
        );
      case ElementType.horizontalLine:
        return Container(
          width: (el.width ?? 200) * scale,
          height: 2,
          color: style.color,
        );
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
        ),
        child: const Text('120% | A4 Layout', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
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
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 0.5)),
      ],
    );
  }
}

class _RibbonButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  const _RibbonButton({required this.icon, required this.label, required this.onTap, this.iconColor});
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
  const _RibbonToggle({required this.icon, required this.label, required this.value, required this.onChanged});
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
            Text(label, style: TextStyle(fontSize: 10, color: value ? Colors.blue[800] : Colors.black)),
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
    return Container(width: 1, height: 60, color: Colors.grey.withValues(alpha: 0.15), margin: const EdgeInsets.symmetric(horizontal: 12));
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  const _ToggleButton({required this.icon, required this.isActive, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(color: isActive ? Colors.blue : Colors.grey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 18, color: isActive ? Colors.blue : Colors.grey[700]),
      ),
    );
  }
}

class _AlignmentButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  const _AlignmentButton({required this.icon, required this.isActive, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: isActive ? Colors.blue : Colors.grey[600], size: 18),
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
