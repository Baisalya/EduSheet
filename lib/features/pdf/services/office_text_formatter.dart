import 'package:edusheet/features/math_keyboard/domain/services/math_compatibility_service.dart';

import 'package:edusheet/features/paper_composer/application/question_print_content_projection.dart';

class OfficeTextFormatter {
  static String questionText(
    String text, {
    String geometryPlaceholder = '[diagram]',
  }) {
    final projection = QuestionPrintContentProjection.fromRichText(text);
    if (projection.isStructuredRichText) {
      final buffer = StringBuffer();
      for (final object in projection.objects) {
        switch (object.kind) {
          case QuestionPrintContentKind.richText:
            for (final operation in object.operations) {
              final insert = operation['insert'];
              if (insert is String) buffer.write(insert);
            }
            break;
          case QuestionPrintContentKind.mathExpression:
            final expression = object.mathExpression;
            if (expression == null) {
              buffer.write('[formula]');
            } else {
              buffer.write(
                const MathCompatibilityService()
                    .inspectSource(
                      expression.latex,
                      plainFallback: expression.plainText,
                    )
                    .readableFallback,
              );
            }
            break;
          case QuestionPrintContentKind.geometry:
            buffer.write(geometryPlaceholder);
            break;
        }
      }
      return buffer
          .toString()
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
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
