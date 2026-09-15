import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('math_keyboard feature uses only relative self-imports', () {
    final root = Directory('lib/features/math_keyboard');
    expect(root.existsSync(), isTrue);

    final offenders = <String>[];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('package:edusheet/features/math_keyboard/')) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Files inside math_keyboard must use relative self-imports so '
          'one feature instance cannot load its own models under two URIs.',
    );
  });

  test('cross-feature project math_keyboard imports use the package URI', () {
    final root = Directory('lib');
    expect(root.existsSync(), isTrue);

    final offenders = <String>[];
    final importUriPattern = RegExp(r'''import\s+['"]([^'"]+)['"]''');

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      // Compare normalized path segments case-insensitively. Windows may
      // report the same worktree as EduSheet or edusheet, and File paths may
      // be relative or absolute depending on the runner.
      final normalizedPath = entity.path.replaceAll('\\', '/').toLowerCase();
      if (normalizedPath.startsWith('lib/features/math_keyboard/') ||
          normalizedPath.contains('/lib/features/math_keyboard/')) {
        continue;
      }

      for (final rawLine in entity.readAsLinesSync()) {
        final line = rawLine.trim();
        if (!line.startsWith('import ')) continue;

        final match = importUriPattern.firstMatch(line);
        if (match == null) continue;
        final uri = match.group(1)!.replaceAll('\\', '/');

        // package:math_keyboard is the external dependency. It is not an
        // EduSheet feature-boundary import and cannot duplicate our models.
        if (uri.startsWith('package:math_keyboard/')) continue;

        final targetsProjectMathFeature =
            uri.startsWith('package:edusheet/features/math_keyboard/') ||
            uri.contains('/math_keyboard/') ||
            uri.startsWith('math_keyboard/');
        if (!targetsProjectMathFeature) continue;

        if (!uri.startsWith('package:edusheet/features/math_keyboard/')) {
          offenders.add('${entity.path}: $line');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Files outside math_keyboard must cross the EduSheet feature '
          'boundary through package:edusheet/features/math_keyboard/... . '
          'Third-party package:math_keyboard imports are intentionally outside '
          'this rule. This keeps shared EduSheet model types on one package URI '
          'even when Windows worktree casing differs (EduSheet vs edusheet).',
    );
  });
}
