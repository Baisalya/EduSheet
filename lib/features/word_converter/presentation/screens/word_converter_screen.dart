import 'dart:async';
import 'dart:io';

import 'package:edusheet/features/document_reader/domain/models/document_model.dart';
import 'package:edusheet/features/document_reader/presentation/screens/file_preview_screen.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_history_entry.dart';
import 'package:edusheet/features/word_converter/domain/models/conversion_job.dart';
import 'package:edusheet/features/word_converter/services/conversion_history_service.dart';
import 'package:edusheet/features/word_converter/services/word_converter_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class WordConverterScreen extends StatefulWidget {
  const WordConverterScreen({super.key});

  @override
  State<WordConverterScreen> createState() => _WordConverterScreenState();
}

class _WordConverterScreenState extends State<WordConverterScreen> {
  bool _isConverting = false;
  bool _isCancelling = false;
  File? _lastOutput;
  ConversionProgress? _progress;
  ConversionSourceInfo? _activeSource;
  ConversionCancellationToken? _cancellationToken;
  List<ConversionHistoryEntry> _recent = const [];
  Timer? _elapsedTimer;
  DateTime? _conversionStartedAt;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Word Converter',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: scheme.onSurface,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Text(
                  'Convert documents without hidden content changes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose a conversion mode, review the source, choose the output name and location, then track each conversion stage.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                _ConverterTile(
                  icon: Icons.picture_as_pdf_outlined,
                  color: Colors.redAccent,
                  title: 'Word to PDF',
                  subtitle:
                      'Preserve supported Word layout, formatting, tables, images, links, headers, footers and page settings.',
                  buttonLabel: 'Choose Word File',
                  enabled: !_isConverting,
                  onPressed: _convertDocxToPdf,
                ),
                const SizedBox(height: 16),
                _ConverterTile(
                  icon: Icons.edit_document,
                  color: Colors.teal,
                  title: 'PDF to Word: Preserve Appearance',
                  subtitle: WordConverterService.supportsPdfAppearancePreservation
                      ? 'Each PDF page is preserved visually inside Word. Text may not be directly editable.'
                      : 'Preserve Appearance is not available on this platform. Use Editable Document instead.',
                  buttonLabel:
                      WordConverterService.supportsPdfAppearancePreservation
                          ? 'Choose PDF File'
                          : 'Unavailable on this platform',
                  enabled: !_isConverting &&
                      WordConverterService.supportsPdfAppearancePreservation,
                  onPressed: _convertPdfToDocxExact,
                ),
                const SizedBox(height: 16),
                _ConverterTile(
                  icon: Icons.edit_note_outlined,
                  color: Colors.blueGrey,
                  title: 'PDF to Word: Editable Document',
                  subtitle:
                      'Reconstruct editable text, paragraphs, headings and supported simple tables from PDF geometry, with OCR fallback for scanned pages. Complex graphics and layouts may differ.',
                  buttonLabel: 'Choose PDF File',
                  enabled: !_isConverting,
                  onPressed: _convertPdfToDocxEditable,
                ),
                const SizedBox(height: 16),
                _ConverterTile(
                  icon: Icons.description_outlined,
                  color: Colors.indigo,
                  title: 'Text to Word',
                  subtitle: 'Pick a .txt file and save it as a Word document.',
                  buttonLabel: 'Choose Text File',
                  enabled: !_isConverting,
                  onPressed: _convertTextToDocx,
                ),
                if (_isConverting) ...[
                  const SizedBox(height: 20),
                  _ConversionProgressPanel(
                    source: _activeSource,
                    progress: _progress,
                    isCancelling: _isCancelling,
                    elapsed: _elapsed,
                    onCancel: _cancelConversion,
                  ),
                ],
                if (_lastOutput != null && !_isConverting) ...[
                  const SizedBox(height: 20),
                  _OutputPanel(
                    file: _lastOutput!,
                    onOpen: () => _openInApp(_lastOutput!),
                    onOpenExternal: () => WordConverterService.open(_lastOutput!),
                    onSaveCopy: () => _saveCopy(_lastOutput!),
                    onReveal: WordConverterService.supportsRevealInFolder
                        ? () => WordConverterService.revealInFolder(_lastOutput!)
                        : null,
                    onConvertAnother: () => setState(() => _lastOutput = null),
                  ),
                ],
                if (_recent.isNotEmpty && !_isConverting) ...[
                  const SizedBox(height: 24),
                  _RecentConversionsPanel(
                    entries: _recent,
                    onOpen: (entry) => _openInApp(File(entry.outputPath)),
                    onClear: _clearHistory,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _convertDocxToPdf() async {
    await _startConversion(
      extensions: const ['docx'],
      outputExtension: '.pdf',
      modeLabel: 'Word → PDF',
      convert: (source, output, token, onProgress) =>
          WordConverterService.convertDocxToPdf(
        source,
        outputPath: output,
        cancellationToken: token,
        onProgress: onProgress,
      ),
    );
  }

  Future<void> _convertPdfToDocxExact() async {
    await _startConversion(
      extensions: const ['pdf'],
      outputExtension: '.docx',
      modeLabel: 'PDF → Word · Preserve Appearance',
      convert: (source, output, token, onProgress) =>
          WordConverterService.convertPdfToDocxExact(
        source,
        outputPath: output,
        cancellationToken: token,
        onProgress: onProgress,
      ),
    );
  }

  Future<void> _convertPdfToDocxEditable() async {
    await _startConversion(
      extensions: const ['pdf'],
      outputExtension: '.docx',
      modeLabel: 'PDF → Word · Editable Document',
      convert: (source, output, token, onProgress) =>
          WordConverterService.convertPdfToDocx(
        source,
        outputPath: output,
        cancellationToken: token,
        onProgress: onProgress,
      ),
    );
  }

  Future<void> _convertTextToDocx() async {
    await _startConversion(
      extensions: const ['txt'],
      outputExtension: '.docx',
      modeLabel: 'Text → Word',
      convert: (source, output, token, onProgress) =>
          WordConverterService.convertTextToDocx(
        source,
        outputPath: output,
        cancellationToken: token,
        onProgress: onProgress,
      ),
    );
  }

  Future<void> _startConversion({
    required List<String> extensions,
    required String outputExtension,
    required String modeLabel,
    required Future<File> Function(
      String source,
      String output,
      ConversionCancellationToken token,
      ConversionProgressCallback onProgress,
    ) convert,
  }) async {
    final sourcePath = await _pickFile(extensions);
    if (sourcePath == null || !mounted) return;

    ConversionSourceInfo sourceInfo;
    try {
      sourceInfo = await WordConverterService.inspectSource(sourcePath);
    } catch (error) {
      if (!mounted) return;
      _showError('Could not read the selected file: $error');
      return;
    }

    if (!mounted) return;
    final confirmed = await _confirmSource(sourceInfo, modeLabel);
    if (!confirmed || !mounted) return;
    final destination = await _chooseDestination(sourcePath, outputExtension);
    if (destination == null || !mounted) return;
    final safeDestination = await _resolveExistingDestination(destination);
    if (safeDestination == null || !mounted) return;

    final token = ConversionCancellationToken();
    _startElapsedTimer();
    setState(() {
      _isConverting = true;
      _isCancelling = false;
      _lastOutput = null;
      _activeSource = sourceInfo;
      _cancellationToken = token;
      _progress = const ConversionProgress(
        stage: ConversionStage.preparing,
        message: 'Preparing conversion…',
      );
    });

    try {
      final output = await convert(
        sourcePath,
        safeDestination,
        token,
        (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );
      if (!mounted) return;
      final stat = await output.stat();
      final entry = ConversionHistoryEntry(
        outputPath: output.path,
        sourceName: p.basename(sourcePath),
        modeLabel: modeLabel,
        createdAt: DateTime.now(),
        sizeBytes: stat.size,
      );
      final recent = await ConversionHistoryService.add(entry);
      if (!mounted) return;
      setState(() {
        _lastOutput = output;
        _recent = recent;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversion complete. Choose what to do with the output.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ConversionCancelledException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversion cancelled. Partial output was cleaned up.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showError('Conversion failed: $error');
    } finally {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
      _conversionStartedAt = null;
      if (mounted) {
        setState(() {
          _isConverting = false;
          _isCancelling = false;
          _cancellationToken = null;
          _activeSource = null;
          _progress = null;
        });
      }
    }
  }

  Future<String?> _pickFile(List<String> extensions) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: false,
    );
    return result?.files.single.path;
  }

  Future<String?> _chooseDestination(
    String sourcePath,
    String outputExtension,
  ) async {
    final extension = outputExtension.replaceFirst('.', '');
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save converted document',
      fileName: WordConverterService.suggestedOutputName(
        sourcePath,
        outputExtension,
      ),
      type: FileType.custom,
      allowedExtensions: [extension],
    );
    if (path == null) return null;
    return path.toLowerCase().endsWith(outputExtension)
        ? path
        : '$path$outputExtension';
  }

  Future<String?> _resolveExistingDestination(String destination) async {
    final file = File(destination);
    if (!await file.exists() || !mounted) return destination;
    final choice = await showDialog<_ExistingFileChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('A file with this name already exists'),
        content: Text(p.basename(destination)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _ExistingFileChoice.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ExistingFileChoice.keepBoth),
            child: const Text('Keep Both'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _ExistingFileChoice.replace),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (choice == _ExistingFileChoice.replace) return destination;
    if (choice == _ExistingFileChoice.keepBoth) {
      return _keepBothPath(destination);
    }
    return null;
  }

  String _keepBothPath(String destination) {
    final directory = p.dirname(destination);
    final extension = p.extension(destination);
    final base = p.basenameWithoutExtension(destination);
    var index = 1;
    var candidate = p.join(directory, '$base ($index)$extension');
    while (File(candidate).existsSync()) {
      index++;
      candidate = p.join(directory, '$base ($index)$extension');
    }
    return candidate;
  }

  Future<bool> _confirmSource(
    ConversionSourceInfo source,
    String modeLabel,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ready to convert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryRow(label: 'Mode', value: modeLabel),
            _SummaryRow(label: 'File', value: source.name),
            _SummaryRow(label: 'Size', value: _formatBytes(source.sizeBytes)),
            if (source.pageCount != null)
              _SummaryRow(label: 'Pages', value: '${source.pageCount}'),
            const SizedBox(height: 12),
            const Text(
              'Next you can rename the output and choose exactly where to save it.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Choose Save Location'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _conversionStartedAt = DateTime.now();
    _elapsed = Duration.zero;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _conversionStartedAt;
      if (!mounted || startedAt == null) return;
      setState(() => _elapsed = DateTime.now().difference(startedAt));
    });
  }

  void _cancelConversion() {
    final token = _cancellationToken;
    if (token == null || token.isCancelled) return;
    token.cancel();
    setState(() {
      _isCancelling = true;
      _progress = const ConversionProgress(
        stage: ConversionStage.cancelled,
        message: 'Stopping safely…',
      );
    });
  }

  Future<void> _saveCopy(File source) async {
    final extension = p.extension(source.path);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save a copy',
      fileName: p.basename(source.path),
      type: FileType.custom,
      allowedExtensions: [extension.replaceFirst('.', '')],
    );
    if (path == null || !mounted) return;
    final destination = path.toLowerCase().endsWith(extension)
        ? path
        : '$path$extension';
    final safeDestination = await _resolveExistingDestination(destination);
    if (safeDestination == null) return;
    try {
      await WordConverterService.saveCopy(source, safeDestination);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copy saved: $safeDestination'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showError('Could not save a copy: $error');
    }
  }

  Future<void> _loadHistory() async {
    final recent = await ConversionHistoryService.load();
    if (!mounted) return;
    setState(() => _recent = recent);
  }

  Future<void> _clearHistory() async {
    await ConversionHistoryService.clear();
    if (!mounted) return;
    setState(() => _recent = const []);
  }

  Future<void> _openInApp(File file) async {
    if (!await file.exists()) {
      if (mounted) _showError('This converted file is no longer available.');
      return;
    }
    final stat = await file.stat();
    if (!mounted) return;

    final extension = p.extension(file.path).toLowerCase();
    final document = DocumentFile(
      name: p.basename(file.path),
      path: file.path,
      extension: extension,
      size: stat.size,
      lastModified: stat.modified,
      type: DocumentFile.getDocumentType(extension),
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FilePreviewScreen(document: document),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

enum _ExistingFileChoice { replace, keepBoth, cancel }

class _ConverterTile extends StatelessWidget {
  const _ConverterTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: enabled ? onPressed : null,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: Text(buttonLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversionProgressPanel extends StatelessWidget {
  const _ConversionProgressPanel({
    required this.source,
    required this.progress,
    required this.isCancelling,
    required this.elapsed,
    required this.onCancel,
  });

  final ConversionSourceInfo? source;
  final ConversionProgress? progress;
  final bool isCancelling;
  final Duration elapsed;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = progress?.fraction;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isCancelling ? 'Stopping conversion' : 'Converting document',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!isCancelling)
                  TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancel'),
                  ),
              ],
            ),
            if (source != null) ...[
              const SizedBox(height: 4),
              Text(
                '${source!.name} · ${_formatBytes(source!.sizeBytes)}${source!.pageCount == null ? '' : ' · ${source!.pageCount} pages'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 14),
            LinearProgressIndicator(value: value),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(progress?.message ?? 'Preparing conversion…')),
                const SizedBox(width: 12),
                Text(
                  _formatElapsed(elapsed),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _StageRow(
              label: 'Read & parse source',
              state: _stageState(progress?.stage, ConversionStage.parsing),
            ),
            _StageRow(
              label: 'Process document content',
              state: _stageState(
                progress?.stage,
                ConversionStage.processingPages,
              ),
            ),
            _StageRow(
              label: 'Render / build output',
              state: _stageState(progress?.stage, ConversionStage.rendering),
            ),
            _StageRow(
              label: 'Write output safely',
              state: _stageState(
                progress?.stage,
                ConversionStage.writingOutput,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static _StageState _stageState(
    ConversionStage? current,
    ConversionStage target,
  ) {
    if (current == null) return _StageState.pending;
    if (current == ConversionStage.cancelled) return _StageState.pending;
    final currentRank = _stageRank(current);
    final targetRank = _stageRank(target);
    if (currentRank > targetRank) return _StageState.done;
    if (currentRank == targetRank) return _StageState.active;
    return _StageState.pending;
  }

  static int _stageRank(ConversionStage stage) => switch (stage) {
        ConversionStage.preparing => 0,
        ConversionStage.readingSource => 1,
        ConversionStage.parsing => 1,
        ConversionStage.processingPages => 2,
        ConversionStage.rendering => 3,
        ConversionStage.writingOutput => 4,
        ConversionStage.completed => 5,
        ConversionStage.cancelled => -1,
      };
}

enum _StageState { pending, active, done }

class _StageRow extends StatelessWidget {
  const _StageRow({required this.label, required this.state});

  final String label;
  final _StageState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (state) {
      _StageState.done => Icons.check_circle,
      _StageState.active => Icons.radio_button_checked,
      _StageState.pending => Icons.radio_button_unchecked,
    };
    final color = switch (state) {
      _StageState.done => Colors.green,
      _StageState.active => scheme.primary,
      _StageState.pending => scheme.onSurfaceVariant,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 9),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _OutputPanel extends StatelessWidget {
  const _OutputPanel({
    required this.file,
    required this.onOpen,
    required this.onOpenExternal,
    required this.onSaveCopy,
    required this.onReveal,
    required this.onConvertAnother,
  });

  final File file;
  final VoidCallback onOpen;
  final VoidCallback onOpenExternal;
  final VoidCallback onSaveCopy;
  final VoidCallback? onReveal;
  final VoidCallback onConvertAnother;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Conversion complete',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.basename(file.path),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Open in EduSheet'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenExternal,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open externally'),
              ),
              OutlinedButton.icon(
                onPressed: onSaveCopy,
                icon: const Icon(Icons.save_as_outlined, size: 18),
                label: const Text('Save a copy'),
              ),
              if (onReveal != null)
                OutlinedButton.icon(
                  onPressed: onReveal,
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: const Text('Show in folder'),
                ),
              TextButton.icon(
                onPressed: onConvertAnother,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Convert another'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentConversionsPanel extends StatelessWidget {
  const _RecentConversionsPanel({
    required this.entries,
    required this.onOpen,
    required this.onClear,
  });

  final List<ConversionHistoryEntry> entries;
  final ValueChanged<ConversionHistoryEntry> onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent conversions',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ),
        const SizedBox(height: 8),
        ...entries.map(
          (entry) => Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            color: scheme.surfaceContainerLow,
            child: ListTile(
              leading: const Icon(Icons.history),
              title: Text(
                p.basename(entry.outputPath),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${entry.modeLabel} · ${_formatBytes(entry.sizeBytes)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpen(entry),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _formatElapsed(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
