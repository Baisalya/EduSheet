import 'dart:io';

import 'package:edusheet/shared/persistence/atomic_json_file_store.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/models/teaching_planner_workspace.dart';
import '../domain/repositories/teaching_planner_repository.dart';
import 'teaching_planner_document_codec.dart';

class TeachingPlannerRepositoryException implements Exception {
  final String message;
  final Object? cause;

  const TeachingPlannerRepositoryException(this.message, {this.cause});

  @override
  String toString() => 'TeachingPlannerRepositoryException: $message';
}

class LocalTeachingPlannerRepository implements TeachingPlannerRepository {
  static const String fileName = 'teaching_planner.json';

  final Future<File> Function() _fileResolver;
  final TeachingPlannerDocumentCodec _codec;
  final SerializedOperationQueue _operations = SerializedOperationQueue();

  LocalTeachingPlannerRepository({
    Future<File> Function()? fileResolver,
    TeachingPlannerDocumentCodec codec = const TeachingPlannerDocumentCodec(),
  }) : _fileResolver = fileResolver ?? _defaultFile,
       _codec = codec;

  static Future<File> _defaultFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }

  Future<AtomicJsonFileStore> _store() async {
    return AtomicJsonFileStore(await _fileResolver());
  }

  @override
  Future<TeachingPlannerWorkspace> load() async {
    final store = await _store();
    final decoded = await store.readJson(orElse: _codec.emptyDocument());
    try {
      return _codec.decode(decoded);
    } catch (primaryError) {
      if (!await store.backupFile.exists()) {
        throw TeachingPlannerRepositoryException(
          'Teaching Planner data is malformed or incompatible.',
          cause: primaryError,
        );
      }

      try {
        final backupStore = AtomicJsonFileStore(store.backupFile);
        final backup = await backupStore.readJson(
          orElse: _codec.emptyDocument(),
        );
        return _codec.decode(backup);
      } catch (backupError) {
        throw TeachingPlannerRepositoryException(
          'Teaching Planner primary and backup data are both unusable.',
          cause: [primaryError, backupError],
        );
      }
    }
  }

  @override
  Future<void> save(TeachingPlannerWorkspace workspace) {
    return _operations.run(() async {
      await _write(workspace);
    });
  }

  @override
  Future<TeachingPlannerWorkspace> update(TeachingPlannerMutation mutation) {
    return _operations.run(() async {
      final current = await load();
      final next = mutation(current);
      await _write(next);
      return next;
    });
  }

  Future<void> _write(TeachingPlannerWorkspace workspace) async {
    final store = await _store();
    await store.writeJson(_codec.encode(workspace));
  }
}
