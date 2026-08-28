import '../data/repositories/document_repository.dart';
import '../domain/models/document_open_request.dart';
import '../domain/models/document_session.dart';

class DocumentOpenResult {
  final DocumentSession? session;
  final String? errorMessage;
  final bool duplicate;

  const DocumentOpenResult._({
    this.session,
    this.errorMessage,
    this.duplicate = false,
  });

  const DocumentOpenResult.success(DocumentSession session)
    : this._(session: session);

  const DocumentOpenResult.failure(String message)
    : this._(errorMessage: message);

  const DocumentOpenResult.duplicate() : this._(duplicate: true);

  bool get isSuccess => session != null;
}

class DocumentOpenCoordinator {
  final DocumentRepository _repository;
  String? _lastActivationKey;
  DateTime? _lastActivationAt;

  DocumentOpenCoordinator(this._repository);

  Future<DocumentOpenResult> resolve(DocumentOpenRequest request) async {
    if (request.localPath.trim().isEmpty) {
      return const DocumentOpenResult.failure(
        'Unable to resolve the selected document.',
      );
    }

    final now = DateTime.now();
    final shouldDedupe =
        request.activationId != null ||
        request.source == DocumentOpenSource.androidViewIntent ||
        request.source == DocumentOpenSource.androidShareIntent;
    if (shouldDedupe &&
        _lastActivationKey == request.dedupeKey &&
        _lastActivationAt != null &&
        now.difference(_lastActivationAt!) < const Duration(seconds: 2)) {
      return const DocumentOpenResult.duplicate();
    }

    final document = await _repository.getDocumentFromRequest(request);
    if (document == null) {
      return const DocumentOpenResult.failure(
        'This file is unavailable or its format is not supported by EduSheet.',
      );
    }

    if (shouldDedupe) {
      _lastActivationKey = request.dedupeKey;
      _lastActivationAt = now;
    }

    return DocumentOpenResult.success(
      DocumentSession(document: document, request: request, openedAt: now),
    );
  }
}
