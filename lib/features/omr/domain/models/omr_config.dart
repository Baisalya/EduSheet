enum OmrOptionsCount { two, three, four, five }

class OmrConfig {
  final String schoolName;
  final String? schoolLogo; // Path or base64
  final String examName;
  final int questionCount;
  final OmrOptionsCount optionsCount;
  final bool includeRollNumber;
  final bool includeSection;
  final bool includeBarcode;
  final String? barcodeData;

  OmrConfig({
    this.schoolName = 'My School',
    this.schoolLogo,
    this.examName = 'Final Examination',
    this.questionCount = 100,
    this.optionsCount = OmrOptionsCount.four,
    this.includeRollNumber = true,
    this.includeSection = true,
    this.includeBarcode = false,
    this.barcodeData,
  });

  OmrConfig copyWith({
    String? schoolName,
    String? schoolLogo,
    String? examName,
    int? questionCount,
    OmrOptionsCount? optionsCount,
    bool? includeRollNumber,
    bool? includeSection,
    bool? includeBarcode,
    String? barcodeData,
  }) {
    return OmrConfig(
      schoolName: schoolName ?? this.schoolName,
      schoolLogo: schoolLogo ?? this.schoolLogo,
      examName: examName ?? this.examName,
      questionCount: questionCount ?? this.questionCount,
      optionsCount: optionsCount ?? this.optionsCount,
      includeRollNumber: includeRollNumber ?? this.includeRollNumber,
      includeSection: includeSection ?? this.includeSection,
      includeBarcode: includeBarcode ?? this.includeBarcode,
      barcodeData: barcodeData ?? this.barcodeData,
    );
  }

  int get optionsIntValue {
    switch (optionsCount) {
      case OmrOptionsCount.two:
        return 2;
      case OmrOptionsCount.three:
        return 3;
      case OmrOptionsCount.four:
        return 4;
      case OmrOptionsCount.five:
        return 5;
    }
  }
}
