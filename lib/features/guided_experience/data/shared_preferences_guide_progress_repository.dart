import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/guide_ids.dart';
import '../domain/guide_progress.dart';
import '../domain/guide_progress_repository.dart';

class SharedPreferencesGuideProgressRepository
    implements GuideProgressRepository {
  static const _keyPrefix = 'guided_experience.progress.';

  @override
  Future<Map<GuideId, GuideProgress>> loadAll() async {
    final preferences = await SharedPreferences.getInstance();
    final result = <GuideId, GuideProgress>{};
    final keys = preferences
        .getKeys()
        .where((key) => key.startsWith(_keyPrefix))
        .toList()
      ..sort();

    for (final key in keys) {
      final encoded = preferences.getString(key);
      if (encoded == null || encoded.isEmpty) continue;

      try {
        final decoded = jsonDecode(encoded);
        if (decoded is! Map) continue;
        final progress = GuideProgress.fromJson(
          decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );
        result[progress.guideId] = progress;
      } on FormatException {
        // Ignore only malformed guide metadata. Business data is never stored
        // in this repository and must not be affected by tutorial corruption.
      }
    }

    return Map<GuideId, GuideProgress>.unmodifiable(result);
  }

  @override
  Future<void> save(GuideProgress progress) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(progress.toJson());
    await preferences.setString(_keyFor(progress.guideId), encoded);
  }

  @override
  Future<void> remove(GuideId guideId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_keyFor(guideId));
  }

  String _keyFor(GuideId guideId) => '$_keyPrefix${guideId.value}';
}
