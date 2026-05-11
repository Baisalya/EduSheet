import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/paper_template.dart';
import 'package:pdf/pdf.dart';

class TemplateRepository {
  static const String _fileName = 'custom_templates.json';

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<List<PaperTemplate>> getCustomTemplates() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];
      
      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      return jsonList.map((e) => _fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveTemplate(PaperTemplate template) async {
    final templates = await getCustomTemplates();
    templates.add(template);
    await _saveAll(templates);
  }

  Future<void> _saveAll(List<PaperTemplate> templates) async {
    final file = await _getFile();
    final jsonList = templates.map((t) => _toJson(t)).toList();
    await file.writeAsString(json.encode(jsonList));
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
    };
  }

  PaperTemplate _fromJson(Map<String, dynamic> json) {
    return PaperTemplate(
      id: json['id'],
      name: json['name'],
      type: TemplateType.values[json['type']],
      primaryColor: PdfColor.fromInt(json['primaryColor']),
      secondaryColor: PdfColor.fromInt(json['secondaryColor']),
      headerFontSize: json['headerFontSize'],
      questionFontSize: json['questionFontSize'],
      hasBorder: json['hasBorder'],
      centeredHeader: json['centeredHeader'],
      headerLayout: HeaderLayout.values[json['headerLayout'] ?? 0],
      paperLayout: PaperLayout.values[json['paperLayout'] ?? 0],
    );
  }
}
