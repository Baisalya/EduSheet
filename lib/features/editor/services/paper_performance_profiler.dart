import 'dart:convert';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/paper_validator.dart';

class PaperPerformanceProfile {
  final int sectionCount;
  final int questionCount;
  final int serializedBytes;
  final Duration validationDuration;
  final Duration serializationDuration;
  final PaperValidationResult validation;

  const PaperPerformanceProfile({
    required this.sectionCount,
    required this.questionCount,
    required this.serializedBytes,
    required this.validationDuration,
    required this.serializationDuration,
    required this.validation,
  });
}

class PaperPerformanceProfiler {
  final PaperValidator validator;

  const PaperPerformanceProfiler({this.validator = const PaperValidator()});

  PaperPerformanceProfile profile(Paper paper) {
    final validationWatch = Stopwatch()..start();
    final validation = validator.validate(paper);
    validationWatch.stop();

    final serializationWatch = Stopwatch()..start();
    final serialized = utf8.encode(jsonEncode(paper.toJson()));
    serializationWatch.stop();

    return PaperPerformanceProfile(
      sectionCount: paper.sections.length,
      questionCount: paper.sections.fold(
        0,
        (count, section) => count + section.questions.length,
      ),
      serializedBytes: serialized.length,
      validationDuration: validationWatch.elapsed,
      serializationDuration: serializationWatch.elapsed,
      validation: validation,
    );
  }
}
