import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/shared_preferences_contextual_help_repository.dart';
import '../data/shared_preferences_guide_progress_repository.dart';
import '../domain/contextual_help_preferences.dart';
import '../domain/contextual_help_state.dart';
import '../domain/guide_progress_repository.dart';
import '../domain/guided_experience_state.dart';
import 'contextual_help_controller.dart';
import 'contextual_help_policy.dart';
import 'guided_experience_controller.dart';

final guideProgressRepositoryProvider = Provider<GuideProgressRepository>((ref) {
  return SharedPreferencesGuideProgressRepository();
});

final guidedExperienceControllerProvider = StateNotifierProvider<
    GuidedExperienceController, GuidedExperienceState>((ref) {
  final controller = GuidedExperienceController(
    ref.watch(guideProgressRepositoryProvider),
  );
  unawaited(controller.load());
  return controller;
});

final contextualHelpPreferencesRepositoryProvider =
    Provider<ContextualHelpPreferencesRepository>((ref) {
  return SharedPreferencesContextualHelpRepository();
});

final contextualHelpPolicyProvider = Provider<ContextualHelpPolicy>((ref) {
  return const ContextualHelpPolicy();
});

final contextualHelpControllerProvider =
    StateNotifierProvider<ContextualHelpController, ContextualHelpState>((ref) {
  final controller = ContextualHelpController(
    ref.watch(contextualHelpPreferencesRepositoryProvider),
  );
  unawaited(controller.load());
  return controller;
});
