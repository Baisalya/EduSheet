import 'premium_state.dart';

/// The single product boundary used by UI and application services.
abstract final class FreemiumPolicy {
  static const int freeSavedPaperLimit = 5;
  static const int freeActiveClassLimit = 2;
  static const int freeMonthlyPdfExportLimit = 5;
  static const Duration premiumGracePeriod = Duration(days: 7);

  static const Set<String> freeTemplateIds = {
    'school_formal',
    'school_modern_left',
    'board_cbse',
  };

  static bool hasFullAccess(PremiumState premium) => premium.hasPremiumAccess;

  static bool canCreatePaper({
    required PremiumState premium,
    required int savedPaperCount,
  }) => hasFullAccess(premium) || savedPaperCount < freeSavedPaperLimit;

  static bool canCreateClass({
    required PremiumState premium,
    required int activeClassCount,
  }) => hasFullAccess(premium) || activeClassCount < freeActiveClassLimit;

  static bool canExportPdf({
    required PremiumState premium,
    required int exportsThisMonth,
  }) => hasFullAccess(premium) || exportsThisMonth < freeMonthlyPdfExportLimit;

  static bool canExportWord(PremiumState premium) => hasFullAccess(premium);

  static bool canUseTemplate({
    required PremiumState premium,
    required String templateId,
    String? existingTemplateId,
  }) =>
      hasFullAccess(premium) ||
      templateId == existingTemplateId ||
      freeTemplateIds.contains(templateId);

  /// Existing logos remain replaceable/removable after expiry. Adding branding
  /// to a paper that did not already contain it is a new Premium operation.
  static bool canAddBranding({
    required PremiumState premium,
    required bool paperAlreadyHasBranding,
  }) => hasFullAccess(premium) || paperAlreadyHasBranding;
}

class FreemiumLimitException implements Exception {
  const FreemiumLimitException(this.message);

  final String message;

  @override
  String toString() => message;
}
