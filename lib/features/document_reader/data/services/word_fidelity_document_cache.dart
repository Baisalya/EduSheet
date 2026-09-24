import 'dart:collection';
import 'dart:io';

import 'package:edusheet/features/word_converter/domain/models/conversion_document.dart';

typedef WordFidelityLoader = Future<ConversionDocument> Function(File file);

/// Small LRU cache for parsed Word conversion documents.
///
/// Reopening the same unchanged DOCX should not repeat the full unzip/XML/media
/// conversion pipeline. The cache is intentionally tiny because a parsed Word
/// document can retain embedded image bytes.
class WordFidelityDocumentCache {
  WordFidelityDocumentCache({this.maxEntries = 2}) : assert(maxEntries > 0);

  final int maxEntries;
  final LinkedHashMap<String, _WordFidelityCacheEntry> _entries =
      LinkedHashMap<String, _WordFidelityCacheEntry>();
  final Map<String, Future<ConversionDocument>> _pending =
      <String, Future<ConversionDocument>>{};

  int get length => _entries.length;

  Future<ConversionDocument> load(
    File file,
    WordFidelityLoader loader,
  ) async {
    final path = file.absolute.path;
    final stat = await file.stat();
    final signature = _WordFidelitySignature(
      size: stat.size,
      modifiedMicros: stat.modified.microsecondsSinceEpoch,
    );

    final cached = _entries.remove(path);
    if (cached != null && cached.signature == signature) {
      _entries[path] = cached;
      return cached.document;
    }

    final pendingKey = '$path|${signature.size}|${signature.modifiedMicros}';
    final existing = _pending[pendingKey];
    if (existing != null) return existing;

    final pending = loader(file);
    _pending[pendingKey] = pending;

    try {
      final document = await pending;
      _entries[path] = _WordFidelityCacheEntry(
        signature: signature,
        document: document,
      );
      while (_entries.length > maxEntries) {
        _entries.remove(_entries.keys.first);
      }
      return document;
    } finally {
      _pending.remove(pendingKey);
    }
  }

  void invalidate(String path) {
    _entries.remove(File(path).absolute.path);
  }

  void clear() {
    _entries.clear();
    _pending.clear();
  }
}

class _WordFidelityCacheEntry {
  const _WordFidelityCacheEntry({
    required this.signature,
    required this.document,
  });

  final _WordFidelitySignature signature;
  final ConversionDocument document;
}

class _WordFidelitySignature {
  const _WordFidelitySignature({
    required this.size,
    required this.modifiedMicros,
  });

  final int size;
  final int modifiedMicros;

  @override
  bool operator ==(Object other) =>
      other is _WordFidelitySignature &&
      other.size == size &&
      other.modifiedMicros == modifiedMicros;

  @override
  int get hashCode => Object.hash(size, modifiedMicros);
}
