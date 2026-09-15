import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';

/// Stable identities for every legacy string surface that can carry structured
/// inline mathematics without changing the persisted [Question] schema.
///
/// The readable legacy string remains the compatibility/export fallback. The
/// structured document lives in [Question.metadata] and is used only while its
/// fallback still matches the current legacy string, so editing an old plain
/// field can never leave stale mathematics attached to different text.
abstract final class QuestionMathSurfaceKey {
  static const instructions = 'details:instructions';
  static const correctAnswer = 'details:correctAnswer';
  static const explanation = 'details:explanation';
  static const stimulusTitle = 'stimulus:title';
  static const stimulusText = 'stimulus:text';
  static const tableCaption = 'table:caption';

  static String option(String optionId) => 'option:$optionId';
  static String wordBank(int index) => 'wordBank:$index';
  static String tableHeader(int column) => 'table:header:$column';
  static String tableCell(int row, int column) => 'table:cell:$row:$column';
  static String attachmentCaption(String attachmentId) =>
      'attachment:$attachmentId:caption';
}

enum QuestionMathInlinePartKind { text, math }

class QuestionMathInlinePart {
  final QuestionMathInlinePartKind kind;
  final String text;
  final MathExpression? expression;

  const QuestionMathInlinePart._({
    required this.kind,
    this.text = '',
    this.expression,
  });

  const QuestionMathInlinePart.text(String text)
    : this._(kind: QuestionMathInlinePartKind.text, text: text);

  const QuestionMathInlinePart.math(MathExpression expression)
    : this._(kind: QuestionMathInlinePartKind.math, expression: expression);

  String get fallbackText {
    if (kind == QuestionMathInlinePartKind.text) return text;
    final math = expression;
    if (math == null) return '';
    final readable = math.plainText.trim();
    return readable.isEmpty ? math.latex.trim() : readable;
  }

  Map<String, dynamic> toJson() {
    return switch (kind) {
      QuestionMathInlinePartKind.text => {'kind': kind.name, 'text': text},
      QuestionMathInlinePartKind.math => {
        'kind': kind.name,
        if (expression != null) 'expression': expression!.toJson(),
      },
    };
  }

  factory QuestionMathInlinePart.fromJson(Map<String, dynamic> json) {
    final kind = QuestionMathInlinePartKind.values.firstWhere(
      (value) => value.name == json['kind']?.toString(),
      orElse: () => QuestionMathInlinePartKind.text,
    );
    if (kind == QuestionMathInlinePartKind.math && json['expression'] is Map) {
      return QuestionMathInlinePart.math(
        MathExpression.fromJson(
          Map<String, dynamic>.from(json['expression'] as Map),
        ),
      );
    }
    return QuestionMathInlinePart.text(json['text']?.toString() ?? '');
  }
}

class QuestionMathInlineDocument {
  final List<QuestionMathInlinePart> parts;

  const QuestionMathInlineDocument({required this.parts});

  factory QuestionMathInlineDocument.fromPlainText(String value) {
    return QuestionMathInlineDocument(
      parts: [QuestionMathInlinePart.text(value)],
    );
  }

  bool get hasMath => parts.any(
    (part) =>
        part.kind == QuestionMathInlinePartKind.math &&
        part.expression != null &&
        part.expression!.latex.trim().isNotEmpty,
  );

  String get fallbackText => parts.map((part) => part.fallbackText).join();

  List<MathExpression> get expressions => parts
      .where((part) => part.kind == QuestionMathInlinePartKind.math)
      .map((part) => part.expression)
      .whereType<MathExpression>()
      .toList(growable: false);

  QuestionMathInlineDocument normalized() {
    final result = <QuestionMathInlinePart>[];
    for (final part in parts) {
      if (part.kind == QuestionMathInlinePartKind.math) {
        final expression = part.expression;
        if (expression == null || expression.latex.trim().isEmpty) continue;
        result.add(
          QuestionMathInlinePart.math(
            expression.copyWith(display: MathExpressionDisplay.inline),
          ),
        );
        continue;
      }
      if (part.text.isEmpty) continue;
      if (result.isNotEmpty &&
          result.last.kind == QuestionMathInlinePartKind.text) {
        final previous = result.removeLast();
        result.add(QuestionMathInlinePart.text(previous.text + part.text));
      } else {
        result.add(part);
      }
    }
    if (result.isEmpty) {
      result.add(const QuestionMathInlinePart.text(''));
    }
    return QuestionMathInlineDocument(parts: result);
  }

  QuestionMathInlineDocument trimOuterWhitespace() {
    final normalizedDocument = normalized();
    final next = normalizedDocument.parts.toList();
    if (next.isNotEmpty && next.first.kind == QuestionMathInlinePartKind.text) {
      next[0] = QuestionMathInlinePart.text(next.first.text.trimLeft());
    }
    if (next.isNotEmpty && next.last.kind == QuestionMathInlinePartKind.text) {
      next[next.length - 1] = QuestionMathInlinePart.text(
        next.last.text.trimRight(),
      );
    }
    return QuestionMathInlineDocument(parts: next).normalized();
  }

  Map<String, dynamic> toJson() => {
    'parts': parts.map((part) => part.toJson()).toList(),
    'fallbackText': fallbackText,
  };

  factory QuestionMathInlineDocument.fromJson(Map<String, dynamic> json) {
    final rawParts = json['parts'];
    final parts = (rawParts is List ? rawParts : const <dynamic>[])
        .whereType<Map>()
        .map(
          (item) =>
              QuestionMathInlinePart.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    if (parts.isEmpty) {
      return QuestionMathInlineDocument.fromPlainText(
        json['fallbackText']?.toString() ?? '',
      );
    }
    return QuestionMathInlineDocument(parts: parts).normalized();
  }
}

class QuestionMathContent {
  static const metadataKey = 'smartPaperMathSurfacesV1';
  static const empty = QuestionMathContent();

  final Map<String, QuestionMathInlineDocument> surfaces;

  const QuestionMathContent({this.surfaces = const {}});

  int get structuredSurfaceCount =>
      surfaces.values.where((document) => document.hasMath).length;

  List<MathExpression> get expressions {
    final result = <MathExpression>[];
    final seen = <String>{};
    for (final document in surfaces.values) {
      for (final expression in document.expressions) {
        if (seen.add(expression.persistentIdentity)) result.add(expression);
      }
    }
    return result;
  }

  Set<String> get expressionIds => expressions
      .map((expression) => expression.id)
      .where((id) => id.isNotEmpty)
      .toSet();

  Set<String> get expressionIdentities =>
      expressions.map((expression) => expression.persistentIdentity).toSet();

  bool get hasAny => structuredSurfaceCount > 0;

  QuestionMathInlineDocument? documentFor(
    String surfaceKey, {
    required String currentFallback,
  }) {
    final document = surfaces[surfaceKey];
    if (document == null || !document.hasMath) return null;
    return document.fallbackText == currentFallback ? document : null;
  }

  QuestionMathContent setDocument(
    String surfaceKey,
    QuestionMathInlineDocument document,
  ) {
    final normalized = document.normalized();
    final next = Map<String, QuestionMathInlineDocument>.from(surfaces);
    if (!normalized.hasMath) {
      next.remove(surfaceKey);
    } else {
      next[surfaceKey] = normalized;
    }
    return QuestionMathContent(surfaces: next);
  }

  QuestionMathContent remapForCopy({
    required Map<String, String> optionIds,
    required Map<String, String> attachmentIds,
    required MathExpression Function(MathExpression source) mapExpression,
  }) {
    final next = <String, QuestionMathInlineDocument>{};
    for (final entry in surfaces.entries) {
      var key = entry.key;
      if (key.startsWith('option:')) {
        final oldId = key.substring('option:'.length);
        final newId = optionIds[oldId];
        if (newId == null) continue;
        key = QuestionMathSurfaceKey.option(newId);
      } else if (key.startsWith('attachment:') && key.endsWith(':caption')) {
        final oldId = key.substring(
          'attachment:'.length,
          key.length - ':caption'.length,
        );
        final newId = attachmentIds[oldId];
        if (newId == null) continue;
        key = QuestionMathSurfaceKey.attachmentCaption(newId);
      }

      final parts = entry.value.parts.map((part) {
        if (part.kind == QuestionMathInlinePartKind.text ||
            part.expression == null) {
          return QuestionMathInlinePart.text(part.text);
        }
        return QuestionMathInlinePart.math(mapExpression(part.expression!));
      }).toList();
      final document = QuestionMathInlineDocument(parts: parts).normalized();
      if (document.hasMath) next[key] = document;
    }
    return QuestionMathContent(surfaces: next);
  }

  QuestionMathContent remove(String surfaceKey) {
    if (!surfaces.containsKey(surfaceKey)) return this;
    final next = Map<String, QuestionMathInlineDocument>.from(surfaces)
      ..remove(surfaceKey);
    return QuestionMathContent(surfaces: next);
  }

  /// Drops documents whose readable compatibility string no longer matches the
  /// live legacy field. This is the safety fence that lets old editors keep
  /// editing plain strings without silently attaching formulas to changed text.
  QuestionMathContent retainMatching(Map<String, String> currentSurfaces) {
    final next = <String, QuestionMathInlineDocument>{};
    for (final entry in surfaces.entries) {
      final current = currentSurfaces[entry.key];
      if (current != null && current == entry.value.fallbackText) {
        next[entry.key] = entry.value;
      }
    }
    return QuestionMathContent(surfaces: next);
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'surfaces': surfaces.map(
      (key, document) => MapEntry(key, document.toJson()),
    ),
  };

  factory QuestionMathContent.fromQuestion(Question question) {
    return QuestionMathContent.fromMetadata(question.metadata);
  }

  factory QuestionMathContent.fromMetadata(Map<String, dynamic> metadata) {
    final raw = metadata[metadataKey];
    if (raw is! Map) return empty;
    final rawSurfaces = raw['surfaces'];
    if (rawSurfaces is! Map) return empty;
    final surfaces = <String, QuestionMathInlineDocument>{};
    for (final entry in rawSurfaces.entries) {
      if (entry.value is! Map) continue;
      final document = QuestionMathInlineDocument.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
      if (document.hasMath) surfaces[entry.key.toString()] = document;
    }
    return QuestionMathContent(surfaces: surfaces);
  }

  Map<String, dynamic> writeToMetadata(Map<String, dynamic> source) {
    final next = Map<String, dynamic>.from(source);
    if (!hasAny) {
      next.remove(metadataKey);
    } else {
      next[metadataKey] = toJson();
    }
    return next;
  }
}
