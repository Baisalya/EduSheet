import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:edusheet/features/editor/data/repositories/local_paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/shared/persistence/atomic_json_file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('edusheet_atomic_test_');
    file = File('${directory.path}/data.json');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('keeps the previous valid generation as a backup', () async {
    final store = AtomicJsonFileStore(file);
    await store.writeJson({'value': 1});
    await store.writeJson({'value': 2});

    expect(await store.readJson(orElse: null), {'value': 2});
    expect(
      jsonDecode(await store.backupFile.readAsString()),
      {'value': 1},
    );
  });

  test('recovers from a corrupt primary without returning empty data', () async {
    final store = AtomicJsonFileStore(file);
    await store.writeJson({'value': 'recover me'});
    await store.writeJson({'value': 'current'});
    await file.writeAsString('{corrupt', flush: true);

    expect(await store.readJson(orElse: null), {'value': 'recover me'});
  });

  test('surfaces a typed error when primary and backup are corrupt', () async {
    final store = AtomicJsonFileStore(file);
    await file.writeAsString('{bad', flush: true);
    await store.backupFile.writeAsString('{also bad', flush: true);

    await expectLater(
      store.readJson(orElse: null),
      throwsA(
        isA<PersistenceException>().having(
          (error) => error.kind,
          'kind',
          PersistenceFailureKind.recovery,
        ),
      ),
    );
  });

  test('paper repository migrates a legacy list on the next save', () async {
    final paper = Paper(
      id: 'paper-1',
      title: 'Legacy paper',
      createdAt: DateTime.utc(2025),
    );
    await file.writeAsString(jsonEncode([paper.toJson()]), flush: true);
    final repository = LocalPaperRepository(fileResolver: () async => file);

    expect((await repository.getAllPapers()).single.title, 'Legacy paper');
    await repository.savePaper(paper.copyWith(title: 'Migrated paper'));

    final stored = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(stored['schemaVersion'], 2);
    expect((stored['items'] as List).single['title'], 'Migrated paper');
  });

  test('serialized operation queue preserves mutation order', () async {
    final queue = SerializedOperationQueue();
    final releaseFirst = Completer<void>();
    final order = <int>[];

    final first = queue.run(() async {
      await releaseFirst.future;
      order.add(1);
    });
    final second = queue.run(() async => order.add(2));
    releaseFirst.complete();
    await Future.wait([first, second]);

    expect(order, [1, 2]);
  });
}
