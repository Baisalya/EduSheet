import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart' as xml;

import '../../domain/models/presentation_model.dart';
import 'document_file_read_service.dart';

class PresentationParserService {
  Future<PresentationDocument> load(File file) async {
    final bytes = await DocumentFileReadService.readAllBytes(file);
    final payload = await compute(_parsePresentationPayload, bytes);
    return _documentFromPayload(payload);
  }

  PresentationDocument _documentFromPayload(Map<String, Object?> payload) {
    final slides = <PresentationSlide>[];
    final rawSlides = payload['slides'];
    if (rawSlides is List) {
      for (final rawSlide in rawSlides) {
        if (rawSlide is! Map) continue;
        final elements = <PresentationElement>[];
        final rawElements = rawSlide['elements'];
        if (rawElements is List) {
          for (final rawElement in rawElements) {
            if (rawElement is! Map) continue;
            final rawType = rawElement['type']?.toString();
            final type = switch (rawType) {
              'image' => PresentationElementType.image,
              'placeholder' => PresentationElementType.placeholder,
              _ => PresentationElementType.text,
            };
            final rawImage = rawElement['imageBytes'];
            elements.add(
              PresentationElement(
                type: type,
                objectId: rawElement['objectId']?.toString(),
                left: (rawElement['left'] as num?)?.toDouble() ?? 0,
                top: (rawElement['top'] as num?)?.toDouble() ?? 0,
                width: (rawElement['width'] as num?)?.toDouble() ?? 0,
                height: (rawElement['height'] as num?)?.toDouble() ?? 0,
                hasBounds: rawElement['hasBounds'] == true,
                text: rawElement['text']?.toString() ?? '',
                imageBytes: rawImage is Uint8List
                    ? rawImage
                    : rawImage is List
                    ? Uint8List.fromList(rawImage.cast<int>())
                    : null,
                fillColor: (rawElement['fillColor'] as num?)?.toInt(),
                fillGradient: _gradientFromPayload(rawElement['fillGradient']),
                strokeColor: (rawElement['strokeColor'] as num?)?.toInt(),
                strokeWidthPoints: (rawElement['strokeWidthPoints'] as num?)
                    ?.toDouble(),
                textColor: (rawElement['textColor'] as num?)?.toInt(),
                fontSizePoints: (rawElement['fontSizePoints'] as num?)
                    ?.toDouble(),
                fontFamily: rawElement['fontFamily']?.toString(),
                bold: rawElement['bold'] == true,
                italic: rawElement['italic'] == true,
                underline: rawElement['underline'] == true,
                alignment: rawElement['alignment']?.toString(),
                rotationDegrees:
                    (rawElement['rotationDegrees'] as num?)?.toDouble() ?? 0,
                shapeKind: rawElement['shapeKind']?.toString(),
                textRuns: _textRunsFromPayload(rawElement['textRuns']),
              ),
            );
          }
        }

        final rawTransition = rawSlide['transition'];
        final transitionMap = rawTransition is Map ? rawTransition : const {};
        slides.add(
          PresentationSlide(
            number: (rawSlide['number'] as num?)?.toInt() ?? slides.length + 1,
            elements: elements,
            backgroundColor: (rawSlide['backgroundColor'] as num?)?.toInt(),
            backgroundGradient: _gradientFromPayload(
              rawSlide['backgroundGradient'],
            ),
            hasNativeAnimations: rawSlide['hasNativeAnimations'] == true,
            animations: _animationsFromPayload(rawSlide['animations']),
            transition: PresentationTransition(
              kind: _transitionKind(transitionMap['kind']?.toString()),
              direction: transitionMap['direction']?.toString(),
              duration: Duration(
                milliseconds:
                    (transitionMap['durationMs'] as num?)?.toInt() ?? 280,
              ),
            ),
          ),
        );
      }
    }

    return PresentationDocument(
      slideWidth: (payload['slideWidth'] as num?)?.toDouble() ?? 12192000,
      slideHeight: (payload['slideHeight'] as num?)?.toDouble() ?? 6858000,
      slides: slides,
    );
  }

  List<PresentationTextRun> _textRunsFromPayload(Object? raw) {
    if (raw is! List) return const <PresentationTextRun>[];
    return raw.whereType<Map>().map((run) {
      return PresentationTextRun(
        text: run['text']?.toString() ?? '',
        color: (run['color'] as num?)?.toInt(),
        fontSizePoints: (run['fontSizePoints'] as num?)?.toDouble(),
        fontFamily: run['fontFamily']?.toString(),
        bold: run['bold'] == true,
        italic: run['italic'] == true,
        underline: run['underline'] == true,
      );
    }).toList(growable: false);
  }

  List<PresentationAnimationStep> _animationsFromPayload(Object? raw) {
    if (raw is! List) return const <PresentationAnimationStep>[];
    return raw.whereType<Map>().map((item) {
      return PresentationAnimationStep(
        targetObjectId: item['targetObjectId']?.toString() ?? '',
        kind: _animationKind(item['kind']?.toString()),
        trigger: _animationTrigger(item['trigger']?.toString()),
        duration: Duration(
          milliseconds: (item['durationMs'] as num?)?.toInt() ?? 400,
        ),
        delay: Duration(
          milliseconds: (item['delayMs'] as num?)?.toInt() ?? 0,
        ),
        direction: item['direction']?.toString(),
        magnitude: (item['magnitude'] as num?)?.toDouble() ?? 1.2,
        supported: item['supported'] != false,
        sourceEffect: item['sourceEffect']?.toString(),
      );
    }).where((step) => step.targetObjectId.isNotEmpty).toList(growable: false);
  }

  PresentationAnimationKind _animationKind(String? value) {
    return switch (value) {
      'appear' => PresentationAnimationKind.appear,
      'fadeIn' => PresentationAnimationKind.fadeIn,
      'fadeOut' => PresentationAnimationKind.fadeOut,
      'flyIn' => PresentationAnimationKind.flyIn,
      'flyOut' => PresentationAnimationKind.flyOut,
      'wipeIn' => PresentationAnimationKind.wipeIn,
      'wipeOut' => PresentationAnimationKind.wipeOut,
      'zoomIn' => PresentationAnimationKind.zoomIn,
      'zoomOut' => PresentationAnimationKind.zoomOut,
      'growShrink' => PresentationAnimationKind.growShrink,
      'pulse' => PresentationAnimationKind.pulse,
      'disappear' => PresentationAnimationKind.disappear,
      _ => PresentationAnimationKind.unsupported,
    };
  }

  PresentationAnimationTrigger _animationTrigger(String? value) {
    return switch (value) {
      'withPrevious' => PresentationAnimationTrigger.withPrevious,
      'afterPrevious' => PresentationAnimationTrigger.afterPrevious,
      _ => PresentationAnimationTrigger.onClick,
    };
  }

  PresentationGradient? _gradientFromPayload(Object? raw) {
    if (raw is! Map) return null;
    final stops = <PresentationGradientStop>[];
    final rawStops = raw['stops'];
    if (rawStops is List) {
      for (final stop in rawStops.whereType<Map>()) {
        final color = (stop['color'] as num?)?.toInt();
        if (color == null) continue;
        stops.add(
          PresentationGradientStop(
            position: ((stop['position'] as num?)?.toDouble() ?? 0).clamp(0, 1).toDouble(),
            color: color,
          ),
        );
      }
    }
    if (stops.isEmpty) return null;
    return PresentationGradient(
      stops: stops,
      angleDegrees: (raw['angleDegrees'] as num?)?.toDouble() ?? 0,
    );
  }

  PresentationTransitionKind _transitionKind(String? value) {
    return switch (value) {
      'fade' => PresentationTransitionKind.fade,
      'push' => PresentationTransitionKind.push,
      'wipe' => PresentationTransitionKind.wipe,
      'split' => PresentationTransitionKind.split,
      'cover' => PresentationTransitionKind.cover,
      'uncover' => PresentationTransitionKind.uncover,
      'zoom' => PresentationTransitionKind.zoom,
      _ => PresentationTransitionKind.none,
    };
  }
}

Map<String, Object?> _parsePresentationPayload(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final files = <String, ArchiveFile>{
    for (final entry in archive.files) p.posix.normalize(entry.name): entry,
  };

  final presentationEntry = files['ppt/presentation.xml'];
  final presentationXml = presentationEntry == null
      ? null
      : xml.XmlDocument.parse(utf8.decode(_entryBytes(presentationEntry)));

  var slideWidth = 12192000.0;
  var slideHeight = 6858000.0;
  if (presentationXml != null) {
    final slideSize = _firstDescendant(presentationXml, 'sldSz');
    slideWidth =
        double.tryParse(slideSize?.getAttribute('cx') ?? '') ?? slideWidth;
    slideHeight =
        double.tryParse(slideSize?.getAttribute('cy') ?? '') ?? slideHeight;
  }

  final slidePaths = _orderedSlidePaths(files, presentationXml);
  final slides = <Object>[];
  for (var index = 0; index < slidePaths.length; index++) {
    final slidePath = slidePaths[index];
    final entry = files[slidePath];
    if (entry == null) continue;
    final slideXml = xml.XmlDocument.parse(utf8.decode(_entryBytes(entry)));
    final slideRels = _relationships(files, slidePath);

    final layoutPath = _relationshipTargetByType(slideRels, 'slideLayout');
    final layoutXml = _loadXml(files, layoutPath);
    final layoutRels = layoutPath == null
        ? const <String, _Relationship>{}
        : _relationships(files, layoutPath);
    final masterPath = _relationshipTargetByType(layoutRels, 'slideMaster');
    final masterXml = _loadXml(files, masterPath);
    final masterRels = masterPath == null
        ? const <String, _Relationship>{}
        : _relationships(files, masterPath);
    final themePath = _relationshipTargetByType(masterRels, 'theme');
    final themeXml = _loadXml(files, themePath);
    final theme = _ThemeData.fromXml(themeXml);

    final layoutPlaceholders = _placeholderShapes(layoutXml);
    final masterPlaceholders = _placeholderShapes(masterXml);
    final masterTextStyles = _masterTextStyles(masterXml, theme);

    final elements = <Object>[];
    final spTree = _firstDescendant(slideXml, 'spTree');
    final children = spTree?.childElements ?? <xml.XmlElement>[];
    for (final element in children) {
      if (element.name.local == 'sp') {
        final key = _placeholderKey(element);
        final ph = _firstDescendant(element, 'ph');
        final typeKey = ph == null ? null : 'type:${ph.getAttribute('type') ?? 'body'}';
        final inheritedLayout = key == null
            ? null
            : layoutPlaceholders[key] ??
                  (typeKey == null ? null : layoutPlaceholders[typeKey]);
        final inheritedMaster = key == null
            ? null
            : masterPlaceholders[key] ??
                  (typeKey == null ? null : masterPlaceholders[typeKey]);
        final data = _shapePayload(
          element,
          inheritedLayout,
          inheritedMaster,
          masterTextStyles,
          theme,
          slideWidth,
          slideHeight,
        );
        if (data != null) elements.add(data);
      } else if (element.name.local == 'pic') {
        final data = _picturePayload(
          element,
          files,
          slideRels,
          slideWidth,
          slideHeight,
        );
        if (data != null) elements.add(data);
      } else if (element.name.local == 'graphicFrame') {
        final data = _graphicFramePayload(element, slideWidth, slideHeight, theme);
        if (data != null) elements.add(data);
      }
    }

    if (elements.isEmpty) {
      final readableText = _extractParagraphText(slideXml.rootElement);
      for (final text in readableText) {
        elements.add(<String, Object?>{
          'type': 'text',
          'text': text,
          'hasBounds': false,
        });
      }
    }

    final background = _resolvedBackground(
      slideXml,
      layoutXml,
      masterXml,
      theme,
    );

    slides.add(<String, Object?>{
      'number': index + 1,
      'elements': elements,
      'backgroundColor': background.color,
      'backgroundGradient': background.gradient,
      'hasNativeAnimations': slideXml.descendants
          .whereType<xml.XmlElement>()
          .any((element) => element.name.local == 'timing'),
      'animations': _animationPayloads(slideXml),
      'transition': _transitionPayload(slideXml),
    });
  }

  return <String, Object?>{
    'slideWidth': slideWidth,
    'slideHeight': slideHeight,
    'slides': slides,
  };
}

class _Relationship {
  final String id;
  final String target;
  final String type;

  const _Relationship(this.id, this.target, this.type);
}

Map<String, _Relationship> _relationships(
  Map<String, ArchiveFile> files,
  String sourcePath,
) {
  final relPath = p.posix.join(
    p.posix.dirname(sourcePath),
    '_rels',
    '${p.posix.basename(sourcePath)}.rels',
  );
  final relEntry = files[relPath];
  if (relEntry == null) return const {};
  final result = <String, _Relationship>{};
  final relXml = xml.XmlDocument.parse(utf8.decode(_entryBytes(relEntry)));
  for (final rel in relXml.descendants.whereType<xml.XmlElement>()) {
    if (rel.name.local != 'Relationship') continue;
    final id = rel.getAttribute('Id');
    final target = rel.getAttribute('Target');
    final type = rel.getAttribute('Type') ?? '';
    if (id != null && target != null) {
      result[id] = _Relationship(id, _resolvePath(sourcePath, target), type);
    }
  }
  return result;
}

String? _relationshipTargetByType(
  Map<String, _Relationship> relationships,
  String typeSuffix,
) {
  for (final relationship in relationships.values) {
    if (relationship.type.endsWith('/$typeSuffix')) return relationship.target;
  }
  return null;
}

xml.XmlDocument? _loadXml(Map<String, ArchiveFile> files, String? path) {
  if (path == null) return null;
  final entry = files[path];
  if (entry == null) return null;
  return xml.XmlDocument.parse(utf8.decode(_entryBytes(entry)));
}

List<String> _orderedSlidePaths(
  Map<String, ArchiveFile> files,
  xml.XmlDocument? presentationXml,
) {
  final presentationRels = files['ppt/_rels/presentation.xml.rels'];
  if (presentationXml != null && presentationRels != null) {
    final targets = <String, String>{};
    final relXml = xml.XmlDocument.parse(utf8.decode(_entryBytes(presentationRels)));
    for (final rel in relXml.descendants.whereType<xml.XmlElement>()) {
      if (rel.name.local != 'Relationship') continue;
      final id = rel.getAttribute('Id');
      final target = rel.getAttribute('Target');
      if (id != null && target != null && target.contains('slides/')) {
        targets[id] = _resolvePath('ppt/presentation.xml', target);
      }
    }
    final ordered = <String>[];
    for (final slideId in presentationXml.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local == 'sldId')) {
      String? relId;
      for (final attribute in slideId.attributes) {
        if (attribute.name.local == 'id' && attribute.name.prefix == 'r') {
          relId = attribute.value;
          break;
        }
      }
      final path = targets[relId];
      if (path != null && files.containsKey(path)) ordered.add(path);
    }
    if (ordered.isNotEmpty) return ordered;
  }
  final slidePaths = files.keys
      .where((name) => RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(name))
      .toList();
  slidePaths.sort((a, b) => _slideNumber(a).compareTo(_slideNumber(b)));
  return slidePaths;
}

String? _placeholderKey(xml.XmlElement shape) {
  final ph = _firstDescendant(shape, 'ph');
  if (ph == null) return null;
  final idx = ph.getAttribute('idx');
  final type = ph.getAttribute('type');
  if (idx != null && idx.isNotEmpty) return 'idx:$idx';
  return 'type:${type ?? 'body'}';
}

Map<String, xml.XmlElement> _placeholderShapes(xml.XmlDocument? document) {
  if (document == null) return const {};
  final result = <String, xml.XmlElement>{};
  final spTree = _firstDescendant(document, 'spTree');
  if (spTree == null) return result;
  for (final shape in spTree.childElements.where((e) => e.name.local == 'sp')) {
    final ph = _firstDescendant(shape, 'ph');
    if (ph == null) continue;
    final idx = ph.getAttribute('idx');
    final type = ph.getAttribute('type');
    if (idx != null && idx.isNotEmpty) result['idx:$idx'] = shape;
    if (type != null && type.isNotEmpty) result['type:$type'] = shape;
    if ((idx == null || idx.isEmpty) && (type == null || type.isEmpty)) {
      result['type:body'] = shape;
    }
  }
  return result;
}

class _MasterTextStyle {
  final double? fontSizePoints;
  final int? color;
  final String? fontFamilyToken;
  final bool bold;
  final String? alignment;

  const _MasterTextStyle({
    this.fontSizePoints,
    this.color,
    this.fontFamilyToken,
    this.bold = false,
    this.alignment,
  });
}

Map<String, _MasterTextStyle> _masterTextStyles(
  xml.XmlDocument? master,
  _ThemeData theme,
) {
  if (master == null) return const {};
  final txStyles = _firstDescendant(master, 'txStyles');
  if (txStyles == null) return const {};
  final result = <String, _MasterTextStyle>{};
  for (final entry in const {'titleStyle': 'title', 'bodyStyle': 'body', 'otherStyle': 'other'}.entries) {
    final section = _firstDescendant(txStyles, entry.key);
    if (section == null) continue;
    final level = _firstDescendant(section, 'lvl1pPr');
    final defRPr = level == null ? null : _firstDescendant(level, 'defRPr');
    final rawSize = double.tryParse(defRPr?.getAttribute('sz') ?? '');
    final latin = defRPr == null ? null : _firstDescendant(defRPr, 'latin');
    result[entry.value] = _MasterTextStyle(
      fontSizePoints: rawSize == null ? null : rawSize / 100,
      color: defRPr == null ? null : _colorFromNode(defRPr, theme),
      fontFamilyToken: latin?.getAttribute('typeface'),
      bold: _boolAttr(defRPr?.getAttribute('b')),
      alignment: level?.getAttribute('algn'),
    );
  }
  return result;
}

Map<String, Object?>? _shapePayload(
  xml.XmlElement shape,
  xml.XmlElement? layoutShape,
  xml.XmlElement? masterShape,
  Map<String, _MasterTextStyle> masterTextStyles,
  _ThemeData theme,
  double slideWidth,
  double slideHeight,
) {
  final text = _extractParagraphText(shape).join('\n').trim();
  final bounds = _resolvedBoundsPayload(
    shape,
    layoutShape,
    masterShape,
    slideWidth,
    slideHeight,
  );
  final slideSpPr = _directChild(shape, 'spPr');
  final layoutSpPr = layoutShape == null ? null : _directChild(layoutShape, 'spPr');
  final masterSpPr = masterShape == null ? null : _directChild(masterShape, 'spPr');
  final spPr = _firstNonNull([slideSpPr, layoutSpPr, masterSpPr]);

  var fill = _resolvedFill([slideSpPr, layoutSpPr, masterSpPr], theme);
  var line = _resolvedLine([slideSpPr, layoutSpPr, masterSpPr], theme);
  final shapeStyle = _directChild(shape, 'style') ??
      (layoutShape == null ? null : _directChild(layoutShape, 'style')) ??
      (masterShape == null ? null : _directChild(masterShape, 'style'));
  if (fill.color == null && fill.gradient == null && shapeStyle != null) {
    final fillRef = _directChild(shapeStyle, 'fillRef');
    final refColor = fillRef == null ? null : _colorFromNode(fillRef, theme);
    if (refColor != null) fill = _ResolvedFill(color: refColor);
  }
  if (line.color == null && shapeStyle != null) {
    final lineRef = _directChild(shapeStyle, 'lnRef');
    final refColor = lineRef == null ? null : _colorFromNode(lineRef, theme);
    if (refColor != null) line = _ResolvedLine(color: refColor);
  }
  final placeholderType = _firstDescendant(shape, 'ph')?.getAttribute('type');
  final styleKey = placeholderType == 'title' ||
          placeholderType == 'ctrTitle' ||
          placeholderType == 'subTitle'
      ? 'title'
      : placeholderType == 'body' || placeholderType == 'obj'
      ? 'body'
      : 'other';
  final masterStyle = masterTextStyles[styleKey];
  final textStyle = _resolvedTextStyle(shape, layoutShape, masterShape, masterStyle, theme);
  final textRuns = _textRunsPayload(shape, textStyle, theme);
  if (text.isEmpty && fill.color == null && fill.gradient == null && line.color == null) {
    return null;
  }

  final xfrm = spPr == null ? null : _firstDescendant(spPr, 'xfrm');
  final rawRotation = double.tryParse(xfrm?.getAttribute('rot') ?? '');
  final preset = spPr == null ? null : _firstDescendant(spPr, 'prstGeom')?.getAttribute('prst');

  return <String, Object?>{
    'type': placeholderType == null ? 'text' : 'placeholder',
    'objectId': _objectIdForElement(shape),
    'text': text,
    ...bounds,
    'fillColor': fill.color,
    'fillGradient': fill.gradient,
    'strokeColor': line.color,
    'strokeWidthPoints': line.widthPoints,
    'textColor': textStyle.color,
    'fontSizePoints': textStyle.fontSizePoints,
    'fontFamily': textStyle.fontFamily,
    'bold': textStyle.bold,
    'italic': textStyle.italic,
    'underline': textStyle.underline,
    'alignment': textStyle.alignment,
    'rotationDegrees': rawRotation == null ? 0.0 : rawRotation / 60000,
    'shapeKind': preset,
    'textRuns': textRuns,
  };
}

Map<String, Object?>? _picturePayload(
  xml.XmlElement picture,
  Map<String, ArchiveFile> files,
  Map<String, _Relationship> relationships,
  double slideWidth,
  double slideHeight,
) {
  final blip = _firstDescendant(picture, 'blip');
  if (blip == null) return null;
  String? relId;
  for (final attribute in blip.attributes) {
    if (attribute.name.local == 'embed') {
      relId = attribute.value;
      break;
    }
  }
  final imagePath = relId == null ? null : relationships[relId]?.target;
  final imageEntry = imagePath == null ? null : files[imagePath];
  if (imageEntry == null) return null;
  final spPr = _directChild(picture, 'spPr');
  final xfrm = spPr == null ? null : _firstDescendant(spPr, 'xfrm');
  final rawRotation = double.tryParse(xfrm?.getAttribute('rot') ?? '');
  return <String, Object?>{
    'type': 'image',
    'objectId': _objectIdForElement(picture),
    'imageBytes': _entryBytes(imageEntry),
    ..._boundsPayload(picture, slideWidth, slideHeight),
    'rotationDegrees': rawRotation == null ? 0.0 : rawRotation / 60000,
  };
}

Map<String, Object?>? _graphicFramePayload(
  xml.XmlElement frame,
  double slideWidth,
  double slideHeight,
  _ThemeData theme,
) {
  final text = _extractParagraphText(frame).join('\n').trim();
  if (text.isEmpty) return null;
  return <String, Object?>{
    'type': 'placeholder',
    'objectId': _objectIdForElement(frame),
    'text': text,
    ..._boundsPayload(frame, slideWidth, slideHeight),
    'textColor': theme.schemeColors['tx1'],
    'fontFamily': theme.minorFont,
  };
}

Map<String, Object?> _resolvedBoundsPayload(
  xml.XmlElement shape,
  xml.XmlElement? layoutShape,
  xml.XmlElement? masterShape,
  double slideWidth,
  double slideHeight,
) {
  for (final candidate in [shape, layoutShape, masterShape]) {
    if (candidate == null) continue;
    final bounds = _boundsPayload(candidate, slideWidth, slideHeight);
    if (bounds['hasBounds'] == true) return bounds;
  }
  return const <String, Object?>{'hasBounds': false};
}

Map<String, Object?> _boundsPayload(
  xml.XmlElement element,
  double slideWidth,
  double slideHeight,
) {
  final xfrm = _firstDescendant(element, 'xfrm');
  if (xfrm == null) return const <String, Object?>{'hasBounds': false};
  final off = _directChild(xfrm, 'off') ?? _firstDescendant(xfrm, 'off');
  final ext = _directChild(xfrm, 'ext') ?? _firstDescendant(xfrm, 'ext');
  final x = double.tryParse(off?.getAttribute('x') ?? '');
  final y = double.tryParse(off?.getAttribute('y') ?? '');
  final width = double.tryParse(ext?.getAttribute('cx') ?? '');
  final height = double.tryParse(ext?.getAttribute('cy') ?? '');
  if (x == null || y == null || width == null || height == null || slideWidth <= 0 || slideHeight <= 0) {
    return const <String, Object?>{'hasBounds': false};
  }
  return <String, Object?>{
    'left': (x / slideWidth).clamp(0.0, 1.2).toDouble(),
    'top': (y / slideHeight).clamp(0.0, 1.2).toDouble(),
    'width': (width / slideWidth).clamp(0.0, 1.4).toDouble(),
    'height': (height / slideHeight).clamp(0.0, 1.4).toDouble(),
    'hasBounds': true,
  };
}

class _ResolvedFill {
  final int? color;
  final Map<String, Object?>? gradient;
  const _ResolvedFill({this.color, this.gradient});
}

_ResolvedFill _resolvedFill(List<xml.XmlElement?> nodes, _ThemeData theme) {
  for (final node in nodes) {
    if (node == null) continue;
    if (_directChild(node, 'noFill') != null) return const _ResolvedFill();
    final solid = _directChild(node, 'solidFill');
    if (solid != null) {
      final color = _colorFromNode(solid, theme);
      if (color != null) return _ResolvedFill(color: color);
    }
    final grad = _directChild(node, 'gradFill');
    if (grad != null) {
      final payload = _gradientPayload(grad, theme);
      if (payload != null) return _ResolvedFill(gradient: payload);
    }
  }
  return const _ResolvedFill();
}

class _ResolvedLine {
  final int? color;
  final double? widthPoints;
  const _ResolvedLine({this.color, this.widthPoints});
}

_ResolvedLine _resolvedLine(List<xml.XmlElement?> nodes, _ThemeData theme) {
  for (final node in nodes) {
    if (node == null) continue;
    final ln = _directChild(node, 'ln');
    if (ln == null) continue;
    if (_directChild(ln, 'noFill') != null) return const _ResolvedLine();
    final color = _colorFromNode(ln, theme);
    final rawWidth = double.tryParse(ln.getAttribute('w') ?? '');
    return _ResolvedLine(
      color: color,
      widthPoints: rawWidth == null ? null : rawWidth / 12700,
    );
  }
  return const _ResolvedLine();
}

class _ResolvedTextStyle {
  final int? color;
  final double? fontSizePoints;
  final String? fontFamily;
  final bool bold;
  final bool italic;
  final bool underline;
  final String? alignment;

  const _ResolvedTextStyle({
    this.color,
    this.fontSizePoints,
    this.fontFamily,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.alignment,
  });
}

_ResolvedTextStyle _resolvedTextStyle(
  xml.XmlElement shape,
  xml.XmlElement? layoutShape,
  xml.XmlElement? masterShape,
  _MasterTextStyle? masterStyle,
  _ThemeData theme,
) {
  xml.XmlElement? rPr;
  xml.XmlElement? pPr;
  for (final candidate in [shape, layoutShape, masterShape]) {
    if (candidate == null) continue;
    rPr ??= _firstDescendant(candidate, 'rPr') ?? _firstDescendant(candidate, 'defRPr');
    pPr ??= _firstDescendant(candidate, 'pPr');
  }
  final rawSize = double.tryParse(rPr?.getAttribute('sz') ?? '');
  final latin = rPr == null ? null : _firstDescendant(rPr, 'latin');
  final typeface = latin?.getAttribute('typeface') ?? masterStyle?.fontFamilyToken;
  return _ResolvedTextStyle(
    color: (rPr == null ? null : _colorFromNode(rPr, theme)) ?? masterStyle?.color ?? theme.schemeColors['tx1'],
    fontSizePoints: rawSize == null ? masterStyle?.fontSizePoints : rawSize / 100,
    fontFamily: theme.resolveTypeface(typeface),
    bold: rPr?.getAttribute('b') == null ? (masterStyle?.bold ?? false) : _boolAttr(rPr?.getAttribute('b')),
    italic: _boolAttr(rPr?.getAttribute('i')),
    underline: (rPr?.getAttribute('u') ?? 'none') != 'none',
    alignment: pPr?.getAttribute('algn') ?? masterStyle?.alignment,
  );
}

List<Map<String, Object?>> _textRunsPayload(
  xml.XmlElement shape,
  _ResolvedTextStyle fallback,
  _ThemeData theme,
) {
  final result = <Map<String, Object?>>[];
  final paragraphs = shape.descendants.whereType<xml.XmlElement>().where((e) => e.name.local == 'p').toList();
  for (var pIndex = 0; pIndex < paragraphs.length; pIndex++) {
    final paragraph = paragraphs[pIndex];
    for (final child in paragraph.childElements) {
      if (child.name.local != 'r' && child.name.local != 'fld') continue;
      final textNode = _firstDescendant(child, 't');
      final text = textNode?.innerText ?? '';
      if (text.isEmpty) continue;
      final rPr = _directChild(child, 'rPr');
      final rawSize = double.tryParse(rPr?.getAttribute('sz') ?? '');
      final latin = rPr == null ? null : _firstDescendant(rPr, 'latin');
      result.add(<String, Object?>{
        'text': text,
        'color': (rPr == null ? null : _colorFromNode(rPr, theme)) ?? fallback.color,
        'fontSizePoints': rawSize == null ? fallback.fontSizePoints : rawSize / 100,
        'fontFamily': theme.resolveTypeface(latin?.getAttribute('typeface')) ?? fallback.fontFamily,
        'bold': rPr?.getAttribute('b') == null ? fallback.bold : _boolAttr(rPr?.getAttribute('b')),
        'italic': rPr?.getAttribute('i') == null ? fallback.italic : _boolAttr(rPr?.getAttribute('i')),
        'underline': rPr?.getAttribute('u') == null ? fallback.underline : rPr?.getAttribute('u') != 'none',
      });
    }
    if (pIndex < paragraphs.length - 1 && result.isNotEmpty) {
      final previous = result.last;
      result[result.length - 1] = <String, Object?>{...previous, 'text': '${previous['text']}\n'};
    }
  }
  return result;
}

class _BackgroundPayload {
  final int? color;
  final Map<String, Object?>? gradient;
  const _BackgroundPayload({this.color, this.gradient});
}

_BackgroundPayload _resolvedBackground(
  xml.XmlDocument slide,
  xml.XmlDocument? layout,
  xml.XmlDocument? master,
  _ThemeData theme,
) {
  for (final document in [slide, layout, master]) {
    if (document == null) continue;
    final bg = _firstElementNamed(document.descendants, 'bg');
    if (bg == null) continue;
    final solid = _firstDescendant(bg, 'solidFill');
    if (solid != null) {
      final color = _colorFromNode(solid, theme);
      if (color != null) return _BackgroundPayload(color: color);
    }
    final grad = _firstDescendant(bg, 'gradFill');
    if (grad != null) {
      final gradient = _gradientPayload(grad, theme);
      if (gradient != null) return _BackgroundPayload(gradient: gradient);
    }
    final bgRef = _firstDescendant(bg, 'bgRef');
    if (bgRef != null) {
      final color = _colorFromNode(bgRef, theme);
      if (color != null) return _BackgroundPayload(color: color);
    }
  }
  return _BackgroundPayload(color: theme.schemeColors['bg1'] ?? 0xFFFFFFFF);
}

Map<String, Object?>? _gradientPayload(xml.XmlElement gradFill, _ThemeData theme) {
  final stops = <Map<String, Object?>>[];
  for (final gs in gradFill.descendants.whereType<xml.XmlElement>().where((e) => e.name.local == 'gs')) {
    final color = _colorFromNode(gs, theme);
    if (color == null) continue;
    final pos = double.tryParse(gs.getAttribute('pos') ?? '') ?? 0;
    stops.add(<String, Object?>{
      'position': (pos / 100000).clamp(0.0, 1.0),
      'color': color,
    });
  }
  if (stops.isEmpty) return null;
  final lin = _firstDescendant(gradFill, 'lin');
  final angle = double.tryParse(lin?.getAttribute('ang') ?? '') ?? 0;
  return <String, Object?>{'stops': stops, 'angleDegrees': angle / 60000};
}

List<String> _extractParagraphText(xml.XmlElement container) {
  final paragraphs = container.descendants.whereType<xml.XmlElement>().where((element) => element.name.local == 'p').toList();
  if (paragraphs.isEmpty) {
    final text = container.descendants.whereType<xml.XmlElement>().where((element) => element.name.local == 't').map((element) => element.innerText).join();
    return text.trim().isEmpty ? const [] : <String>[text.trim()];
  }
  return paragraphs
      .map((paragraph) => paragraph.descendants.whereType<xml.XmlElement>().where((element) => element.name.local == 't').map((element) => element.innerText).join())
      .map((text) => text.trim())
      .where((text) => text.isNotEmpty)
      .toList();
}

String? _objectIdForElement(xml.XmlElement element) {
  final cNvPr = _firstDescendant(element, 'cNvPr');
  final id = cNvPr?.getAttribute('id');
  if (id == null || id.isEmpty || id == '0') return null;
  return id;
}

class _AnimationBehaviorCandidate {
  final xml.XmlElement behavior;
  final xml.XmlElement? timingNode;
  final String targetObjectId;
  final String timingKey;
  final bool targetsTextRange;
  final bool interactiveSequence;
  final bool subTimeNode;

  const _AnimationBehaviorCandidate({
    required this.behavior,
    required this.timingNode,
    required this.targetObjectId,
    required this.timingKey,
    required this.targetsTextRange,
    required this.interactiveSequence,
    required this.subTimeNode,
  });
}

List<Map<String, Object?>> _animationPayloads(xml.XmlDocument slideXml) {
  const behaviorNames = {
    'animEffect',
    'set',
    'animScale',
    'animMotion',
    'anim',
    'animClr',
    'animRot',
  };
  final candidates = <_AnimationBehaviorCandidate>[];
  var fallbackKey = 0;

  for (final behavior in slideXml.descendants.whereType<xml.XmlElement>()) {
    if (!behaviorNames.contains(behavior.name.local)) continue;
    final target = _firstDescendant(behavior, 'spTgt')?.getAttribute('spid');
    if (target == null || target.isEmpty) continue;
    final timingNode = _nearestTimingNode(behavior);
    final timingId = timingNode?.getAttribute('id');
    candidates.add(
      _AnimationBehaviorCandidate(
        behavior: behavior,
        timingNode: timingNode,
        targetObjectId: target,
        timingKey: timingId == null || timingId.isEmpty
            ? 'fallback:${fallbackKey++}'
            : 'ctn:$timingId',
        targetsTextRange: _firstDescendant(behavior, 'txEl') != null,
        interactiveSequence: _hasTimingAncestorType(
          behavior,
          'interactiveSeq',
        ),
        subTimeNode: _hasAncestorElement(behavior, 'subTnLst'),
      ),
    );
  }

  final result = <Map<String, Object?>>[];
  final emittedTimingKeys = <String>{};
  for (final candidate in candidates) {
    final behavior = candidate.behavior;
    // PowerPoint frequently pairs a visibility <set> with the actual visual
    // behavior in the same timing node. The visual behavior already models
    // that state change, so emitting both would create a duplicate effect.
    if (behavior.name.local == 'set' &&
        candidates.any(
          (other) =>
              other.timingKey == candidate.timingKey &&
              other.targetObjectId == candidate.targetObjectId &&
              other.behavior.name.local != 'set',
        )) {
      continue;
    }

    final timingNode = candidate.timingNode;
    final nodeType = timingNode?.getAttribute('nodeType');
    final presetClass = timingNode?.getAttribute('presetClass');
    final baseTrigger = switch (nodeType) {
      'withEffect' => 'withPrevious',
      'afterEffect' => 'afterPrevious',
      _ => 'onClick',
    };
    final trigger = emittedTimingKeys.add(candidate.timingKey)
        ? baseTrigger
        : 'withPrevious';
    final durationMs = _behaviorDurationMs(behavior);
    final delayMs = _timingDelayMs(timingNode);
    final effect = _animationEffectPayload(behavior, presetClass);

    result.add(<String, Object?>{
      'targetObjectId': candidate.targetObjectId,
      'kind': effect.kind,
      'trigger': trigger,
      'durationMs': durationMs,
      'delayMs': delayMs,
      'direction': effect.direction,
      'magnitude': effect.magnitude,
      'supported': effect.supported &&
          !candidate.targetsTextRange &&
          !candidate.interactiveSequence &&
          !candidate.subTimeNode,
      'sourceEffect': candidate.targetsTextRange
          ? '${effect.sourceEffect ?? effect.kind}:text-range'
          : candidate.interactiveSequence
          ? '${effect.sourceEffect ?? effect.kind}:interactive'
          : candidate.subTimeNode
          ? '${effect.sourceEffect ?? effect.kind}:sub-timing'
          : effect.sourceEffect,
    });
  }
  return result;
}

class _AnimationEffectPayload {
  final String kind;
  final String? direction;
  final double magnitude;
  final bool supported;
  final String? sourceEffect;

  const _AnimationEffectPayload({
    required this.kind,
    this.direction,
    this.magnitude = 1.2,
    this.supported = true,
    this.sourceEffect,
  });
}

_AnimationEffectPayload _animationEffectPayload(
  xml.XmlElement behavior,
  String? presetClass,
) {
  final name = behavior.name.local;
  if (name == 'set') {
    final valueNode = _firstDescendant(behavior, 'strVal') ??
        _firstDescendant(behavior, 'boolVal');
    final value = valueNode?.getAttribute('val')?.toLowerCase();
    if (value == 'hidden' || value == 'false' || value == '0') {
      return const _AnimationEffectPayload(
        kind: 'disappear',
        sourceEffect: 'set:hidden',
      );
    }
    return const _AnimationEffectPayload(
      kind: 'appear',
      sourceEffect: 'set:visible',
    );
  }

  if (name == 'animScale') {
    final by = _firstDescendant(behavior, 'by');
    final x = double.tryParse(by?.getAttribute('x') ?? '');
    final y = double.tryParse(by?.getAttribute('y') ?? '');
    final scale = [x, y]
        .whereType<double>()
        .map((value) => value.abs() / 100000)
        .fold<double>(1.2, (best, value) => value > best ? value : best)
        .clamp(0.2, 4.0)
        .toDouble();
    if (presetClass == 'entr') {
      return _AnimationEffectPayload(
        kind: 'zoomIn',
        magnitude: scale,
        sourceEffect: 'animScale',
      );
    }
    if (presetClass == 'exit') {
      return _AnimationEffectPayload(
        kind: 'zoomOut',
        magnitude: scale,
        sourceEffect: 'animScale',
      );
    }
    return _AnimationEffectPayload(
      kind: 'growShrink',
      magnitude: scale,
      sourceEffect: 'animScale',
    );
  }

  if (name == 'animMotion') {
    final path = behavior.getAttribute('path') ??
        _firstDescendant(behavior, 'animMotion')?.getAttribute('path');
    final direction = _motionDirectionFromPath(path);
    if (presetClass == 'entr') {
      return _AnimationEffectPayload(
        kind: 'flyIn',
        direction: direction,
        sourceEffect: 'animMotion',
      );
    }
    if (presetClass == 'exit') {
      return _AnimationEffectPayload(
        kind: 'flyOut',
        direction: direction,
        sourceEffect: 'animMotion',
      );
    }
    return _AnimationEffectPayload(
      kind: 'pulse',
      direction: direction,
      supported: false,
      sourceEffect: 'animMotion',
    );
  }

  if (name != 'animEffect') {
    return _AnimationEffectPayload(
      kind: 'unsupported',
      supported: false,
      sourceEffect: name,
    );
  }

  final filter = (behavior.getAttribute('filter') ?? '').toLowerCase();
  final transition = (behavior.getAttribute('transition') ?? '').toLowerCase();
  final isExit = transition == 'out' || presetClass == 'exit';
  final source = filter.isEmpty ? 'animEffect' : filter;
  final direction = _effectDirection(behavior, filter);

  if (filter.contains('fade')) {
    return _AnimationEffectPayload(
      kind: isExit ? 'fadeOut' : 'fadeIn',
      direction: direction,
      sourceEffect: source,
    );
  }
  if (filter.contains('wipe') ||
      filter.contains('blinds') ||
      filter.contains('strips') ||
      filter.contains('barn')) {
    return _AnimationEffectPayload(
      kind: isExit ? 'wipeOut' : 'wipeIn',
      direction: direction,
      sourceEffect: source,
    );
  }
  if (filter.contains('fly') ||
      filter.contains('slide') ||
      filter.contains('float')) {
    return _AnimationEffectPayload(
      kind: isExit ? 'flyOut' : 'flyIn',
      direction: direction,
      sourceEffect: source,
    );
  }
  if (filter.contains('zoom') || filter.contains('grow')) {
    return _AnimationEffectPayload(
      kind: isExit ? 'zoomOut' : 'zoomIn',
      direction: direction,
      sourceEffect: source,
    );
  }
  if (presetClass == 'emph') {
    return _AnimationEffectPayload(
      kind: 'pulse',
      direction: direction,
      sourceEffect: source,
    );
  }
  if (presetClass == 'entr' || transition == 'in') {
    return _AnimationEffectPayload(
      kind: 'appear',
      direction: direction,
      supported: filter.isEmpty,
      sourceEffect: source,
    );
  }
  if (isExit) {
    return _AnimationEffectPayload(
      kind: 'disappear',
      direction: direction,
      supported: filter.isEmpty,
      sourceEffect: source,
    );
  }
  return _AnimationEffectPayload(
    kind: 'unsupported',
    direction: direction,
    supported: false,
    sourceEffect: source,
  );
}

bool _hasAncestorElement(xml.XmlElement behavior, String localName) {
  return behavior.ancestors
      .whereType<xml.XmlElement>()
      .any((element) => element.name.local == localName);
}

bool _hasTimingAncestorType(xml.XmlElement behavior, String nodeType) {
  for (final ancestor in behavior.ancestors.whereType<xml.XmlElement>()) {
    if (ancestor.name.local == 'cTn' &&
        ancestor.getAttribute('nodeType') == nodeType) {
      return true;
    }
  }
  return false;
}

xml.XmlElement? _nearestTimingNode(xml.XmlElement behavior) {
  for (final ancestor in behavior.ancestors.whereType<xml.XmlElement>()) {
    if (ancestor.name.local != 'cTn') continue;
    final type = ancestor.getAttribute('nodeType');
    if (type == 'clickEffect' || type == 'withEffect' || type == 'afterEffect') {
      return ancestor;
    }
  }
  for (final ancestor in behavior.ancestors.whereType<xml.XmlElement>()) {
    if (ancestor.name.local == 'cTn') return ancestor;
  }
  return null;
}

int _behaviorDurationMs(xml.XmlElement behavior) {
  final cTn = _firstDescendant(behavior, 'cTn');
  final raw = cTn?.getAttribute('dur');
  return _officeTimeMs(raw, fallback: behavior.name.local == 'set' ? 1 : 400);
}

int _timingDelayMs(xml.XmlElement? timingNode) {
  if (timingNode == null) return 0;
  final conditions = _directChild(timingNode, 'stCondLst');
  if (conditions == null) return 0;
  for (final condition in conditions.childElements) {
    if (condition.name.local != 'cond') continue;
    final raw = condition.getAttribute('delay');
    if (raw == null || raw == 'indefinite') continue;
    return _officeTimeMs(raw, fallback: 0);
  }
  return 0;
}

int _officeTimeMs(String? raw, {required int fallback}) {
  if (raw == null || raw.isEmpty || raw == 'indefinite') return fallback;
  final direct = int.tryParse(raw);
  if (direct != null) return direct.clamp(0, 600000).toInt();
  final parts = raw.split(':');
  if (parts.length == 3) {
    final hours = double.tryParse(parts[0]) ?? 0;
    final minutes = double.tryParse(parts[1]) ?? 0;
    final seconds = double.tryParse(parts[2]) ?? 0;
    return (((hours * 60 + minutes) * 60 + seconds) * 1000)
        .round()
        .clamp(0, 600000)
        .toInt();
  }
  return fallback;
}

String? _effectDirection(xml.XmlElement behavior, String filter) {
  final direct = behavior.getAttribute('dir');
  if (direct != null && direct.isNotEmpty) return direct;
  final normalized = filter.replaceAll(RegExp(r'[^a-z]'), '');
  if (normalized.contains('fromleft') || normalized.contains('left')) return 'l';
  if (normalized.contains('fromright') || normalized.contains('right')) return 'r';
  if (normalized.contains('fromtop') || normalized.contains('up')) return 'u';
  if (normalized.contains('frombottom') || normalized.contains('down')) return 'd';
  return null;
}

String? _motionDirectionFromPath(String? path) {
  if (path == null || path.isEmpty) return null;
  final numbers = RegExp(r'-?\d+(?:\.\d+)?')
      .allMatches(path)
      .map((match) => double.tryParse(match.group(0) ?? ''))
      .whereType<double>()
      .toList(growable: false);
  if (numbers.length < 4) return null;
  final dx = numbers[numbers.length - 2] - numbers[0];
  final dy = numbers[numbers.length - 1] - numbers[1];
  if (dx.abs() >= dy.abs()) return dx < 0 ? 'l' : 'r';
  return dy < 0 ? 'u' : 'd';
}

Map<String, Object?> _transitionPayload(xml.XmlDocument document) {
  final transition = _firstElementNamed(document.descendants, 'transition');
  if (transition == null) return const <String, Object?>{'kind': 'none', 'durationMs': 280};
  final effect = transition.childElements.isEmpty ? null : transition.childElements.first;
  final effectName = effect?.name.local ?? 'none';
  final kind = switch (effectName) {
    'fade' => 'fade',
    'push' => 'push',
    'wipe' => 'wipe',
    'split' => 'split',
    'cover' => 'cover',
    'uncover' => 'uncover',
    'zoom' => 'zoom',
    _ => 'fade',
  };
  final speed = transition.getAttribute('spd');
  final duration = switch (speed) {'slow' => 700, 'med' => 420, _ => 280};
  return <String, Object?>{
    'kind': kind,
    'direction': effect?.getAttribute('dir'),
    'durationMs': duration,
  };
}

class _ThemeData {
  final Map<String, int> schemeColors;
  final String? majorFont;
  final String? minorFont;

  const _ThemeData(this.schemeColors, this.majorFont, this.minorFont);
  const _ThemeData.empty() : schemeColors = const {}, majorFont = null, minorFont = null;

  factory _ThemeData.fromXml(xml.XmlDocument? document) {
    if (document == null) return const _ThemeData.empty();
    final colors = <String, int>{};
    final clrScheme = _firstDescendant(document, 'clrScheme');
    if (clrScheme != null) {
      for (final child in clrScheme.childElements) {
        final color = _colorFromRawColorContainer(child);
        if (color != null) colors[child.name.local] = color;
      }
    }
    // Common aliases used in slide XML.
    if (colors['lt1'] != null) colors['bg1'] = colors['lt1']!;
    if (colors['dk1'] != null) colors['tx1'] = colors['dk1']!;
    if (colors['lt2'] != null) colors['bg2'] = colors['lt2']!;
    if (colors['dk2'] != null) colors['tx2'] = colors['dk2']!;

    final fontScheme = _firstDescendant(document, 'fontScheme');
    final major = fontScheme == null ? null : _directChild(fontScheme, 'majorFont');
    final minor = fontScheme == null ? null : _directChild(fontScheme, 'minorFont');
    return _ThemeData(
      colors,
      major == null ? null : _directChild(major, 'latin')?.getAttribute('typeface'),
      minor == null ? null : _directChild(minor, 'latin')?.getAttribute('typeface'),
    );
  }

  String? resolveTypeface(String? raw) {
    if (raw == null || raw.isEmpty) return minorFont;
    if (raw == '+mj-lt') return majorFont;
    if (raw == '+mn-lt') return minorFont;
    return raw;
  }
}

int? _colorFromRawColorContainer(xml.XmlElement container) {
  final srgb = _firstDescendant(container, 'srgbClr');
  final srgbValue = srgb?.getAttribute('val');
  if (srgbValue != null && srgbValue.length == 6) return int.tryParse('FF$srgbValue', radix: 16);
  final sys = _firstDescendant(container, 'sysClr');
  final last = sys?.getAttribute('lastClr');
  if (last != null && last.length == 6) return int.tryParse('FF$last', radix: 16);
  return null;
}

int? _colorFromNode(xml.XmlElement container, _ThemeData theme) {
  xml.XmlElement? colorNode;
  if (const {'srgbClr', 'schemeClr', 'sysClr', 'prstClr'}.contains(container.name.local)) {
    colorNode = container;
  } else {
    for (final candidate in container.descendants.whereType<xml.XmlElement>()) {
      if (const {'srgbClr', 'schemeClr', 'sysClr', 'prstClr'}
          .contains(candidate.name.local)) {
        colorNode = candidate;
        break;
      }
    }
    if (colorNode == null) return null;
  }
  int? color;
  if (colorNode.name.local == 'srgbClr') {
    final value = colorNode.getAttribute('val');
    if (value != null && value.length == 6) color = int.tryParse('FF$value', radix: 16);
  } else if (colorNode.name.local == 'schemeClr') {
    color = theme.schemeColors[colorNode.getAttribute('val')];
  } else if (colorNode.name.local == 'sysClr') {
    final value = colorNode.getAttribute('lastClr');
    if (value != null && value.length == 6) color = int.tryParse('FF$value', radix: 16);
  }
  if (color == null) return null;
  return _applyColorTransforms(color, colorNode);
}

int _applyColorTransforms(int argb, xml.XmlElement colorNode) {
  var a = (argb >> 24) & 0xFF;
  var r = (argb >> 16) & 0xFF;
  var g = (argb >> 8) & 0xFF;
  var b = argb & 0xFF;
  for (final child in colorNode.childElements) {
    final raw = double.tryParse(child.getAttribute('val') ?? '');
    if (raw == null) continue;
    final factor = (raw / 100000).clamp(0.0, 1.0);
    switch (child.name.local) {
      case 'alpha':
        a = (255 * factor).round();
        break;
      case 'tint':
        r = (r + (255 - r) * factor).round();
        g = (g + (255 - g) * factor).round();
        b = (b + (255 - b) * factor).round();
        break;
      case 'shade':
        r = (r * factor).round();
        g = (g * factor).round();
        b = (b * factor).round();
        break;
      case 'lumMod':
        r = (r * factor).round().clamp(0, 255).toInt();
        g = (g * factor).round().clamp(0, 255).toInt();
        b = (b * factor).round().clamp(0, 255).toInt();
        break;
      default:
        break;
    }
  }
  return (a << 24) | (r << 16) | (g << 8) | b;
}

T? _firstNonNull<T>(Iterable<T?> values) {
  for (final value in values) {
    if (value != null) return value;
  }
  return null;
}

bool _boolAttr(String? value) => value == '1' || value == 'true';

xml.XmlElement? _directChild(xml.XmlElement element, String localName) {
  for (final child in element.childElements) {
    if (child.name.local == localName) return child;
  }
  return null;
}

xml.XmlElement? _firstElementNamed(Iterable<xml.XmlNode> nodes, String localName) {
  for (final node in nodes) {
    if (node is xml.XmlElement && node.name.local == localName) return node;
  }
  return null;
}

xml.XmlElement? _firstDescendant(Object node, String localName) {
  final descendants = switch (node) {
    xml.XmlDocument document => document.descendants,
    xml.XmlElement element => element.descendants,
    _ => <xml.XmlNode>[],
  };
  for (final child in descendants.whereType<xml.XmlElement>()) {
    if (child.name.local == localName) return child;
  }
  return null;
}

String _resolvePath(String sourcePath, String target) {
  final normalizedTarget = target.replaceAll('\\', '/');
  if (normalizedTarget.startsWith('/')) return p.posix.normalize(normalizedTarget.substring(1));
  return p.posix.normalize(p.posix.join(p.posix.dirname(sourcePath), normalizedTarget));
}

int _slideNumber(String name) {
  final match = RegExp(r'slide(\d+)\.xml$').firstMatch(name);
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

Uint8List _entryBytes(ArchiveFile entry) => entry.content;
