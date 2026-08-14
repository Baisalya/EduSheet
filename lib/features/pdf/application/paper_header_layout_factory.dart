import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';

/// Resolves a persisted [PaperTemplate] into the header geometry consumed by
/// PDF, Word and Flutter preview renderers.
///
/// This is intentionally separate from [PaperTemplate]: the domain model is
/// persisted data, while this factory is presentation policy.
class PaperHeaderLayoutFactory {
  const PaperHeaderLayoutFactory._();

  static CustomLayout resolve(PaperTemplate template) {
    if (template.headerLayout == HeaderLayout.custom &&
        template.customLayout != null) {
      return template.customLayout!;
    }

    return switch (template.headerLayout) {
      HeaderLayout.centered => _centered(template),
      HeaderLayout.logoLeft => _logoSide(template, logoLeft: true),
      HeaderLayout.logoRight => _logoSide(template, logoLeft: false),
      HeaderLayout.modernCoaching => _modern(template),
      HeaderLayout.minimal => _minimal(template),
      HeaderLayout.academic => _academic(template),
      // These enum values are retained for persisted compatibility. Their old
      // branded layouts are deliberately replaced by neutral professional
      // structures.
      HeaderLayout.ssvm => _structuredFormal(template),
      HeaderLayout.dps => _boardClassic(template),
      HeaderLayout.custom => _centered(template),
    };
  }

  /// Adapts the resolved layout to real paper metadata without changing the
  /// persisted template. Built-in headers reserve two two-column metadata rows;
  /// extra teacher fields expand the header and move following elements down.
  static CustomLayout resolveForPaper(PaperTemplate template, Paper paper) {
    final base = resolve(template);
    if (template.headerLayout == HeaderLayout.custom) return base;

    TemplateElement? fieldsBlock;
    for (final element in base.elements) {
      if (element.type == ElementType.headerFieldsBlock) {
        fieldsBlock = element;
        break;
      }
    }
    if (fieldsBlock == null) return base;
    final block = fieldsBlock;

    final requestedLabels = (block.properties['fieldLabels'] as List?)
            ?.where((value) => value.toString().trim().isNotEmpty)
            .length ??
        0;
    final fieldCount = requestedLabels > 0
        ? requestedLabels
        : paper.headerFields.length;
    final rows = (fieldCount / 2).ceil();
    final extraRows = rows > 2 ? rows - 2 : 0;
    if (extraRows == 0) return base;

    final extraHeight = extraRows * 18.0;
    final threshold = block.y + 20;
    final elements = base.elements.map((element) {
      if (element.id == block.id) {
        return element.copyWith(
          height: (element.height ?? 30) + extraHeight,
        );
      }
      if (element.y > threshold) {
        return element.copyWith(y: element.y + extraHeight);
      }
      return element;
    }).toList(growable: false);
    return CustomLayout(
      elements: elements,
      canvasHeight: base.canvasHeight + extraHeight,
    );
  }

  static const double _w = CustomLayout.designWidth;

  static CustomLayout _centered(PaperTemplate template) {
    final headingAlignment = template.centeredHeader ? 'center' : 'left';
    return CustomLayout(
      canvasHeight: 122,
      elements: [
        _el(
          'school',
          ElementType.schoolName,
          0,
          0,
          width: _w,
          properties: _text(16, bold: true, alignment: headingAlignment),
        ),
        _el(
          'title',
          ElementType.paperTitle,
          0,
          25,
          width: _w,
          properties: _text(
            template.headerFontSize,
            bold: true,
            alignment: headingAlignment,
          ),
        ),
        _el(
          'fields',
          ElementType.headerFieldsBlock,
          0,
          57,
          width: _w,
          properties: _text(10.5, alignment: 'center'),
        ),
        _el(
          'marks',
          ElementType.maxMarks,
          0,
          91,
          width: _w,
          properties: _text(10.5, bold: true, alignment: 'right'),
        ),
        _line('divider', 116, template),
      ],
    );
  }

  static CustomLayout _logoSide(
    PaperTemplate template, {
    required bool logoLeft,
  }) {
    final logoX = logoLeft ? 0.0 : _w - 52;
    final textX = logoLeft ? 68.0 : 0.0;
    final textWidth = _w - 68;
    final alignment = logoLeft ? 'left' : 'right';
    return CustomLayout(
      canvasHeight: 142,
      elements: [
        _el('logo', ElementType.logo, logoX, 5, width: 52, height: 52),
        _el(
          'school',
          ElementType.schoolName,
          textX,
          7,
          width: textWidth,
          properties: _text(16, bold: true, alignment: alignment),
        ),
        _el(
          'title',
          ElementType.paperTitle,
          textX,
          32,
          width: textWidth,
          properties: _text(
            template.headerFontSize,
            bold: true,
            alignment: alignment,
          ),
        ),
        _el(
          'fields',
          ElementType.headerFieldsBlock,
          0,
          78,
          width: _w,
          properties: _text(10.5),
        ),
        _el(
          'marks',
          ElementType.maxMarks,
          0,
          111,
          width: _w,
          properties: _text(10.5, bold: true, alignment: 'right'),
        ),
        _line('divider', 136, template),
      ],
    );
  }

  static CustomLayout _modern(PaperTemplate template) {
    return CustomLayout(
      canvasHeight: 132,
      elements: [
        _el('logo', ElementType.logo, 0, 4, width: 48, height: 48),
        _el(
          'school',
          ElementType.schoolName,
          64,
          5,
          width: _w - 64,
          properties: _text(
            17,
            bold: true,
            color: template.primaryColor.toInt(),
          ),
        ),
        _el(
          'title',
          ElementType.paperTitle,
          64,
          31,
          width: _w - 64,
          properties: _text(template.headerFontSize, bold: true),
        ),
        _line('accent', 65, template, thickness: 2),
        _el(
          'fields',
          ElementType.headerFieldsBlock,
          0,
          79,
          width: _w,
          properties: _text(10.5),
        ),
        _el(
          'marks',
          ElementType.maxMarks,
          0,
          107,
          width: _w,
          properties: _text(10.5, bold: true, alignment: 'right'),
        ),
      ],
    );
  }

  static CustomLayout _minimal(PaperTemplate template) {
    return CustomLayout(
      canvasHeight: 108,
      elements: [
        _el(
          'school',
          ElementType.schoolName,
          0,
          0,
          width: _w * 0.68,
          properties: _text(9.5, bold: true),
        ),
        _el(
          'marks',
          ElementType.maxMarks,
          _w * 0.68,
          0,
          width: _w * 0.32,
          properties: _text(9.5, bold: true, alignment: 'right'),
        ),
        _el(
          'title',
          ElementType.paperTitle,
          0,
          24,
          width: _w,
          properties: _text(template.headerFontSize, bold: true),
        ),
        _el(
          'fields',
          ElementType.headerFieldsBlock,
          0,
          58,
          width: _w,
          properties: _text(10),
        ),
        _line('divider', 101, template, thickness: 0.7),
      ],
    );
  }

  static CustomLayout _academic(PaperTemplate template) {
    return CustomLayout(
      canvasHeight: 166,
      elements: [
        _el('logo', ElementType.logo, 0, 3, width: 48, height: 48),
        _el(
          'school',
          ElementType.schoolName,
          62,
          5,
          width: _w - 62,
          properties: _text(16.5, bold: true),
        ),
        _el(
          'title',
          ElementType.paperTitle,
          62,
          31,
          width: _w - 62,
          properties: _text(template.headerFontSize, bold: true),
        ),
        _line('dividerTop', 67, template),
        _el(
          'fields',
          ElementType.headerFieldsBlock,
          0,
          82,
          width: _w,
          properties: _text(10.5),
        ),
        _el(
          'marks',
          ElementType.maxMarks,
          0,
          132,
          width: _w,
          properties: _text(10.5, bold: true, alignment: 'right'),
        ),
        _line('dividerBottom', 159, template),
      ],
    );
  }

  static CustomLayout _structuredFormal(PaperTemplate template) {
    final headingAlignment = template.centeredHeader ? 'center' : 'left';
    return CustomLayout(
      canvasHeight: 168,
      elements: [
        _el(
          'school',
          ElementType.schoolName,
          12,
          6,
          width: _w - 24,
          properties: _text(17, bold: true, alignment: headingAlignment),
        ),
        _el(
          'title',
          ElementType.paperTitle,
          12,
          34,
          width: _w - 24,
          properties: _text(
            template.headerFontSize,
            bold: true,
            alignment: headingAlignment,
          ),
        ),
        _line('dividerTop', 70, template),
        _el(
          'fields',
          ElementType.headerFieldsBlock,
          12,
          84,
          width: _w - 24,
          properties: _text(10.5),
        ),
        _el(
          'marks',
          ElementType.maxMarks,
          12,
          132,
          width: _w - 24,
          properties: _text(10.5, bold: true, alignment: 'right'),
        ),
        _line('dividerBottom', 161, template),
      ],
    );
  }

  static CustomLayout _boardClassic(PaperTemplate template) {
    final headingAlignment = template.centeredHeader ? 'center' : 'left';
    return CustomLayout(
      canvasHeight: 195,
      elements: [
        _el(
          'school',
          ElementType.schoolName,
          0,
          3,
          width: _w,
          properties: _text(15.5, bold: true, alignment: headingAlignment),
        ),
        _el(
          'title',
          ElementType.paperTitle,
          0,
          31,
          width: _w,
          properties: _text(
            template.headerFontSize,
            bold: true,
            alignment: headingAlignment,
          ),
        ),
        _line('dividerTop', 65, template, thickness: 1.2),
        _el(
          'fields',
          ElementType.headerFieldsBlock,
          8,
          80,
          width: _w - 16,
          properties: _text(10.5),
        ),
        _el(
          'marks',
          ElementType.maxMarks,
          8,
          150,
          width: _w - 16,
          properties: _text(10.5, bold: true, alignment: 'right'),
        ),
        _line('dividerBottom', 188, template, thickness: 1.2),
      ],
    );
  }

  static TemplateElement _line(
    String id,
    double y,
    PaperTemplate template, {
    double thickness = 1,
  }) {
    return _el(
      id,
      ElementType.horizontalLine,
      0,
      y,
      width: _w,
      properties: {
        'color': template.primaryColor.toInt(),
        'thickness': thickness,
      },
    );
  }

  static Map<String, dynamic> _text(
    double size, {
    bool bold = false,
    String alignment = 'left',
    int? color,
  }) {
    return {
      'fontSize': size,
      'bold': bold,
      'alignment': alignment,
      'color': ?color,
    };
  }

  static TemplateElement _el(
    String id,
    ElementType type,
    double x,
    double y, {
    double? width,
    double? height,
    String content = '',
    Map<String, dynamic> properties = const {},
  }) {
    return TemplateElement(
      id: 'resolved-$id',
      type: type,
      x: x,
      y: y,
      width: width,
      height: height,
      content: content,
      properties: properties,
    );
  }
}
