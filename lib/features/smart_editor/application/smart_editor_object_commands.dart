import 'dart:math' as math;

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/geometry_builder/application/geometry_embed_layout.dart';
import 'package:edusheet/features/geometry_builder/models/geometry_diagram.dart';
import 'package:edusheet/features/geometry_builder/services/geometry_diagram_registry.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_expression_embed_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Canonical Smart Editor commands for first-class academic objects.
///
/// Math and geometry are stored directly in the Quill delta. Geometry embeds
/// include the complete diagram payload, so reopening a document never depends
/// on the transient in-memory geometry registry.
class SmartEditorObjectCommands {
  const SmartEditorObjectCommands._();

  static (int, int) selectionRange(QuillController controller) {
    final end = math.max(0, controller.document.length - 1);
    final selection = controller.selection;
    final start = selection.start.clamp(0, end).toInt();
    final finish = selection.end.clamp(start, end).toInt();
    return (start, finish - start);
  }

  static void insertMath(
    QuillController controller,
    MathExpression expression, {
    (int, int)? range,
  }) {
    final effectiveRange = range ?? selectionRange(controller);
    var start = effectiveRange.$1;
    final length = effectiveRange.$2;

    if (expression.display == MathExpressionDisplay.inline) {
      controller.replaceText(
        start,
        length,
        MathExpressionEmbed(expression),
        null,
      );
      controller.updateSelection(
        TextSelection.collapsed(offset: start + 1),
        ChangeSource.local,
      );
      return;
    }

    if (length > 0) controller.replaceText(start, length, '', null);
    var text = controller.document.toPlainText();
    if (start > 0 && start <= text.length && text[start - 1] != '\n') {
      controller.replaceText(start, 0, '\n', null);
      start += 1;
    }
    controller.replaceText(start, 0, MathExpressionEmbed(expression), null);
    text = controller.document.toPlainText();
    final after = start + 1;
    if (after >= text.length || text[after] != '\n') {
      controller.replaceText(after, 0, '\n', null);
    }
    controller.updateSelection(
      TextSelection.collapsed(
        offset: math.min(start + 2, controller.document.length - 1),
      ),
      ChangeSource.local,
    );
  }

  static void insertGeometry(
    QuillController controller,
    GeometryDiagram diagram, {
    (int, int)? range,
  }) {
    GeometryDiagramRegistry.instance.save(diagram);
    final payload = GeometryEmbedLayout.forDiagram(diagram).encode();
    insertGeometryPayload(controller, payload, range: range);
  }

  static void insertGeometryPayload(
    QuillController controller,
    String payload, {
    (int, int)? range,
  }) {
    final effectiveRange = range ?? selectionRange(controller);
    var start = effectiveRange.$1;
    final length = effectiveRange.$2;
    if (length > 0) controller.replaceText(start, length, '', null);

    var text = controller.document.toPlainText();
    if (start > 0 && start <= text.length && text[start - 1] != '\n') {
      controller.replaceText(start, 0, '\n', null);
      start += 1;
    }
    controller.replaceText(
      start,
      0,
      BlockEmbed.custom(CustomBlockEmbed('geometry', payload)),
      null,
    );
    text = controller.document.toPlainText();
    final after = start + 1;
    if (after >= text.length || text[after] != '\n') {
      controller.replaceText(after, 0, '\n', null);
    }
    controller.updateSelection(
      TextSelection.collapsed(
        offset: math.min(start + 2, controller.document.length - 1),
      ),
      ChangeSource.local,
    );
  }
}
