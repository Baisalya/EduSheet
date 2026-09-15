enum TeachingResourceFileCategory {
  image,
  pdf,
  video,
  audio,
  document,
  spreadsheet,
  presentation,
  text,
  other,
}

class TeachingResourceFileMetadata {
  const TeachingResourceFileMetadata._();

  static String mimeTypeForFileName(String fileName) {
    final extension = _extension(fileName);
    return switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      'svg' => 'image/svg+xml',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'mp4' => 'video/mp4',
      'webm' => 'video/webm',
      'mov' => 'video/quicktime',
      'avi' => 'video/x-msvideo',
      'mkv' => 'video/x-matroska',
      'm4v' => 'video/x-m4v',
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'ogg' => 'audio/ogg',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      'html' || 'htm' => 'text/html',
      'md' => 'text/markdown',
      'json' => 'application/json',
      'rtf' => 'application/rtf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'odt' => 'application/vnd.oasis.opendocument.text',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ods' => 'application/vnd.oasis.opendocument.spreadsheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'odp' => 'application/vnd.oasis.opendocument.presentation',
      _ => 'application/octet-stream',
    };
  }

  static TeachingResourceFileCategory categoryFor({
    required String fileName,
    String? mimeType,
  }) {
    final mime = (mimeType ?? mimeTypeForFileName(fileName)).toLowerCase();
    if (mime.startsWith('image/')) return TeachingResourceFileCategory.image;
    if (mime == 'application/pdf') return TeachingResourceFileCategory.pdf;
    if (mime.startsWith('video/')) return TeachingResourceFileCategory.video;
    if (mime.startsWith('audio/')) return TeachingResourceFileCategory.audio;
    if (mime.contains('spreadsheet') || mime.contains('excel')) {
      return TeachingResourceFileCategory.spreadsheet;
    }
    if (mime.contains('presentation') || mime.contains('powerpoint')) {
      return TeachingResourceFileCategory.presentation;
    }
    if (mime.contains('word') ||
        mime.contains('opendocument.text') ||
        mime == 'application/rtf') {
      return TeachingResourceFileCategory.document;
    }
    if (mime.startsWith('text/') || mime == 'application/json') {
      return TeachingResourceFileCategory.text;
    }
    return TeachingResourceFileCategory.other;
  }

  static String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }
}
