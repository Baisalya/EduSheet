import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyNotifier extends StateNotifier<AsyncValue<int>> {
  PrivacyNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  static const int currentPolicyVersion =
      3; // Increment this when policy changes
  static const String _storageKey = 'accepted_privacy_version';

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final acceptedVersion = prefs.getInt(_storageKey) ?? 0;
    state = AsyncValue.data(acceptedVersion);
  }

  Future<void> acceptPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_storageKey, currentPolicyVersion);
    state = const AsyncValue.data(currentPolicyVersion);
  }

  bool get needsApproval {
    return state.maybeWhen(
      data: (version) => version < currentPolicyVersion,
      orElse: () => false,
    );
  }
}

final privacyProvider = StateNotifierProvider<PrivacyNotifier, AsyncValue<int>>(
  (ref) {
    return PrivacyNotifier();
  },
);
