import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:edusheet/shared/persistence/atomic_json_file_store.dart';

import '../../domain/models/paper_model.dart';
import 'paper_repository.dart';

class LocalPaperRepository implements PaperRepository, PaperImportRepository {
  static const String _fileName = 'papers.json';
  final Future<File> Function() _fileResolver;
  final SerializedOperationQueue _mutations = SerializedOperationQueue();

  LocalPaperRepository({Future<File> Function()? fileResolver})
    : _fileResolver = fileResolver ?? _defaultFile;

  static Future<File> _defaultFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<AtomicJsonFileStore> _store() async {
    return AtomicJsonFileStore(await _fileResolver());
  }

  @override
  Future<List<Paper>> getAllPapers() async {
    final decoded = await (await _store()).readJson(orElse: const []);
    return AtomicJsonFileStore.versionedItems(decoded)
        .whereType<Map>()
        .map((item) => Paper.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<void> savePaper(Paper paper) async {
    await _mutations.run(() async {
      final papers = await getAllPapers();
      final index = papers.indexWhere((item) => item.id == paper.id);
      if (index != -1) {
        final current = papers[index];
        if (_sameEditableContent(current, paper)) {
          papers[index] = paper.copyWith(
            originId: current.originId,
            revision: current.revision,
            updatedAt: current.updatedAt,
          );
        } else {
          final nextRevision =
              (current.revision > paper.revision
                      ? current.revision
                      : paper.revision) +
                  1;
          papers[index] = paper.copyWith(
            originId: current.originId,
            revision: nextRevision,
            updatedAt: DateTime.now().toUtc(),
          );
        }
      } else {
        papers.add(paper);
      }
      await _savePapers(papers);
    });
  }

  @override
  Future<void> replacePaperFromImport(
    Paper paper, {
    required String expectedOriginId,
    required int expectedRevision,
  }) async {
    await _mutations.run(() async {
      final papers = await getAllPapers();
      final index = papers.indexWhere((item) => item.id == paper.id);
      if (index == -1) {
        throw StateError(
          'The matching Saved Paper no longer exists. Import it as a new paper instead.',
        );
      }
      final current = papers[index];
      if (current.originId != expectedOriginId ||
          current.originId != paper.originId) {
        throw StateError(
          'EduSheet blocked a cross-lineage paper replacement.',
        );
      }
      if (current.revision != expectedRevision) {
        throw StateError(
          'The matching Saved Paper changed before replacement. EduSheet kept the newer local work unchanged.',
        );
      }
      if (paper.revision <= current.revision) {
        throw StateError(
          'Only a newer revision can replace the matching local paper.',
        );
      }
      papers[index] = paper;
      await _savePapers(papers);
    });
  }

  @override
  Future<void> deletePaper(String id) async {
    await _mutations.run(() async {
      final papers = await getAllPapers();
      papers.removeWhere((paper) => paper.id == id);
      await _savePapers(papers);
    });
  }

  Future<void> _savePapers(List<Paper> papers) async {
    final items = papers.map((paper) => paper.toJson()).toList();
    await (await _store()).writeJson(AtomicJsonFileStore.envelope(items));
  }

  bool _sameEditableContent(Paper a, Paper b) {
    Map<String, dynamic> content(Paper paper) {
      final json = Map<String, dynamic>.from(paper.toJson());
      json.remove('originId');
      json.remove('revision');
      json.remove('updatedAt');
      return json;
    }

    return jsonEncode(content(a)) == jsonEncode(content(b));
  }
}
