import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/application/paper_document_marks.dart';
import 'package:edusheet/features/pdf/application/paper_header_layout_factory.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:flutter/material.dart';

/// Shared Flutter renderer for the canonical paper header geometry.
///
/// Preview and Word Mode both use this canvas. Word Mode only swaps the text
/// nodes for borderless inline editors, so the teacher edits the same x/y/width
/// geometry that Preview/PDF resolve from [PaperHeaderLayoutFactory].
class PaperHeaderLayoutCanvas extends StatelessWidget {
  final PaperTemplate template;
  final Paper? paper;
  final double? height;
  final bool editable;
  final ValueChanged<String>? onSchoolNameChanged;
  final ValueChanged<String>? onTitleChanged;
  final void Function(String fieldId, String value)? onHeaderFieldChanged;

  const PaperHeaderLayoutCanvas({
    super.key,
    required this.template,
    this.paper,
    this.height,
    this.editable = false,
    this.onSchoolNameChanged,
    this.onTitleChanged,
    this.onHeaderFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    final layout = paper == null
        ? PaperHeaderLayoutFactory.resolve(template)
        : PaperHeaderLayoutFactory.resolveForPaper(template, paper!);
    final design = SizedBox(
      width: CustomLayout.designWidth,
      height: layout.canvasHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final element in layout.elements)
            Positioned(
              left: element.x,
              top: element.y,
              child: PaperHeaderElementView(
                element: element,
                paper: paper,
                template: template,
                editable: editable,
                onSchoolNameChanged: onSchoolNameChanged,
                onTitleChanged: onTitleChanged,
                onHeaderFieldChanged: onHeaderFieldChanged,
              ),
            ),
        ],
      ),
    );

    if (height != null) {
      return SizedBox(
        height: height,
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
            child: design,
          ),
        ),
      );
    }

    // Width-driven mode is the WYSIWYG path used by Preview and Word Mode.
    // The aspect ratio guarantees that both surfaces scale the same geometry.
    return AspectRatio(
      aspectRatio: CustomLayout.designWidth / layout.canvasHeight,
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: design,
      ),
    );
  }
}

/// Public element renderer reused by the header arrangement surface.
class PaperHeaderElementView extends StatelessWidget {
  final TemplateElement element;
  final Paper? paper;
  final PaperTemplate template;
  final bool editable;
  final ValueChanged<String>? onSchoolNameChanged;
  final ValueChanged<String>? onTitleChanged;
  final void Function(String fieldId, String value)? onHeaderFieldChanged;

  const PaperHeaderElementView({
    super.key,
    required this.element,
    required this.paper,
    required this.template,
    this.editable = false,
    this.onSchoolNameChanged,
    this.onTitleChanged,
    this.onHeaderFieldChanged,
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
        final hasActualLogo =
            paper == null || paper!.logos.any((path) => path.trim().isNotEmpty);
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
          child: const Icon(
            Icons.school_outlined,
            size: 24,
            color: Colors.black45,
          ),
        );
      case ElementType.schoolName:
        return _box(
          width,
          height,
          alignment,
          editable && paper != null && onSchoolNameChanged != null
              ? _HeaderInlineField(
                  key: const Key('word-paper-school-name'),
                  initialValue: paper!.schoolName,
                  hintText: 'School / institution',
                  style: style,
                  textAlign: textAlign,
                  maxLines: 2,
                  onChanged: onSchoolNameChanged!,
                )
              : Text(
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
          editable && paper != null && onTitleChanged != null
              ? _HeaderInlineField(
                  key: const Key('word-paper-title'),
                  initialValue: paper!.title,
                  hintText: 'Examination title',
                  style: style,
                  textAlign: textAlign,
                  maxLines: 2,
                  onChanged: onTitleChanged!,
                )
              : Text(
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
            _maximumMarksLabel,
            maxLines: 1,
            textAlign: textAlign,
            style: style,
          ),
        );
      case ElementType.headerFieldsBlock:
        return _buildHeaderFields(element, style);
      case ElementType.staticText:
        final text =
            paper?.customHeaderValues[element.paperBindingKey] ??
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
            color: element.properties['fillColor'] is num
                ? Color((element.properties['fillColor'] as num).toInt())
                : null,
            border: Border.all(
              color: element.properties['borderColor'] is num
                  ? Color((element.properties['borderColor'] as num).toInt())
                  : Colors.black54,
              width: _number(element.properties['borderWidth'], 1),
            ),
            borderRadius: element.properties['borderRadius'] == null
                ? null
                : BorderRadius.circular(
                    _number(element.properties['borderRadius'], 0),
                  ),
          ),
          child: element.content.isEmpty
              ? null
              : Text(element.content, style: style, textAlign: textAlign),
        );
    }
  }

  Widget _buildHeaderFields(TemplateElement element, TextStyle style) {
    final fields = _resolvedHeaderFields(element);
    if (fields.isEmpty) {
      return SizedBox(width: element.width ?? 300, height: element.height);
    }
    final fieldStyle = style.copyWith(fontSize: (style.fontSize ?? 12) * 0.88);
    final rows = <Widget>[];
    for (var index = 0; index < fields.length; index += 2) {
      final rowFields = fields.sublist(
        index,
        (index + 2).clamp(0, fields.length).toInt(),
      );
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var cellIndex = 0; cellIndex < 2; cellIndex++) ...[
              if (cellIndex > 0) const SizedBox(width: 18),
              Expanded(
                child: cellIndex < rowFields.length
                    ? _HeaderFieldCell(
                        field: rowFields[cellIndex],
                        style: fieldStyle,
                        editable: editable && paper != null,
                        onChanged: onHeaderFieldChanged,
                      )
                    : const SizedBox(),
              ),
            ],
          ],
        ),
      );
      if (index + 2 < fields.length) {
        rows.add(const SizedBox(height: 5));
      }
    }
    return SizedBox(
      width: element.width ?? 300,
      height: element.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }

  List<PaperHeaderField> _resolvedHeaderFields(TemplateElement element) {
    if (paper == null) {
      final requestedLabels =
          (element.properties['fieldLabels'] as List?)
              ?.map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false) ??
          const <String>[];
      final labels = requestedLabels.isEmpty
          ? const ['Subject', 'Class', 'Time', 'Date']
          : requestedLabels;
      return [
        for (var i = 0; i < labels.length; i++)
          PaperHeaderField(
            id: 'preview-$i',
            label: labels[i],
            isPlaceholder: true,
          ),
      ];
    }
    return PaperHeaderLayoutFactory.resolveHeaderFields(element, paper!);
  }

  String get _schoolName {
    if (paper == null) {
      return 'SCHOOL / INSTITUTION';
    }
    return paper!.schoolName.trim();
  }

  String get _paperTitle {
    if (paper == null) {
      return 'EXAMINATION';
    }
    return paper!.title.trim();
  }

  String get _maximumMarksLabel => paper == null
      ? 'Maximum Marks: 80'
      : PaperDocumentMarks.maximumMarksLabel(paper!);

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
      padding: border
          ? const EdgeInsets.symmetric(horizontal: 3, vertical: 2)
          : null,
      alignment: alignment,
      decoration: border
          ? BoxDecoration(border: Border.all(color: Colors.black54))
          : null,
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

class _HeaderFieldCell extends StatelessWidget {
  final PaperHeaderField field;
  final TextStyle style;
  final bool editable;
  final void Function(String fieldId, String value)? onChanged;

  const _HeaderFieldCell({
    required this.field,
    required this.style,
    required this.editable,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final value = field.value.trim();
    final content = field.isPlaceholder || value.isEmpty
        ? '________________'
        : value;
    if (!editable || field.id.isEmpty || onChanged == null) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${field.label}: ',
              style: style.copyWith(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: content, style: style),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '${field.label}: ',
          style: style.copyWith(fontWeight: FontWeight.w700),
        ),
        Expanded(
          child: _HeaderInlineField(
            key: ValueKey('wysiwyg-header-field-${field.id}'),
            initialValue: field.isPlaceholder ? '' : field.value,
            hintText: '________',
            style: style,
            textAlign: TextAlign.left,
            maxLines: 1,
            onChanged: (value) => onChanged!(field.id, value),
          ),
        ),
      ],
    );
  }
}

class _HeaderInlineField extends StatefulWidget {
  final String initialValue;
  final String hintText;
  final TextStyle style;
  final TextAlign textAlign;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _HeaderInlineField({
    super.key,
    required this.initialValue,
    required this.hintText,
    required this.style,
    required this.textAlign,
    required this.maxLines,
    required this.onChanged,
  });

  @override
  State<_HeaderInlineField> createState() => _HeaderInlineFieldState();
}

class _HeaderInlineFieldState extends State<_HeaderInlineField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _HeaderInlineField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && widget.initialValue != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.initialValue,
        selection: TextSelection.collapsed(offset: widget.initialValue.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: widget.maxLines,
      minLines: 1,
      textAlign: widget.textAlign,
      style: widget.style,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
        hintText: widget.hintText,
        hintStyle: widget.style.copyWith(color: Colors.black38),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
