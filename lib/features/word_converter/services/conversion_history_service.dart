import 'dart:io';

import 'package:edusheet/features/word_converter/domain/models/conversion_history_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConversionHistoryService {
  ConversionHistoryService._();

  static const _storageKey = 'word_converter_recent_conversions_v1';
  static const maxEntries = 8;

  static Future<List<ConversionHistoryEntry>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getStringList(_storageKey) ?? const <String>[];
    final entries = <ConversionHistoryEntry>[];
    for (final value in encoded) {
      final entry = ConversionHistoryEntry.decode(value);
      if (entry == null) continue;
      if (!await File(entry.outputPath).exists()) continue;
      entries.add(entry);
      if (entries.length == maxEntries) break;
    }
    return entries;
  }

  static Future<List<ConversionHistoryEntry>> add(
    ConversionHistoryEntry entry,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final existing = await load();
    final updated = <ConversionHistoryEntry>[
      entry,
      ...existing.where((item) => item.outputPath != entry.outputPath),
    ].take(maxEntries).toList(growable: false);
    await preferences.setStringList(
      _storageKey,
      updated.map((item) => item.encode()).toList(growable: false),
    );
    return updated;
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }
}
