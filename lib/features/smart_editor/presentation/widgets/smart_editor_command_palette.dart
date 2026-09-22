import 'package:flutter/material.dart';

enum SmartEditorCommandId {
  math,
  geometry,
  pageBreak,
  sectionBreak,
  titleStyle,
  heading1,
  heading2,
  questionStyle,
  sectionStyle,
  instructionStyle,
  normalStyle,
  instructionsBlock,
  answerLines,
  signatureBlock,
  pageLayout,
  headerFooter,
  properties,
  exportDocx,
  exportPdf,
}

class SmartEditorCommandDescriptor {
  const SmartEditorCommandDescriptor({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.keywords = '',
  });

  final SmartEditorCommandId id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String keywords;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$title $subtitle $keywords'.toLowerCase().contains(q);
  }
}

const smartEditorAllCommands = <SmartEditorCommandDescriptor>[
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.math,
    title: 'Insert Math',
    subtitle: 'Editable equation with Math Keyboard',
    icon: Icons.functions_rounded,
    keywords: 'equation formula fraction root algebra',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.geometry,
    title: 'Insert Geometry',
    subtitle: 'Editable diagram from Geometry Studio',
    icon: Icons.change_history_rounded,
    keywords: 'diagram triangle circle graph',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.pageBreak,
    title: 'Page break',
    subtitle: 'Start content on a new page boundary',
    icon: Icons.insert_page_break_outlined,
    keywords: 'new page break',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.sectionBreak,
    title: 'Section break',
    subtitle: 'Insert a semantic section boundary',
    icon: Icons.segment_rounded,
    keywords: 'section part break',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.titleStyle,
    title: 'Title style',
    subtitle: 'Large document title',
    icon: Icons.title_rounded,
    keywords: 'heading title h1',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.heading1,
    title: 'Heading 1',
    subtitle: 'Primary heading style',
    icon: Icons.format_size_rounded,
    keywords: 'heading h2',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.heading2,
    title: 'Heading 2',
    subtitle: 'Secondary heading style',
    icon: Icons.text_fields_rounded,
    keywords: 'heading h3',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.questionStyle,
    title: 'Question style',
    subtitle: 'Convert paragraph to numbered question styling',
    icon: Icons.quiz_outlined,
    keywords: 'question convert academic',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.sectionStyle,
    title: 'Section style',
    subtitle: 'Convert paragraph to a strong section heading',
    icon: Icons.view_agenda_outlined,
    keywords: 'section heading convert',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.instructionStyle,
    title: 'Instruction style',
    subtitle: 'Emphasize directions without locking the layout',
    icon: Icons.info_outline_rounded,
    keywords: 'instruction directions note',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.normalStyle,
    title: 'Normal text',
    subtitle: 'Return the paragraph to normal editable text',
    icon: Icons.subject_rounded,
    keywords: 'normal clear convert',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.instructionsBlock,
    title: 'Instructions block',
    subtitle: 'Insert a reusable editable instructions starter',
    icon: Icons.rule_rounded,
    keywords: 'reusable instructions block',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.answerLines,
    title: 'Answer lines',
    subtitle: 'Insert editable answer writing lines',
    icon: Icons.horizontal_rule_rounded,
    keywords: 'answer blank lines space',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.signatureBlock,
    title: 'Signature block',
    subtitle: 'Insert an editable signature line',
    icon: Icons.draw_outlined,
    keywords: 'signature teacher principal block',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.pageLayout,
    title: 'Page layout',
    subtitle: 'Margins, size, orientation and border',
    icon: Icons.straighten_rounded,
    keywords: 'margin a4 landscape portrait border',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.headerFooter,
    title: 'Header & footer',
    subtitle: 'Edit free header and footer text',
    icon: Icons.view_agenda_outlined,
    keywords: 'header footer page',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.properties,
    title: 'Properties',
    subtitle: 'Open paragraph and page controls',
    icon: Icons.tune_rounded,
    keywords: 'properties panel formatting',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.exportDocx,
    title: 'Export Word (.docx)',
    subtitle: 'Save an editable Microsoft Word compatible copy',
    icon: Icons.description_outlined,
    keywords: 'word docx export save share',
  ),
  SmartEditorCommandDescriptor(
    id: SmartEditorCommandId.exportPdf,
    title: 'Export PDF',
    subtitle: 'Create a print-ready PDF copy',
    icon: Icons.picture_as_pdf_outlined,
    keywords: 'pdf export print save',
  ),
];

class SmartEditorCommandPalette extends StatefulWidget {
  const SmartEditorCommandPalette({
    super.key,
    required this.commands,
    this.initialQuery = '',
    this.title = 'Commands',
    this.searchEnabled = true,
  });

  final List<SmartEditorCommandDescriptor> commands;
  final String initialQuery;
  final String title;
  final bool searchEnabled;

  static Future<SmartEditorCommandId?> show(
    BuildContext context, {
    required List<SmartEditorCommandDescriptor> commands,
    String initialQuery = '',
    String title = 'Commands',
    bool searchEnabled = true,
  }) {
    return showModalBottomSheet<SmartEditorCommandId>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.72,
        child: SmartEditorCommandPalette(
          commands: commands,
          initialQuery: initialQuery,
          title: title,
          searchEnabled: searchEnabled,
        ),
      ),
    );
  }

  @override
  State<SmartEditorCommandPalette> createState() =>
      _SmartEditorCommandPaletteState();
}

class _SmartEditorCommandPaletteState
    extends State<SmartEditorCommandPalette> {
  late final TextEditingController _queryController;
  late String _query;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _queryController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.commands.where((item) => item.matches(_query)).toList();
    return Column(
      key: const Key('smart-editor-command-palette'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded),
              const SizedBox(width: 8),
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${visible.length}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
        if (widget.searchEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              key: const Key('smart-editor-command-search'),
              controller: _queryController,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search actions…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('No matching command'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final command = visible[index];
                    return ListTile(
                      key: ValueKey('smart-editor-command-${command.id.name}'),
                      leading: Icon(command.icon),
                      title: Text(command.title),
                      subtitle: Text(command.subtitle),
                      onTap: () => Navigator.pop(context, command.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
