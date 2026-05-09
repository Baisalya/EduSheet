import '../../domain/models/question_bank_model.dart';

abstract class QuestionBankRepository {
  Future<List<QuestionBankQuestion>> getAllQuestions();
  Future<void> addQuestion(QuestionBankQuestion question);
  Future<void> updateQuestion(QuestionBankQuestion question);
  Future<void> deleteQuestion(String id);
  Future<String> exportToJson();
  Future<void> importFromJson(String jsonString);
}
