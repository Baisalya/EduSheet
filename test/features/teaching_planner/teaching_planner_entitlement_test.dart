import 'package:edusheet/features/premium/domain/premium_state.dart';
import 'package:edusheet/features/teaching_planner/application/teaching_planner_entitlement_adapter.dart';
import 'package:edusheet/features/teaching_planner/domain/models/teaching_planner_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('free users keep core planning capabilities', () {
    final capabilities = TeachingPlannerEntitlementAdapter.fromPremiumState(
      const PremiumState(
        isPremium: false,
        isComplimentaryAccess: false,
        storeStatus: PremiumStoreStatus.ready,
      ),
    );

    expect(capabilities.accessLevel, TeachingPlannerAccessLevel.free);
    expect(capabilities.allows(TeachingPlannerCapability.corePlanning), isTrue);
    expect(
      capabilities.allows(TeachingPlannerCapability.syllabusManagement),
      isTrue,
    );
    expect(
      capabilities.allows(TeachingPlannerCapability.advancedDashboards),
      isFalse,
    );
  });

  test('existing premium entitlement unlocks centralized pro capabilities', () {
    final capabilities = TeachingPlannerEntitlementAdapter.fromPremiumState(
      const PremiumState(isPremium: true),
    );

    expect(capabilities.accessLevel, TeachingPlannerAccessLevel.pro);
    expect(
      capabilities.allows(TeachingPlannerCapability.advancedScheduling),
      isTrue,
    );
    expect(
      capabilities.allows(TeachingPlannerCapability.bulkOperations),
      isTrue,
    );
  });

  test('complimentary fail-open access remains full access', () {
    final capabilities = TeachingPlannerEntitlementAdapter.fromPremiumState(
      const PremiumState(isComplimentaryAccess: true),
    );

    expect(
      capabilities.accessLevel,
      TeachingPlannerAccessLevel.complimentaryPro,
    );
    expect(capabilities.hasProConvenience, isTrue);
  });
}
