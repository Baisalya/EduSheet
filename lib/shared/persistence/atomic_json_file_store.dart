import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum PersistenceFailureKind { read, decode, write, recovery }

class PersistenceException implements Exception {
  final PersistenceFailureKind kind;
  final String path;
  final String message;
  final Object? cause;

  const PersistenceException({
    required this.kind,
    required this.path,
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'PersistenceException($kind, $path): $message';
}

class AtomicJsonFileStore {
  final File file;

  const AtomicJsonFileStore(this.file);

  File get backupFile => File('${file.path}.bak');
  File get temporaryFile => File('${file.path}.tmp');

  Future<dynamic> readJson({required dynamic orElse}) async {
    if (!await file.exists()) {
      if (await backupFile.exists()) {
        return _decodeFile(backupFile, isRecovery: true);
      }
      return orElse;
    }

    try {
      return await _decodeFile(file);
    } on PersistenceException catch (primaryError) {
      if (!await backupFile.exists()) rethrow;
      try {
        return await _decodeFile(backupFile, isRecovery: true);
      } on PersistenceException catch (backupError) {
        throw PersistenceException(
          kind: PersistenceFailureKind.recovery,
          path: file.path,
          message: 'Primary and backup data are unreadable.',
          cause: [primaryError, backupError],
        );
      }
    }
  }

  Future<void> writeJson(Object? value) async {
    await file.parent.create(recursive: true);
    final encoded = jsonEncode(value);

    try {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      await temporaryFile.writeAsString(encoded, flush: true);
      await _decodeFile(temporaryFile);

      if (await file.exists()) {
        final primaryIsValid = await _isValidJson(file);
        if (primaryIsValid) {
          if (await backupFile.exists()) await backupFile.delete();
          await file.rename(backupFile.path);
        } else {
          final corruptFile = File('${file.path}.corrupt');
          if (await corruptFile.exists()) await corruptFile.delete();
          await file.rename(corruptFile.path);
        }
      }

      try {
        await temporaryFile.rename(file.path);
      } catch (error) {
        if (!await file.exists() && await backupFile.exists()) {
          await backupFile.copy(file.path);
        }
        throw PersistenceException(
          kind: PersistenceFailureKind.write,
          path: file.path,
          message: 'Could not replace the data file atomically.',
          cause: error,
        );
      }
    } on PersistenceException {
      rethrow;
    } on FileSystemException catch (error) {
      throw PersistenceException(
        kind: PersistenceFailureKind.write,
        path: file.path,
        message: 'The data file could not be written.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw PersistenceException(
        kind: PersistenceFailureKind.decode,
        path: temporaryFile.path,
        message: 'The staged data failed JSON verification.',
        cause: error,
      );
    }
  }

  static List<dynamic> versionedItems(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['items'] is List) {
      return decoded['items'] as List<dynamic>;
    }
    throw const FormatException(
      'Expected a legacy list or a versioned object containing items.',
    );
  }

  static Map<String, dynamic> envelope(
    List<Map<String, dynamic>> items, {
    int schemaVersion = 2,
    DateTime? updatedAt,
  }) {
    return {
      'schemaVersion': schemaVersion,
      'updatedAt': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'items': items,
    };
  }

  Future<dynamic> _decodeFile(File source, {bool isRecovery = false}) async {
    try {
      return jsonDecode(await source.readAsString());
    } on FileSystemException catch (error) {
      throw PersistenceException(
        kind: isRecovery
            ? PersistenceFailureKind.recovery
            : PersistenceFailureKind.read,
        path: source.path,
        message: 'The data file could not be read.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw PersistenceException(
        kind: isRecovery
            ? PersistenceFailureKind.recovery
            : PersistenceFailureKind.decode,
        path: source.path,
        message: 'The data file contains invalid JSON.',
        cause: error,
      );
    }
  }

  Future<bool> _isValidJson(File source) async {
    try {
      await _decodeFile(source);
      return true;
    } on PersistenceException {
      return false;
    }
  }
}

class SerializedOperationQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
