import 'dart:convert';
import 'dart:io';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:path/path.dart' as p;

class PortablePaperAsset {
  final String fileName;
  final List<int> bytes;

  const PortablePaperAsset({
    required this.fileName,
    required this.bytes,
  });

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'bytes': base64Encode(bytes),
      };

  factory PortablePaperAsset.fromJson(Map<String, dynamic> json) {
    final fileName = json['fileName']?.toString().trim() ?? '';
    final encoded = json['bytes'];
    if (fileName.isEmpty || encoded is! String) {
      throw const FormatException('Portable paper asset is invalid.');
    }
    return PortablePaperAsset(
      fileName: fileName,
      bytes: List<int>.unmodifiable(base64Decode(encoded)),
    );
  }
}

/// A paper snapshot whose local file references have been replaced by stable
/// `.eds` asset tokens. The matching binary files are embedded in [assets].
class PortablePaperSnapshot {
  static const String assetTokenPrefix = 'eds-paper-asset://';

  final Paper paper;
  final Map<String, PortablePaperAsset> assets;

  PortablePaperSnapshot({
    required this.paper,
    Map<String, PortablePaperAsset> assets = const {},
  }) : assets = Map<String, PortablePaperAsset>.unmodifiable(assets) {
    _validateAssetBindings();
  }

  Map<String, dynamic> toJson() => {
        'paper': paper.toJson(),
        if (assets.isNotEmpty)
          'assets': {
            for (final entry in assets.entries) entry.key: entry.value.toJson(),
          },
      };

  factory PortablePaperSnapshot.fromJson(Map<String, dynamic> json) {
    final paperJson = json['paper'];
    if (paperJson is! Map) {
      throw const FormatException('Portable paper snapshot is missing paper data.');
    }
    final rawAssets = json['assets'];
    final assets = <String, PortablePaperAsset>{};
    if (rawAssets != null) {
      if (rawAssets is! Map) {
        throw const FormatException('Portable paper assets must be an object.');
      }
      for (final entry in rawAssets.entries) {
        if (entry.value is! Map) {
          throw const FormatException('Portable paper asset payload is invalid.');
        }
        assets[entry.key.toString()] = PortablePaperAsset.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }
    return PortablePaperSnapshot(
      paper: Paper.fromJson(Map<String, dynamic>.from(paperJson)),
      assets: assets,
    );
  }

  /// Captures every local paper file reference (logos, legacy imageUrl values,
  /// and structured question attachments) into one portable snapshot.
  static Future<PortablePaperSnapshot> capture(Paper source) async {
    final json = _deepJsonMap(source.toJson());
    final assets = <String, PortablePaperAsset>{};

    Future<String> capturePath(String rawPath, String key) async {
      final trimmed = rawPath.trim();
      if (trimmed.isEmpty) return rawPath;
      final file = File(trimmed);
      if (!await file.exists()) {
        throw FormatException(
          'Paper "${source.title}" references a file that is missing on this device.',
        );
      }
      final bytes = await file.readAsBytes();
      assets[key] = PortablePaperAsset(
        fileName: p.basename(trimmed).trim().isEmpty
            ? 'paper-asset.bin'
            : p.basename(trimmed),
        bytes: List<int>.unmodifiable(bytes),
      );
      return '$assetTokenPrefix$key';
    }

    final logos = json['logos'];
    if (logos is List) {
      for (var index = 0; index < logos.length; index++) {
        final value = logos[index]?.toString() ?? '';
        if (value.trim().isEmpty) continue;
        logos[index] = await capturePath(value, 'logo/$index');
      }
    }

    final sections = json['sections'];
    if (sections is List) {
      for (var sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
        final section = sections[sectionIndex];
        if (section is! Map) continue;
        final questions = section['questions'];
        if (questions is! List) continue;
        for (var questionIndex = 0;
            questionIndex < questions.length;
            questionIndex++) {
          final question = questions[questionIndex];
          if (question is Map) {
            await _captureQuestionAssets(
              question,
              'section/$sectionIndex/question/$questionIndex',
              capturePath,
            );
          }
        }
      }
    }

    return PortablePaperSnapshot(
      paper: Paper.fromJson(json),
      assets: assets,
    );
  }

  Future<bool> representsSamePaper(Paper candidate) async {
    if (candidate.id != paper.id) return false;
    try {
      final other = await PortablePaperSnapshot.capture(candidate);
      return equivalentTo(other);
    } catch (_) {
      return false;
    }
  }

  bool equivalentTo(PortablePaperSnapshot other) {
    if (jsonEncode(paper.toJson()) != jsonEncode(other.paper.toJson())) {
      return false;
    }
    if (assets.length != other.assets.length) return false;
    for (final entry in assets.entries) {
      final otherAsset = other.assets[entry.key];
      if (otherAsset == null || !_bytesEqual(entry.value.bytes, otherAsset.bytes)) {
        return false;
      }
    }
    return true;
  }

  /// Restores a normalized snapshot after [resolvedAssetPaths] has materialized
  /// every embedded asset on the destination device.
  Paper restoreWithPaths(
    Map<String, String> resolvedAssetPaths, {
    String? paperId,
  }) {
    final json = _deepJsonMap(paper.toJson());

    String resolve(Object? value) {
      final text = value?.toString() ?? '';
      if (!text.startsWith(assetTokenPrefix)) return text;
      final key = text.substring(assetTokenPrefix.length);
      final path = resolvedAssetPaths[key];
      if (path == null || path.trim().isEmpty) {
        throw const FormatException(
          'Portable paper is missing a materialized asset path.',
        );
      }
      return path;
    }

    final logos = json['logos'];
    if (logos is List) {
      for (var index = 0; index < logos.length; index++) {
        logos[index] = resolve(logos[index]);
      }
    }

    final sections = json['sections'];
    if (sections is List) {
      for (final section in sections.whereType<Map>()) {
        final questions = section['questions'];
        if (questions is! List) continue;
        for (final question in questions.whereType<Map>()) {
          _restoreQuestionPaths(question, resolve);
        }
      }
    }
    if (paperId != null) json['id'] = paperId;
    return Paper.fromJson(json);
  }

  void _validateAssetBindings() {
    final referenced = <String>{};
    final json = paper.toJson();

    void collect(Object? value) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty) return;
      if (!text.startsWith(assetTokenPrefix)) {
        throw const FormatException(
          'Portable paper contains a local file path that was not embedded.',
        );
      }
      referenced.add(text.substring(assetTokenPrefix.length));
    }

    final logos = json['logos'];
    if (logos is List) {
      for (final logo in logos) {
        collect(logo);
      }
    }
    final sections = json['sections'];
    if (sections is List) {
      for (final section in sections.whereType<Map>()) {
        final questions = section['questions'];
        if (questions is! List) continue;
        for (final question in questions.whereType<Map>()) {
          _collectQuestionTokens(question, collect);
        }
      }
    }

    final missing = referenced.difference(assets.keys.toSet());
    final unknown = assets.keys.toSet().difference(referenced);
    if (missing.isNotEmpty || unknown.isNotEmpty) {
      throw const FormatException(
        'Portable paper asset bindings are incomplete or inconsistent.',
      );
    }
  }

  static Future<void> _captureQuestionAssets(
    Map question,
    String prefix,
    Future<String> Function(String path, String key) capturePath,
  ) async {
    final imageUrl = question['imageUrl']?.toString() ?? '';
    if (imageUrl.trim().isNotEmpty) {
      question['imageUrl'] = await capturePath(imageUrl, '$prefix/image');
    }

    final attachments = question['attachments'];
    if (attachments is List) {
      for (var index = 0; index < attachments.length; index++) {
        final attachment = attachments[index];
        if (attachment is! Map) continue;
        final path = attachment['path']?.toString() ?? '';
        if (path.trim().isEmpty) continue;
        attachment['path'] = await capturePath(
          path,
          '$prefix/attachment/$index',
        );
      }
    }

    for (final childKey in const ['subQuestions', 'internalChoices']) {
      final children = question[childKey];
      if (children is! List) continue;
      for (var index = 0; index < children.length; index++) {
        final child = children[index];
        if (child is Map) {
          await _captureQuestionAssets(
            child,
            '$prefix/$childKey/$index',
            capturePath,
          );
        }
      }
    }
  }

  static void _restoreQuestionPaths(
    Map question,
    String Function(Object? value) resolve,
  ) {
    if (question['imageUrl'] != null) {
      question['imageUrl'] = resolve(question['imageUrl']);
    }
    final attachments = question['attachments'];
    if (attachments is List) {
      for (final attachment in attachments.whereType<Map>()) {
        if (attachment['path'] != null) {
          attachment['path'] = resolve(attachment['path']);
        }
      }
    }
    for (final childKey in const ['subQuestions', 'internalChoices']) {
      final children = question[childKey];
      if (children is! List) continue;
      for (final child in children.whereType<Map>()) {
        _restoreQuestionPaths(child, resolve);
      }
    }
  }

  static void _collectQuestionTokens(
    Map question,
    void Function(Object? value) collect,
  ) {
    collect(question['imageUrl']);
    final attachments = question['attachments'];
    if (attachments is List) {
      for (final attachment in attachments.whereType<Map>()) {
        collect(attachment['path']);
      }
    }
    for (final childKey in const ['subQuestions', 'internalChoices']) {
      final children = question[childKey];
      if (children is! List) continue;
      for (final child in children.whereType<Map>()) {
        _collectQuestionTokens(child, collect);
      }
    }
  }

  static Map<String, dynamic> _deepJsonMap(Map<String, dynamic> source) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(source)) as Map);

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
