import 'dart:io';
import 'package:flutter/material.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';

class TemplateHeaderPreview extends StatelessWidget {
  final Paper paper;
  final PaperTemplate template;

  const TemplateHeaderPreview({
    super.key,
    required this.paper,
    required this.template,
  });

  @override
  Widget build(BuildContext context) {
    final layout = template.effectiveLayout;

    const double contentWidth = CustomLayout.designWidth;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double scale = constraints.maxWidth / contentWidth;

        int logoIdx = 0;
        final elements = layout.elements.map((el) {
          Widget? child;
          if (el.type == ElementType.logo) {
            final currentIdx = logoIdx++;
            final String? logoPath = paper.logos.length > currentIdx
                ? paper.logos[currentIdx]
                : null;
            child = _buildElement(el, paper, logoPath, template, scale);
          } else {
            child = _buildElement(el, paper, null, template, scale);
          }

          return Positioned(
            left: el.x * scale,
            top: el.y * scale,
            child: SizedBox(
              width: (el.width ?? contentWidth) * scale,
              height: el.height != null ? el.height! * scale : null,
              child: child,
            ),
          );
        }).toList();

        return Container(
          height: layout.canvasHeight * scale,
          width: constraints.maxWidth,
          decoration: const BoxDecoration(color: Colors.white),
          clipBehavior: Clip.hardEdge,
          child: Stack(children: elements),
        );
      },
    );
  }

  Widget _buildElement(
    TemplateElement el,
    Paper paper,
    String? logoPath,
    PaperTemplate template,
    double scale,
  ) {
    final style = TextStyle(
      fontSize: (el.properties['fontSize']?.toDouble() ?? 12) * scale,
      fontWeight: el.properties['bold'] == true
          ? FontWeight.bold
          : FontWeight.normal,
      color: el.properties['color'] != null
          ? Color(el.properties['color'])
          : Colors.black,
    );

    final alignment = _getAlignment(el.properties['alignment']);

    switch (el.type) {
      case ElementType.schoolName:
        return Container(
          alignment: alignment,
          child: Text(
            paper.schoolName,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      case ElementType.paperTitle:
        return Container(
          alignment: alignment,
          child: Text(
            paper.title,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      case ElementType.logo:
        Widget? logoWidget;
        if (logoPath != null && logoPath.isNotEmpty) {
          logoWidget = Image.file(File(logoPath), fit: BoxFit.contain);
        } else if (el.content.isNotEmpty) {
          logoWidget = Image.file(File(el.content), fit: BoxFit.contain);
        }

        return Container(
          alignment: alignment,
          child:
              logoWidget ??
              Container(
                color: Colors.grey.withAlpha(50),
                child: Center(
                  child: Icon(
                    Icons.image,
                    size: 20 * scale,
                    color: Colors.grey,
                  ),
                ),
              ),
        );
      case ElementType.maxMarks:
        return Container(
          alignment: alignment,
          child: Text(
            'Max Marks: ${paper.totalMarks.toStringAsFixed(0)}',
            style: style,
          ),
        );
      case ElementType.headerFieldsBlock:
        final List<dynamic> labels =
            el.properties['fieldLabels'] ?? ['Subject', 'Date'];
        return Wrap(
          spacing: 16 * scale,
          runSpacing: 4 * scale,
          alignment: _getWrapAlignment(el.properties['alignment']),
          children: labels.map((l) {
            final field = paper.headerFields.firstWhere(
              (f) => f.label.toLowerCase() == l.toString().toLowerCase(),
              orElse: () => PaperHeaderField(
                id: '',
                label: l.toString(),
                isPlaceholder: true,
              ),
            );
            final content = field.isPlaceholder
                ? '________________'
                : field.value;
            return RichText(
              text: TextSpan(
                style: style.copyWith(
                  fontSize: style.fontSize! * 0.85,
                  color: Colors.black,
                ),
                children: [
                  TextSpan(
                    text: '${field.label}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: content),
                ],
              ),
            );
          }).toList(),
        );
      case ElementType.staticText:
        final content =
            paper.customHeaderValues[el.paperBindingKey] ?? el.content;
        return Container(
          alignment: alignment,
          child: Text(
            content,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      case ElementType.horizontalLine:
        return Center(
          child: Container(
            width: (el.width ?? 100) * scale,
            height: 1 * scale,
            color: style.color,
          ),
        );
      case ElementType.rectangular:
        return Container(
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
    }
  }

  Alignment _getAlignment(String? align) {
    switch (align) {
      case 'center':
        return Alignment.center;
      case 'right':
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }

  WrapAlignment _getWrapAlignment(String? align) {
    switch (align) {
      case 'center':
        return WrapAlignment.center;
      case 'right':
        return WrapAlignment.end;
      default:
        return WrapAlignment.start;
    }
  }
}
