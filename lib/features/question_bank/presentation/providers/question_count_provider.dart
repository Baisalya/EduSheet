import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'question_count_provider.g.dart';

@riverpod
class QuestionCount extends _$QuestionCount {
  @override
  int build() => 0;

  void increment() => state++;
  void decrement() {
    if (state > 0) state--;
  }
}
