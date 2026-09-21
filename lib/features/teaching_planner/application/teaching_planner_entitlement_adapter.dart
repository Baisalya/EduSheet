import '../../premium/domain/premium_state.dart';
import '../domain/models/teaching_planner_capabilities.dart';

class TeachingPlannerEntitlementAdapter {
  const TeachingPlannerEntitlementAdapter._();

  static TeachingPlannerCapabilities fromPremiumState(PremiumState state) {
    if (state.hasPremiumAccess && !state.isComplimentaryAccess) {
      return TeachingPlannerCapabilities.pro();
    }
    if (state.isComplimentaryAccess) {
      return TeachingPlannerCapabilities.complimentaryPro();
    }
    return TeachingPlannerCapabilities.free();
  }
}
