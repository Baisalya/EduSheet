import 'dart:math' as math;

import 'package:edusheet/features/paper_composer/domain/word_shape_object.dart';
import 'package:uuid/uuid.dart';

enum WordObjectAlignment {
  left,
  horizontalCenter,
  right,
  top,
  verticalCenter,
  bottom,
}

enum WordObjectDistribution { horizontal, vertical }

class WordObjectMoveResult {
  final WordShapeObject object;
  final double? verticalGuide;
  final double? horizontalGuide;

  const WordObjectMoveResult({
    required this.object,
    this.verticalGuide,
    this.horizontalGuide,
  });
}

/// Pure manipulation rules for the Word Mode floating-object layer.
///
/// The service owns no UI state. Selection remains transient in the editor;
/// this class only transforms persisted document objects.
class WordObjectManipulationService {
  const WordObjectManipulationService._();

  static const double defaultSnapThreshold = 0.012;
  static const double keyboardNudge = 0.004;
  static const double keyboardNudgeLarge = 0.02;

  static WordObjectMoveResult moveWithSnap(
    WordShapeObject object, {
    required double deltaX,
    required double deltaY,
    required Iterable<WordShapeObject> siblings,
    double threshold = defaultSnapThreshold,
  }) {
    if (object.locked) return WordObjectMoveResult(object: object);

    var x = (object.x + deltaX)
        .clamp(0.0, math.max(0.0, 1.0 - object.width))
        .toDouble();
    var y = (object.y + deltaY)
        .clamp(0.0, math.max(0.0, 1.0 - object.height))
        .toDouble();

    final xSnap = _bestAxisSnap(
      position: x,
      size: object.width,
      siblingStarts: [for (final item in siblings) item.x],
      siblingSizes: [for (final item in siblings) item.width],
      threshold: threshold,
    );
    final ySnap = _bestAxisSnap(
      position: y,
      size: object.height,
      siblingStarts: [for (final item in siblings) item.y],
      siblingSizes: [for (final item in siblings) item.height],
      threshold: threshold,
    );

    if (xSnap != null) x = xSnap.position;
    if (ySnap != null) y = ySnap.position;

    return WordObjectMoveResult(
      object: object.copyWith(x: x, y: y),
      verticalGuide: xSnap?.guide,
      horizontalGuide: ySnap?.guide,
    );
  }

  static List<WordShapeObject> moveSelection(
    List<WordShapeObject> objects,
    Set<String> selectedIds, {
    required double deltaX,
    required double deltaY,
  }) {
    if (selectedIds.isEmpty) return objects;
    final selected = objects
        .where((item) => selectedIds.contains(item.id) && !item.locked)
        .toList(growable: false);
    if (selected.isEmpty) return objects;

    final minX = selected.map((item) => item.x).reduce(math.min);
    final minY = selected.map((item) => item.y).reduce(math.min);
    final maxRight = selected
        .map((item) => item.x + item.width)
        .reduce(math.max);
    final maxBottom = selected
        .map((item) => item.y + item.height)
        .reduce(math.max);
    final safeDx = deltaX.clamp(-minX, 1.0 - maxRight).toDouble();
    final safeDy = deltaY.clamp(-minY, 1.0 - maxBottom).toDouble();

    return [
      for (final item in objects)
        if (selectedIds.contains(item.id) && !item.locked)
          item.copyWith(x: item.x + safeDx, y: item.y + safeDy)
        else
          item,
    ];
  }

  static WordShapeObject resizeBottomRight(
    WordShapeObject object, {
    required double deltaWidth,
    required double deltaHeight,
  }) {
    if (object.locked) return object;
    final maxWidth = math.max(0.08, 1.0 - object.x);
    final maxHeight = math.max(0.08, 1.0 - object.y);

    if (object.aspectRatioLocked && object.height > 0) {
      final ratio = object.width / object.height;
      final widthDeltaDominates = deltaWidth.abs() >= deltaHeight.abs();
      if (widthDeltaDominates) {
        final width = (object.width + deltaWidth)
            .clamp(0.08, maxWidth)
            .toDouble();
        final height = (width / ratio).clamp(0.08, maxHeight).toDouble();
        return object.copyWith(width: width, height: height);
      }
      final height = (object.height + deltaHeight)
          .clamp(0.08, maxHeight)
          .toDouble();
      final width = (height * ratio).clamp(0.08, maxWidth).toDouble();
      return object.copyWith(width: width, height: height);
    }

    return object.copyWith(
      width: (object.width + deltaWidth).clamp(0.08, maxWidth).toDouble(),
      height: (object.height + deltaHeight).clamp(0.08, maxHeight).toDouble(),
    );
  }

  static List<WordShapeObject> align(
    List<WordShapeObject> objects,
    Set<String> selectedIds,
    WordObjectAlignment alignment,
  ) {
    final selected = objects
        .where((item) => selectedIds.contains(item.id))
        .toList(growable: false);
    if (selected.length < 2) return objects;

    final minLeft = selected.map((item) => item.x).reduce(math.min);
    final maxRight = selected
        .map((item) => item.x + item.width)
        .reduce(math.max);
    final minTop = selected.map((item) => item.y).reduce(math.min);
    final maxBottom = selected
        .map((item) => item.y + item.height)
        .reduce(math.max);
    final centerX = (minLeft + maxRight) / 2;
    final centerY = (minTop + maxBottom) / 2;

    return [
      for (final item in objects)
        if (!selectedIds.contains(item.id) || item.locked)
          item
        else
          switch (alignment) {
            WordObjectAlignment.left => item.copyWith(x: minLeft),
            WordObjectAlignment.horizontalCenter => item.copyWith(
              x: (centerX - item.width / 2)
                  .clamp(0.0, math.max(0.0, 1 - item.width))
                  .toDouble(),
            ),
            WordObjectAlignment.right => item.copyWith(
              x: (maxRight - item.width)
                  .clamp(0.0, math.max(0.0, 1 - item.width))
                  .toDouble(),
            ),
            WordObjectAlignment.top => item.copyWith(y: minTop),
            WordObjectAlignment.verticalCenter => item.copyWith(
              y: (centerY - item.height / 2)
                  .clamp(0.0, math.max(0.0, 1 - item.height))
                  .toDouble(),
            ),
            WordObjectAlignment.bottom => item.copyWith(
              y: (maxBottom - item.height)
                  .clamp(0.0, math.max(0.0, 1 - item.height))
                  .toDouble(),
            ),
          },
    ];
  }

  static List<WordShapeObject> distribute(
    List<WordShapeObject> objects,
    Set<String> selectedIds,
    WordObjectDistribution distribution,
  ) {
    final selected = objects
        .where((item) => selectedIds.contains(item.id) && !item.locked)
        .toList();
    if (selected.length < 3) return objects;

    final replacements = <String, WordShapeObject>{};
    if (distribution == WordObjectDistribution.horizontal) {
      selected.sort((a, b) => a.x.compareTo(b.x));
      final start = selected.first.x;
      final end = selected.last.x + selected.last.width;
      final totalWidth = selected.fold<double>(0, (sum, item) => sum + item.width);
      final gap = math.max(0.0, (end - start - totalWidth) / (selected.length - 1));
      var cursor = start;
      for (final item in selected) {
        replacements[item.id] = item.copyWith(x: cursor);
        cursor += item.width + gap;
      }
    } else {
      selected.sort((a, b) => a.y.compareTo(b.y));
      final start = selected.first.y;
      final end = selected.last.y + selected.last.height;
      final totalHeight = selected.fold<double>(0, (sum, item) => sum + item.height);
      final gap = math.max(0.0, (end - start - totalHeight) / (selected.length - 1));
      var cursor = start;
      for (final item in selected) {
        replacements[item.id] = item.copyWith(y: cursor);
        cursor += item.height + gap;
      }
    }

    return [for (final item in objects) replacements[item.id] ?? item];
  }

  static List<WordShapeObject> duplicate(
    List<WordShapeObject> objects,
    Set<String> selectedIds,
  ) {
    final selected = objects
        .where((item) => selectedIds.contains(item.id))
        .toList(growable: false);
    if (selected.isEmpty) return objects;
    var nextZ = objects.isEmpty
        ? 0
        : objects.map((item) => item.zIndex).reduce(math.max) + 1;
    final copies = <WordShapeObject>[];
    for (final item in selected) {
      copies.add(
        item.copyWith(
          id: const Uuid().v4(),
          x: (item.x + 0.025)
              .clamp(0.0, math.max(0.0, 1 - item.width))
              .toDouble(),
          y: (item.y + 0.025)
              .clamp(0.0, math.max(0.0, 1 - item.height))
              .toDouble(),
          zIndex: nextZ++,
          locked: false,
        ),
      );
    }
    return [...objects, ...copies];
  }

  static List<WordShapeObject> deleteSelection(
    List<WordShapeObject> objects,
    Set<String> selectedIds,
  ) {
    return objects
        .where((item) => !selectedIds.contains(item.id) || item.locked)
        .toList(growable: false);
  }

  static List<WordShapeObject> setLocked(
    List<WordShapeObject> objects,
    Set<String> selectedIds,
    bool locked,
  ) {
    return [
      for (final item in objects)
        if (selectedIds.contains(item.id)) item.copyWith(locked: locked) else item,
    ];
  }


  static List<WordShapeObject> bringForwardOne(
    List<WordShapeObject> objects,
    Set<String> selectedIds,
  ) => _moveLayerOne(objects, selectedIds, forward: true);

  static List<WordShapeObject> sendBackwardOne(
    List<WordShapeObject> objects,
    Set<String> selectedIds,
  ) => _moveLayerOne(objects, selectedIds, forward: false);

  static List<WordShapeObject> _moveLayerOne(
    List<WordShapeObject> objects,
    Set<String> selectedIds, {
    required bool forward,
  }) {
    if (selectedIds.isEmpty || objects.length < 2) return objects;
    final ordered = [...objects]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    if (forward) {
      for (var i = ordered.length - 2; i >= 0; i--) {
        if (selectedIds.contains(ordered[i].id) &&
            !selectedIds.contains(ordered[i + 1].id)) {
          final temp = ordered[i];
          ordered[i] = ordered[i + 1];
          ordered[i + 1] = temp;
        }
      }
    } else {
      for (var i = 1; i < ordered.length; i++) {
        if (selectedIds.contains(ordered[i].id) &&
            !selectedIds.contains(ordered[i - 1].id)) {
          final temp = ordered[i];
          ordered[i] = ordered[i - 1];
          ordered[i - 1] = temp;
        }
      }
    }
    return [
      for (var i = 0; i < ordered.length; i++) ordered[i].copyWith(zIndex: i),
    ];
  }

  static List<WordShapeObject> paste(
    List<WordShapeObject> objects,
    Iterable<WordShapeObject> source,
  ) {
    final copied = source.toList(growable: false);
    if (copied.isEmpty) return objects;
    var nextZ = objects.isEmpty
        ? 0
        : objects.map((item) => item.zIndex).reduce(math.max) + 1;
    final clones = <WordShapeObject>[];
    for (final item in copied) {
      clones.add(
        item.copyWith(
          id: const Uuid().v4(),
          x: (item.x + 0.025)
              .clamp(0.0, math.max(0.0, 1 - item.width))
              .toDouble(),
          y: (item.y + 0.025)
              .clamp(0.0, math.max(0.0, 1 - item.height))
              .toDouble(),
          zIndex: nextZ++,
          locked: false,
        ),
      );
    }
    return [...objects, ...clones];
  }

  static List<WordShapeObject> bringToFront(
    List<WordShapeObject> objects,
    Set<String> selectedIds,
  ) => _moveLayerGroup(objects, selectedIds, toFront: true);

  static List<WordShapeObject> sendToBack(
    List<WordShapeObject> objects,
    Set<String> selectedIds,
  ) => _moveLayerGroup(objects, selectedIds, toFront: false);

  static List<WordShapeObject> _moveLayerGroup(
    List<WordShapeObject> objects,
    Set<String> selectedIds, {
    required bool toFront,
  }) {
    if (selectedIds.isEmpty) return objects;
    final ordered = [...objects]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    final selected = ordered.where((item) => selectedIds.contains(item.id)).toList();
    final others = ordered.where((item) => !selectedIds.contains(item.id)).toList();
    final combined = toFront ? [...others, ...selected] : [...selected, ...others];
    return [
      for (var i = 0; i < combined.length; i++) combined[i].copyWith(zIndex: i),
    ];
  }

  static WordShapeObject updateText(
    WordShapeObject object,
    String text,
  ) {
    var updated = object.copyWith(text: text);
    if (updated.textBoxSizing == WordTextBoxSizing.autoHeight &&
        updated.isTextContainer) {
      updated = updated.copyWith(height: estimatedAutoHeight(text));
    }
    return updated;
  }

  static WordShapeObject setTextBoxSizing(
    WordShapeObject object,
    WordTextBoxSizing sizing,
  ) {
    var updated = object.copyWith(textBoxSizing: sizing);
    if (sizing == WordTextBoxSizing.autoHeight && updated.isTextContainer) {
      updated = updated.copyWith(height: estimatedAutoHeight(updated.text));
    }
    return updated;
  }

  static double estimatedAutoHeight(String text) {
    final source = text.trim();
    if (source.isEmpty) return 0.14;
    var lines = 0;
    for (final rawLine in source.split('\n')) {
      lines += math.max(1, (rawLine.length / 30).ceil());
    }
    return (0.10 + lines * 0.055).clamp(0.14, 0.75).toDouble();
  }

  static _AxisSnap? _bestAxisSnap({
    required double position,
    required double size,
    required List<double> siblingStarts,
    required List<double> siblingSizes,
    required double threshold,
  }) {
    _AxisSnap? best;
    void consider(double candidatePosition, double guide) {
      final distance = (candidatePosition - position).abs();
      if (distance > threshold) return;
      if (best == null || distance < best!.distance) {
        best = _AxisSnap(
          position: candidatePosition.clamp(0.0, math.max(0.0, 1 - size)).toDouble(),
          guide: guide.clamp(0.0, 1.0).toDouble(),
          distance: distance,
        );
      }
    }

    consider(0, 0);
    consider((1 - size) / 2, 0.5);
    consider(1 - size, 1);

    for (var i = 0; i < siblingStarts.length; i++) {
      final start = siblingStarts[i];
      final siblingSize = siblingSizes[i];
      final center = start + siblingSize / 2;
      final end = start + siblingSize;
      consider(start, start);
      consider(center - size / 2, center);
      consider(end - size, end);
    }
    return best;
  }
}

class _AxisSnap {
  final double position;
  final double guide;
  final double distance;

  const _AxisSnap({
    required this.position,
    required this.guide,
    required this.distance,
  });
}
