import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_file_opener.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_service.dart';

typedef SmartEditorPersistCurrent = Future<bool> Function();
typedef SmartEditorSaveImported = Future<void> Function(SmartDocument document);
typedef SmartEditorClearImportedRecovery = Future<void> Function(String documentId);

/// Coordinates the destructive boundary of opening a Word file in Smart Editor.
///
/// The picker/importer may inspect a candidate DOCX first, but the currently
/// edited document must be persisted successfully before the imported document
/// is committed to the Smart Editor repository. This keeps the workflow
/// testable without mounting the full Quill editor and prevents a failed save
/// from silently replacing the user's current work.
class SmartEditorOpenImportWorkflow {
  SmartEditorOpenImportWorkflow({
    SmartEditorDocxFileOpener? opener,
  }) : _opener = opener ?? SmartEditorDocxFileOpener();

  final SmartEditorDocxFileOpener _opener;

  Future<SmartEditorDocxImportResult?> run({
    required SmartEditorPersistCurrent persistCurrent,
    required SmartEditorSaveImported saveImported,
    SmartEditorClearImportedRecovery? clearImportedRecovery,
  }) async {
    final result = await _opener.pickAndImport();
    if (result == null) return null;

    final persisted = await persistCurrent();
    if (!persisted) return null;

    await saveImported(result.document);
    final clearRecovery = clearImportedRecovery;
    if (clearRecovery != null) {
      try {
        await clearRecovery(result.document.id);
      } catch (_) {
        // Recovery cleanup is secondary to the authoritative repository save.
      }
    }
    return result;
  }
}
