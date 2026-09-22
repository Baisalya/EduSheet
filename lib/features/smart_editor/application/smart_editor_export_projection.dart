import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/geometry_builder/application/geometry_embed_layout.dart';
import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_interop_embed_builders.dart';

sealed class SmartEditorExportBlock {
  const SmartEditorExportBlock();
}

class SmartEditorExportParagraph extends SmartEditorExportBlock {
  const SmartEditorExportParagraph({
    required this.inlines,
    required this.attributes,
  });

  final List<SmartEditorExportInline> inlines;
  final Map<String, dynamic> attributes;

  bool get isEmpty => inlines.every((inline) => inline.plainText.isEmpty);
}

class SmartEditorExportGeometry extends SmartEditorExportBlock {
  const SmartEditorExportGeometry(this.layout);
  final GeometryEmbedLayout layout;
}

class SmartEditorExportImage extends SmartEditorExportBlock {
  const SmartEditorExportImage(this.payload);
  final SmartEditorInteropImagePayload payload;
}

class SmartEditorExportTable extends SmartEditorExportBlock {
  const SmartEditorExportTable(this.payload);
  final SmartEditorInteropTablePayload payload;
}

class SmartEditorExportBreak extends SmartEditorExportBlock {
  const SmartEditorExportBreak(this.type);
  final String type;
}

sealed class SmartEditorExportInline {
  const SmartEditorExportInline();
  String get plainText;
}

class SmartEditorExportText extends SmartEditorExportInline {
  const SmartEditorExportText(this.text, this.attributes);
  final String text;
  final Map<String, dynamic> attributes;

  @override
  String get plainText => text;
}

class SmartEditorExportMath extends SmartEditorExportInline {
  const SmartEditorExportMath(this.expression);
  final MathExpression expression;

  @override
  String get plainText => expression.plainText.trim().isEmpty
      ? expression.latex
      : expression.plainText;
}

class SmartEditorExportProjection {
  const SmartEditorExportProjection({required this.blocks});
  final List<SmartEditorExportBlock> blocks;

  factory SmartEditorExportProjection.fromDocument(SmartDocument document) {
    final blocks = <SmartEditorExportBlock>[];
    var inlines = <SmartEditorExportInline>[];

    void flushParagraph([Map<String, dynamic> attributes = const {}]) {
      blocks.add(
        SmartEditorExportParagraph(
          inlines: List<SmartEditorExportInline>.unmodifiable(inlines),
          attributes: Map<String, dynamic>.unmodifiable(attributes),
        ),
      );
      inlines = <SmartEditorExportInline>[];
    }

    for (final raw in document.deltaJson) {
      if (raw is! Map) continue;
      final op = Map<String, dynamic>.from(raw);
      final insert = op['insert'];
      final attributes = _attributes(op['attributes']);

      if (insert is String) {
        var start = 0;
        for (var index = 0; index < insert.length; index++) {
          if (insert.codeUnitAt(index) != 10) continue;
          final chunk = insert.substring(start, index);
          if (chunk.isNotEmpty) {
            inlines.add(SmartEditorExportText(chunk, _inlineAttributes(attributes)));
          }
          flushParagraph(_blockAttributes(attributes));
          start = index + 1;
        }
        if (start < insert.length) {
          final chunk = insert.substring(start);
          if (chunk.isNotEmpty) {
            inlines.add(SmartEditorExportText(chunk, _inlineAttributes(attributes)));
          }
        }
        continue;
      }

      final embed = _embedMap(insert);
      if (embed == null) continue;

      if (embed.containsKey(MathExpression.quillEmbedKey)) {
        final expression = MathExpression.tryFromQuillEmbedData(
          embed[MathExpression.quillEmbedKey],
        );
        if (expression == null) continue;
        if (expression.display == MathExpressionDisplay.block) {
          if (inlines.isNotEmpty) flushParagraph();
          blocks.add(
            SmartEditorExportParagraph(
              inlines: <SmartEditorExportInline>[SmartEditorExportMath(expression)],
              attributes: const <String, dynamic>{'align': 'center'},
            ),
          );
        } else {
          inlines.add(SmartEditorExportMath(expression));
        }
        continue;
      }

      if (embed.containsKey('geometry')) {
        if (inlines.isNotEmpty) flushParagraph();
        blocks.add(
          SmartEditorExportGeometry(
            GeometryEmbedLayout.fromData(embed['geometry']),
          ),
        );
        continue;
      }

      if (embed.containsKey('smartBreak')) {
        if (inlines.isNotEmpty) flushParagraph();
        blocks.add(SmartEditorExportBreak(embed['smartBreak']?.toString() ?? 'page'));
        continue;
      }

      if (embed.containsKey(SmartEditorInteropImageEmbedBuilder.keyName)) {
        if (inlines.isNotEmpty) flushParagraph();
        blocks.add(
          SmartEditorExportImage(
            SmartEditorInteropImagePayload.fromData(
              embed[SmartEditorInteropImageEmbedBuilder.keyName],
            ),
          ),
        );
        continue;
      }

      if (embed.containsKey(SmartEditorInteropTableEmbedBuilder.keyName)) {
        if (inlines.isNotEmpty) flushParagraph();
        blocks.add(
          SmartEditorExportTable(
            SmartEditorInteropTablePayload.fromData(
              embed[SmartEditorInteropTableEmbedBuilder.keyName],
            ),
          ),
        );
      }
    }

    if (inlines.isNotEmpty) flushParagraph();
    if (blocks.isEmpty) {
      blocks.add(
        const SmartEditorExportParagraph(
          inlines: <SmartEditorExportInline>[],
          attributes: <String, dynamic>{},
        ),
      );
    }
    return SmartEditorExportProjection(blocks: List.unmodifiable(blocks));
  }
}

Map<String, dynamic>? _embedMap(Object? value) {
  if (value is! Map) return null;
  final map = Map<String, dynamic>.from(value);

  // flutter_quill serializes CustomBlockEmbed values under a `custom`
  // envelope (for example: {custom: {smartBreak: page}}). Imported/native
  // Smart Editor payloads may already be in the direct shape. Normalize both
  // forms here so DOCX/PDF export never silently drops custom objects.
  final custom = map['custom'];
  if (custom is Map) {
    return Map<String, dynamic>.from(custom);
  }
  if (custom is String) {
    try {
      final decoded = jsonDecode(custom);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      // Not every third-party custom embed is JSON. Leave unknown custom
      // values untouched so export can ignore them without crashing.
    }
  }
  return map;
}

Map<String, dynamic> _attributes(Object? value) {
  if (value is! Map) return const <String, dynamic>{};
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic> _inlineAttributes(Map<String, dynamic> attributes) {
  if (attributes.isEmpty) return const <String, dynamic>{};
  const blockKeys = <String>{
    'align',
    'direction',
    'header',
    'indent',
    'list',
    'blockquote',
    'code-block',
    'line-height',
  };
  return <String, dynamic>{
    for (final entry in attributes.entries)
      if (!blockKeys.contains(entry.key)) entry.key: entry.value,
  };
}

Map<String, dynamic> _blockAttributes(Map<String, dynamic> attributes) {
  if (attributes.isEmpty) return const <String, dynamic>{};
  const blockKeys = <String>{
    'align',
    'direction',
    'header',
    'indent',
    'list',
    'blockquote',
    'code-block',
    'line-height',
  };
  return <String, dynamic>{
    for (final entry in attributes.entries)
      if (blockKeys.contains(entry.key)) entry.key: entry.value,
  };
}
