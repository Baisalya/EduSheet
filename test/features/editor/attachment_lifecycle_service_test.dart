import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/attachment_lifecycle_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds nested references and reports only true orphans', () {
    final child = Question(
      id: 'child',
      text: 'Child',
      attachments: const [
        QuestionAttachment(
          id: 'attachment',
          kind: QuestionAttachmentKind.image,
          path: '/managed/child.png',
          alternativeText: 'Triangle',
        ),
      ],
    );
    final paper = Paper(
      id: 'paper',
      title: 'Paper',
      createdAt: DateTime.utc(2025),
      logos: const ['/managed/logo.png'],
      sections: [
        PaperSection(
          id: 'section',
          title: 'A',
          questions: [
            Question(id: 'parent', text: 'Parent', subQuestions: [child]),
          ],
        ),
      ],
    );

    const service = AttachmentLifecycleService();
    expect(
      service.orphanPaths(
        const [
          '/managed/logo.png',
          '/managed/child.png',
          '/managed/orphan.png',
        ],
        [paper],
      ),
      {'/managed/orphan.png'},
    );
  });
}
