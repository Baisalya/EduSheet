enum ExportStage { preparing, rendering, serializing, writing, complete }

class ExportProgress {
  final ExportStage stage;
  final double fraction;
  final String message;

  const ExportProgress({
    required this.stage,
    required this.fraction,
    required this.message,
  });
}

typedef ExportProgressCallback = void Function(ExportProgress progress);

class ExportCancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() => _isCancelled = true;

  void throwIfCancelled() {
    if (_isCancelled) throw const ExportCancelledException();
  }
}

class ExportCancelledException implements Exception {
  const ExportCancelledException();

  @override
  String toString() => 'Export was cancelled.';
}

enum ExportFailureKind {
  permission,
  lowStorage,
  unsupportedContent,
  cancelled,
  unknown,
}

class ExportFailureClassifier {
  const ExportFailureClassifier();

  ExportFailureKind classify(Object error) {
    if (error is ExportCancelledException) return ExportFailureKind.cancelled;
    final message = error.toString().toLowerCase();
    if (message.contains('permission') || message.contains('access denied')) {
      return ExportFailureKind.permission;
    }
    if (message.contains('no space') || message.contains('disk full')) {
      return ExportFailureKind.lowStorage;
    }
    if (message.contains('unicode') || message.contains('unsupported')) {
      return ExportFailureKind.unsupportedContent;
    }
    return ExportFailureKind.unknown;
  }

  String userMessage(Object error) {
    return switch (classify(error)) {
      ExportFailureKind.permission =>
        'Storage access was denied. Choose an available folder and retry.',
      ExportFailureKind.lowStorage =>
        'There is not enough free storage to finish this export.',
      ExportFailureKind.unsupportedContent =>
        'Some content could not be rendered. Your paper is still saved.',
      ExportFailureKind.cancelled => 'Export cancelled. Your paper is still saved.',
      ExportFailureKind.unknown =>
        'The export could not be completed. Your paper is still saved.',
    };
  }
}
