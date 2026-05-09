import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/omr_config.dart';

class OmrNotifier extends Notifier<OmrConfig> {
  @override
  OmrConfig build() {
    return OmrConfig();
  }

  void updateSchoolName(String name) => state = state.copyWith(schoolName: name);
  void updateExamName(String name) => state = state.copyWith(examName: name);
  void updateQuestionCount(int count) => state = state.copyWith(questionCount: count);
  void updateOptionsCount(OmrOptionsCount count) => state = state.copyWith(optionsCount: count);
  void toggleRollNumber(bool value) => state = state.copyWith(includeRollNumber: value);
  void toggleSection(bool value) => state = state.copyWith(includeSection: value);
  void toggleBarcode(bool value) => state = state.copyWith(includeBarcode: value);
  void updateBarcodeData(String data) => state = state.copyWith(barcodeData: data);
  void updateSchoolLogo(String? path) => state = state.copyWith(schoolLogo: path);
}

final omrProvider = NotifierProvider<OmrNotifier, OmrConfig>(() => OmrNotifier());
