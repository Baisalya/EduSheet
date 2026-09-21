import 'dart:io';

import 'package:edusheet/core/files/recent_native_file_store.dart';
import 'package:edusheet/features/document_reader/domain/models/document_open_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('recent files are newest first and duplicate paths are refreshed', () async {
    final directory = await Directory.systemTemp.createTemp('edusheet-recents');
    addTearDown(() => directory.delete(recursive: true));
    final first = File('${directory.path}${Platform.pathSeparator}first.pdf')
      ..writeAsStringSync('pdf');
    final second = File('${directory.path}${Platform.pathSeparator}second.eds')
      ..writeAsStringSync('eds');
    final store = RecentNativeFileStore();

    await store.record(DocumentOpenRequest.fromReader(first.path));
    await store.record(DocumentOpenRequest.fromReader(second.path));
    await store.record(DocumentOpenRequest.fromReader(first.path));

    final entries = await store.load();
    expect(entries, hasLength(2));
    expect(entries.first.path, first.path);
    expect(entries.last.path, second.path);
  });

  test('missing recent paths are automatically pruned', () async {
    final directory = await Directory.systemTemp.createTemp('edusheet-recents');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}lesson.edtp')
      ..writeAsStringSync('pack');
    final store = RecentNativeFileStore();

    await store.record(DocumentOpenRequest.fromReader(file.path));
    expect(await store.load(), hasLength(1));

    file.deleteSync();
    expect(await store.load(), isEmpty);
  });
}
