import 'package:crypto/crypto.dart';

import '../domain/models/teaching_planner_workspace.dart';
import '../domain/models/teaching_resource.dart';

TeachingPlannerWorkspace portableTeachingResourceWorkspace(
  TeachingPlannerWorkspace workspace,
) {
  return workspace.copyWith(
    resources: workspace.resources
        .map((resource) {
          if (resource.kind != TeachingResourceKind.file ||
              resource.fileOwnership !=
                  TeachingResourceFileOwnership.linkedExternal) {
            return resource;
          }
          return resource.copyWith(
            fileOwnership: TeachingResourceFileOwnership.managed,
            localRelativePath: 'portable/${resource.id}/resource.bin',
            externalFilePath: null,
            // A linked original may have changed since it was first attached.
            // The current bytes captured for export become the new portable
            // integrity source rather than a stale machine-local fingerprint.
            contentSha256: null,
          );
        })
        .toList(growable: false),
  );
}

/// Produces portable resource metadata that exactly matches the bytes embedded
/// in `.eds` / curriculum packages. This is important for linked originals,
/// which are intentionally allowed to change in place on Windows.
TeachingPlannerWorkspace portableTeachingResourceWorkspaceWithFiles(
  TeachingPlannerWorkspace workspace,
  Map<String, List<int>> resourceFiles,
) {
  final portable = portableTeachingResourceWorkspace(workspace);
  return portable.copyWith(
    resources: portable.resources
        .map((resource) {
          if (resource.kind != TeachingResourceKind.file) return resource;
          final bytes = resourceFiles[resource.id];
          if (bytes == null) return resource;
          return resource.copyWith(
            sizeBytes: bytes.length,
            contentSha256: sha256.convert(bytes).toString(),
          );
        })
        .toList(growable: false),
  );
}
