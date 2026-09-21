import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/teaching_planner/data/portable_paper_snapshot.dart';
import 'package:edusheet/shared/portable/eds_unified_container.dart';
import 'package:uuid/uuid.dart';

class SavedPaperEdsPackage {
  final EdsPackageManifest manifest;
  final PortablePaperSnapshot snapshot;

  const SavedPaperEdsPackage({
    required this.manifest,
    required this.snapshot,
  });

  Paper get paper => snapshot.paper;
}

/// Canonical `.eds` codec for one fully editable Saved Paper.
///
/// The paper itself remains the Phase-9 canonical Paper JSON model. Binary
/// files referenced by that model are captured by [PortablePaperSnapshot].
class SavedPaperEdsCodec {
  const SavedPaperEdsCodec({
    EdsUnifiedContainer container = const EdsUnifiedContainer(),
  }) : _container = container;

  final EdsUnifiedContainer _container;

  static const int paperSchemaVersion = 1;

  String encodeSnapshot(
    PortablePaperSnapshot snapshot, {
    DateTime? exportedAt,
    String? packageId,
  }) {
    final paper = snapshot.paper;
    final manifest = EdsPackageManifest(
      packageId: packageId ?? const Uuid().v4(),
      contentType: EdsContentType.paper,
      schemaVersion: paperSchemaVersion,
      entityId: paper.id,
      originId: paper.originId,
      revision: paper.revision,
      title: paper.title,
      exportedAt: exportedAt ?? DateTime.now().toUtc(),
      metadata: <String, dynamic>{
        'schoolName': paper.schoolName,
        'totalMarks': paper.totalMarks,
        'sectionCount': paper.sections.length,
        'questionCount': _questionCount(paper),
        'assetCount': snapshot.assets.length,
        'createdAt': paper.createdAt.toUtc().toIso8601String(),
        'updatedAt': paper.updatedAt.toUtc().toIso8601String(),
      },
    );
    return _container.encode(
      manifest: manifest,
      payload: <String, dynamic>{
        'snapshot': snapshot.toJson(),
      },
    );
  }

  SavedPaperEdsPackage decode(String source) {
    final package = _container.decode(source);
    if (package.manifest.contentType != EdsContentType.paper) {
      throw FormatException(
        'This EduSheet file contains ${package.manifest.contentType.name}, not a Saved Paper.',
      );
    }
    if (package.manifest.schemaVersion != paperSchemaVersion) {
      throw const FormatException('Unsupported EduSheet paper schema version.');
    }
    final rawSnapshot = package.payload['snapshot'];
    if (rawSnapshot is! Map) {
      throw const FormatException('EduSheet paper payload is missing.');
    }
    final snapshot = PortablePaperSnapshot.fromJson(
      Map<String, dynamic>.from(rawSnapshot),
    );
    final paper = snapshot.paper;
    if (package.manifest.entityId != paper.id ||
        package.manifest.originId != paper.originId ||
        package.manifest.revision != paper.revision) {
      throw const FormatException(
        'EduSheet paper identity metadata does not match its canonical document.',
      );
    }
    return SavedPaperEdsPackage(
      manifest: package.manifest,
      snapshot: snapshot,
    );
  }

  static String suggestedFileName(Paper paper) {
    var title = paper.title.trim();
    if (title.isEmpty || title == 'New Paper') title = 'EduSheet Paper';
    title = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    while (title.endsWith('.')) {
      title = title.substring(0, title.length - 1).trimRight();
    }
    if (title.isEmpty) title = 'EduSheet Paper';
    return '$title.${EdsUnifiedContainer.fileExtension}';
  }

  static int _questionCount(Paper paper) {
    int countQuestion(Question question) {
      var count = 1;
      for (final child in question.subQuestions) {
        count += countQuestion(child);
      }
      for (final child in question.internalChoices) {
        count += countQuestion(child);
      }
      return count;
    }

    var count = 0;
    for (final section in paper.sections) {
      for (final question in section.questions) {
        count += countQuestion(question);
      }
    }
    return count;
  }
}
