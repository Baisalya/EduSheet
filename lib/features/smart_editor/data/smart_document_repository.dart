import 'dart:io';

import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/shared/persistence/atomic_json_file_store.dart';
import 'package:path_provider/path_provider.dart';

abstract class SmartDocumentRepository {
  Future<List<SmartDocument>> getAll();
  Future<SmartDocument?> getById(String id);
  Future<void> save(SmartDocument document);
  Future<void> delete(String id);
}

class LocalSmartDocumentRepository implements SmartDocumentRepository {
  static const String _fileName = 'smart_documents.json';

  final Future<File> Function() _fileResolver;
  final SerializedOperationQueue _mutations = SerializedOperationQueue();
  List<SmartDocument>? _cache;

  LocalSmartDocumentRepository({Future<File> Function()? fileResolver})
    : _fileResolver = fileResolver ?? _defaultFile;

  static Future<File> _defaultFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<AtomicJsonFileStore> _store() async {
    return AtomicJsonFileStore(await _fileResolver());
  }

  @override
  Future<List<SmartDocument>> getAll() async {
    final documents = await _loadDocuments();
    final snapshot = List<SmartDocument>.from(documents);
    snapshot.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return snapshot;
  }

  Future<List<SmartDocument>> _loadDocuments() async {
    final cached = _cache;
    if (cached != null) return List<SmartDocument>.from(cached);
    final decoded = await (await _store()).readJson(orElse: const []);
    final documents = AtomicJsonFileStore.versionedItems(decoded)
        .whereType<Map>()
        .map(
          (item) => SmartDocument.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    _cache = List<SmartDocument>.from(documents);
    return documents;
  }

  @override
  Future<SmartDocument?> getById(String id) async {
    final documents = await _loadDocuments();
    for (final document in documents) {
      if (document.id == id) return document;
    }
    return null;
  }

  @override
  Future<void> save(SmartDocument document) async {
    await _mutations.run(() async {
      final documents = await _loadDocuments();
      final index = documents.indexWhere((item) => item.id == document.id);
      if (index == -1) {
        documents.add(document);
      } else {
        documents[index] = document;
      }
      await _saveAll(documents);
    });
  }

  @override
  Future<void> delete(String id) async {
    await _mutations.run(() async {
      final documents = await _loadDocuments();
      documents.removeWhere((item) => item.id == id);
      await _saveAll(documents);
    });
  }

  Future<void> _saveAll(List<SmartDocument> documents) async {
    await (await _store()).writeJson(
      AtomicJsonFileStore.envelope(
        documents.map((item) => item.toJson()).toList(growable: false),
        schemaVersion: 2,
      ),
    );
    _cache = List<SmartDocument>.from(documents);
  }
}
