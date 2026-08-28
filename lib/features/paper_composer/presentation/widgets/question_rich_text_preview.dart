import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_embed_builder.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_expression_embed_builder.dart';
import 'package:edusheet/features/paper_composer/application/question_rich_text_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class QuestionRichTextPreview extends StatefulWidget {
  final Question question;
  final double maxHeight;

  const QuestionRichTextPreview({
    super.key,
    required this.question,
    this.maxHeight = 160,
  });

  @override
  State<QuestionRichTextPreview> createState() =>
      _QuestionRichTextPreviewState();
}

class _QuestionRichTextPreviewState extends State<QuestionRichTextPreview> {
  static const _codec = QuestionRichTextCodec();
  late QuillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _buildController(widget.question);
  }

  @override
  void didUpdateWidget(covariant QuestionRichTextPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.text == widget.question.text) return;
    final previous = _controller;
    _controller = _buildController(widget.question);
    previous.dispose();
  }

  QuillController _buildController(Question question) {
    return QuillController(
      document: _codec.decodeQuestion(question),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: IgnorePointer(
        child: QuillEditor.basic(
          controller: _controller,
          config: QuillEditorConfig(
            padding: EdgeInsets.zero,
            embedBuilders: [
              GeometryEmbedBuilder(),
              const MathExpressionEmbedBuilder(),
            ],
          ),
        ),
      ),
    );
  }
}
