import 'package:edusheet/features/pdf/domain/models/paper_template.dart';
import 'package:pdf/pdf.dart';

enum PaperStyleCategory { school, board, college, coaching, primary }

class PaperStylePreset {
  final PaperTemplate template;
  final PaperStyleCategory category;
  final String description;
  final String bestFor;
  final bool recommended;
  final bool legacyOnly;

  const PaperStylePreset({
    required this.template,
    required this.category,
    required this.description,
    required this.bestFor,
    this.recommended = false,
    this.legacyOnly = false,
  });
}

/// Curated teacher-facing style catalog.
///
/// Internal IDs from previous releases are preserved in [allBuiltInTemplates]
/// so saved papers keep resolving, while the visible catalog uses neutral
/// professional names and never claims affiliation with an examination board
/// or institution.
class PaperStyleCatalog {
  const PaperStyleCatalog._();

  static const String defaultTemplateId = 'school_formal';

  static final List<PaperStylePreset> presets = [
    PaperStylePreset(
      template: const PaperTemplate(
        id: defaultTemplateId,
        name: 'School Formal',
        type: TemplateType.school,
        headerLayout: HeaderLayout.centered,
        headerFontSize: 18,
        questionFontSize: 11.5,
      ),
      category: PaperStyleCategory.school,
      description: 'Balanced, formal and easy to photocopy.',
      bestFor: 'Unit, periodic, half-yearly and annual exams',
      recommended: true,
    ),
    PaperStylePreset(
      template: const PaperTemplate(
        id: 'school_modern_left',
        name: 'School Compact',
        type: TemplateType.school,
        headerLayout: HeaderLayout.logoLeft,
        headerFontSize: 17,
        questionFontSize: 11,
        primaryColor: PdfColors.blueGrey900,
      ),
      category: PaperStyleCategory.school,
      description: 'Compact identity header with more room for questions.',
      bestFor: 'Class tests and shorter school examinations',
    ),
    PaperStylePreset(
      template: const PaperTemplate(
        id: 'board_cbse',
        name: 'Board Exam Classic',
        type: TemplateType.board,
        headerLayout: HeaderLayout.dps,
        headerFontSize: 17,
        questionFontSize: 11,
        primaryColor: PdfColors.black,
      ),
      category: PaperStyleCategory.board,
      description: 'Conservative black-and-white formal examination layout.',
      bestFor: 'Mock boards, pre-boards and formal high-school papers',
      recommended: true,
    ),
    PaperStylePreset(
      template: const PaperTemplate(
        id: 'board_icse',
        name: 'Board Exam Structured',
        type: TemplateType.board,
        headerLayout: HeaderLayout.ssvm,
        headerFontSize: 17,
        questionFontSize: 11,
        primaryColor: PdfColors.black,
        hasBorder: true,
      ),
      category: PaperStyleCategory.board,
      description: 'Strong metadata structure with a restrained border.',
      bestFor: 'Long formal examinations and practice papers',
    ),
    PaperStylePreset(
      template: const PaperTemplate(
        id: 'college_formal',
        name: 'University Semester',
        type: TemplateType.college,
        headerLayout: HeaderLayout.academic,
        headerFontSize: 18,
        questionFontSize: 11,
        primaryColor: PdfColors.grey900,
      ),
      category: PaperStyleCategory.college,
      description: 'Academic header with space for course and paper details.',
      bestFor: 'College and university semester examinations',
      recommended: true,
    ),
    PaperStylePreset(
      template: const PaperTemplate(
        id: 'college_modern',
        name: 'Institutional Modern',
        type: TemplateType.college,
        headerLayout: HeaderLayout.modernCoaching,
        headerFontSize: 17,
        questionFontSize: 11,
        primaryColor: PdfColors.blueGrey800,
        secondaryColor: PdfColors.blue100,
      ),
      category: PaperStyleCategory.college,
      description: 'Modern identity treatment without decorative clutter.',
      bestFor: 'Institutes, colleges and internal assessments',
    ),
    PaperStylePreset(
      template: const PaperTemplate(
        id: 'college_semester',
        name: 'Minimal Print',
        type: TemplateType.college,
        headerLayout: HeaderLayout.minimal,
        headerFontSize: 16,
        questionFontSize: 10.5,
        primaryColor: PdfColors.black,
      ),
      category: PaperStyleCategory.college,
      description: 'Maximum usable page space and low ink usage.',
      bestFor: 'Dense papers and economical printing',
    ),
    PaperStylePreset(
      template: const PaperTemplate(
        id: 'coaching_minimal',
        name: 'Coaching Mock',
        type: TemplateType.coaching,
        headerLayout: HeaderLayout.modernCoaching,
        headerFontSize: 16,
        questionFontSize: 10.5,
        primaryColor: PdfColors.blueGrey900,
        secondaryColor: PdfColors.blue100,
      ),
      category: PaperStyleCategory.coaching,
      description: 'Compact mock-test header with clear hierarchy.',
      bestFor: 'Competitive practice and coaching assessments',
      recommended: true,
    ),
    PaperStylePreset(
      template: const PaperTemplate(
        id: 'kids_playful',
        name: 'Primary Friendly',
        type: TemplateType.kids,
        headerLayout: HeaderLayout.centered,
        headerFontSize: 20,
        questionFontSize: 13,
        primaryColor: PdfColors.blue800,
        secondaryColor: PdfColors.blue100,
        hasBorder: true,
      ),
      category: PaperStyleCategory.primary,
      description: 'Larger text and friendly spacing while staying printable.',
      bestFor: 'Classes 1–5 tests and activity papers',
    ),
    PaperStylePreset(
      template: const PaperTemplate(
        id: 'kids_creative',
        name: 'Primary Worksheet',
        type: TemplateType.kids,
        headerLayout: HeaderLayout.logoRight,
        headerFontSize: 19,
        questionFontSize: 13,
        primaryColor: PdfColors.orange400,
        secondaryColor: PdfColors.orange100,
      ),
      category: PaperStyleCategory.primary,
      description: 'Simple worksheet identity with generous reading space.',
      bestFor: 'Homework, worksheets and classroom activities',
    ),
  ];

  /// Compatibility-only definitions for IDs shipped by earlier releases.
  /// They deliberately use neutral layouts/names and are hidden from the main
  /// chooser so an old saved paper remains printable without preserving old
  /// imitation branding.
  static final List<PaperStylePreset> legacyPresets = [
    PaperStylePreset(
      template: const PaperTemplate(
        id: 'school_ssvm_style',
        name: 'Legacy School Structured',
        type: TemplateType.school,
        headerLayout: HeaderLayout.ssvm,
        hasBorder: true,
        headerFontSize: 18,
        questionFontSize: 11,
      ),
      category: PaperStyleCategory.school,
      description: 'Compatibility style for an older saved paper.',
      bestFor: 'Legacy documents',
      legacyOnly: true,
    ),
    PaperStylePreset(
      template: const PaperTemplate(
        id: 'school_dps_style',
        name: 'Legacy School Classic',
        type: TemplateType.school,
        headerLayout: HeaderLayout.dps,
        headerFontSize: 17,
        questionFontSize: 11,
      ),
      category: PaperStyleCategory.school,
      description: 'Compatibility style for an older saved paper.',
      bestFor: 'Legacy documents',
      legacyOnly: true,
    ),
    PaperStylePreset(
      template: const PaperTemplate(
        id: 'school_xavier_style',
        name: 'Legacy Academic Formal',
        type: TemplateType.school,
        headerLayout: HeaderLayout.academic,
        hasBorder: true,
        headerFontSize: 18,
        questionFontSize: 11,
      ),
      category: PaperStyleCategory.school,
      description: 'Compatibility style for an older saved paper.',
      bestFor: 'Legacy documents',
      legacyOnly: true,
    ),
    PaperStylePreset(
      template: const PaperTemplate(
        id: 'coaching_allen',
        name: 'Legacy Coaching Modern',
        type: TemplateType.coaching,
        headerLayout: HeaderLayout.modernCoaching,
        headerFontSize: 16,
        questionFontSize: 11,
      ),
      category: PaperStyleCategory.coaching,
      description: 'Compatibility style for an older saved paper.',
      bestFor: 'Legacy documents',
      legacyOnly: true,
    ),
    PaperStylePreset(
      template: const PaperTemplate(
        id: 'coaching_akash',
        name: 'Legacy Coaching Compact',
        type: TemplateType.coaching,
        headerLayout: HeaderLayout.logoLeft,
        headerFontSize: 16,
        questionFontSize: 11,
      ),
      category: PaperStyleCategory.coaching,
      description: 'Compatibility style for an older saved paper.',
      bestFor: 'Legacy documents',
      legacyOnly: true,
    ),
    PaperStylePreset(
      template: const PaperTemplate(
        id: 'kids_cartoon',
        name: 'Legacy Primary Friendly',
        type: TemplateType.kids,
        headerLayout: HeaderLayout.centered,
        hasBorder: true,
        headerFontSize: 20,
        questionFontSize: 13,
      ),
      category: PaperStyleCategory.primary,
      description: 'Compatibility style for an older saved paper.',
      bestFor: 'Legacy documents',
      legacyOnly: true,
    ),
  ];

  static List<PaperTemplate> get visibleTemplates =>
      List.unmodifiable(presets.map((preset) => preset.template));

  static List<PaperTemplate> get allBuiltInTemplates => List.unmodifiable([
    ...presets.map((preset) => preset.template),
    ...legacyPresets.map((preset) => preset.template),
  ]);

  static PaperStylePreset? presetForId(String id) {
    for (final preset in [...presets, ...legacyPresets]) {
      if (preset.template.id == id) return preset;
    }
    return null;
  }

  static bool isVisibleBuiltIn(String id) =>
      presets.any((preset) => preset.template.id == id);
}
