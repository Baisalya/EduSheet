import 'dart:io';

import 'package:edusheet/features/editor/application/saved_paper_eds_service.dart';
import 'package:edusheet/features/editor/data/portable/saved_paper_eds_codec.dart';
import 'package:edusheet/features/editor/data/repositories/paper_repository.dart';
import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/domain/models/paper_page_layout.dart';
import 'package:edusheet/features/teaching_planner/data/portable_paper_asset_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 18, 12);

  test(
    'paper .eds round trip preserves canonical paper and binary assets',
    () async {
      final temp = await Directory.systemTemp.createTemp('edusheet-paper-eds-');
      addTearDown(() => temp.delete(recursive: true));
      final logo = File('${temp.path}/logo.png');
      final questionImage = File('${temp.path}/question.png');
      await logo.writeAsBytes([1, 2, 3], flush: true);
      await questionImage.writeAsBytes([4, 5, 6], flush: true);

      final paper = Paper(
        id: 'paper-1',
        originId: 'origin-paper-1',
        revision: 4,
        updatedAt: now,
        title: 'Class 10 Maths Unit Test 1',
        schoolName: 'ABC Public School',
        logos: [logo.path],
        sections: [
          PaperSection(
            id: 'section-a',
            title: 'Section A',
            questions: [
              Question(
                id: 'q1',
                text: 'Identify the graph',
                imageUrl: questionImage.path,
                marks: 3,
                metadata: const {
                  'edusheet.wordShapes': [
                    {
                      'id': 'shape-1',
                      'kind': 'rectangle',
                      'x': 0.1,
                      'y': 0.2,
                      'width': 0.3,
                      'height': 0.2,
                    },
                  ],
                },
                createdAt: now,
                modifiedAt: now,
              ),
            ],
          ),
        ],
        pageLayout: PaperPageLayout.defaults.copyWith(
          watermarkText: 'CONFIDENTIAL',
          watermarkOpacity: 0.14,
        ),
        createdAt: now,
      );
      final sourceRepository = _MemoryPaperRepository([paper]);
      final sourceService = SavedPaperEdsService(
        paperRepository: sourceRepository,
      );
      final encoded = await sourceService.exportPaper(paper);
      final decoded = const SavedPaperEdsCodec().decode(encoded);

      expect(encoded, startsWith('EDUSHEET/4'));
      expect(decoded.manifest.originId, 'origin-paper-1');
      expect(decoded.manifest.revision, 4);
      expect(decoded.snapshot.assets, hasLength(2));

      final targetRepository = _MemoryPaperRepository();
      final targetService = SavedPaperEdsService(
        paperRepository: targetRepository,
        assetStore: PortablePaperAssetStore(
          rootResolver: () async => Directory('${temp.path}/target-assets'),
          importDirectoryId: () => 'import-a',
        ),
      );
      final inspection = await targetService.inspect(encoded);
      final result = await targetService.importInspected(
        inspection,
        mode: SavedPaperImportMode.addAsNew,
        maximumSavedPaperCount: null,
      );

      expect(result.paper.id, 'paper-1');
      expect(result.paper.originId, 'origin-paper-1');
      expect(result.paper.revision, 4);
      expect(result.paper.title, paper.title);
      expect(result.paper.pageLayout.watermarkText, 'CONFIDENTIAL');
      expect(
        result
            .paper
            .sections
            .single
            .questions
            .single
            .metadata['edusheet.wordShapes'],
        isNotNull,
      );
      expect(await File(result.paper.logos.single).readAsBytes(), [1, 2, 3]);
      expect(
        await File(
          result.paper.sections.single.questions.single.imageUrl!,
        ).readAsBytes(),
        [4, 5, 6],
      );
    },
  );

  test(
    'Add as new never overwrites same id and preserves source lineage',
    () async {
      final local = _paper(now, title: 'Local paper');
      final incoming = _paper(now, title: 'Incoming paper', revision: 3);
      final source = await SavedPaperEdsService(
        paperRepository: _MemoryPaperRepository([incoming]),
      ).exportPaper(incoming);
      final repository = _MemoryPaperRepository([local]);
      final temp = await Directory.systemTemp.createTemp(
        'edusheet-paper-copy-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final service = SavedPaperEdsService(
        paperRepository: repository,
        assetStore: PortablePaperAssetStore(
          rootResolver: () async => Directory('${temp.path}/assets'),
        ),
        idGenerator: () => 'safe-copy-id',
      );

      final inspection = await service.inspect(source);
      final result = await service.importInspected(
        inspection,
        mode: SavedPaperImportMode.addAsNew,
        maximumSavedPaperCount: null,
      );

      expect(result.paper.id, 'safe-copy-id');
      expect(result.paper.originId, incoming.originId);
      expect((await repository.getAllPapers()), hasLength(2));
      expect((await repository.getAllPapers()).first.title, 'Local paper');
    },
  );

  test('Add as new enforces the caller supplied saved-paper limit', () async {
    final incoming = _paper(now, id: 'incoming', title: 'Incoming paper');
    final source = await SavedPaperEdsService(
      paperRepository: _MemoryPaperRepository([incoming]),
    ).exportPaper(incoming);
    final repository = _MemoryPaperRepository([
      for (var index = 0; index < 5; index++)
        _paper(now, id: 'local-$index', title: 'Local $index'),
    ]);
    final service = SavedPaperEdsService(paperRepository: repository);
    final inspection = await service.inspect(source);

    await expectLater(
      service.importInspected(
        inspection,
        mode: SavedPaperImportMode.addAsNew,
        maximumSavedPaperCount: 5,
      ),
      throwsA(isA<SavedPaperImportLimitException>()),
    );
    expect(await repository.getAllPapers(), hasLength(5));
  });

  test(
    'replace is offered only for same lineage and non-older revision',
    () async {
      final existing = _paper(now, title: 'Revision 2', revision: 2);
      final incoming = _paper(now, title: 'Revision 3', revision: 3);
      final source = await SavedPaperEdsService(
        paperRepository: _MemoryPaperRepository([incoming]),
      ).exportPaper(incoming);
      final repository = _MemoryPaperRepository([existing]);
      final temp = await Directory.systemTemp.createTemp(
        'edusheet-paper-replace-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final service = SavedPaperEdsService(
        paperRepository: repository,
        assetStore: PortablePaperAssetStore(
          rootResolver: () async => Directory('${temp.path}/assets'),
        ),
      );

      final inspection = await service.inspect(source);
      expect(inspection.canReplace, isTrue);
      final result = await service.importInspected(
        inspection,
        mode: SavedPaperImportMode.replaceSameLineage,
        maximumSavedPaperCount: null,
      );

      expect(result.paper.id, existing.id);
      expect(result.paper.originId, existing.originId);
      expect(result.paper.revision, 3);
      expect((await repository.getAllPapers()).single.title, 'Revision 3');
    },
  );

  test('replace aborts if the local paper changes after preview', () async {
    final existing = _paper(now, title: 'Revision 2', revision: 2);
    final incoming = _paper(now, title: 'Revision 3', revision: 3);
    final source = await SavedPaperEdsService(
      paperRepository: _MemoryPaperRepository([incoming]),
    ).exportPaper(incoming);
    final repository = _MemoryPaperRepository([existing]);
    final service = SavedPaperEdsService(paperRepository: repository);
    final inspection = await service.inspect(source);

    await repository.savePaper(
      existing.copyWith(title: 'Edited after preview', revision: 4),
    );

    await expectLater(
      service.importInspected(
        inspection,
        mode: SavedPaperImportMode.replaceSameLineage,
        maximumSavedPaperCount: null,
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      (await repository.getAllPapers()).single.title,
      'Edited after preview',
    );
  });

  test('equal revision is never treated as a newer replacement', () async {
    final existing = _paper(now, title: 'Local branch', revision: 4);
    final incoming = _paper(now, title: 'Incoming branch', revision: 4);
    final source = await SavedPaperEdsService(
      paperRepository: _MemoryPaperRepository([incoming]),
    ).exportPaper(incoming);
    final service = SavedPaperEdsService(
      paperRepository: _MemoryPaperRepository([existing]),
    );

    final inspection = await service.inspect(source);

    expect(inspection.canReplace, isFalse);
    expect(inspection.replaceBlockedReason, contains('same revision'));
  });

  test(
    'older incoming revision cannot replace newer same-lineage paper',
    () async {
      final existing = _paper(now, title: 'Revision 5', revision: 5);
      final incoming = _paper(now, title: 'Revision 4', revision: 4);
      final source = await SavedPaperEdsService(
        paperRepository: _MemoryPaperRepository([incoming]),
      ).exportPaper(incoming);
      final service = SavedPaperEdsService(
        paperRepository: _MemoryPaperRepository([existing]),
      );

      final inspection = await service.inspect(source);

      expect(inspection.canReplace, isFalse);
      expect(inspection.replaceBlockedReason, contains('older'));
    },
  );

  test('suggested file name follows paper title and stays filesystem-safe', () {
    final paper = _paper(now, title: 'Class 10: Maths / Unit Test 1');
    expect(
      SavedPaperEdsCodec.suggestedFileName(paper),
      'Class 10_ Maths _ Unit Test 1.eds',
    );
  });
}

Paper _paper(
  DateTime now, {
  String id = 'paper-1',
  String? originId,
  String title = 'Paper',
  int revision = 1,
}) => Paper(
  id: id,
  originId: originId ?? id,
  revision: revision,
  updatedAt: now,
  title: title,
  createdAt: now,
);

class _MemoryPaperRepository implements PaperRepository, PaperImportRepository {
  _MemoryPaperRepository([Iterable<Paper> initial = const []]) {
    for (final paper in initial) {
      _papers[paper.id] = Paper.fromJson(paper.toJson());
    }
  }

  final Map<String, Paper> _papers = <String, Paper>{};

  @override
  Future<List<Paper>> getAllPapers() async => _papers.values
      .map((paper) => Paper.fromJson(paper.toJson()))
      .toList(growable: false);

  @override
  Future<void> savePaper(Paper paper) async {
    _papers[paper.id] = Paper.fromJson(paper.toJson());
  }

  @override
  Future<void> deletePaper(String id) async {
    _papers.remove(id);
  }

  @override
  Future<void> replacePaperFromImport(
    Paper paper, {
    required String expectedOriginId,
    required int expectedRevision,
  }) async {
    final current = _papers[paper.id];
    if (current == null ||
        current.originId != expectedOriginId ||
        current.revision != expectedRevision ||
        paper.originId != expectedOriginId ||
        paper.revision <= current.revision) {
      throw StateError('Atomic paper replacement precondition failed.');
    }
    _papers[paper.id] = Paper.fromJson(paper.toJson());
  }
}
