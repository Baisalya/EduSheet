import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:edusheet/shared/persistence/atomic_json_file_store.dart';
import '../../domain/models/paper_model.dart';
import 'paper_repository.dart';

class LocalPaperRepository implements PaperRepository {
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
        papers[index] = paper;
      } else {
        papers.add(paper);
      }
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
}
