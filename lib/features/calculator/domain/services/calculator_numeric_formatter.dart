/// Central numeric presentation policy for calculator results and `Ans`.
///
/// Keeping formatting separate from parsing/evaluation prevents display rules
/// from silently changing calculation semantics (for example, treating every
/// tiny finite value as zero).
class CalculatorNumericFormatter {
  const CalculatorNumericFormatter();

  String format(double value) {
    if (value == 0) return '0';

    final absolute = value.abs();
    if (absolute >= 1e10 || absolute < 1e-6) {
      return _trimExponential(value.toStringAsExponential(10));
    }

    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }

    var text = value.toStringAsFixed(10);
    while (text.contains('.') && text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }

  /// Serializes a finite value back into syntax accepted by MathEngine.
  ///
  /// Dart may emit scientific notation with a lowercase `e`, while the
  /// calculator reserves lowercase `e` for Euler's constant. Convert exponent
  /// notation into an explicit power-of-ten expression before reinsertion.
  String serialize(double value) {
    final text = value.toString();
    final exponentMarker = text.contains('e')
        ? 'e'
        : (text.contains('E') ? 'E' : null);
    if (exponentMarker == null) return text;

    final parts = text.split(exponentMarker);
    if (parts.length != 2) return text;
    final exponent = int.tryParse(parts[1]);
    if (exponent == null) return text;
    return '${parts[0]}*10^($exponent)';
  }

  String _trimExponential(String value) {
    final parts = value.split('e');
    var mantissa = parts[0];
    while (mantissa.contains('.') && mantissa.endsWith('0')) {
      mantissa = mantissa.substring(0, mantissa.length - 1);
    }
    if (mantissa.endsWith('.')) {
      mantissa = mantissa.substring(0, mantissa.length - 1);
    }
    final exponent = int.parse(parts[1]);
    return '${mantissa}e${exponent >= 0 ? '+' : ''}$exponent';
  }
}
