import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/presentation/widgets/paper_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('section card exposes smart structure and drag handles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final section = PaperSection(
      id: 's1',
      title: 'Group A',
      requiredCount: 1,
      numberingStyle: QuestionNumberStyle.lowerAlpha,
      defaultMarks: 2,
      answerSpaceLines: 3,
      questions: [
        Question(id: 'q1', text: 'First', marks: 2),
        Question(id: 'q2', text: 'Second', marks: 2),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReorderableListView(
            buildDefaultDragHandles: false,
            onReorderItem: (_, _) {},
            children: [
              PaperSectionCard(
                key: const ValueKey('section'),
                section: section,
                sectionNumber: 1,
                paperNumberingStyle: QuestionNumberStyle.number,
                sectionReorderIndex: 0,
                onReorderQuestions: (_, _) {},
                onAddQuestion: () {},
                onAddFromBank: () {},
                onEditQuestion: (_) {},
                onDuplicateQuestion: (_) {},
                onDeleteQuestion: (_) {},
                onSaveQuestionToBank: (_) {},
                onRename: () {},
                onEditInstruction: () {},
                onEditStructure: () {},
                onDuplicateSection: () {},
                onDeleteSection: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('Answer any 1'), findsOneWidget);
    expect(find.text('2 default marks'), findsOneWidget);
    expect(find.text('3 answer lines'), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
