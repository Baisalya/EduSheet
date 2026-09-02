import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:uuid/uuid.dart';

/// Metadata-backed canonical shape mutations for Word Mode.
///
/// Keeping shapes in [Question.metadata] means existing Paper JSON remains the
/// single source of truth and older papers need no database/schema migration.
class WordShapeService {
  const WordShapeService._();

  static const metadataKey = 'edusheet.wordShapes';
  static const metadataVersionKey = 'edusheet.wordShapesVersion';

  static List<WordShapeObject> shapesOf(Question question) {
    final raw = question.metadata[metadataKey];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (item) => WordShapeObject.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  static WordShapeObject create(WordShapeKind kind) {
    final lineLike =
        kind == WordShapeKind.line ||
        kind == WordShapeKind.arrow ||
        kind == WordShapeKind.doubleArrow;
    return WordShapeObject(
      id: const Uuid().v4(),
      kind: kind,
      width: lineLike ? 0.52 : 0.36,
      height: lineLike ? 0.10 : 0.30,
      text: switch (kind) {
        WordShapeKind.textBox => 'Text',
        WordShapeKind.callout => 'Callout',
        _ => '',
      },
    );
  }

  static Question append(Question question, WordShapeObject shape) {
    return _write(question, [...shapesOf(question), shape]);
  }

  static Question replace(Question question, WordShapeObject shape) {
    return _write(question, [
      for (final item in shapesOf(question))
        if (item.id == shape.id) shape else item,
    ]);
  }

  static Question remove(Question question, String shapeId) {
    return _write(
      question,
      shapesOf(question).where((item) => item.id != shapeId).toList(),
    );
  }

  static Question bringForward(Question question, String shapeId) {
    return _moveLayer(question, shapeId, 1);
  }

  static Question sendBackward(Question question, String shapeId) {
    return _moveLayer(question, shapeId, -1);
  }

  static Question _moveLayer(Question question, String shapeId, int direction) {
    final ordered = [...shapesOf(question)]
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final index = ordered.indexWhere((item) => item.id == shapeId);
    if (index < 0 || ordered.length < 2) return question;
    final target = (index + direction).clamp(0, ordered.length - 1).toInt();
    if (target == index) return question;

    final normalized = [
      for (var i = 0; i < ordered.length; i++) ordered[i].copyWith(zIndex: i),
    ];
    final moving = normalized[index];
    normalized[index] = normalized[target];
    normalized[target] = moving;
    return _write(question, [
      for (var i = 0; i < normalized.length; i++)
        normalized[i].copyWith(zIndex: i),
    ]);
  }

  static Question _write(Question question, List<WordShapeObject> shapes) {
    final metadata = Map<String, dynamic>.from(question.metadata);
    if (shapes.isEmpty) {
      metadata.remove(metadataKey);
      metadata.remove(metadataVersionKey);
    } else {
      metadata[metadataKey] = shapes.map((item) => item.toJson()).toList();
      metadata[metadataVersionKey] = 1;
    }
    return question.copyWith(metadata: metadata);
  }
}
