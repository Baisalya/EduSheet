import 'dart:convert';

class OfficeTextFormatter {
  static String questionText(String text) {
    try {
      final trimmed = text.trimLeft();
      if (trimmed.startsWith('[')) {
        final data = jsonDecode(trimmed) as List<dynamic>;
        return data
            .map((op) {
              if (op is! Map<String, dynamic>) return '';
              final insert = op['insert'];
              return insert is String ? insert : ' ';
            })
            .join()
            .replaceAll('\n', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }
    } catch (_) {
      // Fall through to plain text.
    }

    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String xml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String safeFileName(String title, String fallback) {
    final sanitized = title
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    return sanitized.isEmpty ? fallback : sanitized;
  }
}
