import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/editor/services/question_numbering_service.dart';
import 'package:edusheet/shared/presentation/widgets/adaptive_modal_bottom_sheet.dart';
import 'package:flutter/material.dart';

class SectionFormatDraft {
  final String prefix;
  final int? requiredCount;
  final QuestionNumberStyle? numberingStyle;
  final double? defaultMarks;
  final bool showTitle;
  final bool showDivider;
  final bool pageBreakBefore;
  final int answerSpaceLines;
  final bool ruledAnswerArea;
  final bool graphAnswerArea;

  const SectionFormatDraft({
    required this.prefix,
    required this.requiredCount,
    required this.numberingStyle,
    required this.defaultMarks,
    required this.showTitle,
    required this.showDivider,
    required this.pageBreakBefore,
    required this.answerSpaceLines,
    required this.ruledAnswerArea,
    required this.graphAnswerArea,
  });
}

class SectionFormatSheet extends StatefulWidget {
  final PaperSection section;
  final QuestionNumberStyle paperNumberingStyle;

  const SectionFormatSheet({
    super.key,
    required this.section,
    required this.paperNumberingStyle,
  });

  static Future<SectionFormatDraft?> show(
    BuildContext context, {
    required PaperSection section,
    required QuestionNumberStyle paperNumberingStyle,
  }) {
    return showAdaptiveModalBottomSheet<SectionFormatDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SectionFormatSheet(
        section: section,
        paperNumberingStyle: paperNumberingStyle,
      ),
    );
  }

  @override
  State<SectionFormatSheet> createState() => _SectionFormatSheetState();
}

class _SectionFormatSheetState extends State<SectionFormatSheet> {
  late final TextEditingController _prefixController;
  late final TextEditingController _requiredController;
  late final TextEditingController _defaultMarksController;
  late bool _answerAll;
  late String _numberingKey;
  late bool _showTitle;
  late bool _showDivider;
  late bool _pageBreakBefore;
  late int _answerSpaceLines;
  late _AnswerAreaKind _answerArea;
  String? _requiredError;
  String? _marksError;

  @override
  void initState() {
    super.initState();
    final section = widget.section;
    _prefixController = TextEditingController(text: section.prefix);
    _requiredController = TextEditingController(
      text: section.requiredCount?.toString() ?? '',
    );
    _defaultMarksController = TextEditingController(
      text: section.defaultMarks == null
          ? ''
          : _formatMarks(section.defaultMarks!),
    );
    _answerAll = section.requiredCount == null;
    _numberingKey = section.numberingStyle?.name ?? '_paper';
    _showTitle = section.showTitle;
    _showDivider = section.showDivider;
    _pageBreakBefore = section.pageBreakBefore;
    _answerSpaceLines = section.answerSpaceLines.clamp(0, 12).toInt();
    _answerArea = section.graphAnswerArea
        ? _AnswerAreaKind.graph
        : section.ruledAnswerArea
        ? _AnswerAreaKind.ruled
        : _AnswerAreaKind.plain;
  }

  @override
  void dispose() {
    _prefixController.dispose();
    _requiredController.dispose();
    _defaultMarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxQuestions = widget.section.questions
        .where((question) => !question.isOptional)
        .length;

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Section format'),
          actions: [
            TextButton(onPressed: _save, child: const Text('Apply')),
            const SizedBox(width: 6),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              widget.section.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _prefixController,
              decoration: const InputDecoration(
                labelText: 'Prefix (optional)',
                hintText: 'Example: Group A, Part I',
                helperText: 'Shown before the section title.',
              ),
            ),
            const SizedBox(height: 18),
            _SectionHeading(
              title: 'Student answer rule',
              subtitle: maxQuestions == 0
                  ? 'Add questions first, then set Answer any N.'
                  : '$maxQuestions compulsory-question slot${maxQuestions == 1 ? '' : 's'} available.',
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Answer all')),
                ButtonSegment(value: false, label: Text('Answer any')),
              ],
              selected: {_answerAll},
              onSelectionChanged: (selection) {
                setState(() {
                  _answerAll = selection.first;
                  _requiredError = null;
                });
              },
            ),
            if (!_answerAll) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _requiredController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Questions students must answer',
                  hintText: maxQuestions == 0 ? '0' : '1 – $maxQuestions',
                  errorText: _requiredError,
                ),
              ),
            ],
            const SizedBox(height: 22),
            _SectionHeading(
              title: 'Question numbering',
              subtitle:
                  'Section numbering can override the paper style without changing saved question text.',
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _numberingKey,
              decoration: const InputDecoration(labelText: 'Numbering style'),
              items: [
                DropdownMenuItem<String>(
                  value: '_paper',
                  child: Text(
                    'Use paper style (${QuestionNumberingService.displayName(widget.paperNumberingStyle)})',
                  ),
                ),
                ...QuestionNumberStyle.values
                    .where((style) => style != QuestionNumberStyle.custom)
                    .map(
                      (style) => DropdownMenuItem<String>(
                        value: style.name,
                        child: Text(
                          QuestionNumberingService.displayName(style),
                        ),
                      ),
                    ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _numberingKey = value);
              },
            ),
            const SizedBox(height: 22),
            _SectionHeading(
              title: 'New-question defaults',
              subtitle:
                  'A section default saves taps on repeated 1-mark, 2-mark or 5-mark groups. Existing questions are not changed.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _defaultMarksController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Default marks (optional)',
                hintText: 'Example: 2',
                errorText: _marksError,
              ),
            ),
            const SizedBox(height: 22),
            _SectionHeading(
              title: 'Printed structure',
              subtitle: 'These choices affect Preview, PDF and Word layout.',
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show section title'),
              value: _showTitle,
              onChanged: (value) => setState(() => _showTitle = value),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show divider'),
              value: _showDivider,
              onChanged: (value) => setState(() => _showDivider = value),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start on a new page'),
              value: _pageBreakBefore,
              onChanged: (value) => setState(() => _pageBreakBefore = value),
            ),
            const SizedBox(height: 16),
            _SectionHeading(
              title: 'Answer space',
              subtitle:
                  'Reserve reusable writing space after every question in this section.',
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _answerSpaceLines.toDouble(),
                    min: 0,
                    max: 12,
                    divisions: 12,
                    label: '$_answerSpaceLines lines',
                    onChanged: (value) =>
                        setState(() => _answerSpaceLines = value.round()),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    _answerSpaceLines == 0
                        ? 'None'
                        : '$_answerSpaceLines line${_answerSpaceLines == 1 ? '' : 's'}',
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            if (_answerSpaceLines > 0) ...[
              const SizedBox(height: 8),
              SegmentedButton<_AnswerAreaKind>(
                segments: const [
                  ButtonSegment(
                    value: _AnswerAreaKind.plain,
                    label: Text('Plain'),
                  ),
                  ButtonSegment(
                    value: _AnswerAreaKind.ruled,
                    label: Text('Ruled'),
                  ),
                  ButtonSegment(
                    value: _AnswerAreaKind.graph,
                    label: Text('Graph'),
                  ),
                ],
                selected: {_answerArea},
                onSelectionChanged: (selection) =>
                    setState(() => _answerArea = selection.first),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _save() {
    final maxQuestions = widget.section.questions
        .where((question) => !question.isOptional)
        .length;
    int? requiredCount;
    if (!_answerAll) {
      requiredCount = int.tryParse(_requiredController.text.trim());
      if (requiredCount == null ||
          requiredCount <= 0 ||
          maxQuestions == 0 ||
          requiredCount > maxQuestions) {
        setState(() {
          _requiredError = maxQuestions == 0
              ? 'Add questions before using Answer any.'
              : 'Enter a number from 1 to $maxQuestions';
        });
        return;
      }
    }

    final rawMarks = _defaultMarksController.text.trim();
    final defaultMarks = rawMarks.isEmpty ? null : double.tryParse(rawMarks);
    if (rawMarks.isNotEmpty &&
        (defaultMarks == null || !defaultMarks.isFinite || defaultMarks <= 0)) {
      setState(() => _marksError = 'Enter marks above 0, or leave blank');
      return;
    }

    Navigator.pop(
      context,
      SectionFormatDraft(
        prefix: _prefixController.text.trim(),
        requiredCount: requiredCount,
        numberingStyle: _numberingKey == '_paper'
            ? null
            : QuestionNumberStyle.values.firstWhere(
                (style) => style.name == _numberingKey,
              ),
        defaultMarks: defaultMarks,
        showTitle: _showTitle,
        showDivider: _showDivider,
        pageBreakBefore: _pageBreakBefore,
        answerSpaceLines: _answerSpaceLines,
        ruledAnswerArea:
            _answerSpaceLines > 0 && _answerArea == _AnswerAreaKind.ruled,
        graphAnswerArea:
            _answerSpaceLines > 0 && _answerArea == _AnswerAreaKind.graph,
      ),
    );
  }

  static String _formatMarks(double marks) {
    return marks == marks.roundToDouble()
        ? marks.toInt().toString()
        : marks.toStringAsFixed(1);
  }
}

enum _AnswerAreaKind { plain, ruled, graph }

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
