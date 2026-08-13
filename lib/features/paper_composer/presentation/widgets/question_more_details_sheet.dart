import 'package:edusheet/features/editor/domain/models/paper_model.dart';
import 'package:edusheet/features/paper_composer/domain/question_details_draft.dart';
import 'package:flutter/material.dart';

class QuestionMoreDetailsSheet extends StatefulWidget {
  final QuestionDetailsDraft initial;

  const QuestionMoreDetailsSheet({super.key, required this.initial});

  static Future<QuestionDetailsDraft?> show(
    BuildContext context, {
    required QuestionDetailsDraft initial,
  }) {
    return showModalBottomSheet<QuestionDetailsDraft>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: QuestionMoreDetailsSheet(initial: initial),
      ),
    );
  }

  @override
  State<QuestionMoreDetailsSheet> createState() =>
      _QuestionMoreDetailsSheetState();
}

class _QuestionMoreDetailsSheetState extends State<QuestionMoreDetailsSheet> {
  late final TextEditingController _answer;
  late final TextEditingController _explanation;
  late final TextEditingController _negativeMarks;
  late final TextEditingController _minutes;
  late final TextEditingController _grade;
  late final TextEditingController _subject;
  late final TextEditingController _chapter;
  late final TextEditingController _topic;
  late final TextEditingController _objective;
  late final TextEditingController _tags;
  late final TextEditingController _language;
  late final TextEditingController _instructions;
  late final TextEditingController _source;
  late QuestionDifficulty _difficulty;
  late CognitiveLevel _cognitiveLevel;
  String? _negativeMarksError;
  String? _minutesError;

  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    _answer = TextEditingController(text: value.correctAnswer);
    _explanation = TextEditingController(text: value.explanation);
    _negativeMarks = TextEditingController(
      text: value.negativeMarks == 0 ? '' : _number(value.negativeMarks),
    );
    _minutes = TextEditingController(
      text: value.estimatedAnswerMinutes?.toString() ?? '',
    );
    _grade = TextEditingController(text: value.grade);
    _subject = TextEditingController(text: value.subject);
    _chapter = TextEditingController(text: value.chapter);
    _topic = TextEditingController(text: value.topic);
    _objective = TextEditingController(text: value.learningObjective);
    _tags = TextEditingController(text: value.tags.join(', '));
    _language = TextEditingController(text: value.language);
    _instructions = TextEditingController(text: value.instructions);
    _source = TextEditingController(text: value.sourceReference);
    _difficulty = value.difficulty;
    _cognitiveLevel = value.cognitiveLevel;
  }

  @override
  void dispose() {
    _answer.dispose();
    _explanation.dispose();
    _negativeMarks.dispose();
    _minutes.dispose();
    _grade.dispose();
    _subject.dispose();
    _chapter.dispose();
    _topic.dispose();
    _objective.dispose();
    _tags.dispose();
    _language.dispose();
    _instructions.dispose();
    _source.dispose();
    super.dispose();
  }

  void _save() {
    final negativeRaw = _negativeMarks.text.trim();
    final negative = negativeRaw.isEmpty ? 0.0 : double.tryParse(negativeRaw);
    final minutesRaw = _minutes.text.trim();
    final minutes = minutesRaw.isEmpty ? null : int.tryParse(minutesRaw);

    final validNegative =
        negative != null && negative.isFinite && negative >= 0;
    final validMinutes = minutesRaw.isEmpty || (minutes != null && minutes > 0);
    if (!validNegative || !validMinutes) {
      setState(() {
        _negativeMarksError = validNegative
            ? null
            : 'Use 0 or a positive number';
        _minutesError = validMinutes ? null : 'Use whole minutes above 0';
      });
      return;
    }

    final tags = <String>[];
    final seen = <String>{};
    for (final raw in _tags.text.split(RegExp(r'[,\n]'))) {
      final tag = raw.trim();
      if (tag.isNotEmpty && seen.add(tag.toLowerCase())) tags.add(tag);
    }

    final details = widget.initial.copyWith(
      negativeMarks: negative,
      correctAnswer: _answer.text.trim(),
      explanation: _explanation.text.trim(),
      estimatedAnswerMinutes: minutes,
      clearEstimatedAnswerMinutes: minutes == null,
      difficulty: _difficulty,
      grade: _grade.text.trim(),
      subject: _subject.text.trim(),
      chapter: _chapter.text.trim(),
      topic: _topic.text.trim(),
      learningObjective: _objective.text.trim(),
      cognitiveLevel: _cognitiveLevel,
      tags: tags,
      language: _language.text.trim().isEmpty ? 'en' : _language.text.trim(),
      instructions: _instructions.text.trim(),
      sourceReference: _source.text.trim(),
    );
    Navigator.pop(context, details);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Answer & more details',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Optional fields stay out of the main writing screen.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _DetailsHeading(
                      icon: Icons.fact_check_outlined,
                      title: 'Answer',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _answer,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Correct / model answer',
                        hintText: 'Optional',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _explanation,
                      minLines: 2,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Explanation / solution note',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _DetailsHeading(
                      icon: Icons.tune_rounded,
                      title: 'Assessment',
                    ),
                    const SizedBox(height: 10),
                    _ResponsivePair(
                      first: DropdownButtonFormField<QuestionDifficulty>(
                        initialValue: _difficulty,
                        decoration: const InputDecoration(
                          labelText: 'Difficulty',
                        ),
                        items: [
                          for (final value in QuestionDifficulty.values)
                            DropdownMenuItem(
                              value: value,
                              child: Text(_difficultyLabel(value)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _difficulty = value);
                          }
                        },
                      ),
                      second: TextField(
                        controller: _negativeMarks,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Negative marks',
                          hintText: '0',
                          errorText: _negativeMarksError,
                        ),
                        onChanged: (_) {
                          if (_negativeMarksError != null) {
                            setState(() => _negativeMarksError = null);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ResponsivePair(
                      first: TextField(
                        controller: _minutes,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Estimated minutes',
                          errorText: _minutesError,
                        ),
                        onChanged: (_) {
                          if (_minutesError != null) {
                            setState(() => _minutesError = null);
                          }
                        },
                      ),
                      second: DropdownButtonFormField<CognitiveLevel>(
                        initialValue: _cognitiveLevel,
                        decoration: const InputDecoration(
                          labelText: 'Cognitive level',
                        ),
                        items: [
                          for (final value in CognitiveLevel.values)
                            DropdownMenuItem(
                              value: value,
                              child: Text(_cognitiveLabel(value)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _cognitiveLevel = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _DetailsHeading(
                      icon: Icons.school_outlined,
                      title: 'Teaching context',
                    ),
                    const SizedBox(height: 10),
                    _ResponsivePair(
                      first: TextField(
                        controller: _subject,
                        decoration: const InputDecoration(labelText: 'Subject'),
                      ),
                      second: TextField(
                        controller: _grade,
                        decoration: const InputDecoration(labelText: 'Class / grade'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ResponsivePair(
                      first: TextField(
                        controller: _chapter,
                        decoration: const InputDecoration(labelText: 'Chapter'),
                      ),
                      second: TextField(
                        controller: _topic,
                        decoration: const InputDecoration(labelText: 'Topic'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _objective,
                      decoration: const InputDecoration(
                        labelText: 'Learning objective',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tags,
                      decoration: const InputDecoration(
                        labelText: 'Tags',
                        hintText: 'algebra, revision, board-exam',
                        helperText: 'Separate tags with commas.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ResponsivePair(
                      first: TextField(
                        controller: _language,
                        decoration: const InputDecoration(
                          labelText: 'Language code',
                          hintText: 'en',
                        ),
                      ),
                      second: TextField(
                        controller: _source,
                        decoration: const InputDecoration(
                          labelText: 'Source / reference',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _instructions,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Question-specific instruction',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Apply details'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _difficultyLabel(QuestionDifficulty value) {
    switch (value) {
      case QuestionDifficulty.easy:
        return 'Easy';
      case QuestionDifficulty.medium:
        return 'Medium';
      case QuestionDifficulty.hard:
        return 'Hard';
    }
  }

  static String _cognitiveLabel(CognitiveLevel value) {
    switch (value) {
      case CognitiveLevel.remember:
        return 'Remember';
      case CognitiveLevel.understand:
        return 'Understand';
      case CognitiveLevel.apply:
        return 'Apply';
      case CognitiveLevel.analyse:
        return 'Analyse';
      case CognitiveLevel.evaluate:
        return 'Evaluate';
      case CognitiveLevel.create:
        return 'Create';
      case CognitiveLevel.unspecified:
        return 'Not specified';
    }
  }

  static String _number(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }
}

class _DetailsHeading extends StatelessWidget {
  final IconData icon;
  final String title;

  const _DetailsHeading({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  final Widget first;
  final Widget second;

  const _ResponsivePair({required this.first, required this.second});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: [first, const SizedBox(height: 12), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
