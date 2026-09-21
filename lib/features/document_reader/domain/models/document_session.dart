import 'package:edusheet/features/document_reader/domain/models/document_model.dart';
import 'package:edusheet/features/document_reader/domain/models/document_open_request.dart';

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
