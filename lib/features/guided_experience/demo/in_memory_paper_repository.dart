import '../../editor/data/repositories/paper_repository.dart';
import '../../editor/domain/models/paper_model.dart';

/// Ephemeral Paper repository used only by Guided Demo sessions.
///
/// Values are deep-copied through the existing model codec so demo mutations
/// cannot retain references to production editor objects. Nothing is written
/// to the application documents directory.
class InMemoryPaperRepository implements PaperRepository {
  final Map<String, Paper> _papers = <String, Paper>{};

  void reset() => _papers.clear();

  @override
  Future<List<Paper>> getAllPapers() async {
    return _papers.values.map(_copy).toList(growable: false);
  }

  @override
  Future<void> savePaper(Paper paper) async {
    _papers[paper.id] = _copy(paper);
  }

  @override
  Future<void> deletePaper(String id) async {
    _papers.remove(id);
  }

  Paper _copy(Paper paper) => Paper.fromJson(paper.toJson());
}
