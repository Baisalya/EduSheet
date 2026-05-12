import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/document_repository.dart';
import '../../domain/models/document_model.dart';

final documentRepositoryProvider = Provider((ref) => DocumentRepository());

class DocumentState {
  final List<DocumentFile> allDocuments;
  final List<DocumentFile> filteredDocuments;
  final bool isLoading;
  final DocumentType? selectedFilter;
  final String searchQuery;

  DocumentState({
    this.allDocuments = const [],
    this.filteredDocuments = const [],
    this.isLoading = false,
    this.selectedFilter,
    this.searchQuery = '',
  });

  DocumentState copyWith({
    List<DocumentFile>? allDocuments,
    List<DocumentFile>? filteredDocuments,
    bool? isLoading,
    DocumentType? selectedFilter,
    bool clearFilter = false,
    String? searchQuery,
  }) {
    return DocumentState(
      allDocuments: allDocuments ?? this.allDocuments,
      filteredDocuments: filteredDocuments ?? this.filteredDocuments,
      isLoading: isLoading ?? this.isLoading,
      selectedFilter: clearFilter ? null : (selectedFilter ?? this.selectedFilter),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class DocumentNotifier extends StateNotifier<DocumentState> {
  final DocumentRepository _repository;

  DocumentNotifier(this._repository) : super(DocumentState()) {
    refreshDocuments();
  }

  Future<void> refreshDocuments() async {
    state = state.copyWith(isLoading: true);
    final docs = await _repository.getDocuments();
    state = state.copyWith(
      allDocuments: docs,
      isLoading: false,
    );
    _applyFilters();
  }

  void setFilter(DocumentType? type) {
    if (state.selectedFilter == type) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(selectedFilter: type);
    }
    _applyFilters();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  void _applyFilters() {
    var filtered = state.allDocuments;

    if (state.selectedFilter != null) {
      filtered = filtered.where((doc) => doc.type == state.selectedFilter).toList();
    }

    if (state.searchQuery.isNotEmpty) {
      filtered = filtered
          .where((doc) => doc.name.toLowerCase().contains(state.searchQuery.toLowerCase()))
          .toList();
    }

    state = state.copyWith(filteredDocuments: filtered);
  }
}

final documentProvider = StateNotifierProvider<DocumentNotifier, DocumentState>((ref) {
  final repo = ref.watch(documentRepositoryProvider);
  return DocumentNotifier(repo);
});
