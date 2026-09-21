import 'package:edusheet/shared/portable/eds_unified_container.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v4 container round-trips typed identity and payload', () {
    final exportedAt = DateTime.utc(2026, 9, 18, 12);
    final manifest = EdsPackageManifest(
      packageId: 'package-1',
      contentType: EdsContentType.paper,
      schemaVersion: 1,
      entityId: 'paper-local-1',
      originId: 'paper-origin-1',
      revision: 7,
      title: 'Algebra Test',
      exportedAt: exportedAt,
      metadata: const {'class': '10'},
    );

    const codec = EdsUnifiedContainer();
    final encoded = codec.encode(
      manifest: manifest,
      payload: const {'value': 42},
    );
    final decoded = codec.decode(encoded);

    expect(encoded, startsWith('EDUSHEET/4\n'));
    expect(decoded.manifest.contentType, EdsContentType.paper);
    expect(decoded.manifest.entityId, 'paper-local-1');
    expect(decoded.manifest.originId, 'paper-origin-1');
    expect(decoded.manifest.revision, 7);
    expect(decoded.manifest.exportedAt, exportedAt);
    expect(decoded.payload['value'], 42);
  });

  test('v4 container rejects unsupported content types', () {
    const source = '''EDUSHEET/4
{
  "format": "edusheet.portable-package",
  "containerVersion": 4,
  "manifest": {
    "packageId": "p",
    "contentType": "futureUnknownType",
    "schemaVersion": 1,
    "entityId": "e",
    "originId": "o",
    "revision": 1,
    "title": "x",
    "exportedAt": "2026-09-18T12:00:00.000Z"
  },
  "payload": {}
}''';

    expect(() => const EdsUnifiedContainer().decode(source), throwsFormatException);
  });
}
