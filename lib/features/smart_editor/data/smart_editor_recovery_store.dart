import 'dart:io';

import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/shared/persistence/atomic_json_file_store.dart';
import 'package:path_provider/path_provider.dart';

/// A small per-document crash-recovery journal for Smart Editor sessions.
///
/// The normal document repository remains the source of truth. This journal
/// only keeps the newest in-progress snapshot so a process crash between two
/// debounced repository saves does not discard the teacher's latest typing.
class SmartEditorRecoveryStore {
  SmartEditorRecoveryStore({Future<Directory> Function()? directoryResolver})
    : _directoryResolver = directoryResolver ?? _defaultDirectory;

  static const int schemaVersion = 1;

  final Future<Directory> Function() _directoryResolver;
  final SerializedOperationQueue _mutations = SerializedOperationQueue();

  static Future<Directory> _defaultDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}${Platform.pathSeparator}smart_editor_recovery');
  }

  Future<File> _fileFor(String documentId) async {
    final directory = await _directoryResolver();
    final safeId = documentId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return File('${directory.path}${Platform.pathSeparator}$safeId.json');
  }

  Future<void> save(SmartDocument document) async {
    await _mutations.run(() async {
      final file = await _fileFor(document.id);
      final store = AtomicJsonFileStore(file);
      await store.writeJson(<String, dynamic>{
        'schemaVersion': schemaVersion,
        'document': document.toJson(),
      });
    });
  }

  /// Returns a recovery snapshot only when it belongs to [base] and is newer
  /// than the repository copy. Invalid or obsolete recovery data is ignored.
  Future<SmartDocument?> newerSnapshotFor(SmartDocument base) async {
    final file = await _fileFor(base.id);
    final store = AtomicJsonFileStore(file);
    final decoded = await store.readJson(orElse: null);
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded);
    if (map['schemaVersion'] != schemaVersion || map['document'] is! Map) {
      return null;
    }
    final recovered = SmartDocument.fromJson(
      Map<String, dynamic>.from(map['document'] as Map),
    );
    if (recovered.id != base.id) return null;
    if (!recovered.updatedAt.isAfter(base.updatedAt)) {
      await clear(base.id);
      return null;
    }
    return recovered;
  }

  Future<void> clear(String documentId) async {
    await _mutations.run(() async {
      final file = await _fileFor(documentId);
      for (final candidate in <File>[
        file,
        File('${file.path}.bak'),
        File('${file.path}.tmp'),
        File('${file.path}.corrupt'),
      ]) {
        if (await candidate.exists()) {
          await candidate.delete();
        }
      }
    });
  }
}
