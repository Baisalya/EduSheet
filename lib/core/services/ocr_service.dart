import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  final TextRecognizer _englishRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final TextRecognizer _hindiRecognizer = TextRecognizer(script: TextRecognitionScript.devanagiri);

  Future<String> recognizeText(String imagePath, {bool isHindi = false}) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizer = isHindi ? _hindiRecognizer : _englishRecognizer;

    try {
      final RecognizedText recognizedText = await recognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      return 'Error recognizing text: $e';
    }
  }

  void dispose() {
    _englishRecognizer.close();
    _hindiRecognizer.close();
  }
}
