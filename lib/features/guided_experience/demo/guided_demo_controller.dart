import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'guided_demo_session.dart';

class GuidedDemoController extends StateNotifier<GuidedDemoSession?> {
  GuidedDemoController() : super(null);

  void start(GuidedDemoFeature feature) {
    state = GuidedDemoSession(feature: feature, startedAt: DateTime.now());
  }

  void stop() {
    state = null;
  }
}

final guidedDemoControllerProvider =
    StateNotifierProvider<GuidedDemoController, GuidedDemoSession?>((ref) {
      return GuidedDemoController();
    });
