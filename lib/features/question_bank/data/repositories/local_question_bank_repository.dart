import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:edusheet/shared/persistence/atomic_json_file_store.dart';
import '../../domain/models/question_bank_model.dart';
import 'question_bank_repository.dart';

class LocalQuestionBankRepository implements QuestionBankRepository {
  static const String _fileName = 'question_bank.json';
  final Future<File> Function() _fileResolver;
  final SerializedOperationQueue _mutations = SerializedOperationQueue();

  LocalQuestionBankRepository({Future<File> Function()? fileResolver})
    : _fileResolver = fileResolver ?? _defaultFile;

  static Future<File> _defaultFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<AtomicJsonFileStore> _store() async {
    return AtomicJsonFileStore(await _fileResolver());
  }

  @override
  Future<List<QuestionBankQuestion>> getAllQuestions() async {
    final decoded = await (await _store()).readJson(orElse: const []);
    return AtomicJsonFileStore.versionedItems(decoded)
        .whereType<Map>()
        .map(
          (item) => QuestionBankQuestion.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  @override
  Future<void> addQuestion(QuestionBankQuestion question) async {
    await _mutations.run(() async {
      final questions = await getAllQuestions();
      questions.add(question);
      await _saveQuestions(questions);
    });
  }

  @override
  Future<void> updateQuestion(QuestionBankQuestion question) async {
    await _mutations.run(() async {
      final questions = await getAllQuestions();
      final index = questions.indexWhere(
        (item) => item.question.id == question.question.id,
      );
      if (index != -1) {
        questions[index] = question;
        await _saveQuestions(questions);
      }
    });
  }

  @override
  Future<void> deleteQuestion(String id) async {
    await _mutations.run(() async {
      final questions = await getAllQuestions();
      questions.removeWhere((question) => question.question.id == id);
      await _saveQuestions(questions);
    });
  }

  Future<void> _saveQuestions(List<QuestionBankQuestion> questions) async {
    final items = questions.map((question) => question.toJson()).toList();
    await (await _store()).writeJson(AtomicJsonFileStore.envelope(items));
  }

  @override
  Future<String> exportToJson() async {
    final questions = await getAllQuestions();
    return json.encode(questions.map((q) => q.toJson()).toList());
  }

  @override
  Future<void> importFromJson(String jsonString) async {
    final decoded = json.decode(jsonString);
    final questions = AtomicJsonFileStore.versionedItems(decoded)
        .whereType<Map>()
        .map(
          (item) => QuestionBankQuestion.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
    await _mutations.run(() => _saveQuestions(questions));
  }
}
