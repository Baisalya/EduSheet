import 'package:path/path.dart' as p;

enum DocumentType { pdf, word, excel, powerpoint, text, other }

enum DocumentSupportLevel { native, rich, basic, externalOnly, unsupported }

class DocumentViewerCapability {
  final DocumentSupportLevel level;
  final String label;
  final String description;
  final bool canPreview;

  const DocumentViewerCapability({
    required this.level,
    required this.label,
    required this.description,
    required this.canPreview,
  });
}

class DocumentFile {
  final String name;
  final String path;
  final String extension;
  final int size;
  final DateTime lastModified;
  final DocumentType type;
  final String? mimeType;
  final String? originalUri;

  DocumentFile({
    required this.name,
    required this.path,
    required this.extension,
    required this.size,
    required this.lastModified,
    required this.type,
    this.mimeType,
    this.originalUri,
  });

  static const Set<String> supportedExtensions = {
    '.pdf',
    '.doc',
    '.docx',
    '.rtf',
    '.odt',
    '.xls',
    '.xlsx',
    '.csv',
    '.ods',
    '.ppt',
    '.pptx',
    '.odp',
    '.txt',
  };

  static DocumentType getDocumentType(String ext) {
    switch (_normalizeExtension(ext)) {
      case '.pdf':
        return DocumentType.pdf;
      case '.doc':
      case '.docx':
      case '.rtf':
      case '.odt':
        return DocumentType.word;
      case '.xls':
      case '.xlsx':
      case '.csv':
      case '.ods':
        return DocumentType.excel;
      case '.ppt':
      case '.pptx':
      case '.odp':
        return DocumentType.powerpoint;
      case '.txt':
        return DocumentType.text;
      default:
        return DocumentType.other;
    }
  }

  static DocumentViewerCapability capabilityForExtension(String ext) {
    switch (_normalizeExtension(ext)) {
      case '.pdf':
        return const DocumentViewerCapability(
          level: DocumentSupportLevel.native,
          label: 'Full PDF viewer',
          description:
              'Native PDF rendering with search, page navigation, and zoom.',
          canPreview: true,
        );
      case '.docx':
        return const DocumentViewerCapability(
          level: DocumentSupportLevel.rich,
          label: 'DOCX viewer',
          description:
              'Paged DOCX preview with responsive sizing and built-in zoom.',
          canPreview: true,
        );
      case '.xlsx':
        return const DocumentViewerCapability(
          level: DocumentSupportLevel.rich,
          label: 'Spreadsheet viewer',
          description:
              'Multi-sheet XLSX preview with virtualized rows for large sheets.',
          canPreview: true,
        );
      case '.csv':
        return const DocumentViewerCapability(
          level: DocumentSupportLevel.rich,
          label: 'CSV viewer',
          description:
              'Quoted-field CSV preview with a virtualized grid for large tables.',
          canPreview: true,
        );
      case '.pptx':
        return const DocumentViewerCapability(
          level: DocumentSupportLevel.rich,
          label: 'Presentation viewer',
          description:
              'Structured PPTX slide preview with text, images, layout, and supported slide transitions.',
          canPreview: true,
        );
      case '.txt':
        return const DocumentViewerCapability(
          level: DocumentSupportLevel.rich,
          label: 'Text viewer',
          description: 'Virtualized text preview optimized for large files.',
          canPreview: true,
        );
      case '.doc':
      case '.rtf':
      case '.odt':
      case '.xls':
      case '.ods':
      case '.ppt':
      case '.odp':
        return const DocumentViewerCapability(
          level: DocumentSupportLevel.externalOnly,
          label: 'External Office viewer recommended',
          description:
              'This legacy/OpenDocument format is recognized, but the current authorized renderer cannot reproduce it faithfully in-app.',
          canPreview: false,
        );
      default:
        return const DocumentViewerCapability(
          level: DocumentSupportLevel.unsupported,
          label: 'Unsupported format',
          description:
              'EduSheet does not currently recognize this file format.',
          canPreview: false,
        );
    }
  }

  DocumentViewerCapability get capability => capabilityForExtension(extension);

  bool get canPreview => capability.canPreview;

  String get displayExtension => extension.replaceFirst('.', '').toUpperCase();

  String get sizeString {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String extensionFromName(String name) =>
      _normalizeExtension(p.extension(name));

  static String _normalizeExtension(String ext) {
    final trimmed = ext.trim().toLowerCase();
    if (trimmed.isEmpty) return '';
    return trimmed.startsWith('.') ? trimmed : '.$trimmed';
  }
}
