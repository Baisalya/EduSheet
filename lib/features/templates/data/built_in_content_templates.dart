import '../../editor/domain/models/paper_model.dart';
import '../domain/models/content_template.dart';

class BuiltInContentTemplates {
  static final DateTime _createdAt = DateTime.utc(2026, 7, 19);

  static final List<SectionTemplate> sections = [
    _section('builtin-section-mcq', 'Section A: Multiple Choice', 'Choose the correct answer.', 1),
    _section('builtin-section-short', 'Section B: Short Answers', 'Answer briefly.', 2),
    _section('builtin-section-long', 'Section C: Long Answers', 'Show complete working.', 5),
    _section('builtin-section-numerical', 'Section D: Numerical Problems', 'Write formula, substitution and answer with units.', 3),
  ];

  static final List<PaperBlueprint> papers = [
    _paper('unit-test', 'School unit test', 'Short classroom assessment', 'Unit Test', ['Multiple Choice', 'Short Answers'], 'school_ssvm_style'),
    _paper('monthly-exam', 'Monthly examination', 'Monthly subject examination', 'Monthly Examination', ['Section A', 'Section B', 'Section C'], 'school_dps_style'),
    _paper('term-exam', 'Term examination', 'Formal term paper with three sections', 'Term Examination', ['Objective', 'Short Answers', 'Long Answers'], 'school_xavier_style'),
    _paper('board-exam', 'Board-style examination', 'Board-style instructions and structured sections', 'Board Examination', ['Section A', 'Section B', 'Section C', 'Section D'], 'board_cbse'),
    _paper('math-worksheet', 'Mathematics worksheet', 'Practice sheet for mathematical work', 'Mathematics Worksheet', ['Practice Questions'], 'coaching_minimal'),
    _paper('practice-assignment', 'Practice assignment', 'Take-home practice paper', 'Practice Assignment', ['Questions'], 'school_modern_left'),
    _paper('mcq-test', 'Multiple-choice test', 'Objective paper ready for OMR', 'Multiple-Choice Test', ['Multiple Choice'], 'coaching_akash', includeOmr: true),
    _paper('qa-booklet', 'Question-and-answer booklet', 'Paper with answer space after each question', 'Question-and-Answer Booklet', ['Questions and Answers'], 'college_formal'),
    _paper('answer-sheet', 'Answer sheet', 'Student information and ruled response sections', 'Answer Sheet', ['Answers'], 'coaching_minimal'),
    _paper('custom-blank', 'Custom blank template', 'Minimal blank paper ready to customise', '{{exam_name}}', const [], 'coaching_minimal'),
  ];

  static SectionTemplate _section(
    String id,
    String name,
    String instruction,
    double marks,
  ) {
    return SectionTemplate(
      id: id,
      name: name,
      description: instruction,
      isBuiltIn: true,
      createdAt: _createdAt,
      modifiedAt: _createdAt,
      section: PaperSection(
        id: '$id-source',
        title: name.split(':').last.trim(),
        instruction: instruction,
        prefix: name.split(':').first,
        questions: [
          Question(
            id: '$id-placeholder',
            text: 'Replace this sample question',
            marks: marks,
            status: QuestionStatus.draft,
            createdAt: _createdAt,
            modifiedAt: _createdAt,
          ),
        ],
      ),
    );
  }

  static PaperBlueprint _paper(
    String id,
    String name,
    String description,
    String examName,
    List<String> sectionNames,
    String visualTemplateId, {
    bool includeOmr = false,
  }) {
    return PaperBlueprint(
      id: 'builtin-paper-$id',
      name: name,
      description: description,
      isBuiltIn: true,
      createdAt: _createdAt,
      modifiedAt: _createdAt,
      variableDefaults: {
        'school_name': 'My School',
        'exam_name': examName,
        'class': '',
        'subject': 'Mathematics',
        'date': '',
        'duration': '3 Hours',
        'maximum_marks': '100',
        'teacher_name': '',
        'academic_year': '2026-27',
      },
      paper: Paper(
        id: 'builtin-paper-$id-source',
        title: examName,
        schoolName: '{{school_name}}',
        instruction:
            'Read every question carefully. Show all necessary working.',
        includeOmr: includeOmr,
        templateId: visualTemplateId,
        createdAt: _createdAt,
        headerFields: [
          PaperHeaderField(id: '$id-subject', label: 'Subject', value: '{{subject}}'),
          PaperHeaderField(id: '$id-class', label: 'Class', value: '{{class}}'),
          PaperHeaderField(id: '$id-year', label: 'Academic Year', value: '{{academic_year}}'),
          PaperHeaderField(id: '$id-date', label: 'Date', value: '{{date}}'),
          PaperHeaderField(id: '$id-time', label: 'Duration', value: '{{duration}}'),
          PaperHeaderField(id: '$id-marks', label: 'Maximum Marks', value: '{{maximum_marks}}'),
          PaperHeaderField(id: '$id-student', label: 'Student Name', isPlaceholder: true),
          PaperHeaderField(id: '$id-roll', label: 'Roll No', isPlaceholder: true),
        ],
        sections: sectionNames.asMap().entries.map((entry) {
          return PaperSection(
            id: '$id-section-${entry.key}',
            title: entry.value,
            prefix: 'Section ${String.fromCharCode(65 + entry.key)}',
            instruction: 'Add questions for ${entry.value}.',
          );
        }).toList(),
      ),
    );
  }
}
