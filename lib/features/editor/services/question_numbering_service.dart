import 'package:edusheet/features/editor/domain/models/paper_model.dart';

class QuestionNumberingService {
  const QuestionNumberingService._();

  static String label(
    int oneBased,
    QuestionNumberStyle style, {
    List<String> customLabels = const [],
  }) {
    if (oneBased <= 0) return oneBased.toString();

    return switch (style) {
      QuestionNumberStyle.number => oneBased.toString(),
      QuestionNumberStyle.lowerAlpha => _alpha(oneBased).toLowerCase(),
      QuestionNumberStyle.upperAlpha => _alpha(oneBased),
      QuestionNumberStyle.lowerRoman => _roman(oneBased).toLowerCase(),
      QuestionNumberStyle.upperRoman => _roman(oneBased),
      QuestionNumberStyle.hindiDigits => _localizedDigits(oneBased, const [
        '०',
        '१',
        '२',
        '३',
        '४',
        '५',
        '६',
        '७',
        '८',
        '९',
      ]),
      QuestionNumberStyle.odiaDigits => _localizedDigits(oneBased, const [
        '୦',
        '୧',
        '୨',
        '୩',
        '୪',
        '୫',
        '୬',
        '୭',
        '୮',
        '୯',
      ]),
      QuestionNumberStyle.hindiLetters => _sequenceLabel(oneBased, const [
        'क',
        'ख',
        'ग',
        'घ',
        'ङ',
        'च',
        'छ',
        'ज',
        'झ',
        'ञ',
        'ट',
        'ठ',
        'ड',
        'ढ',
        'ण',
        'त',
        'थ',
        'द',
        'ध',
        'न',
        'प',
        'फ',
        'ब',
        'भ',
        'म',
        'य',
        'र',
        'ल',
        'व',
        'श',
        'ष',
        'स',
        'ह',
      ]),
      QuestionNumberStyle.odiaLetters => _sequenceLabel(oneBased, const [
        'କ',
        'ଖ',
        'ଗ',
        'ଘ',
        'ଙ',
        'ଚ',
        'ଛ',
        'ଜ',
        'ଝ',
        'ଞ',
        'ଟ',
        'ଠ',
        'ଡ',
        'ଢ',
        'ଣ',
        'ତ',
        'ଥ',
        'ଦ',
        'ଧ',
        'ନ',
        'ପ',
        'ଫ',
        'ବ',
        'ଭ',
        'ମ',
        'ଯ',
        'ର',
        'ଲ',
        'ୱ',
        'ଶ',
        'ଷ',
        'ସ',
        'ହ',
      ]),
      QuestionNumberStyle.englishWords => _englishWords(oneBased),
      QuestionNumberStyle.custom => _customLabel(oneBased, customLabels),
    };
  }

  static String paperLabel(int oneBased, Paper paper) {
    return label(
      oneBased,
      paper.questionNumberStyle,
      customLabels: paper.customQuestionNumberLabels,
    );
  }

  static String displayName(QuestionNumberStyle style) {
    return switch (style) {
      QuestionNumberStyle.number => '1, 2, 3',
      QuestionNumberStyle.lowerAlpha => 'a, b, c',
      QuestionNumberStyle.upperAlpha => 'A, B, C',
      QuestionNumberStyle.lowerRoman => 'i, ii, iii',
      QuestionNumberStyle.upperRoman => 'I, II, III',
      QuestionNumberStyle.hindiDigits => 'Hindi १, २, ३',
      QuestionNumberStyle.odiaDigits => 'Odia ୧, ୨, ୩',
      QuestionNumberStyle.hindiLetters => 'Hindi क, ख, ग',
      QuestionNumberStyle.odiaLetters => 'Odia କ, ଖ, ଗ',
      QuestionNumberStyle.englishWords => 'one, two, three',
      QuestionNumberStyle.custom => 'Custom labels',
    };
  }

  static String sample(
    QuestionNumberStyle style, {
    List<String> customLabels = const [],
  }) {
    return List.generate(
      3,
      (index) => label(index + 1, style, customLabels: customLabels),
    ).join(', ');
  }

  static String _alpha(int value) {
    var current = value;
    final chars = <String>[];
    while (current > 0) {
      current--;
      chars.insert(0, String.fromCharCode(65 + (current % 26)));
      current ~/= 26;
    }
    return chars.join();
  }

  static String _roman(int value) {
    if (value > 3999) return value.toString();

    const symbols = [
      (1000, 'M'),
      (900, 'CM'),
      (500, 'D'),
      (400, 'CD'),
      (100, 'C'),
      (90, 'XC'),
      (50, 'L'),
      (40, 'XL'),
      (10, 'X'),
      (9, 'IX'),
      (5, 'V'),
      (4, 'IV'),
      (1, 'I'),
    ];

    var remaining = value;
    final buffer = StringBuffer();
    for (final (number, symbol) in symbols) {
      while (remaining >= number) {
        buffer.write(symbol);
        remaining -= number;
      }
    }
    return buffer.toString();
  }

  static String _localizedDigits(int value, List<String> digits) {
    return value
        .toString()
        .split('')
        .map((char) => digits[int.parse(char)])
        .join();
  }

  static String _sequenceLabel(int value, List<String> labels) {
    final index = value - 1;
    if (index < labels.length) return labels[index];
    return value.toString();
  }

  static String _customLabel(int value, List<String> labels) {
    final cleaned = labels
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList();
    return _sequenceLabel(value, cleaned);
  }

  static String _englishWords(int value) {
    const small = [
      'zero',
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
      'ten',
      'eleven',
      'twelve',
      'thirteen',
      'fourteen',
      'fifteen',
      'sixteen',
      'seventeen',
      'eighteen',
      'nineteen',
    ];
    const tens = [
      '',
      '',
      'twenty',
      'thirty',
      'forty',
      'fifty',
      'sixty',
      'seventy',
      'eighty',
      'ninety',
    ];

    if (value < small.length) return small[value];
    if (value < 100) {
      final ten = value ~/ 10;
      final remainder = value % 10;
      return remainder == 0 ? tens[ten] : '${tens[ten]}-${small[remainder]}';
    }
    return value.toString();
  }
}
