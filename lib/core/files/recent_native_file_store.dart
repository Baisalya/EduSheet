import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edusheet/features/document_reader/domain/models/document_open_request.dart';

class RecentNativeFileEntry {
  final String path;
  final String displayName;
  final String extension;
  final DateTime openedAt;

  const RecentNativeFileEntry({
    required this.path,
    required this.displayName,
    required this.extension,
    required this.openedAt,
  });

  Map<String, Object?> toJson() => {
    'path': path,
    'displayName': displayName,
    'extension': extension,
    'openedAt': openedAt.toUtc().toIso8601String(),
  };

  static RecentNativeFileEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final path = value['path']?.toString().trim() ?? '';
    if (path.isEmpty) return null;
    final openedAt = DateTime.tryParse(value['openedAt']?.toString() ?? '');
    if (openedAt == null) return null;
    return RecentNativeFileEntry(
      path: path,
      displayName: value['displayName']?.toString().trim().isNotEmpty == true
          ? value['displayName'].toString().trim()
          : p.basename(path),
      extension: value['extension']?.toString().toLowerCase() ??
          p.extension(path).toLowerCase(),
      openedAt: openedAt.toLocal(),
    );
  }
}

class RecentNativeFileStore {
  static const _key = 'native_recent_files_v1';
  static const _maxEntries = 12;

  Future<List<RecentNativeFileEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final entries = decoded
          .map(RecentNativeFileEntry.fromJson)
          .whereType<RecentNativeFileEntry>()
          .where((entry) => File(entry.path).existsSync())
          .toList()
        ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
      if (entries.length != decoded.length) {
        await _save(prefs, entries.take(_maxEntries).toList());
      }
      return entries.take(_maxEntries).toList(growable: false);
    } catch (_) {
      await prefs.remove(_key);
      return const [];
    }
  }

  Future<void> record(DocumentOpenRequest request) async {
    final path = request.localPath.trim();
    if (path.isEmpty || !File(path).existsSync()) return;

    final prefs = await SharedPreferences.getInstance();
    final current = await load();
    final normalized = Platform.isWindows ? path.toLowerCase() : path;
    final next = <RecentNativeFileEntry>[
      RecentNativeFileEntry(
        path: path,
        displayName: request.displayName?.trim().isNotEmpty == true
            ? request.displayName!.trim()
            : p.basename(path),
        extension: request.effectiveExtension,
        openedAt: DateTime.now(),
      ),
      ...current.where((entry) {
        final existing = Platform.isWindows
            ? entry.path.toLowerCase()
            : entry.path;
        return existing != normalized;
      }),
    ];
    await _save(prefs, next.take(_maxEntries).toList());
  }

  Future<void> remove(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await load();
    final normalized = Platform.isWindows ? path.toLowerCase() : path;
    await _save(
      prefs,
      current.where((entry) {
        final existing = Platform.isWindows
            ? entry.path.toLowerCase()
            : entry.path;
        return existing != normalized;
      }).toList(),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _save(
    SharedPreferences prefs,
    List<RecentNativeFileEntry> entries,
  ) {
    return prefs.setString(
      _key,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }
}

final recentNativeFileStoreProvider = Provider<RecentNativeFileStore>(
  (ref) => RecentNativeFileStore(),
);
