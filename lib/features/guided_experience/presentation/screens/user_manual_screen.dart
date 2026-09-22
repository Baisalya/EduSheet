import 'package:flutter/material.dart';

import '../../demo/guided_demo_screen.dart';
import '../../demo/guided_demo_session.dart';

enum EduSheetManualSection {
  start,
  paper,
  smartEditor,
  planner,
  syllabus,
  lesson,
  files,
  reader,
  backup,
  tools,
}

class EduSheetUserManualScreen extends StatelessWidget {
  const EduSheetUserManualScreen({
    super.key,
    this.focus,
  });

  final EduSheetManualSection? focus;

  @override
  Widget build(BuildContext context) {
    final sections = <_ManualSectionData>[
      const _ManualSectionData(
        id: EduSheetManualSection.start,
        icon: Icons.home_outlined,
        title: 'Start here',
        summary: 'The easiest way to begin using EduSheet.',
        steps: <String>[
          'For question papers, tap Create Paper on the Home screen.',
          'For a completely free Word-style document, tap Smart Editor.',
          'For daily teaching, tap Teaching Planner.',
          'For PDF, Word, Excel or PowerPoint files, tap PDF/Word Reader.',
          'If you are unsure, use the Smart Work Assistant when it appears. It only suggests a next step; it never changes your work by itself.',
        ],
      ),
      const _ManualSectionData(
        id: EduSheetManualSection.paper,
        icon: Icons.note_add_outlined,
        title: 'Create a question paper',
        summary: 'Make, preview and save a paper.',
        steps: <String>[
          'Home → Create Paper.',
          'Open Paper Setup and enter only the details you need.',
          'Add questions. Use Math, Geometry or Question Bank when useful.',
          'Open Preview and check the pages.',
          'Save the editable paper, or export PDF/Word when finished.',
        ],
      ),
      const _ManualSectionData(
        id: EduSheetManualSection.smartEditor,
        icon: Icons.edit_note_rounded,
        title: 'Smart Editor',
        summary: 'Write a normal Word-style document without forced paper structure.',
        steps: <String>[
          'Home → Smart Editor → New document, or Teaching Planner → Syllabus → Resources & Papers → Create Smart Document.',
          'Inside a syllabus item you can also Attach Smart Document to reuse an existing Smart Editor document without making a duplicate copy.',
          'Type freely. Use the ribbon for font, headings, lists, alignment, indent and line spacing.',
          'Use Math to insert an editable equation with the EduSheet Math Keyboard. Tap the equation later to edit it again.',
          'Use Geometry to build an editable diagram. Tap it for size/alignment/wrap tools or double-tap Edit to reopen Geometry Studio.',
          'Use Smart mode for a small adaptive toolbar. Switch to Full when you want every Word-style formatting control.',
          'Type / to open slash commands, or press Ctrl+K on Windows to search actions such as Math, Geometry, page break or styles.',
          'Use + Insert for reusable Instructions, Answer lines or Signature blocks. Everything inserted remains normal editable content.',
          'If EduSheet notices question, section or instruction-like text, it may suggest a style. Tap Apply or Ignore; it never rewrites the text automatically.',
          'Use Header & footer to type any school name, exam title, notes or footer text you want.',
          'Use Page layout for size, orientation, margins and page border.',
          'Open Properties for paragraph controls, reusable styles and manual page/section breaks.',
          'To edit a Word file, open Smart Editor and tap the open-file button, then choose a .docx file. Supported text and formatting become editable; Word tables and images are preserved as document blocks, with advanced table-cell editing still limited.',
          'Use Export → Word (.docx) when another teacher needs a Word copy, or Export → PDF for a print-ready copy. EduSheet Math exports as Word math when supported; Geometry is rendered clearly and stays natively editable when the unchanged EduSheet DOCX returns to EduSheet.',
          'Your document autosaves while you type. On Windows, Ctrl+S saves immediately; the Back button also saves before closing.',
          'If EduSheet or the device closes unexpectedly, Smart Editor keeps a short recovery copy and restores newer unsaved changes the next time you open that document.',
        ],
      ),
      const _ManualSectionData(
        id: EduSheetManualSection.planner,
        icon: Icons.calendar_month_outlined,
        title: 'Teaching Planner',
        summary: 'Set up classes and plan what you will teach.',
        steps: <String>[
          'Home → Teaching Planner.',
          'Add a class. A class name is enough to start.',
          'Open Syllabus and add a subject and chapter.',
          'In Resources & Papers you can create a question paper, create a Smart Document, attach an existing Smart Document, or keep teaching files with that syllabus item.',
          'Removing a Smart Document from a syllabus only removes that planner link; the original document stays safely in Smart Editor.',
          'Plan a lesson for the chapter and choose the date/period.',
          'After teaching, mark the lesson Taught. Finish the chapter only when the chapter is actually complete.',
        ],
      ),
      const _ManualSectionData(
        id: EduSheetManualSection.syllabus,
        icon: Icons.account_tree_outlined,
        title: 'Syllabus',
        summary: 'Keep class → subject → unit → chapter → topic organised.',
        steps: <String>[
          'A simple syllabus only needs Class → Subject → Chapter.',
          'Unit and Topic are optional; add them only when they help.',
          'Use the 3-dot menu (or long-press/right-click) to edit, move, duplicate, archive or move items to Trash.',
          'Chapter progress controls the main syllabus progress. Mark a chapter complete when it is really finished.',
        ],
      ),
      const _ManualSectionData(
        id: EduSheetManualSection.lesson,
        icon: Icons.menu_book_outlined,
        title: 'Plan a lesson',
        summary: 'A short daily workflow for teachers.',
        steps: <String>[
          'Choose Class → Subject → Chapter.',
          'Choose date and period. The chapter name is used as the lesson title unless you change it.',
          'Teaching details such as objective, topics, activities, homework and notes are optional.',
          'Use Teaching Workspace to keep files, notes, links and diagrams with that lesson.',
        ],
      ),
      const _ManualSectionData(
        id: EduSheetManualSection.files,
        icon: Icons.attach_file_rounded,
        title: 'Teaching files and materials',
        summary: 'Keep files safely with a chapter or lesson.',
        steps: <String>[
          'Add to EduSheet is recommended. EduSheet keeps a managed copy for portable backups.',
          'On Windows, Link original keeps the file in its current folder. If that file moves, EduSheet may ask you to Locate or Replace it.',
          'The same managed file can be reused without making unnecessary physical copies.',
          'Removing a file from one lesson does not delete another lesson\'s shared copy.',
        ],
      ),
      const _ManualSectionData(
        id: EduSheetManualSection.reader,
        icon: Icons.description_outlined,
        title: 'Open documents',
        summary: 'Read supported teaching documents inside EduSheet.',
        steps: <String>[
          'Home → PDF/Word Reader → Open file.',
          'PDF, Word, Excel/CSV, PowerPoint and text files open in EduSheet when supported.',
          'You can also use Open with EduSheet from Windows for supported documents.',
          'Recent files are available from the clock/history button on the Home screen while the files still exist.',
        ],
      ),
      const _ManualSectionData(
        id: EduSheetManualSection.backup,
        icon: Icons.inventory_2_outlined,
        title: 'Backup, import and share',
        summary: 'Use .eds and .edtp without losing the original structure.',
        steps: <String>[
          '.eds is the main portable EduSheet package for papers, planner backups and curriculum content.',
          '.edtp is a Teaching Pack for sharing one lesson and its teaching materials.',
          'Settings → Import & Export opens the main portable-file tools.',
          'Before replacing important data, read the import preview. EduSheet keeps conflict and hierarchy checks enabled.',
        ],
      ),
      const _ManualSectionData(
        id: EduSheetManualSection.tools,
        icon: Icons.apps_outlined,
        title: 'Other useful Home tools',
        summary: 'Where to find saved work and everyday teacher utilities.',
        steps: <String>[
          'Smart Editor is the free Word-style space for normal documents without forced question or section structure.',
          'Saved Papers keeps the editable question papers you saved in EduSheet.',
          'Question Bank stores reusable questions. OMR Generator creates answer sheets when you need them.',
          'Calculator is for quick calculations. Word Converter handles supported document conversion tasks.',
          'Settings contains appearance, guides, the User Manual, Import & Export, support and app information.',
        ],
      ),
    ];

    final ordered = focus == null
        ? sections
        : <_ManualSectionData>[
            ...sections.where((item) => item.id == focus),
            ...sections.where((item) => item.id != focus),
          ];

    return Scaffold(
      appBar: AppBar(title: const Text('EduSheet User Manual')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                const _ManualIntroCard(),
                const SizedBox(height: 12),
                _SafeDemoCard(
                  onPaperDemo: () => _openDemo(
                    context,
                    GuidedDemoFeature.createPaper,
                  ),
                  onPlannerDemo: () => _openDemo(
                    context,
                    GuidedDemoFeature.createSyllabus,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Simple instructions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                for (final section in ordered)
                  _ManualSectionCard(
                    data: section,
                    initiallyExpanded: section.id == focus,
                  ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tip: You do not need to fill every field. EduSheet keeps optional details optional. Start with the minimum information and add more only when useful.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  height: 1.45,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDemo(BuildContext context, GuidedDemoFeature feature) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GuidedDemoScreen(feature: feature),
      ),
    );
  }
}

class _ManualIntroCard extends StatelessWidget {
  const _ManualIntroCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_rounded, color: scheme.onPrimaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Short, simple help',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Read only the section you need. Each task is written as a few simple steps. The safe demos use temporary data, so you can practise without changing your real papers or planner.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafeDemoCard extends StatelessWidget {
  const _SafeDemoCard({
    required this.onPaperDemo,
    required this.onPlannerDemo,
  });

  final VoidCallback onPaperDemo;
  final VoidCallback onPlannerDemo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Want to practise first?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Safe Demo uses temporary practice data. Your real work is not changed.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onPaperDemo,
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Create Paper demo'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onPlannerDemo,
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('Planner & Syllabus demo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualSectionData {
  const _ManualSectionData({
    required this.id,
    required this.icon,
    required this.title,
    required this.summary,
    required this.steps,
  });

  final EduSheetManualSection id;
  final IconData icon;
  final String title;
  final String summary;
  final List<String> steps;
}

class _ManualSectionCard extends StatelessWidget {
  const _ManualSectionCard({
    required this.data,
    required this.initiallyExpanded,
  });

  final _ManualSectionData data;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(data.icon),
        title: Text(
          data.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(data.summary),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (var index = 0; index < data.steps.length; index++)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        data.steps[index],
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
