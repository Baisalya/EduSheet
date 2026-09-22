import 'package:edusheet/features/smart_editor/data/smart_document_repository.dart';
import 'package:edusheet/features/smart_editor/data/smart_editor_recovery_store.dart';
import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final smartDocumentRepositoryProvider = Provider<SmartDocumentRepository>(
  (ref) => LocalSmartDocumentRepository(),
);


final smartEditorRecoveryStoreProvider = Provider<SmartEditorRecoveryStore>(
  (ref) => SmartEditorRecoveryStore(),
);

final smartDocumentsProvider = FutureProvider.autoDispose<List<SmartDocument>>(
  (ref) => ref.watch(smartDocumentRepositoryProvider).getAll(),
);
