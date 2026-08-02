import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:edusheet/shared/persistence/atomic_json_file_store.dart';
import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:edusheet/features/pdf/domain/models/custom_layout.dart';
import 'package:pdf/pdf.dart';

class TemplateRepository {
  static const String _fileName = 'custom_templates.json';
  final Future<File> Function() _fileResolver;
  final SerializedOperationQueue _mutations = SerializedOperationQueue();

  TemplateRepository({Future<File> Function()? fileResolver})
    : _fileResolver = fileResolver ?? _defaultFile;

  static Future<File> _defaultFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<AtomicJsonFileStore> _store() async {
    return AtomicJsonFileStore(await _fileResolver());
  }

  Future<List<PaperTemplate>> getCustomTemplates() async {
    final decoded = await (await _store()).readJson(orElse: const []);
    return AtomicJsonFileStore.versionedItems(decoded)
        .whereType<Map>()
        .map((item) => _fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> saveTemplate(PaperTemplate template) async {
    await _mutations.run(() async {
      final templates = await getCustomTemplates();
      final index = templates.indexWhere((item) => item.id == template.id);
      if (index != -1) {
        templates[index] = template;
      } else {
        templates.add(template);
      }
      await _saveAll(templates);
    });
  }

  Future<void> _saveAll(List<PaperTemplate> templates) async {
    final items = templates.map(_toJson).toList();
    await (await _store()).writeJson(AtomicJsonFileStore.envelope(items));
  }

  Map<String, dynamic> _toJson(PaperTemplate t) {
    return {
      'id': t.id,
      'name': t.name,
      'type': t.type.index,
      'primaryColor': t.primaryColor.toInt(),
      'secondaryColor': t.secondaryColor.toInt(),
      'headerFontSize': t.headerFontSize,
      'questionFontSize': t.questionFontSize,
      'hasBorder': t.hasBorder,
      'centeredHeader': t.centeredHeader,
      'headerLayout': t.headerLayout.index,
      'paperLayout': t.paperLayout.index,
      'paperSize': t.paperSize.index,
      'customLayout': t.customLayout?.toJson(),
    };
  }

  PaperTemplate _fromJson(Map<String, dynamic> json) {
    T enumAt<T>(List<T> values, dynamic raw, T fallback) {
      final index = raw is num ? raw.toInt() : int.tryParse('$raw');
      return index != null && index >= 0 && index < values.length
          ? values[index]
          : fallback;
    }

    return PaperTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Custom template',
      type: enumAt(TemplateType.values, json['type'], TemplateType.school),
      primaryColor: PdfColor.fromInt(
        (json['primaryColor'] as num?)?.toInt() ?? 0xFF000000,
      ),
      secondaryColor: PdfColor.fromInt(
        (json['secondaryColor'] as num?)?.toInt() ?? 0xFFFFFFFF,
      ),
      headerFontSize: (json['headerFontSize'] as num?)?.toDouble() ?? 18,
      questionFontSize: (json['questionFontSize'] as num?)?.toDouble() ?? 12,
      hasBorder: json['hasBorder'] == true,
      centeredHeader: json['centeredHeader'] != false,
      headerLayout: enumAt(
        HeaderLayout.values,
        json['headerLayout'],
        HeaderLayout.centered,
      ),
      paperLayout: enumAt(
        PaperLayout.values,
        json['paperLayout'],
        PaperLayout.standard,
      ),
      paperSize: enumAt(PaperSize.values, json['paperSize'], PaperSize.a4),
      customLayout: json['customLayout'] is Map
          ? CustomLayout.fromJson(
              Map<String, dynamic>.from(json['customLayout'] as Map),
            )
          : null,
    );
  }
}
