import 'document_model.dart';
import 'document_open_request.dart';

class DocumentSession {
  final DocumentFile document;
  final DocumentOpenRequest request;
  final DateTime openedAt;

  const DocumentSession({
    required this.document,
    required this.request,
    required this.openedAt,
  });

  DocumentViewerCapability get capability => document.capability;
}
