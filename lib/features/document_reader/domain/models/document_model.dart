enum DocumentType {
  pdf,
  word,
  excel,
  powerpoint,
  text,
  other
}

class DocumentFile {
  final String name;
  final String path;
  final String extension;
  final int size;
  final DateTime lastModified;
  final DocumentType type;

  DocumentFile({
    required this.name,
    required this.path,
    required this.extension,
    required this.size,
    required this.lastModified,
    required this.type,
  });

  static DocumentType getDocumentType(String ext) {
    switch (ext.toLowerCase()) {
      case '.pdf':
        return DocumentType.pdf;
      case '.doc':
      case '.docx':
        return DocumentType.word;
      case '.xls':
      case '.xlsx':
        return DocumentType.excel;
      case '.ppt':
      case '.pptx':
        return DocumentType.powerpoint;
      case '.txt':
        return DocumentType.text;
      default:
        return DocumentType.other;
    }
  }

  String get sizeString {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
