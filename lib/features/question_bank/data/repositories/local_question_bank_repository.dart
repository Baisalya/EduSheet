import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/question_bank_model.dart';
import 'question_bank_repository.dart';

class LocalQuestionBankRepository implements QuestionBankRepository {
  static const String _fileName = 'question_bank.json';

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  @override
  Future<List<QuestionBankQuestion>> getAllQuestions() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];
      
      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      return jsonList.map((e) => QuestionBankQuestion.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> addQuestion(QuestionBankQuestion question) async {
    final questions = await getAllQuestions();
    questions.add(question);
    await _saveQuestions(questions);
  }

  @override
  Future<void> updateQuestion(QuestionBankQuestion question) async {
    final questions = await getAllQuestions();
    final index = questions.indexWhere((q) => q.question.id == question.question.id);
    if (index != -1) {
      questions[index] = question;
      await _saveQuestions(questions);
    }
  }

  @override
  Future<void> deleteQuestion(String id) async {
    final questions = await getAllQuestions();
    questions.removeWhere((q) => q.question.id == id);
    await _saveQuestions(questions);
  }

  Future<void> _saveQuestions(List<QuestionBankQuestion> questions) async {
    final file = await _getFile();
    final jsonList = questions.map((q) => q.toJson()).toList();
    await file.writeAsString(json.encode(jsonList));
  }

  @override
  Future<String> exportToJson() async {
    final questions = await getAllQuestions();
    return json.encode(questions.map((q) => q.toJson()).toList());
  }

  @override
  Future<void> importFromJson(String jsonString) async {
    final List<dynamic> jsonList = json.decode(jsonString);
    final questions = jsonList.map((e) => QuestionBankQuestion.fromJson(e)).toList();
    await _saveQuestions(questions);
  }
}
