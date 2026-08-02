import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:edusheet/shared/persistence/atomic_json_file_store.dart';

import '../domain/models/content_template.dart';
import 'built_in_content_templates.dart';

abstract class ContentTemplateRepository {
  Future<List<QuestionTemplate>> getQuestionTemplates();
  Future<List<SectionTemplate>> getSectionTemplates();
  Future<List<PaperBlueprint>> getPaperBlueprints();
  Future<void> saveQuestionTemplate(QuestionTemplate template);
  Future<void> saveSectionTemplate(SectionTemplate template);
  Future<void> savePaperBlueprint(PaperBlueprint template);
  Future<void> deleteQuestionTemplate(String id);
  Future<void> deleteSectionTemplate(String id);
  Future<void> deletePaperBlueprint(String id);
}

class LocalContentTemplateRepository implements ContentTemplateRepository {
  static const String fileName = 'content_templates.json';
  final Future<File> Function() _fileResolver;
  final SerializedOperationQueue _mutations = SerializedOperationQueue();

  LocalContentTemplateRepository({Future<File> Function()? fileResolver})
    : _fileResolver = fileResolver ?? _defaultFile;

  static Future<File> _defaultFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }

  Future<AtomicJsonFileStore> _store() async {
    return AtomicJsonFileStore(await _fileResolver());
  }

  Future<TemplateLibraryData> _loadCustom() async {
    final decoded = await (await _store()).readJson(
      orElse: const <String, dynamic>{},
    );
    if (decoded is Map && decoded.isEmpty) return const TemplateLibraryData();
    if (decoded is! Map) {
      throw const FormatException('Template library root must be an object.');
    }
    return TemplateLibraryData.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> _saveCustom(TemplateLibraryData data) async {
    await (await _store()).writeJson(data.toJson());
  }

  @override
  Future<List<QuestionTemplate>> getQuestionTemplates() async {
    return (await _loadCustom()).questions;
  }

  @override
  Future<List<SectionTemplate>> getSectionTemplates() async {
    return [...BuiltInContentTemplates.sections, ...(await _loadCustom()).sections];
  }

  @override
  Future<List<PaperBlueprint>> getPaperBlueprints() async {
    return [...BuiltInContentTemplates.papers, ...(await _loadCustom()).papers];
  }

  @override
  Future<void> saveQuestionTemplate(QuestionTemplate template) async {
    await _mutations.run(() async {
      final data = await _loadCustom();
      final items = [...data.questions];
      _upsert(items, template, (item) => item.id);
      await _saveCustom(data.copyWith(questions: items));
    });
  }

  @override
  Future<void> saveSectionTemplate(SectionTemplate template) async {
    await _mutations.run(() async {
      final data = await _loadCustom();
      final items = [...data.sections];
      _upsert(items, template, (item) => item.id);
      await _saveCustom(data.copyWith(sections: items));
    });
  }

  @override
  Future<void> savePaperBlueprint(PaperBlueprint template) async {
    await _mutations.run(() async {
      final data = await _loadCustom();
      final items = [...data.papers];
      _upsert(items, template, (item) => item.id);
      await _saveCustom(data.copyWith(papers: items));
    });
  }

  @override
  Future<void> deleteQuestionTemplate(String id) async {
    await _mutations.run(() async {
      final data = await _loadCustom();
      await _saveCustom(
        data.copyWith(
          questions: data.questions.where((item) => item.id != id).toList(),
        ),
      );
    });
  }

  @override
  Future<void> deleteSectionTemplate(String id) async {
    await _mutations.run(() async {
      final data = await _loadCustom();
      await _saveCustom(
        data.copyWith(
          sections: data.sections.where((item) => item.id != id).toList(),
        ),
      );
    });
  }

  @override
  Future<void> deletePaperBlueprint(String id) async {
    await _mutations.run(() async {
      final data = await _loadCustom();
      await _saveCustom(
        data.copyWith(
          papers: data.papers.where((item) => item.id != id).toList(),
        ),
      );
    });
  }
}

void _upsert<T>(List<T> items, T value, String Function(T item) idOf) {
  final index = items.indexWhere((item) => idOf(item) == idOf(value));
  if (index == -1) {
    items.add(value);
  } else {
    items[index] = value;
  }
}
