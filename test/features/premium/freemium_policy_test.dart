import 'package:edusheet/features/premium/domain/freemium_policy.dart';
import 'package:edusheet/features/premium/domain/premium_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const free = PremiumState();
  const premium = PremiumState(isPremium: true);

  test('free creation limits still allow meaningful use', () {
    expect(
      FreemiumPolicy.canCreatePaper(premium: free, savedPaperCount: 4),
      isTrue,
    );
    expect(
      FreemiumPolicy.canCreatePaper(premium: free, savedPaperCount: 5),
      isFalse,
    );
    expect(
      FreemiumPolicy.canCreateClass(premium: free, activeClassCount: 1),
      isTrue,
    );
    expect(
      FreemiumPolicy.canCreateClass(premium: free, activeClassCount: 2),
      isFalse,
    );
  });

  test('premium and grace period remove creation limits', () {
    expect(
      FreemiumPolicy.canCreatePaper(premium: premium, savedPaperCount: 100),
      isTrue,
    );
    expect(
      FreemiumPolicy.canCreateClass(
        premium: const PremiumState(isInGracePeriod: true),
        activeClassCount: 100,
      ),
      isTrue,
    );
  });

  test(
    'existing premium template and branding remain editable after expiry',
    () {
      expect(
        FreemiumPolicy.canUseTemplate(
          premium: free,
          templateId: 'college_formal',
          existingTemplateId: 'college_formal',
        ),
        isTrue,
      );
      expect(
        FreemiumPolicy.canAddBranding(
          premium: free,
          paperAlreadyHasBranding: true,
        ),
        isTrue,
      );
      expect(
        FreemiumPolicy.canAddBranding(
          premium: free,
          paperAlreadyHasBranding: false,
        ),
        isFalse,
      );
    },
  );
}
