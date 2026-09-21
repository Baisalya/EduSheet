import 'dart:io';

import 'package:edusheet/features/editor/data/repositories/local_paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local edits keep origin id and advance revision only when content changes', () async {
    final directory = await Directory.systemTemp.createTemp('edusheet-lineage-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/papers.json');
    final repository = LocalPaperRepository(fileResolver: () async => file);
    final now = DateTime.utc(2026, 9, 18, 12);
    final paper = Paper(
      id: 'local-paper',
      originId: 'canonical-origin',
      revision: 4,
      updatedAt: now,
      title: 'Original',
      createdAt: now,
    );

    await repository.savePaper(paper);
    await repository.savePaper(paper);
    final unchanged = (await repository.getAllPapers()).single;
    expect(unchanged.revision, 4);
    expect(unchanged.originId, 'canonical-origin');

    await repository.savePaper(paper.copyWith(title: 'Edited'));
    final edited = (await repository.getAllPapers()).single;
    expect(edited.revision, 5);
    expect(edited.originId, 'canonical-origin');
    expect(edited.title, 'Edited');
    expect(edited.updatedAt.isAfter(now), isTrue);
  });

  test('atomic imported replacement rejects a concurrent local revision', () async {
    final directory = await Directory.systemTemp.createTemp('edusheet-lineage-cas-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/papers.json');
    final repository = LocalPaperRepository(fileResolver: () async => file);
    final now = DateTime.utc(2026, 9, 18, 12);
    final original = Paper(
      id: 'local-paper',
      originId: 'canonical-origin',
      revision: 2,
      updatedAt: now,
      title: 'Original',
      createdAt: now,
    );
    await repository.savePaper(original);

    await repository.savePaper(original.copyWith(title: 'Local autosave wins'));
    final locallyEdited = (await repository.getAllPapers()).single;
    expect(locallyEdited.revision, 3);

    await expectLater(
      repository.replacePaperFromImport(
        original.copyWith(
          title: 'Incoming revision 3',
          revision: 3,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
        expectedOriginId: 'canonical-origin',
        expectedRevision: 2,
      ),
      throwsA(isA<StateError>()),
    );

    final afterRejectedImport = (await repository.getAllPapers()).single;
    expect(afterRejectedImport.title, 'Local autosave wins');
    expect(afterRejectedImport.revision, 3);
  });

  test('atomic imported replacement accepts a strictly newer matching lineage', () async {
    final directory = await Directory.systemTemp.createTemp('edusheet-lineage-replace-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/papers.json');
    final repository = LocalPaperRepository(fileResolver: () async => file);
    final now = DateTime.utc(2026, 9, 18, 12);
    final original = Paper(
      id: 'local-paper',
      originId: 'canonical-origin',
      revision: 2,
      updatedAt: now,
      title: 'Revision 2',
      createdAt: now,
    );
    await repository.savePaper(original);

    await repository.replacePaperFromImport(
      original.copyWith(
        title: 'Revision 3',
        revision: 3,
        updatedAt: now.add(const Duration(minutes: 1)),
      ),
      expectedOriginId: 'canonical-origin',
      expectedRevision: 2,
    );

    final replaced = (await repository.getAllPapers()).single;
    expect(replaced.title, 'Revision 3');
    expect(replaced.revision, 3);
    expect(replaced.originId, 'canonical-origin');
  });

  test('legacy papers derive stable lineage from their existing id', () {
    final paper = Paper.fromJson({
      'id': 'legacy-paper-id',
      'title': 'Legacy paper',
      'createdAt': '2025-01-01T00:00:00.000Z',
    });

    expect(paper.originId, 'legacy-paper-id');
    expect(paper.revision, 1);
    expect(paper.updatedAt, DateTime.utc(2025, 1, 1));
  });
}
