import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all app modal bottom sheets use the adaptive presenter', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('adaptive_modal_bottom_sheet.dart')) continue;
      final source = entity.readAsStringSync();
      if (RegExp(r'\bshowModalBottomSheet\s*(?:<|\()').hasMatch(source)) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use showAdaptiveModalBottomSheet so narrow Windows/Android layouts '
          'receive finite full-width modal constraints. Offenders: $offenders',
    );
  });
}
