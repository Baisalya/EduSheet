import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/paper_model.dart';
import 'paper_repository.dart';

class LocalPaperRepository implements PaperRepository {
  static const String _fileName = 'papers.json';

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  @override
  Future<List<Paper>> getAllPapers() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];
      
      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      return jsonList.map((e) => Paper.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> savePaper(Paper paper) async {
    final papers = await getAllPapers();
    final index = papers.indexWhere((p) => p.id == paper.id);
    if (index != -1) {
      papers[index] = paper;
    } else {
      papers.add(paper);
    }
    await _savePapers(papers);
  }

  @override
  Future<void> deletePaper(String id) async {
    final papers = await getAllPapers();
    papers.removeWhere((p) => p.id == id);
    await _savePapers(papers);
  }

  Future<void> _savePapers(List<Paper> papers) async {
    final file = await _getFile();
    final jsonList = papers.map((p) => p.toJson()).toList();
    await file.writeAsString(json.encode(jsonList));
  }
}
