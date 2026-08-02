import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../editor/domain/models/paper_model.dart';
import '../domain/models/content_template.dart';

class TemplateCloneService {
  final String Function() newId;

  TemplateCloneService({String Function()? newId})
    : newId = newId ?? (() => const Uuid().v4());

  Question cloneQuestion(Question source) {
    final now = DateTime.now();
    return source.copyWith(
      id: newId(),
      options: source.options
          .map((option) => option.copyWith(id: newId()))
          .toList(),
      mathExpressions: source.mathExpressions
          .map((expression) => expression.copyWith(id: newId()))
          .toList(),
      attachments: source.attachments
          .map((attachment) => attachment.copyWith(id: newId()))
          .toList(),
      subQuestions: source.subQuestions.map(cloneQuestion).toList(),
      internalChoices: source.internalChoices.map(cloneQuestion).toList(),
      createdAt: now,
      modifiedAt: now,
      version: 1,
    );
  }

  PaperSection cloneSection(PaperSection source) {
    return PaperSection(
      id: newId(),
      title: source.title,
      instruction: source.instruction,
      prefix: source.prefix,
      questions: source.questions.map(cloneQuestion).toList(),
      requiredCount: source.requiredCount,
      showTitle: source.showTitle,
      showDivider: source.showDivider,
      numberingStyle: source.numberingStyle,
      defaultMarks: source.defaultMarks,
      pageBreakBefore: source.pageBreakBefore,
      keepTogether: source.keepTogether,
      answerSpaceLines: source.answerSpaceLines,
      ruledAnswerArea: source.ruledAnswerArea,
      graphAnswerArea: source.graphAnswerArea,
    );
  }

  Paper instantiatePaper(
    PaperBlueprint blueprint, {
    Map<String, String> variables = const {},
  }) {
    final source = blueprint.paper;
    final mergedVariables = {
      ...blueprint.variableDefaults,
      ...variables,
    };
    final cloned = source.copyWith(
      id: newId(),
      createdAt: DateTime.now(),
      headerFields: source.headerFields
          .map((field) => field.copyWith(id: newId()))
          .toList(),
      sections: source.sections.map(cloneSection).toList(),
    );
    return const TemplateVariableResolver().resolvePaper(
      cloned,
      mergedVariables,
    );
  }
}

class TemplateVariableResolver {
  static final RegExp _variable = RegExp(r'\{\{\s*([a-zA-Z0-9_]+)\s*\}\}');

  const TemplateVariableResolver();

  String resolveString(String input, Map<String, String> variables) {
    return input.replaceAllMapped(_variable, (match) {
      final key = match.group(1)!;
      return variables.containsKey(key) ? variables[key]! : match.group(0)!;
    });
  }

  Set<String> unresolvedVariables(Paper paper) {
    final unresolved = <String>{};
    final serialized = jsonEncode(paper.toJson());
    for (final match in _variable.allMatches(serialized)) {
      unresolved.add(match.group(1)!);
    }
    return unresolved;
  }

  Paper resolvePaper(Paper paper, Map<String, String> variables) {
    return paper.copyWith(
      title: resolveString(paper.title, variables),
      schoolName: resolveString(paper.schoolName, variables),
      instruction: resolveString(paper.instruction, variables),
      logos: paper.logos.map((item) => resolveString(item, variables)).toList(),
      customHeaderValues: paper.customHeaderValues.map(
        (key, value) => MapEntry(key, resolveString(value, variables)),
      ),
      headerFields: paper.headerFields.map((field) {
        return field.copyWith(
          label: resolveString(field.label, variables),
          value: resolveString(field.value, variables),
        );
      }).toList(),
      sections: paper.sections
          .map((section) => _resolveSection(section, variables))
          .toList(),
    );
  }

  PaperSection _resolveSection(
    PaperSection section,
    Map<String, String> variables,
  ) {
    return section.copyWith(
      title: resolveString(section.title, variables),
      instruction: section.instruction == null
          ? null
          : resolveString(section.instruction!, variables),
      prefix: resolveString(section.prefix, variables),
      questions: section.questions
          .map((question) => _resolveQuestion(question, variables))
          .toList(),
    );
  }

  Question _resolveQuestion(
    Question question,
    Map<String, String> variables,
  ) {
    return question.copyWith(
      text: _resolveRichText(question.text, variables),
      plainTextAccessibility: resolveString(
        question.plainTextAccessibility,
        variables,
      ),
      options: question.options
          .map(
            (option) => option.copyWith(
              text: resolveString(option.text, variables),
            ),
          )
          .toList(),
      correctAnswer: resolveString(question.correctAnswer, variables),
      explanation: resolveString(question.explanation, variables),
      grade: resolveString(question.grade, variables),
      subject: resolveString(question.subject, variables),
      chapter: resolveString(question.chapter, variables),
      topic: resolveString(question.topic, variables),
      learningObjective: resolveString(question.learningObjective, variables),
      instructions: resolveString(question.instructions, variables),
      sourceReference: resolveString(question.sourceReference, variables),
      mathExpressions: question.mathExpressions
          .map(
            (expression) => expression.copyWith(
              latex: resolveString(expression.latex, variables),
              plainText: resolveString(expression.plainText, variables),
            ),
          )
          .toList(),
      attachments: question.attachments
          .map(
            (attachment) => attachment.copyWith(
              path: resolveString(attachment.path, variables),
              alternativeText: resolveString(
                attachment.alternativeText,
                variables,
              ),
              caption: resolveString(attachment.caption, variables),
            ),
          )
          .toList(),
      subQuestions: question.subQuestions
          .map((item) => _resolveQuestion(item, variables))
          .toList(),
      internalChoices: question.internalChoices
          .map((item) => _resolveQuestion(item, variables))
          .toList(),
    );
  }

  String _resolveRichText(String input, Map<String, String> variables) {
    try {
      final decoded = jsonDecode(input);
      if (decoded is List) {
        final operations = decoded.map((operation) {
          if (operation is! Map) return operation;
          final updated = Map<String, dynamic>.from(operation);
          final insert = updated['insert'];
          if (insert is String) {
            updated['insert'] = resolveString(insert, variables);
          }
          return updated;
        }).toList();
        return jsonEncode(operations);
      }
    } catch (_) {
      // Plain text and malformed rich text remain editable through replacement.
    }
    return resolveString(input, variables);
  }
}
