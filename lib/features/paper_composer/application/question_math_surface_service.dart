import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/domain/question_advanced_content.dart';
import 'package:edusheet/features/paper_composer/domain/question_draft.dart';
import 'package:edusheet/features/editor/domain/models/question_math_content.dart';

class QuestionMathSurfaceDescriptor {
  final String key;
  final String group;
  final String label;
  final String fallbackText;

  const QuestionMathSurfaceDescriptor({
    required this.key,
    required this.group,
    required this.label,
    required this.fallbackText,
  });
}

/// Maps the existing Question/Draft string surfaces onto stable metadata keys.
///
/// No database field is added: each structured document keeps the ordinary
/// string as its compatibility fallback and stores the richer sequence in the
/// question's already-versioned metadata map.
class QuestionMathSurfaceService {
  const QuestionMathSurfaceService();

  List<QuestionMathSurfaceDescriptor> descriptorsForDraft(QuestionDraft draft) {
    final result = <QuestionMathSurfaceDescriptor>[];

    void add(String key, String group, String label, String value) {
      result.add(
        QuestionMathSurfaceDescriptor(
          key: key,
          group: group,
          label: label,
          fallbackText: value,
        ),
      );
    }

    for (final entry in draft.options.asMap().entries) {
      add(
        QuestionMathSurfaceKey.option(entry.value.id),
        'Answer options',
        'Option ${String.fromCharCode(65 + entry.key)}',
        entry.value.text,
      );
    }

    final stimulus = draft.advancedContent.stimulus;
    if (stimulus != null) {
      add(
        QuestionMathSurfaceKey.stimulusTitle,
        'Stimulus',
        '${stimulus.kind.label} title',
        stimulus.title,
      );
      add(
        QuestionMathSurfaceKey.stimulusText,
        'Stimulus',
        '${stimulus.kind.label} text',
        stimulus.text,
      );
    }

    for (final entry in draft.advancedContent.wordBank.asMap().entries) {
      add(
        QuestionMathSurfaceKey.wordBank(entry.key),
        'Word bank',
        'Word bank item ${entry.key + 1}',
        entry.value,
      );
    }

    final table = draft.tableData;
    if (table != null) {
      add(
        QuestionMathSurfaceKey.tableCaption,
        'Table',
        'Table caption',
        table.caption,
      );
      for (final entry in table.headers.asMap().entries) {
        add(
          QuestionMathSurfaceKey.tableHeader(entry.key),
          'Table',
          'Header ${entry.key + 1}',
          entry.value,
        );
      }
      for (final row in table.rows.asMap().entries) {
        for (final cell in row.value.asMap().entries) {
          add(
            QuestionMathSurfaceKey.tableCell(row.key, cell.key),
            'Table',
            'Row ${row.key + 1}, column ${cell.key + 1}',
            cell.value,
          );
        }
      }
    }

    for (final attachment in draft.attachments) {
      add(
        QuestionMathSurfaceKey.attachmentCaption(attachment.id),
        'Images',
        'Image caption',
        attachment.caption,
      );
    }

    add(
      QuestionMathSurfaceKey.instructions,
      'Question details',
      'Instructions',
      draft.details.instructions,
    );
    add(
      QuestionMathSurfaceKey.correctAnswer,
      'Question details',
      'Correct answer',
      draft.details.correctAnswer,
    );
    add(
      QuestionMathSurfaceKey.explanation,
      'Question details',
      'Explanation',
      draft.details.explanation,
    );

    return result;
  }

  Map<String, String> currentSurfaceText(QuestionDraft draft) => {
    for (final descriptor in descriptorsForDraft(draft))
      descriptor.key: descriptor.fallbackText,
  };

  QuestionDraft applyDocument(
    QuestionDraft draft,
    String key,
    QuestionMathInlineDocument document,
  ) {
    final normalized = document.normalized().trimOuterWhitespace();
    final fallback = normalized.fallbackText;
    final previousIdentities =
        draft.mathContent.surfaces[key]?.expressions
            .map((expression) => expression.persistentIdentity)
            .toSet() ??
        const <String>{};
    var next = draft.copyWith(
      mathExpressions: draft.mathExpressions
          .where(
            (expression) =>
                !previousIdentities.contains(expression.persistentIdentity),
          )
          .toList(),
      mathContent: draft.mathContent.setDocument(key, normalized),
    );

    if (key.startsWith('option:')) {
      final id = key.substring('option:'.length);
      next = next.copyWith(
        options: next.options
            .map(
              (option) =>
                  option.id == id ? option.copyWith(text: fallback) : option,
            )
            .toList(),
      );
      return next;
    }

    if (key == QuestionMathSurfaceKey.stimulusTitle ||
        key == QuestionMathSurfaceKey.stimulusText) {
      final stimulus = next.advancedContent.stimulus;
      if (stimulus == null) return next;
      final updated = key == QuestionMathSurfaceKey.stimulusTitle
          ? stimulus.copyWith(title: fallback)
          : stimulus.copyWith(text: fallback);
      return next.copyWith(
        advancedContent: next.advancedContent.copyWith(stimulus: updated),
      );
    }

    if (key.startsWith('wordBank:')) {
      final index = int.tryParse(key.substring('wordBank:'.length));
      if (index == null ||
          index < 0 ||
          index >= next.advancedContent.wordBank.length) {
        return next;
      }
      final items = [...next.advancedContent.wordBank]..[index] = fallback;
      return next.copyWith(
        advancedContent: next.advancedContent.copyWith(wordBank: items),
      );
    }

    if (key == QuestionMathSurfaceKey.tableCaption ||
        key.startsWith('table:header:') ||
        key.startsWith('table:cell:')) {
      final table = next.tableData;
      if (table == null) return next;
      var headers = List<String>.from(table.headers);
      var rows = table.rows.map((row) => List<String>.from(row)).toList();
      var caption = table.caption;
      if (key == QuestionMathSurfaceKey.tableCaption) {
        caption = fallback;
      } else if (key.startsWith('table:header:')) {
        final index = int.tryParse(key.substring('table:header:'.length));
        if (index != null && index >= 0 && index < headers.length) {
          headers[index] = fallback;
        }
      } else {
        final parts = key.split(':');
        if (parts.length == 4) {
          final row = int.tryParse(parts[2]);
          final column = int.tryParse(parts[3]);
          if (row != null &&
              column != null &&
              row >= 0 &&
              row < rows.length &&
              column >= 0 &&
              column < rows[row].length) {
            rows[row][column] = fallback;
          }
        }
      }
      return next.copyWith(
        tableData: QuestionTable(
          headers: headers,
          rows: rows,
          caption: caption,
          accessibilitySummary: table.accessibilitySummary,
        ),
      );
    }

    if (key.startsWith('attachment:') && key.endsWith(':caption')) {
      final id = key.substring(
        'attachment:'.length,
        key.length - ':caption'.length,
      );
      return next.copyWith(
        attachments: next.attachments
            .map(
              (attachment) => attachment.id == id
                  ? attachment.copyWith(caption: fallback)
                  : attachment,
            )
            .toList(),
      );
    }

    if (key == QuestionMathSurfaceKey.instructions) {
      return next.copyWith(
        details: next.details.copyWith(instructions: fallback),
      );
    }
    if (key == QuestionMathSurfaceKey.correctAnswer) {
      return next.copyWith(
        details: next.details.copyWith(correctAnswer: fallback),
      );
    }
    if (key == QuestionMathSurfaceKey.explanation) {
      return next.copyWith(
        details: next.details.copyWith(explanation: fallback),
      );
    }
    return next;
  }

  QuestionDraft removeDocument(QuestionDraft draft, String key) {
    final previousIdentities =
        draft.mathContent.surfaces[key]?.expressions
            .map((expression) => expression.persistentIdentity)
            .toSet() ??
        const <String>{};
    return draft.copyWith(
      mathExpressions: draft.mathExpressions
          .where(
            (expression) =>
                !previousIdentities.contains(expression.persistentIdentity),
          )
          .toList(),
      mathContent: draft.mathContent.remove(key),
    );
  }

  Map<String, String> currentSurfaceTextForQuestion(Question question) {
    final values = <String, String>{};
    for (final option in question.options) {
      values[QuestionMathSurfaceKey.option(option.id)] = option.text;
    }
    final advanced = QuestionAdvancedContent.fromQuestion(question);
    final stimulus = advanced.stimulus;
    if (stimulus != null) {
      values[QuestionMathSurfaceKey.stimulusTitle] = stimulus.title;
      values[QuestionMathSurfaceKey.stimulusText] = stimulus.text;
    }
    for (final entry in advanced.wordBank.asMap().entries) {
      values[QuestionMathSurfaceKey.wordBank(entry.key)] = entry.value;
    }
    final table = question.tableData;
    if (table != null) {
      values[QuestionMathSurfaceKey.tableCaption] = table.caption;
      for (final entry in table.headers.asMap().entries) {
        values[QuestionMathSurfaceKey.tableHeader(entry.key)] = entry.value;
      }
      for (final row in table.rows.asMap().entries) {
        for (final cell in row.value.asMap().entries) {
          values[QuestionMathSurfaceKey.tableCell(row.key, cell.key)] =
              cell.value;
        }
      }
    }
    for (final attachment in question.attachments) {
      values[QuestionMathSurfaceKey.attachmentCaption(attachment.id)] =
          attachment.caption;
    }
    values[QuestionMathSurfaceKey.instructions] = question.instructions;
    values[QuestionMathSurfaceKey.correctAnswer] = question.correctAnswer;
    values[QuestionMathSurfaceKey.explanation] = question.explanation;
    return values;
  }

  QuestionMathContent activeContentForQuestion(Question question) {
    return QuestionMathContent.fromQuestion(
      question,
    ).retainMatching(currentSurfaceTextForQuestion(question));
  }

  Question reconcileQuestion(Question question) {
    final content = QuestionMathContent.fromQuestion(question);
    final reconciled = content.retainMatching(
      currentSurfaceTextForQuestion(question),
    );
    final surfaceOwnedIdentities = content.expressionIdentities;
    final expressions = _dedupeExpressions([
      ...question.mathExpressions.where(
        (expression) =>
            !surfaceOwnedIdentities.contains(expression.persistentIdentity),
      ),
      ...reconciled.expressions,
    ]);
    final metadata = reconciled.writeToMetadata(question.metadata);
    return question.copyWith(
      mathExpressions: expressions,
      metadata: metadata,
      subQuestions: question.subQuestions.map(reconcileQuestion).toList(),
      internalChoices: question.internalChoices.map(reconcileQuestion).toList(),
      modifiedAt: question.modifiedAt,
    );
  }

  List<MathExpression> _dedupeExpressions(
    Iterable<MathExpression> expressions,
  ) {
    final result = <MathExpression>[];
    final seen = <String>{};
    for (final expression in expressions) {
      if (seen.add(expression.persistentIdentity)) result.add(expression);
    }
    return result;
  }

  QuestionMathInlineDocument? activeDocument(
    Question question,
    String key,
    String fallbackText,
  ) {
    return QuestionMathContent.fromQuestion(
      question,
    ).documentFor(key, currentFallback: fallbackText);
  }
}
