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
  final bool showTopDivider;
  final bool showBottomDivider;
  final PaperTextAlignment headingAlignment;
  final PaperTextAlignment instructionAlignment;
  final PaperTextAlignment answerRuleAlignment;
  final bool showInstructionLabel;
  final bool headingBold;
  final bool headingUppercase;
  final bool headingBoxed;
  final SectionHeadingSize headingSize;
  final SectionSpacing spacing;
  final SectionMarksDisplay sectionMarksDisplay;
  final QuestionMarksPlacement questionMarksPlacement;
  final bool keepTogether;
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
    required this.showTopDivider,
    required this.showBottomDivider,
    required this.headingAlignment,
    required this.instructionAlignment,
    required this.answerRuleAlignment,
    required this.showInstructionLabel,
    required this.headingBold,
    required this.headingUppercase,
    required this.headingBoxed,
    required this.headingSize,
    required this.spacing,
    required this.sectionMarksDisplay,
    required this.questionMarksPlacement,
    required this.keepTogether,
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
  late bool _showTopDivider;
  late bool _showBottomDivider;
  late PaperTextAlignment _headingAlignment;
  late PaperTextAlignment _instructionAlignment;
  late PaperTextAlignment _answerRuleAlignment;
  late bool _showInstructionLabel;
  late bool _headingBold;
  late bool _headingUppercase;
  late bool _headingBoxed;
  late SectionHeadingSize _headingSize;
  late SectionSpacing _spacing;
  late SectionMarksDisplay _sectionMarksDisplay;
  late QuestionMarksPlacement _questionMarksPlacement;
  late bool _keepTogether;
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
    _showTopDivider = section.showTopDivider;
    _showBottomDivider = section.showBottomDivider;
    _headingAlignment = section.headingAlignment;
    _instructionAlignment = section.instructionAlignment;
    _answerRuleAlignment = section.answerRuleAlignment;
    _showInstructionLabel = section.showInstructionLabel;
    _headingBold = section.headingBold;
    _headingUppercase = section.headingUppercase;
    _headingBoxed = section.headingBoxed;
    _headingSize = section.headingSize;
    _spacing = section.spacing;
    _sectionMarksDisplay = section.sectionMarksDisplay;
    _questionMarksPlacement = section.questionMarksPlacement;
    _keepTogether = section.keepTogether;
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
                if (value != null) {
                  setState(() => _numberingKey = value);
                }
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
            const SizedBox(height: 8),
            _AlignmentPicker(
              label: 'Section heading alignment',
              value: _headingAlignment,
              onChanged: (value) => setState(() => _headingAlignment = value),
            ),
            const SizedBox(height: 14),
            _AlignmentPicker(
              label: 'Section instruction alignment',
              value: _instructionAlignment,
              onChanged: (value) =>
                  setState(() => _instructionAlignment = value),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show “Instruction:” label'),
              subtitle: const Text(
                'Off prints exactly what the teacher typed.',
              ),
              value: _showInstructionLabel,
              onChanged: (value) =>
                  setState(() => _showInstructionLabel = value),
            ),
            const SizedBox(height: 6),
            _AlignmentPicker(
              label: 'Answer-rule alignment',
              value: _answerRuleAlignment,
              onChanged: (value) =>
                  setState(() => _answerRuleAlignment = value),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Line above section heading'),
              value: _showTopDivider,
              onChanged: (value) => setState(() => _showTopDivider = value),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Line below section heading'),
              value: _showBottomDivider,
              onChanged: (value) => setState(() => _showBottomDivider = value),
            ),
            const SizedBox(height: 12),
            _SectionHeading(
              title: 'Heading appearance',
              subtitle:
                  'Fast professional presets plus lightweight typography controls.',
            ),
            const SizedBox(height: 8),
            SegmentedButton<_HeadingPreset>(
              segments: const [
                ButtonSegment(
                  value: _HeadingPreset.plain,
                  label: Text('Plain'),
                ),
                ButtonSegment(
                  value: _HeadingPreset.underline,
                  label: Text('Underline'),
                ),
                ButtonSegment(
                  value: _HeadingPreset.ruled,
                  label: Text('Ruled'),
                ),
                ButtonSegment(
                  value: _HeadingPreset.boxed,
                  label: Text('Boxed'),
                ),
              ],
              selected: {_currentHeadingPreset},
              onSelectionChanged: (selection) =>
                  _applyHeadingPreset(selection.first),
            ),
            const SizedBox(height: 12),
            SegmentedButton<SectionHeadingSize>(
              segments: const [
                ButtonSegment(
                  value: SectionHeadingSize.small,
                  label: Text('Small'),
                ),
                ButtonSegment(
                  value: SectionHeadingSize.normal,
                  label: Text('Normal'),
                ),
                ButtonSegment(
                  value: SectionHeadingSize.large,
                  label: Text('Large'),
                ),
              ],
              selected: {_headingSize},
              onSelectionChanged: (selection) =>
                  setState(() => _headingSize = selection.first),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bold section heading'),
              value: _headingBold,
              onChanged: (value) => setState(() => _headingBold = value),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('UPPERCASE section heading'),
              value: _headingUppercase,
              onChanged: (value) => setState(() => _headingUppercase = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SectionMarksDisplay>(
              initialValue: _sectionMarksDisplay,
              decoration: const InputDecoration(
                labelText: 'Section marks display',
              ),
              items: const [
                DropdownMenuItem(
                  value: SectionMarksDisplay.hidden,
                  child: Text('Hidden'),
                ),
                DropdownMenuItem(
                  value: SectionMarksDisplay.inline,
                  child: Text('(20 Marks) after heading'),
                ),
                DropdownMenuItem(
                  value: SectionMarksDisplay.right,
                  child: Text('20 Marks at right edge'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _sectionMarksDisplay = value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<QuestionMarksPlacement>(
              initialValue: _questionMarksPlacement,
              decoration: const InputDecoration(
                labelText: 'Question marks placement',
              ),
              items: const [
                DropdownMenuItem(
                  value: QuestionMarksPlacement.inline,
                  child: Text('Inline after question'),
                ),
                DropdownMenuItem(
                  value: QuestionMarksPlacement.rightEdge,
                  child: Text('Right edge'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _questionMarksPlacement = value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SectionSpacing>(
              initialValue: _spacing,
              decoration: const InputDecoration(labelText: 'Section spacing'),
              items: const [
                DropdownMenuItem(
                  value: SectionSpacing.compact,
                  child: Text('Compact'),
                ),
                DropdownMenuItem(
                  value: SectionSpacing.normal,
                  child: Text('Normal'),
                ),
                DropdownMenuItem(
                  value: SectionSpacing.spacious,
                  child: Text('Spacious'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _spacing = value);
                }
              },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Keep heading with first question'),
              subtitle: const Text(
                'Avoid a section heading being stranded at the bottom of a page.',
              ),
              value: _keepTogether,
              onChanged: (value) => setState(() => _keepTogether = value),
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
        showTopDivider: _showTopDivider,
        showBottomDivider: _showBottomDivider,
        headingAlignment: _headingAlignment,
        instructionAlignment: _instructionAlignment,
        answerRuleAlignment: _answerRuleAlignment,
        showInstructionLabel: _showInstructionLabel,
        headingBold: _headingBold,
        headingUppercase: _headingUppercase,
        headingBoxed: _headingBoxed,
        headingSize: _headingSize,
        spacing: _spacing,
        sectionMarksDisplay: _sectionMarksDisplay,
        questionMarksPlacement: _questionMarksPlacement,
        keepTogether: _keepTogether,
        pageBreakBefore: _pageBreakBefore,
        answerSpaceLines: _answerSpaceLines,
        ruledAnswerArea:
            _answerSpaceLines > 0 && _answerArea == _AnswerAreaKind.ruled,
        graphAnswerArea:
            _answerSpaceLines > 0 && _answerArea == _AnswerAreaKind.graph,
      ),
    );
  }

  _HeadingPreset get _currentHeadingPreset {
    if (_headingBoxed) {
      return _HeadingPreset.boxed;
    }
    if (_showTopDivider && _showBottomDivider) {
      return _HeadingPreset.ruled;
    }
    if (!_showTopDivider && _showBottomDivider) {
      return _HeadingPreset.underline;
    }
    return _HeadingPreset.plain;
  }

  void _applyHeadingPreset(_HeadingPreset preset) {
    setState(() {
      _headingBoxed = preset == _HeadingPreset.boxed;
      _showTopDivider = preset == _HeadingPreset.ruled;
      _showBottomDivider =
          preset == _HeadingPreset.underline || preset == _HeadingPreset.ruled;
    });
  }

  static String _formatMarks(double marks) {
    return marks == marks.roundToDouble()
        ? marks.toInt().toString()
        : marks.toStringAsFixed(1);
  }
}

class _AlignmentPicker extends StatelessWidget {
  final String label;
  final PaperTextAlignment value;
  final ValueChanged<PaperTextAlignment> onChanged;

  const _AlignmentPicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 7),
        SegmentedButton<PaperTextAlignment>(
          segments: const [
            ButtonSegment(
              value: PaperTextAlignment.left,
              icon: Icon(Icons.format_align_left_rounded),
              label: Text('Left'),
            ),
            ButtonSegment(
              value: PaperTextAlignment.center,
              icon: Icon(Icons.format_align_center_rounded),
              label: Text('Center'),
            ),
            ButtonSegment(
              value: PaperTextAlignment.right,
              icon: Icon(Icons.format_align_right_rounded),
              label: Text('Right'),
            ),
          ],
          selected: {value},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ],
    );
  }
}

enum _HeadingPreset { plain, underline, ruled, boxed }

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
