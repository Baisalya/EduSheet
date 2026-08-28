import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class EduSheetLocalizations {
  final Locale locale;

  const EduSheetLocalizations(this.locale);

  static EduSheetLocalizations of(BuildContext context) {
    return Localizations.of<EduSheetLocalizations>(
          context,
          EduSheetLocalizations,
        ) ??
        const EduSheetLocalizations(Locale('en'));
  }

  static const LocalizationsDelegate<EduSheetLocalizations> delegate =
      _EduSheetLocalizationsDelegate();

  String text(String key) {
    final language = _values.containsKey(locale.languageCode)
        ? locale.languageCode
        : 'en';
    return _values[language]?[key] ?? _values['en']?[key] ?? key;
  }

  String get saveAs => text('saveAs');
  String get fileName => text('fileName');
  String get fileNameHint => text('fileNameHint');
  String get chooseFormat => text('chooseFormat');
  String get saveFile => text('saveFile');
  String get saving => text('saving');
  String get cancelExport => text('cancelExport');
  String get enterFileName => text('enterFileName');
  String get paperSaved => text('paperSaved');
  String get pdfOutput => text('pdfOutput');
  String get pageSize => text('pageSize');
  String get orientation => text('orientation');
  String get bookletMargins => text('bookletMargins');
  String get bookletGuidance => text('bookletGuidance');

  String outputMode(String name) => text('output.$name');

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'saveAs': 'Save as',
      'fileName': 'File name',
      'fileNameHint': 'Example: Class 10 Mid Term',
      'chooseFormat': 'Choose format',
      'saveFile': 'Save file',
      'saving': 'Saving…',
      'cancelExport': 'Cancel export',
      'enterFileName': 'Enter a file name',
      'paperSaved': 'Paper saved successfully',
      'pdfOutput': 'PDF output',
      'pageSize': 'Page size',
      'orientation': 'Orientation',
      'bookletMargins': 'Booklet margins and fold gutter',
      'bookletGuidance':
          'Select duplex and short-edge binding in the printer dialog.',
      'progress.preparing': 'Preparing paper…',
      'progress.rendering': 'Rendering PDF…',
      'progress.serializing': 'Finalizing pages…',
      'progress.writing': 'Writing file…',
      'progress.complete': 'Export complete',
      'progress.cancelling': 'Cancelling…',
      'output.standard': 'Standard question paper',
      'output.withAnswerSpace': 'Question paper with answer space',
      'output.questionAnswerBooklet': 'Question-and-answer booklet',
      'output.answerKey': 'Answer key',
      'output.teacherSolution': 'Teacher solution copy',
      'output.studentCopy': 'Student copy',
      'output.multipleSet': 'Multiple-paper set (Set A)',
      'output.worksheet': 'Worksheet',
      'output.compact': 'Compact paper',
      'output.largePrint': 'Large-print accessible',
    },
    'hi': {
      'saveAs': 'इस रूप में सहेजें',
      'fileName': 'फ़ाइल का नाम',
      'fileNameHint': 'उदाहरण: कक्षा 10 मध्यावधि',
      'chooseFormat': 'फ़ॉर्मेट चुनें',
      'saveFile': 'फ़ाइल सहेजें',
      'saving': 'सहेजा जा रहा है…',
      'cancelExport': 'निर्यात रद्द करें',
      'enterFileName': 'फ़ाइल का नाम दर्ज करें',
      'paperSaved': 'प्रश्नपत्र सफलतापूर्वक सहेजा गया',
      'pdfOutput': 'PDF आउटपुट',
      'pageSize': 'पृष्ठ आकार',
      'orientation': 'दिशा',
      'bookletMargins': 'बुकलेट मार्जिन और फोल्ड गटर',
      'bookletGuidance':
          'प्रिंटर डायलॉग में डुप्लेक्स और शॉर्ट-एज बाइंडिंग चुनें।',
      'progress.preparing': 'प्रश्नपत्र तैयार हो रहा है…',
      'progress.rendering': 'PDF बनाया जा रहा है…',
      'progress.serializing': 'पृष्ठ पूरे किए जा रहे हैं…',
      'progress.writing': 'फ़ाइल लिखी जा रही है…',
      'progress.complete': 'निर्यात पूरा हुआ',
      'progress.cancelling': 'रद्द किया जा रहा है…',
      'output.standard': 'मानक प्रश्नपत्र',
      'output.withAnswerSpace': 'उत्तर स्थान सहित प्रश्नपत्र',
      'output.questionAnswerBooklet': 'प्रश्न और उत्तर पुस्तिका',
      'output.answerKey': 'उत्तर कुंजी',
      'output.teacherSolution': 'शिक्षक समाधान प्रति',
      'output.studentCopy': 'विद्यार्थी प्रति',
      'output.multipleSet': 'बहु-प्रश्नपत्र सेट (सेट A)',
      'output.worksheet': 'वर्कशीट',
      'output.compact': 'कॉम्पैक्ट प्रश्नपत्र',
      'output.largePrint': 'बड़े अक्षरों वाला सुलभ प्रश्नपत्र',
    },
  };
}

class _EduSheetLocalizationsDelegate
    extends LocalizationsDelegate<EduSheetLocalizations> {
  const _EduSheetLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const {'en', 'hi'}.contains(locale.languageCode);

  @override
  Future<EduSheetLocalizations> load(Locale locale) {
    return SynchronousFuture(EduSheetLocalizations(locale));
  }

  @override
  bool shouldReload(_EduSheetLocalizationsDelegate old) => false;
}
