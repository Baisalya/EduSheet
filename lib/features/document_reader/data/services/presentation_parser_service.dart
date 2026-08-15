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
                textColor: (rawElement['textColor'] as num?)?.toInt(),
                fontSizePoints: (rawElement['fontSizePoints'] as num?)?.toDouble(),
                bold: rawElement['bold'] == true,
                alignment: rawElement['alignment']?.toString(),
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
            hasNativeAnimations: rawSlide['hasNativeAnimations'] == true,
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
    slideWidth = double.tryParse(slideSize?.getAttribute('cx') ?? '') ?? slideWidth;
    slideHeight = double.tryParse(slideSize?.getAttribute('cy') ?? '') ?? slideHeight;
  }

  final slidePaths = _orderedSlidePaths(files, presentationXml);
  final slides = <Object>[];
  for (var index = 0; index < slidePaths.length; index++) {
    final slidePath = slidePaths[index];
    final entry = files[slidePath];
    if (entry == null) continue;
    final parsed = xml.XmlDocument.parse(utf8.decode(_entryBytes(entry)));
    final relationships = _slideRelationships(files, slidePath);
    final elements = <Object>[];

    for (final element in parsed.descendants.whereType<xml.XmlElement>()) {
      if (element.name.local == 'sp') {
        final data = _shapePayload(element, slideWidth, slideHeight);
        if (data != null) elements.add(data);
      } else if (element.name.local == 'pic') {
        final data = _picturePayload(
          element,
          files,
          relationships,
          slideWidth,
          slideHeight,
        );
        if (data != null) elements.add(data);
      } else if (element.name.local == 'graphicFrame') {
        final data = _graphicFramePayload(element, slideWidth, slideHeight);
        if (data != null) elements.add(data);
      }
    }

    if (elements.isEmpty) {
      final readableText = _extractParagraphText(parsed.rootElement);
      for (final text in readableText) {
        elements.add(<String, Object?>{
          'type': 'text',
          'text': text,
          'hasBounds': false,
        });
      }
    }

    slides.add(<String, Object?>{
      'number': index + 1,
      'elements': elements,
      'backgroundColor': _slideBackgroundColor(parsed),
      'hasNativeAnimations':
          parsed.descendants.whereType<xml.XmlElement>().any(
            (element) => element.name.local == 'timing',
          ),
      'transition': _transitionPayload(parsed),
    });
  }

  return <String, Object?>{
    'slideWidth': slideWidth,
    'slideHeight': slideHeight,
    'slides': slides,
  };
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
    for (final slideId in presentationXml.descendants.whereType<xml.XmlElement>().where(
      (element) => element.name.local == 'sldId',
    )) {
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

Map<String, String> _slideRelationships(
  Map<String, ArchiveFile> files,
  String slidePath,
) {
  final relPath = p.posix.join(
    p.posix.dirname(slidePath),
    '_rels',
    '${p.posix.basename(slidePath)}.rels',
  );
  final relEntry = files[relPath];
  if (relEntry == null) return const {};

  final result = <String, String>{};
  final relXml = xml.XmlDocument.parse(utf8.decode(_entryBytes(relEntry)));
  for (final rel in relXml.descendants.whereType<xml.XmlElement>()) {
    if (rel.name.local != 'Relationship') continue;
    final id = rel.getAttribute('Id');
    final target = rel.getAttribute('Target');
    if (id != null && target != null) {
      result[id] = _resolvePath(slidePath, target);
    }
  }
  return result;
}

Map<String, Object?>? _shapePayload(
  xml.XmlElement shape,
  double slideWidth,
  double slideHeight,
) {
  final text = _extractParagraphText(shape).join('\n').trim();
  final bounds = _boundsPayload(shape, slideWidth, slideHeight);
  final shapeProperties = _firstDescendant(shape, 'spPr');
  final shapeFill = shapeProperties == null
      ? null
      : _colorFromContainer(shapeProperties, 'solidFill');
  if (text.isEmpty && shapeFill == null) return null;

  final styleElement = _firstDescendant(shape, 'rPr') ?? _firstDescendant(shape, 'defRPr');
  final rawSize = double.tryParse(styleElement?.getAttribute('sz') ?? '');
  final rawBold = styleElement?.getAttribute('b');
  final paragraphProperties = _firstDescendant(shape, 'pPr');

  return <String, Object?>{
    'type': 'text',
    'text': text,
    ...bounds,
    'fillColor': shapeFill,
    'textColor': _textColor(shape),
    'fontSizePoints': rawSize == null ? null : rawSize / 100,
    'bold': rawBold == '1' || rawBold == 'true',
    'alignment': paragraphProperties?.getAttribute('algn'),
  };
}

Map<String, Object?>? _picturePayload(
  xml.XmlElement picture,
  Map<String, ArchiveFile> files,
  Map<String, String> relationships,
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
  final imagePath = relationships[relId];
  final imageEntry = imagePath == null ? null : files[imagePath];
  if (imageEntry == null) return null;

  return <String, Object?>{
    'type': 'image',
    'imageBytes': _entryBytes(imageEntry),
    ..._boundsPayload(picture, slideWidth, slideHeight),
  };
}

Map<String, Object?>? _graphicFramePayload(
  xml.XmlElement frame,
  double slideWidth,
  double slideHeight,
) {
  final text = _extractParagraphText(frame).join('\n').trim();
  if (text.isEmpty) return null;
  return <String, Object?>{
    'type': 'placeholder',
    'text': text,
    ..._boundsPayload(frame, slideWidth, slideHeight),
  };
}

Map<String, Object?> _boundsPayload(
  xml.XmlElement element,
  double slideWidth,
  double slideHeight,
) {
  final xfrm = _firstDescendant(element, 'xfrm');
  if (xfrm == null) return const <String, Object?>{'hasBounds': false};
  final off = _firstDescendant(xfrm, 'off');
  final ext = _firstDescendant(xfrm, 'ext');
  final x = double.tryParse(off?.getAttribute('x') ?? '');
  final y = double.tryParse(off?.getAttribute('y') ?? '');
  final width = double.tryParse(ext?.getAttribute('cx') ?? '');
  final height = double.tryParse(ext?.getAttribute('cy') ?? '');
  if (x == null || y == null || width == null || height == null ||
      slideWidth <= 0 || slideHeight <= 0) {
    return const <String, Object?>{'hasBounds': false};
  }

  return <String, Object?>{
    'left': (x / slideWidth).clamp(0.0, 1.0).toDouble(),
    'top': (y / slideHeight).clamp(0.0, 1.0).toDouble(),
    'width': (width / slideWidth).clamp(0.0, 1.2).toDouble(),
    'height': (height / slideHeight).clamp(0.0, 1.2).toDouble(),
    'hasBounds': true,
  };
}

List<String> _extractParagraphText(xml.XmlElement container) {
  final paragraphs = container.descendants
      .whereType<xml.XmlElement>()
      .where((element) => element.name.local == 'p')
      .toList();
  if (paragraphs.isEmpty) {
    final text = container.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local == 't')
        .map((element) => element.innerText)
        .join();
    return text.trim().isEmpty ? const [] : <String>[text.trim()];
  }

  return paragraphs
      .map(
        (paragraph) => paragraph.descendants
            .whereType<xml.XmlElement>()
            .where((element) => element.name.local == 't')
            .map((element) => element.innerText)
            .join(),
      )
      .map((text) => text.trim())
      .where((text) => text.isNotEmpty)
      .toList();
}

Map<String, Object?> _transitionPayload(xml.XmlDocument document) {
  final transition = _firstElementNamed(document.descendants, 'transition');
  if (transition == null) {
    return const <String, Object?>{'kind': 'none', 'durationMs': 280};
  }

  final effect = transition.childElements.isEmpty
      ? null
      : transition.childElements.first;
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
  final duration = switch (speed) {
    'slow' => 700,
    'med' => 420,
    _ => 280,
  };

  return <String, Object?>{
    'kind': kind,
    'direction': effect?.getAttribute('dir'),
    'durationMs': duration,
  };
}

int? _slideBackgroundColor(xml.XmlDocument document) {
  final background = _firstElementNamed(document.descendants, 'bg');
  return background == null ? null : _colorFromContainer(background, 'solidFill');
}

int? _textColor(xml.XmlElement shape) {
  final rPr = _firstDescendant(shape, 'rPr') ?? _firstDescendant(shape, 'defRPr');
  return rPr == null ? null : _colorFromContainer(rPr, 'solidFill');
}

int? _colorFromContainer(xml.XmlElement container, String fillName) {
  final fill = _firstElementNamed(container.descendants, fillName);
  if (fill == null) return null;
  final srgb = _firstElementNamed(fill.descendants, 'srgbClr');
  final value = srgb?.getAttribute('val');
  if (value == null || value.length != 6) return null;
  return int.tryParse('FF$value', radix: 16);
}


xml.XmlElement? _firstElementNamed(
  Iterable<xml.XmlNode> nodes,
  String localName,
) {
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
  if (normalizedTarget.startsWith('/')) {
    return p.posix.normalize(normalizedTarget.substring(1));
  }
  return p.posix.normalize(
    p.posix.join(p.posix.dirname(sourcePath), normalizedTarget),
  );
}

int _slideNumber(String name) {
  final match = RegExp(r'slide(\d+)\.xml$').firstMatch(name);
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

Uint8List _entryBytes(ArchiveFile entry) => entry.content;
