import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_header_layout_canvas.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:flutter/material.dart';

/// Read-only wrapper retained for style chooser and existing call sites.
///
/// Phase 3 moves the actual header rendering into [PaperHeaderLayoutCanvas] so
/// the chooser, paper preview and Word Mode cannot drift into separate layouts.
class PaperHeaderLayoutPreview extends StatelessWidget {
  final PaperTemplate template;
  final Paper? paper;
  final double? height;
  final bool fitToWidth;

  const PaperHeaderLayoutPreview({
    super.key,
    required this.template,
    this.paper,
    this.height = 120,
    this.fitToWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return PaperHeaderLayoutCanvas(
      template: template,
      paper: paper,
      height: fitToWidth ? null : height,
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
