import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/application/paper_header_layout_factory.dart';
import 'package:edusheet/features/pdf/application/paper_marks_resolver.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:flutter/material.dart';

/// Flutter preview of the same resolved header layout used by PDF and Word.
class PaperHeaderLayoutPreview extends StatelessWidget {
  final PaperTemplate template;
  final Paper? paper;
  final double height;

  const PaperHeaderLayoutPreview({
    super.key,
    required this.template,
    this.paper,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    final layout = paper == null
        ? PaperHeaderLayoutFactory.resolve(template)
        : PaperHeaderLayoutFactory.resolveForPaper(template, paper!);
    return SizedBox(
      height: height,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: CustomLayout.designWidth,
            height: layout.canvasHeight,
            child: Stack(
              children: [
                for (final element in layout.elements)
                  Positioned(
                    left: element.x,
                    top: element.y,
                    child: _PreviewElement(
                      element: element,
                      paper: paper,
                      template: template,
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

class PaperStylePreview extends StatelessWidget {
  final PaperTemplate template;
  final Paper? paper;
  final double height;
  final bool showQuestionSkeleton;

  const PaperStylePreview({
    super.key,
    required this.template,
    this.paper,
    this.height = 170,
    this.showQuestionSkeleton = true,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = Color(template.primaryColor.toInt());
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: template.hasBorder ? borderColor : Colors.black12,
          width: template.hasBorder ? 1.4 : 1,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: PaperHeaderLayoutPreview(
              template: template,
              paper: paper,
              height: height * 0.62,
            ),
          ),
          if (showQuestionSkeleton) ...[
            const SizedBox(height: 5),
            _QuestionSkeleton(
              twoColumn: template.paperLayout == PaperLayout.twoColumn,
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewElement extends StatelessWidget {
  final TemplateElement element;
  final Paper? paper;
  final PaperTemplate template;

  const _PreviewElement({
    required this.element,
    required this.paper,
    required this.template,
  });

  @override
  Widget build(BuildContext context) {
    final width = element.width;
    final height = element.height;
    final fontSize = _number(element.properties['fontSize'], 12);
    final color = element.properties['color'] is num
        ? Color((element.properties['color'] as num).toInt())
        : Colors.black;
    final style = TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: element.properties['bold'] == true
          ? FontWeight.w700
          : FontWeight.w400,
      fontStyle: element.properties['italic'] == true
          ? FontStyle.italic
          : FontStyle.normal,
      decoration: element.properties['decoration'] == 'underline'
          ? TextDecoration.underline
          : TextDecoration.none,
      height: 1.05,
    );
    final alignment = _alignment(element.properties['alignment']?.toString());
    final textAlign = _textAlign(element.properties['alignment']?.toString());

    switch (element.type) {
      case ElementType.logo:
        final hasActualLogo = paper == null ||
            paper!.logos.any((path) => path.trim().isNotEmpty);
        if (!hasActualLogo) {
          return SizedBox(width: width ?? 48, height: height ?? 48);
        }
        return Container(
          width: width ?? 48,
          height: height ?? 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black26),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.school_outlined, size: 24, color: Colors.black45),
        );
      case ElementType.schoolName:
        return _box(
          width,
          height,
          alignment,
          Text(
            _schoolName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: style,
          ),
        );
      case ElementType.paperTitle:
        return _box(
          width,
          height,
          alignment,
          Text(
            _paperTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: style,
          ),
        );
      case ElementType.maxMarks:
        return _box(
          width,
          height,
          alignment,
          Text(
            'Maximum Marks: $_marks',
            maxLines: 1,
            textAlign: textAlign,
            style: style,
          ),
        );
      case ElementType.headerFieldsBlock:
        final fields = _headerFields(element);
        return _box(
          width,
          height,
          alignment,
          Text(
            fields,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: style,
          ),
        );
      case ElementType.staticText:
        final text = paper?.customHeaderValues[element.paperBindingKey] ??
            element.content;
        return _box(
          width,
          height,
          alignment,
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: style,
          ),
          border: element.properties['border'] == true,
        );
      case ElementType.horizontalLine:
        return Container(
          width: width ?? 100,
          height: _number(element.properties['thickness'], 1),
          color: color == Colors.black
              ? Color(template.primaryColor.toInt())
              : color,
        );
      case ElementType.rectangular:
        return Container(
          width: width,
          height: height,
          alignment: alignment,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black54),
          ),
          child: element.content.isEmpty
              ? null
              : Text(element.content, style: style, textAlign: textAlign),
        );
    }
  }

  String get _schoolName {
    if (paper == null) return 'SCHOOL / INSTITUTION';
    return paper!.schoolName.trim();
  }

  String get _paperTitle {
    if (paper == null) return 'EXAMINATION';
    return paper!.title.trim();
  }

  String get _marks {
    final value = paper == null
        ? 80.0
        : PaperMarksResolver.effectiveMaximumMarks(paper!);
    return PaperMarksResolver.format(value);
  }

  String _headerFields(TemplateElement element) {
    if (paper == null || paper!.headerFields.isEmpty) {
      return 'Subject: __________   Class: ______   Time: ______';
    }
    final requested = (element.properties['fieldLabels'] as List?)
            ?.map((value) => value.toString().trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toSet() ??
        const <String>{};
    final fields = requested.isEmpty
        ? paper!.headerFields
        : paper!.headerFields
            .where((field) => requested.contains(field.label.toLowerCase()))
            .toList(growable: false);
    return fields.take(6).map((field) {
      final value = field.value.trim();
      return '${field.label}: ${field.isPlaceholder || value.isEmpty ? '________' : value}';
    }).join('   ');
  }

  static Widget _box(
    double? width,
    double? height,
    Alignment alignment,
    Widget child, {
    bool border = false,
  }) {
    return Container(
      width: width,
      height: height,
      padding: border ? const EdgeInsets.symmetric(horizontal: 3, vertical: 2) : null,
      alignment: alignment,
      decoration: border ? BoxDecoration(border: Border.all(color: Colors.black54)) : null,
      child: child,
    );
  }

  static double _number(Object? value, double fallback) =>
      value is num ? value.toDouble() : fallback;

  static Alignment _alignment(String? value) {
    switch (value) {
      case 'center':
        return Alignment.center;
      case 'right':
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }

  static TextAlign _textAlign(String? value) {
    switch (value) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }
}

class _QuestionSkeleton extends StatelessWidget {
  final bool twoColumn;

  const _QuestionSkeleton({required this.twoColumn});

  @override
  Widget build(BuildContext context) {
    if (!twoColumn) {
      return Expanded(child: _column());
    }
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _column()),
          const SizedBox(width: 8),
          Expanded(child: _column()),
        ],
      ),
    );
  }

  Widget _column() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(0.92),
        const SizedBox(height: 5),
        _line(0.74),
        const SizedBox(height: 8),
        _line(0.88),
        const SizedBox(height: 5),
        _line(0.66),
      ],
    );
  }

  Widget _line(double fraction) {
    return FractionallySizedBox(
      widthFactor: fraction,
      child: Container(height: 3, color: Colors.black12),
    );
  }
}
