import 'dart:convert';

import '../domain/models/planner_json.dart';
import '../domain/models/planner_priority.dart';
import '../domain/models/syllabus_import_package.dart';

class SyllabusImportException implements Exception {
  final String message;

  const SyllabusImportException(this.message);

  @override
  String toString() => 'SyllabusImportException: $message';
}

class SyllabusImportCodec {
  const SyllabusImportCodec();

  static const String format = 'edusheet.syllabus';
  static const int currentVersion = 1;

  SyllabusImportPackage decodeString(String source) {
    try {
      return decode(jsonDecode(source));
    } on SyllabusImportException {
      rethrow;
    } on FormatException catch (error) {
      throw SyllabusImportException(
        'The syllabus file is not valid JSON: $error',
      );
    } catch (error) {
      throw SyllabusImportException(
        'The syllabus file could not be read: $error',
      );
    }
  }

  SyllabusImportPackage decode(Object? value) {
    if (value is! Map) {
      throw const SyllabusImportException(
        'A syllabus import must be a JSON object.',
      );
    }
    final json = Map<String, dynamic>.from(value);
    final detectedFormat = json['format']?.toString();
    if (detectedFormat != format) {
      throw const SyllabusImportException(
        'Unsupported syllabus file. Expected an EduSheet syllabus export with format "edusheet.syllabus".',
      );
    }
    final version = plannerInt(json, 'version', fallback: 0);
    if (version != currentVersion) {
      throw SyllabusImportException(
        'Unsupported syllabus format version $version. This EduSheet build supports version $currentVersion.',
      );
    }

    final classObject = json['class'];
    if (classObject is! Map) {
      throw const SyllabusImportException(
        'The syllabus file is missing its class object.',
      );
    }
    final classJson = Map<String, dynamic>.from(classObject);
    final subjects = _listOfMaps(
      json['subjects'],
      'subjects',
    ).map(_subject).toList(growable: false);

    return SyllabusImportPackage(
      className: plannerRequiredString(classJson, 'name'),
      academicYear: plannerOptionalString(classJson, 'academicYear'),
      subjects: subjects,
    );
  }

  SyllabusImportSubject _subject(Map<String, dynamic> json) {
    return SyllabusImportSubject(
      name: plannerRequiredString(json, 'name'),
      code: plannerOptionalString(json, 'code'),
      units: _listOfMaps(
        json['units'],
        'units',
      ).map(_unit).toList(growable: false),
      chapters: _listOfMaps(
        json['chapters'],
        'chapters',
      ).map(_chapter).toList(growable: false),
    );
  }

  SyllabusImportUnit _unit(Map<String, dynamic> json) {
    return SyllabusImportUnit(
      title: plannerRequiredString(json, 'title'),
      plannedPeriods: _nonNegativePeriods(json, 'plannedPeriods'),
      priority: plannerPriorityFromJson(json['priority']),
      chapters: _listOfMaps(
        json['chapters'],
        'chapters',
      ).map(_chapter).toList(growable: false),
    );
  }

  SyllabusImportChapter _chapter(Map<String, dynamic> json) {
    return SyllabusImportChapter(
      title: plannerRequiredString(json, 'title'),
      plannedPeriods: _nonNegativePeriods(json, 'plannedPeriods'),
      priority: plannerPriorityFromJson(json['priority']),
      topics: _listOfMaps(
        json['topics'],
        'topics',
      ).map(_topic).toList(growable: false),
    );
  }

  SyllabusImportTopic _topic(Map<String, dynamic> json) {
    return SyllabusImportTopic(
      title: plannerRequiredString(json, 'title'),
      plannedPeriods: _nonNegativePeriods(json, 'plannedPeriods'),
      priority: plannerPriorityFromJson(json['priority']),
    );
  }

  int _nonNegativePeriods(Map<String, dynamic> json, String key) {
    final value = plannerInt(json, key);
    if (value < 0) {
      throw SyllabusImportException('$key cannot be negative.');
    }
    return value;
  }

  List<Map<String, dynamic>> _listOfMaps(Object? value, String label) {
    if (value == null) return const [];
    if (value is! List) {
      throw SyllabusImportException('$label must be a JSON array.');
    }
    final result = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is! Map) {
        throw SyllabusImportException('$label must contain only JSON objects.');
      }
      result.add(Map<String, dynamic>.from(item));
    }
    return result;
  }
}
