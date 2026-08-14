import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/question_copy_service.dart';
import 'package:edusheet/features/question_bank/domain/models/question_bank_model.dart';

/// Teacher-facing Question Bank operations that sit above persistence.
///
/// The repository stores master questions. This service defines the semantic
/// boundary between a reusable master and the independent copy inserted into a
/// paper, and centralizes metadata compatibility and duplicate detection.
class QuestionBankApplicationService {
  final QuestionCopyService _copyService;

  QuestionBankApplicationService(this._copyService);

  QuestionBankQuestion createMasterCopy(
    Question source, {
    String fallbackSubject = '',
    String fallbackChapter = '',
    String fallbackGrade = '',
    bool isFavorite = false,
    DateTime? createdAt,
  }) {
    final copied = _copyService.copyQuestion(source);
    final subject = _valueOrFallback(
      source.subject,
      fallbackSubject,
      fallback: 'General',
    );
    final chapter = _valueOrFallback(
      source.chapter,
      fallbackChapter,
      fallback: 'General',
    );
    final grade = _valueOrFallback(source.grade, fallbackGrade, fallback: '');
    final normalized = copied.copyWith(
      subject: subject,
      chapter: chapter,
      grade: grade,
      difficulty: source.difficulty,
      tags: List<String>.from(source.tags),
    );

    return QuestionBankQuestion.fromQuestion(
      normalized,
      isFavorite: isFavorite,
      createdAt: createdAt,
    );
  }

  QuestionBankQuestion normalizeEditedMaster(
    Question edited, {
    QuestionBankQuestion? existing,
  }) {
    final subject = _valueOrFallback(
      edited.subject,
      existing?.subject ?? '',
      fallback: 'General',
    );
    final chapter = _valueOrFallback(
      edited.chapter,
      existing?.chapter ?? '',
      fallback: 'General',
    );
    final question = edited.copyWith(
      subject: subject,
      chapter: chapter,
      difficulty: edited.difficulty,
      tags: List<String>.from(edited.tags),
    );
    return QuestionBankQuestion.fromQuestion(
      question,
      isFavorite: existing?.isFavorite ?? false,
      createdAt: existing?.createdAt,
    );
  }

  Question copyIntoPaper(QuestionBankQuestion master) {
    return _copyService.copyQuestion(master.question);
  }

  List<Question> copyManyIntoPaper(Iterable<QuestionBankQuestion> masters) {
    return masters.map(copyIntoPaper).toList();
  }

  QuestionBankQuestion? findLikelyDuplicate(
    Question source,
    Iterable<QuestionBankQuestion> bank,
  ) {
    final signature = contentSignature(source);
    if (signature.isEmpty) {
      return null;
    }
    for (final candidate in bank) {
      if (contentSignature(candidate.question) == signature) {
        return candidate;
      }
    }
    return null;
  }

  String contentSignature(Question question) {
    final semanticText = question.plainTextAccessibility.trim().isNotEmpty
        ? question.plainTextAccessibility
        : question.text;
    final parts = <String>[
      question.type.name,
      question.subject,
      question.chapter,
      semanticText,
      ...question.options.map((option) => option.text),
      ...question.mathExpressions.map((expression) => expression.latex),
    ];
    return parts
        .join('|')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9\u0080-\uFFFF|]+'), '')
        .trim();
  }

  double totalMarks(Iterable<QuestionBankQuestion> questions) {
    return questions.fold(0.0, (sum, entry) => sum + entry.question.marks);
  }

  String _valueOrFallback(
    String value,
    String fallbackValue, {
    required String fallback,
  }) {
    final primary = value.trim();
    if (primary.isNotEmpty) {
      return primary;
    }
    final secondary = fallbackValue.trim();
    return secondary.isNotEmpty ? secondary : fallback;
  }
}
