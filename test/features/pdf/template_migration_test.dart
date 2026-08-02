import 'dart:convert';
import 'dart:io';

import 'package:edusheet/features/pdf/data/repositories/template_repository.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown legacy template enum indexes fall back safely', () async {
    final directory = await Directory.systemTemp.createTemp(
      'edusheet_template_migration_',
    );
    addTearDown(() async => directory.delete(recursive: true));
    final file = File('${directory.path}/templates.json');
    await file.writeAsString(
      jsonEncode([
        {
          'id': 'future-template',
          'name': 'Future template',
          'type': 999,
          'headerLayout': -1,
          'paperLayout': 999,
          'paperSize': 999,
          'customLayout': {
            'elements': [
              {'id': 'element', 'type': 999, 'x': 4, 'y': 8},
            ],
          },
        },
      ]),
      flush: true,
    );

    final templates = await TemplateRepository(
      fileResolver: () async => file,
    ).getCustomTemplates();

    expect(templates.single.type, TemplateType.school);
    expect(templates.single.headerLayout, HeaderLayout.centered);
    expect(templates.single.paperLayout, PaperLayout.standard);
    expect(templates.single.paperSize, PaperSize.a4);
    expect(
      templates.single.customLayout!.elements.single.type,
      ElementType.staticText,
    );
  });
}
