import '../../domain/models/paper_model.dart';

abstract class PaperRepository {
  Future<List<Paper>> getAllPapers();
  Future<void> savePaper(Paper paper);
  Future<void> deletePaper(String id);
}
