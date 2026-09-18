import 'dart:io';

import 'package:path/path.dart' as p;

enum ConversionStage {
  preparing,
  readingSource,
  parsing,
  processingPages,
  rendering,
  writingOutput,
  completed,
  cancelled,
}

class ConversionProgress {
  const ConversionProgress({
    required this.stage,
    required this.message,
    this.current,
    this.total,
  });

  final ConversionStage stage;
  final String message;
  final int? current;
  final int? total;

  double? get fraction {
    final totalValue = total;
    final currentValue = current;
    if (totalValue == null || currentValue == null || totalValue <= 0) {
      return null;
    }
    return (currentValue / totalValue).clamp(0.0, 1.0);
  }
}

class ConversionCancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw const ConversionCancelledException();
    }
  }
}

class ConversionCancelledException implements Exception {
  const ConversionCancelledException();

  @override
  String toString() => 'Conversion cancelled.';
}

class ConversionSourceInfo {
  const ConversionSourceInfo({
    required this.path,
    required this.sizeBytes,
    this.pageCount,
  });

  final String path;
  final int sizeBytes;
  final int? pageCount;

  String get name => p.basename(path);

  static Future<ConversionSourceInfo> fromFile(
    File file, {
    int? pageCount,
  }) async {
    final stat = await file.stat();
    return ConversionSourceInfo(
      path: file.path,
      sizeBytes: stat.size,
      pageCount: pageCount,
    );
  }
}

typedef ConversionProgressCallback = void Function(ConversionProgress progress);
