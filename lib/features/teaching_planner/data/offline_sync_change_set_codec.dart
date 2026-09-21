import 'dart:convert';

import '../domain/models/offline_sync_change_set.dart';

class OfflineSyncChangeSetCodec {
  const OfflineSyncChangeSetCodec();

  String encode(OfflineSyncChangeSet changeSet) =>
      const JsonEncoder.withIndent('  ').convert(changeSet.toJson());

  OfflineSyncChangeSet decode(String source) {
    final value = jsonDecode(source);
    if (value is! Map) {
      throw const FormatException('Offline sync change-set must be an object.');
    }
    return OfflineSyncChangeSet.fromJson(Map<String, dynamic>.from(value));
  }
}
