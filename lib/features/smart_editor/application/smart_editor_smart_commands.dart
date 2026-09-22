import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

enum SmartEditorAcademicStyle { normal, question, section, instruction }

enum SmartEditorReusableBlock { instructions, answerLines, signature }

enum SmartEditorSuggestionKind { question, section, instruction }

class SmartEditorSuggestion {
  const SmartEditorSuggestion({
    required this.kind,
    required this.message,
    required this.signature,
  });

  final SmartEditorSuggestionKind kind;
  final String message;
  final String signature;

  SmartEditorAcademicStyle get style => switch (kind) {
    SmartEditorSuggestionKind.question => SmartEditorAcademicStyle.question,
    SmartEditorSuggestionKind.section => SmartEditorAcademicStyle.section,
    SmartEditorSuggestionKind.instruction => SmartEditorAcademicStyle.instruction,
  };
}

class SmartEditorSmartCommands {
  const SmartEditorSmartCommands._();

  static (int start, int end) currentLineRange(QuillController controller) {
    final text = controller.document.toPlainText();
    return _currentLineRangeForText(controller, text);
  }

  static (int start, int end) _currentLineRangeForText(
    QuillController controller,
    String text,
  ) {
    final maxOffset = math.max(0, text.length);
    final rawOffset = controller.selection.baseOffset;
    final offset = (rawOffset < 0 ? 0 : rawOffset).clamp(0, maxOffset).toInt();
    final previousBreak = offset <= 0 ? -1 : text.lastIndexOf('\n', offset - 1);
    final nextBreak = text.indexOf('\n', offset);
    final start = previousBreak < 0 ? 0 : previousBreak + 1;
    final end = nextBreak < 0 ? text.length : nextBreak;
    return (start, end);
  }

  static String currentLineText(QuillController controller) {
    final text = controller.document.toPlainText();
    final range = _currentLineRangeForText(controller, text);
    if (range.$1 >= text.length || range.$1 > range.$2) return '';
    return text.substring(range.$1, math.min(range.$2, text.length));
  }

  /// Computes slash-command and academic-style assistance from one plain-text
  /// snapshot. This avoids repeatedly serializing a long document while the
  /// teacher is typing near a single line.
  static (String?, SmartEditorSuggestion?) assistFor(
    QuillController controller,
  ) {
    final text = controller.document.toPlainText();
    final range = _currentLineRangeForText(controller, text);
    final slash = _slashQueryFor(controller, text, range);
    final suggestion = _suggestionFor(text, range);
    return (slash, suggestion);
  }

  /// Returns the text after `/` while the caret is on a slash-command line.
  /// A null result means normal editing should continue with no command UI.
  static String? slashQuery(QuillController controller) {
    final text = controller.document.toPlainText();
    final range = _currentLineRangeForText(controller, text);
    return _slashQueryFor(controller, text, range);
  }

  static String? _slashQueryFor(
    QuillController controller,
    String text,
    (int start, int end) range,
  ) {
    if (!controller.selection.isCollapsed) return null;
    final caret = controller.selection.baseOffset.clamp(range.$1, range.$2).toInt();
    if (caret < range.$1 || caret > text.length) return null;
    final prefix = text.substring(range.$1, caret);
    if (!prefix.startsWith('/')) return null;
    if (prefix.length > 40 || prefix.contains('\t')) return null;
    return prefix.substring(1).trimLeft();
  }

  static bool removeSlashPrefix(QuillController controller) {
    final query = slashQuery(controller);
    if (query == null) return false;
    final range = currentLineRange(controller);
    final caret = controller.selection.baseOffset.clamp(range.$1, range.$2).toInt();
    final removeLength = caret - range.$1;
    if (removeLength <= 0) return false;
    controller.replaceText(range.$1, removeLength, '', null);
    controller.updateSelection(
      TextSelection.collapsed(offset: range.$1),
      ChangeSource.local,
    );
    return true;
  }

  static SmartEditorSuggestion? suggestionFor(QuillController controller) {
    final text = controller.document.toPlainText();
    final range = _currentLineRangeForText(controller, text);
    return _suggestionFor(text, range);
  }

  static SmartEditorSuggestion? _suggestionFor(
    String text,
    (int start, int end) range,
  ) {
    if (range.$1 >= text.length || range.$1 > range.$2) return null;
    final raw = text.substring(range.$1, math.min(range.$2, text.length)).trim();
    if (raw.length < 4 || raw.startsWith('/')) return null;
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ');
    final lineStart = range.$1;
    if (RegExp(
      r'^(?:q(?:uestion)?\s*\d+\s*[.):-]?|\d+\s*[.)])\s+\S',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return SmartEditorSuggestion(
        kind: SmartEditorSuggestionKind.question,
        message: 'Question-like text detected. Apply Question style?',
        signature: 'question:$lineStart',
      );
    }
    if (RegExp(
      r'^(?:section|part)\s+[a-z0-9ivx]+(?:\s*[:.-])?',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return SmartEditorSuggestion(
        kind: SmartEditorSuggestionKind.section,
        message: 'Section heading detected. Apply Section style?',
        signature: 'section:$lineStart',
      );
    }
    if (RegExp(
      r'^(?:instructions?|directions?)\s*[:\-]',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return SmartEditorSuggestion(
        kind: SmartEditorSuggestionKind.instruction,
        message: 'Instruction text detected. Apply Instruction style?',
        signature: 'instruction:$lineStart',
      );
    }
    return null;
  }

  static void applyAcademicStyle(
    QuillController controller,
    SmartEditorAcademicStyle style,
  ) {
    switch (style) {
      case SmartEditorAcademicStyle.normal:
        controller.formatSelection(Attribute.clone(Attribute.h1, null));
        controller.formatSelection(Attribute.clone(Attribute.ol, null));
        controller.formatSelection(Attribute.clone(Attribute.bold, null));
        controller.formatSelection(Attribute.clone(Attribute.italic, null));
        break;
      case SmartEditorAcademicStyle.question:
        controller.formatSelection(Attribute.clone(Attribute.h1, null));
        controller.formatSelection(Attribute.bold);
        controller.formatSelection(Attribute.ol);
        break;
      case SmartEditorAcademicStyle.section:
        controller.formatSelection(Attribute.clone(Attribute.ol, null));
        controller.formatSelection(Attribute.h2);
        controller.formatSelection(Attribute.bold);
        break;
      case SmartEditorAcademicStyle.instruction:
        controller.formatSelection(Attribute.clone(Attribute.h1, null));
        controller.formatSelection(Attribute.clone(Attribute.ol, null));
        controller.formatSelection(Attribute.italic);
        break;
    }
  }

  static void insertReusableBlock(
    QuillController controller,
    SmartEditorReusableBlock block,
  ) {
    final range = _selectionRange(controller);
    final text = switch (block) {
      SmartEditorReusableBlock.instructions =>
        'Instructions:\n1. Read each question carefully.\n2. Answer in the space provided.\n',
      SmartEditorReusableBlock.answerLines =>
        'Answer:\n________________________________________\n________________________________________\n________________________________________\n',
      SmartEditorReusableBlock.signature =>
        '\nSignature: ______________________________\n',
    };
    controller.replaceText(range.$1, range.$2, text, null);
    final end = math.min(
      range.$1 + text.length,
      controller.document.length - 1,
    );
    controller.updateSelection(
      TextSelection.collapsed(offset: end),
      ChangeSource.local,
    );
  }

  static void toggleInline(QuillController controller, Attribute attribute) {
    final current = controller.getSelectionStyle().attributes[attribute.key];
    final active = current?.value == attribute.value;
    controller.formatSelection(
      active ? Attribute.clone(attribute, null) : attribute,
    );
  }

  static (int, int) _selectionRange(QuillController controller) {
    final end = math.max(0, controller.document.length - 1);
    final selection = controller.selection;
    final start = selection.start.clamp(0, end).toInt();
    final finish = selection.end.clamp(start, end).toInt();
    return (start, finish - start);
  }
}
