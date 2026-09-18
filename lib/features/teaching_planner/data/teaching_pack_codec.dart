import 'dart:convert';

import '../domain/models/teaching_resource.dart';

class TeachingPackResourcePayload {
  final TeachingResource resource;
  final List<int>? fileBytes;

  const TeachingPackResourcePayload({required this.resource, this.fileBytes});
}

class TeachingPackPayload {
  final String sourceLessonTitle;
  final String sourceClassName;
  final String sourceSubjectName;
  final String sourceChapterTitle;
  final List<TeachingPackResourcePayload> resources;

  const TeachingPackPayload({
    required this.sourceLessonTitle,
    required this.sourceClassName,
    required this.sourceSubjectName,
    required this.sourceChapterTitle,
    required this.resources,
  });
}

class TeachingPackCodec {
  const TeachingPackCodec();

  static const String magicHeader = 'EDUSHEET-TEACHING-PACK/1';
  static const String format = 'edusheet.teaching-pack';
  static const int version = 1;
  static const String fileExtension = 'edtp';

  String encode(TeachingPackPayload payload, {DateTime? exportedAt}) {
    final json = {
      'format': format,
      'version': version,
      'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'source': {
        'lessonTitle': payload.sourceLessonTitle,
        'className': payload.sourceClassName,
        'subjectName': payload.sourceSubjectName,
        'chapterTitle': payload.sourceChapterTitle,
      },
      'resources': payload.resources.map((item) {
        final resource = Map<String, dynamic>.from(item.resource.toJson())
          ..remove('localRelativePath');
        return {
          'resource': resource,
          if (item.fileBytes != null)
            'fileBase64': base64Encode(item.fileBytes!),
        };
      }).toList(),
    };
    return '$magicHeader\n${const JsonEncoder.withIndent('  ').convert(json)}';
  }

  TeachingPackPayload decode(String source) {
    final trimmed = source.trimLeft();
    if (!trimmed.startsWith(magicHeader)) {
      throw const FormatException(
        'This file is not an EduSheet Teaching Pack.',
      );
    }
    final body = trimmed.substring(magicHeader.length).trimLeft();
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Teaching Pack payload must be an object.');
    }
    final json = Map<String, dynamic>.from(decoded);
    if (json['format'] != format || json['version'] != version) {
      throw const FormatException(
        'Unsupported EduSheet Teaching Pack version.',
      );
    }
    final sourceJson = json['source'];
    if (sourceJson is! Map) {
      throw const FormatException('Teaching Pack source metadata is missing.');
    }
    final sourceMap = Map<String, dynamic>.from(sourceJson);
    final rawResources = json['resources'];
    if (rawResources is! List) {
      throw const FormatException('Teaching Pack resources are missing.');
    }
    final resources = <TeachingPackResourcePayload>[];
    for (final raw in rawResources) {
      if (raw is! Map) {
        throw const FormatException('Invalid Teaching Pack resource.');
      }
      final item = Map<String, dynamic>.from(raw);
      final resourceJson = item['resource'];
      if (resourceJson is! Map) {
        throw const FormatException(
          'Teaching Pack resource metadata is missing.',
        );
      }
      final resource = TeachingResource.fromJson(
        Map<String, dynamic>.from(resourceJson),
      );
      final encodedBytes = item['fileBase64'];
      resources.add(
        TeachingPackResourcePayload(
          resource: resource,
          fileBytes: encodedBytes is String ? base64Decode(encodedBytes) : null,
        ),
      );
    }
    String requiredText(String key) {
      final value = sourceMap[key]?.toString().trim() ?? '';
      if (value.isEmpty) {
        throw FormatException('Teaching Pack source $key is missing.');
      }
      return value;
    }

    return TeachingPackPayload(
      sourceLessonTitle: requiredText('lessonTitle'),
      sourceClassName: requiredText('className'),
      sourceSubjectName: requiredText('subjectName'),
      sourceChapterTitle: requiredText('chapterTitle'),
      resources: List.unmodifiable(resources),
    );
  }
}
