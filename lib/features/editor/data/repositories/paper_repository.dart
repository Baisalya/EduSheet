import '../../domain/models/paper_model.dart';

abstract class PaperRepository {
  Future<List<Paper>> getAllPapers();
  Future<void> savePaper(Paper paper);
  Future<void> deletePaper(String id);
}

/// Optional import-specific capability for repositories that can atomically
/// adopt a certified external paper revision without applying normal local-edit
/// revision semantics.
abstract class PaperImportRepository {
  Future<void> replacePaperFromImport(
    Paper paper, {
    required String expectedOriginId,
    required int expectedRevision,
  });
}
