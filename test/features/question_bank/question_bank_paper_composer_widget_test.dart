import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty paper section offers new question and Question Bank', (
    tester,
  ) async {
    var wrote = false;
    var openedBank = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaperSectionCard(
            section: PaperSection(id: 's1', title: 'Section A'),
            sectionNumber: 1,
            onAddQuestion: () => wrote = true,
            onAddFromBank: () => openedBank = true,
            onEditQuestion: (_) {},
            onDuplicateQuestion: (_) {},
            onDeleteQuestion: (_) {},
            onSaveQuestionToBank: (_) {},
            onRename: () {},
            onEditInstruction: () {},
            onDuplicateSection: () {},
            onDeleteSection: () {},
          ),
        ),
      ),
    );

    expect(find.text('Write question'), findsOneWidget);
    expect(find.text('Choose from bank'), findsOneWidget);

    await tester.tap(find.text('Write question'));
    expect(wrote, isTrue);
    await tester.tap(find.text('Choose from bank'));
    expect(openedBank, isTrue);
  });
}
