import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  final TextRecognizer _englishRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  final TextRecognizer _hindiRecognizer = TextRecognizer(
    script: TextRecognitionScript.devanagiri,
  );

  Future<String> recognizeText(String imagePath, {bool isHindi = false}) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizer = isHindi ? _hindiRecognizer : _englishRecognizer;

    try {
      final RecognizedText recognizedText = await recognizer.processImage(
        inputImage,
      );
      return recognizedText.text;
    } catch (e) {
      return 'Error recognizing text: $e';
    }
  }

  Future<String> recognizeTextStrict(
    String imagePath, {
    bool isHindi = false,
  }) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizer = isHindi ? _hindiRecognizer : _englishRecognizer;
    final recognizedText = await recognizer.processImage(inputImage);
    return recognizedText.text;
  }

  Future<String> recognizeTextAuto(String imagePath) async {
    final englishText = await recognizeTextStrict(imagePath);
    final hindiText = await recognizeTextStrict(imagePath, isHindi: true);

    return _score(hindiText) > _score(englishText) ? hindiText : englishText;
  }

  int _score(String text) {
    return text.replaceAll(RegExp(r'\s+'), '').length;
  }

  void dispose() {
    _englishRecognizer.close();
    _hindiRecognizer.close();
  }
}
