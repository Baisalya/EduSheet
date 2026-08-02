import 'dart:io';

import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:path/path.dart' as path;

class AttachmentLifecycleService {
  const AttachmentLifecycleService();

  Set<String> referencedPaths(Iterable<Paper> papers) {
    final referenced = <String>{};
    for (final paper in papers) {
      for (final logo in paper.logos) {
        if (logo.trim().isNotEmpty) referenced.add(path.normalize(logo));
      }
      for (final section in paper.sections) {
        for (final question in section.questions) {
          _collectQuestion(question, referenced);
        }
      }
    }
    return referenced;
  }

  Set<String> orphanPaths(
    Iterable<String> managedPaths,
    Iterable<Paper> papers,
  ) {
    final referenced = referencedPaths(papers);
    return managedPaths
        .map(path.normalize)
        .where((candidate) => !referenced.contains(candidate))
        .toSet();
  }

  Future<File> moveOrphanToTrash({
    required File file,
    required Directory attachmentRoot,
    required Directory trashDirectory,
    required Iterable<Paper> papers,
  }) async {
    final candidate = path.normalize(file.absolute.path);
    final root = path.normalize(attachmentRoot.absolute.path);
    if (!path.isWithin(root, candidate)) {
      throw ArgumentError('Only managed attachment files can be moved.');
    }
    if (referencedPaths(papers).contains(candidate)) {
      throw StateError('The attachment is still referenced by a paper.');
    }
    if (!await file.exists()) {
      throw FileSystemException('Attachment does not exist.', candidate);
    }

    await trashDirectory.create(recursive: true);
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final destination = File(
      path.join(trashDirectory.path, '$timestamp-${path.basename(candidate)}'),
    );
    return file.rename(destination.path);
  }

  void _collectQuestion(Question question, Set<String> referenced) {
    final imageUrl = question.imageUrl;
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      referenced.add(path.normalize(imageUrl));
    }
    for (final attachment in question.attachments) {
      if (attachment.path.trim().isNotEmpty) {
        referenced.add(path.normalize(attachment.path));
      }
    }
    for (final child in [...question.subQuestions, ...question.internalChoices]) {
      _collectQuestion(child, referenced);
    }
  }
}
