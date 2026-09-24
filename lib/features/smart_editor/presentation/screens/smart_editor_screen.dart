import 'dart:async';
import 'dart:math' as math;

import 'package:edusheet/features/editor/domain/models/math_expression.dart';
import 'package:edusheet/features/editor/services/autosave_coordinator.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_builder_screen.dart';
import 'package:edusheet/features/geometry_builder/widgets/geometry_embed_builder.dart';
import 'package:edusheet/features/math_keyboard/presentation/providers/math_keyboard_controller.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/formula_editor_sheet.dart';
import 'package:edusheet/features/math_keyboard/presentation/widgets/math_expression_embed_builder.dart';
import 'package:edusheet/features/printing/domain/print_document_source.dart';
import 'package:edusheet/features/printing/presentation/screens/print_center_screen.dart';
import 'package:edusheet/features/smart_editor/application/smart_editor_object_commands.dart';
import 'package:edusheet/features/smart_editor/application/smart_editor_docx_structure_editing.dart';
import 'package:edusheet/features/smart_editor/application/smart_editor_smart_commands.dart';
import 'package:edusheet/features/smart_editor/domain/smart_document.dart';
import 'package:edusheet/features/smart_editor/presentation/providers/smart_editor_provider.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_break_embed_builder.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_command_palette.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_docx_structure_editors.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_document_actions.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_header_footer_sheet.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_interop_embed_builders.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_page_layout_sheet.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_word_advanced_embed_builder.dart';
import 'package:edusheet/features/smart_editor/presentation/widgets/smart_editor_properties_panel.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_binary_file_saver.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_file_opener.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_docx_service.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_open_import_workflow.dart';
import 'package:edusheet/features/smart_editor/services/smart_editor_pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';

class SmartEditorScreen extends ConsumerStatefulWidget {
  const SmartEditorScreen({
    super.key,
    required this.document,
    this.docxFileOpener,
  });

  final SmartDocument document;
  final SmartEditorDocxFileOpener? docxFileOpener;

  @override
  ConsumerState<SmartEditorScreen> createState() => _SmartEditorScreenState();
}

class _SmartEditorScreenState extends ConsumerState<SmartEditorScreen>
    with WidgetsBindingObserver {
  late SmartDocument _document;
  late QuillController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _editorScrollController;
  late final TextEditingController _titleController;
  late final AutosaveCoordinator<SmartDocument> _autosave;
  late final AutosaveCoordinator<SmartDocument> _recoveryAutosave;
  late final ValueNotifier<AutosaveStatus> _saveStatusNotifier;
  late final ValueNotifier<int> _wordCountNotifier;
  late final ValueNotifier<String?> _slashQueryNotifier;
  late final ValueNotifier<SmartEditorSuggestion?> _suggestionNotifier;
  Timer? _wordCountTimer;
  Timer? _smartAssistTimer;
  int _documentRevision = 0;
  int _snapshotRevision = -1;
  SmartDocument? _snapshotCache;
  bool _closing = false;
  bool _exitApproved = false;
  bool _saveFailureNoticeVisible = false;
  bool _showProperties = false;
  bool _fullMode = false;
  bool _exporting = false;
  bool _openingDocx = false;
  String? _ignoredSuggestionSignature;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _document = widget.document;
    _controller = QuillController(
      document: Document.fromJson(_document.quillOperations),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _focusNode = FocusNode();
    _editorScrollController = ScrollController();
    _titleController = TextEditingController(text: _document.title);
    _saveStatusNotifier = ValueNotifier<AutosaveStatus>(
      const AutosaveStatus(AutosavePhase.idle),
    );
    _wordCountNotifier = ValueNotifier<int>(
      _wordCount(_controller.document.toPlainText()),
    );
    _slashQueryNotifier = ValueNotifier<String?>(null);
    _suggestionNotifier = ValueNotifier<SmartEditorSuggestion?>(null);
    _autosave = AutosaveCoordinator<SmartDocument>(
      delay: const Duration(milliseconds: 650),
      save: (value) => ref.read(smartDocumentRepositoryProvider).save(value),
      onStatus: (status) {
        if (!mounted) return;
        _saveStatusNotifier.value = status;
        if (status.phase == AutosavePhase.saved) {
          unawaited(_clearRecoveryBestEffort());
        }
      },
    );
    _recoveryAutosave = AutosaveCoordinator<SmartDocument>(
      delay: const Duration(milliseconds: 220),
      save: (value) => ref.read(smartEditorRecoveryStoreProvider).save(value),
    );
    _controller.addListener(_handleDocumentChanged);
    _titleController.addListener(_handleTitleChanged);
    _refreshSmartAssist();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flushForLifecycle());
    }
  }

  Future<void> _flushForLifecycle() async {
    await _recoveryAutosave.flush();
    await _autosave.flush();
  }

  Future<void> _clearRecoveryBestEffort() async {
    try {
      await ref.read(smartEditorRecoveryStoreProvider).clear(_document.id);
    } catch (_) {
      // The recovery journal is secondary to the primary atomic save.
    }
  }

  Future<void> _saveRecoveryBestEffort(SmartDocument snapshot) async {
    try {
      await ref.read(smartEditorRecoveryStoreProvider).save(snapshot);
    } catch (_) {
      // Primary document persistence remains authoritative.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_handleDocumentChanged);
    _titleController.removeListener(_handleTitleChanged);
    _wordCountTimer?.cancel();
    _smartAssistTimer?.cancel();
    if (!_exitApproved) {
      final emergencySnapshot = _snapshotForPersistence();
      unawaited(_saveRecoveryBestEffort(emergencySnapshot));
    }
    _autosave.dispose();
    _recoveryAutosave.dispose();
    _controller.dispose();
    _focusNode.dispose();
    _editorScrollController.dispose();
    _titleController.dispose();
    _saveStatusNotifier.dispose();
    _wordCountNotifier.dispose();
    _slashQueryNotifier.dispose();
    _suggestionNotifier.dispose();
    super.dispose();
  }

  void _handleDocumentChanged() {
    _document = _document.copyWith(updatedAt: DateTime.now().toUtc());
    _markPersistenceDirty();
    _autosave.scheduleLazy(_snapshotForPersistence);
    _recoveryAutosave.scheduleLazy(_snapshotForPersistence);
    _scheduleWordCountUpdate();
    _scheduleSmartAssist();
  }

  void _scheduleWordCountUpdate() {
    _wordCountTimer?.cancel();
    _wordCountTimer = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      _wordCountNotifier.value = _wordCount(_controller.document.toPlainText());
    });
  }

  void _scheduleSmartAssist() {
    _smartAssistTimer?.cancel();
    _smartAssistTimer = Timer(const Duration(milliseconds: 90), () {
      if (!mounted) return;
      _refreshSmartAssist();
    });
  }

  void _refreshSmartAssist() {
    final assist = SmartEditorSmartCommands.assistFor(_controller);
    _slashQueryNotifier.value = assist.$1;
    final suggestion = assist.$2;
    _suggestionNotifier.value = suggestion?.signature == _ignoredSuggestionSignature
        ? null
        : suggestion;
  }

  void _ignoreSuggestion(SmartEditorSuggestion suggestion) {
    _ignoredSuggestionSignature = suggestion.signature;
    _suggestionNotifier.value = null;
    _focusNode.requestFocus();
  }

  void _applySuggestion(SmartEditorSuggestion suggestion) {
    SmartEditorSmartCommands.applyAcademicStyle(_controller, suggestion.style);
    _ignoredSuggestionSignature = suggestion.signature;
    _suggestionNotifier.value = null;
    _focusNode.requestFocus();
  }

  void _handleTitleChanged() {
    final clean = _titleController.text.trim();
    _document = _document.copyWith(
      title: clean.isEmpty ? 'Untitled Document' : clean,
      updatedAt: DateTime.now().toUtc(),
    );
    _markPersistenceDirty();
    _autosave.scheduleLazy(_snapshotForPersistence);
    _recoveryAutosave.scheduleLazy(_snapshotForPersistence);
  }

  Future<void> _saveNow() async {
    await _persistNow(showFailure: true);
  }

  void _showSaveFailureNotice() {
    if (_saveFailureNoticeVisible || !mounted) return;
    _saveFailureNoticeVisible = true;
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not save this document. Your recovery copy is still kept.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    unawaited(
      controller.closed.then<void>((_) {
        _saveFailureNoticeVisible = false;
      }),
    );
  }

  Future<bool> _persistNow({required bool showFailure}) async {
    final snapshot = _snapshotForPersistence();
    _recoveryAutosave.schedule(snapshot);
    await _recoveryAutosave.flush();
    _autosave.schedule(snapshot);
    await _autosave.flush();
    final failed = _autosave.status.phase == AutosavePhase.failed;
    if (failed) {
      if (showFailure && mounted) {
        _showSaveFailureNotice();
      }
      return false;
    }
    await _clearRecoveryBestEffort();
    ref.invalidate(smartDocumentsProvider);
    return true;
  }

  void _markPersistenceDirty() {
    _documentRevision += 1;
    _snapshotCache = null;
  }

  SmartDocument _snapshotForPersistence() {
    final cached = _snapshotCache;
    if (cached != null && _snapshotRevision == _documentRevision) {
      return cached;
    }
    _captureDocument();
    _snapshotRevision = _documentRevision;
    _snapshotCache = _document;
    return _document;
  }

  void _captureDocument() {
    _document = _document.copyWith(
      deltaJson: List<dynamic>.from(_controller.document.toDelta().toJson()),
      title: _titleController.text.trim().isEmpty
          ? 'Untitled Document'
          : _titleController.text.trim(),
    );
  }

  Future<void> _close() async {
    if (_closing || _exitApproved) return;
    _closing = true;
    final saved = await _persistNow(showFailure: true);
    if (!mounted) return;
    if (!saved) {
      _closing = false;
      return;
    }
    setState(() => _exitApproved = true);
    // PopScope reads canPop during route-pop evaluation. Wait for the frame
    // that rebuilds it with canPop=true before issuing the approved pop.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _editPageLayout() async {
    final layout = await SmartEditorPageLayoutSheet.show(
      context,
      _document.pageLayout,
    );
    if (layout == null || !mounted) return;
    _updateDocument(_document.copyWith(pageLayout: layout));
    _focusNode.requestFocus();
  }

  Future<void> _editHeaderFooter() async {
    final result = await SmartEditorHeaderFooterSheet.show(
      context,
      header: _document.header,
      footer: _document.footer,
    );
    if (result == null || !mounted) return;
    _updateDocument(
      _document.copyWith(header: result.header, footer: result.footer),
    );
    _focusNode.requestFocus();
  }

  void _setBorder(SmartDocumentPageBorderStyle style) {
    _updateDocument(
      _document.copyWith(
        pageLayout: _document.pageLayout.copyWith(borderStyle: style),
      ),
    );
  }

  void _updateDocument(SmartDocument document) {
    setState(() {
      _document = document.copyWith(updatedAt: DateTime.now().toUtc());
    });
    _markPersistenceDirty();
    _autosave.scheduleLazy(_snapshotForPersistence);
    _recoveryAutosave.scheduleLazy(_snapshotForPersistence);
  }

  Future<void> _openProperties({required bool compact}) async {
    if (!compact) {
      setState(() => _showProperties = !_showProperties);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.82,
        child: SmartEditorPropertiesPanel(
          controller: _controller,
          document: _document,
          onLayout: () {
            Navigator.pop(context);
            unawaited(_editPageLayout());
          },
          onHeaderFooter: () {
            Navigator.pop(context);
            unawaited(_editHeaderFooter());
          },
          onBorderChanged: (style) {
            _setBorder(style);
            Navigator.pop(context);
          },
          onInsertPageBreak: () {
            Navigator.pop(context);
            _insertBreak('page');
          },
          onInsertSectionBreak: () {
            Navigator.pop(context);
            _insertBreak('section');
          },
        ),
      ),
    );
  }

  Future<void> _openCommandPalette({
    String initialQuery = '',
    bool removeSlash = false,
  }) async {
    final command = await SmartEditorCommandPalette.show(
      context,
      commands: smartEditorAllCommands,
      initialQuery: initialQuery,
      title: removeSlash ? 'Slash commands' : 'Smart commands',
    );
    if (command == null || !mounted) {
      _focusNode.requestFocus();
      return;
    }
    if (removeSlash) SmartEditorSmartCommands.removeSlashPrefix(_controller);
    await _runSmartCommand(command);
  }

  Future<void> _openQuickInsert() async {
    const ids = <SmartEditorCommandId>{
      SmartEditorCommandId.math,
      SmartEditorCommandId.geometry,
      SmartEditorCommandId.pageBreak,
      SmartEditorCommandId.sectionBreak,
      SmartEditorCommandId.instructionsBlock,
      SmartEditorCommandId.answerLines,
      SmartEditorCommandId.signatureBlock,
    };
    final command = await SmartEditorCommandPalette.show(
      context,
      commands: smartEditorAllCommands
          .where((command) => ids.contains(command.id))
          .toList(growable: false),
      title: 'Quick insert',
      searchEnabled: false,
    );
    if (command != null && mounted) await _runSmartCommand(command);
  }

  Future<void> _runSmartCommand(SmartEditorCommandId command) async {
    switch (command) {
      case SmartEditorCommandId.math:
        await _insertMath();
        break;
      case SmartEditorCommandId.geometry:
        await _insertGeometry();
        break;
      case SmartEditorCommandId.pageBreak:
        _insertBreak('page');
        break;
      case SmartEditorCommandId.sectionBreak:
        _insertBreak('section');
        break;
      case SmartEditorCommandId.titleStyle:
        _controller.formatSelection(Attribute.h1);
        break;
      case SmartEditorCommandId.heading1:
        _controller.formatSelection(Attribute.h2);
        break;
      case SmartEditorCommandId.heading2:
        _controller.formatSelection(Attribute.h3);
        break;
      case SmartEditorCommandId.questionStyle:
        SmartEditorSmartCommands.applyAcademicStyle(
          _controller,
          SmartEditorAcademicStyle.question,
        );
        break;
      case SmartEditorCommandId.sectionStyle:
        SmartEditorSmartCommands.applyAcademicStyle(
          _controller,
          SmartEditorAcademicStyle.section,
        );
        break;
      case SmartEditorCommandId.instructionStyle:
        SmartEditorSmartCommands.applyAcademicStyle(
          _controller,
          SmartEditorAcademicStyle.instruction,
        );
        break;
      case SmartEditorCommandId.normalStyle:
        SmartEditorSmartCommands.applyAcademicStyle(
          _controller,
          SmartEditorAcademicStyle.normal,
        );
        break;
      case SmartEditorCommandId.instructionsBlock:
        SmartEditorSmartCommands.insertReusableBlock(
          _controller,
          SmartEditorReusableBlock.instructions,
        );
        break;
      case SmartEditorCommandId.answerLines:
        SmartEditorSmartCommands.insertReusableBlock(
          _controller,
          SmartEditorReusableBlock.answerLines,
        );
        break;
      case SmartEditorCommandId.signatureBlock:
        SmartEditorSmartCommands.insertReusableBlock(
          _controller,
          SmartEditorReusableBlock.signature,
        );
        break;
      case SmartEditorCommandId.pageLayout:
        await _editPageLayout();
        break;
      case SmartEditorCommandId.headerFooter:
        await _editHeaderFooter();
        break;
      case SmartEditorCommandId.properties:
        await _openProperties(
          compact: MediaQuery.sizeOf(context).width < 720,
        );
        break;
      case SmartEditorCommandId.importDocx:
        await _openWordDocument();
        break;
      case SmartEditorCommandId.exportDocx:
        await _exportDocument('docx');
        break;
      case SmartEditorCommandId.exportPdf:
        await _exportDocument('pdf');
        break;
    }
    if (mounted) _focusNode.requestFocus();
  }

  Future<void> _openWordDocument() async {
    if (_openingDocx || _exporting) return;
    setState(() => _openingDocx = true);
    try {
      final workflow = SmartEditorOpenImportWorkflow(
        opener: widget.docxFileOpener ?? SmartEditorDocxFileOpener(),
      );
      final result = await workflow.run(
        persistCurrent: () => _persistNow(showFailure: true),
        saveImported: ref.read(smartDocumentRepositoryProvider).save,
        clearImportedRecovery: (documentId) => ref
            .read(smartEditorRecoveryStoreProvider)
            .clear(documentId),
      );
      if (result == null || !mounted) return;

      ref.invalidate(smartDocumentsProvider);
      if (!mounted) return;

      if (result.warnings.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              result.nativeRoundTrip
                  ? 'EduSheet document restored'
                  : 'Word import notes',
            ),
            content: SingleChildScrollView(
              child: Text(result.warnings.map((item) => '• $item').join('\n\n')),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Open document'),
              ),
            ],
          ),
        );
      }
      if (!mounted) return;

      _exitApproved = true;
      unawaited(
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute<void>(
            builder: (_) => SmartEditorScreen(document: result.document),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open/import Word document: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _openingDocx = false);
    }
  }

  Future<void> _exportDocument(String format) async {
    if (_exporting) return;
    final persisted = await _persistNow(showFailure: true);
    if (!persisted || !mounted) return;
    setState(() => _exporting = true);
    try {
      final saver = SmartEditorBinaryFileSaver();
      final fileBase = _safeExportName(_document.title);
      String? savedPath;
      List<String> warnings;
      if (format == 'docx') {
        final result = await const SmartEditorDocxService().export(_document);
        savedPath = await saver.save(
          bytes: result.bytes,
          fileName: '$fileBase.docx',
          extension: 'docx',
          dialogTitle: 'Export Smart Editor document to Word',
        );
        warnings = result.warnings;
      } else {
        final result = await const SmartEditorPdfService().export(_document);
        savedPath = await saver.save(
          bytes: result.bytes,
          fileName: '$fileBase.pdf',
          extension: 'pdf',
          dialogTitle: 'Export Smart Editor document to PDF',
        );
        warnings = result.warnings;
      }
      if (!mounted || savedPath == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${format.toUpperCase()} saved successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (warnings.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export notes'),
            content: SingleChildScrollView(
              child: Text(warnings.map((item) => '• $item').join('\n\n')),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openPrintCenter() async {
    if (_exporting || _openingDocx) return;
    final persisted = await _persistNow(showFailure: true);
    if (!persisted || !mounted) return;

    final printDocument = _document;
    final source = PrintDocumentSource.fixed(
      title: printDocument.title.trim().isEmpty
          ? 'EduSheet Document'
          : printDocument.title,
      description: 'Smart Editor document',
      initialPageFormat: PdfPageFormat(
        printDocument.pageLayout.exportPageWidthPoints,
        printDocument.pageLayout.exportPageHeightPoints,
      ),
      load: () async {
        final result = await const SmartEditorPdfService().export(printDocument);
        return result.bytes;
      },
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PrintCenterScreen(
          source: source,
          allowChooseFile: false,
        ),
      ),
    );
  }

  static String _safeExportName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    return cleaned.isEmpty ? 'EduSheet Document' : cleaned;
  }

  void _toggleEditorMode() {
    setState(() => _fullMode = !_fullMode);
    _focusNode.requestFocus();
  }

  void _restoreSelection(TextSelection selection) {
    final end = math.max(0, _controller.document.length - 1);
    _controller.updateSelection(
      TextSelection(
        baseOffset: selection.baseOffset.clamp(0, end).toInt(),
        extentOffset: selection.extentOffset.clamp(0, end).toInt(),
      ),
      ChangeSource.local,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _insertMath() async {
    final selection = _controller.selection;
    final range = SmartEditorObjectCommands.selectionRange(_controller);
    ref.read(mathKeyboardControllerProvider.notifier).hideKeyboard();
    FocusManager.instance.primaryFocus?.unfocus();
    final expression = await FormulaEditorSheet.show(
      context,
      autoOpenMathKeyboard: true,
    );
    if (expression == null || !mounted) {
      if (mounted) _restoreSelection(selection);
      return;
    }
    SmartEditorObjectCommands.insertMath(
      _controller,
      expression,
      range: range,
    );
    _focusNode.requestFocus();
  }

  Future<MathExpression?> _editEmbeddedMath(
    BuildContext context,
    MathExpression expression,
  ) async {
    ref.read(mathKeyboardControllerProvider.notifier).hideKeyboard();
    FocusManager.instance.primaryFocus?.unfocus();
    final updated = await FormulaEditorSheet.show(
      context,
      initial: expression,
      autoOpenMathKeyboard: true,
    );
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
    return updated;
  }

  Future<SmartEditorWordAdvancedPayload?> _editImportedWordAdvanced(
    BuildContext context,
    SmartEditorWordAdvancedPayload payload,
  ) async {
    ref.read(mathKeyboardControllerProvider.notifier).hideKeyboard();
    FocusManager.instance.primaryFocus?.unfocus();
    final updated = await SmartEditorWordAdvancedEditorDialog.show(
      context,
      payload,
    );
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
    return updated;
  }

  Future<void> _insertGeometry() async {
    final selection = _controller.selection;
    final range = SmartEditorObjectCommands.selectionRange(_controller);
    ref.read(mathKeyboardControllerProvider.notifier).hideKeyboard();
    FocusManager.instance.primaryFocus?.unfocus();
    final diagram = await GeometryBuilderScreen.show(context);
    if (diagram == null || !mounted) {
      if (mounted) _restoreSelection(selection);
      return;
    }
    SmartEditorObjectCommands.insertGeometry(
      _controller,
      diagram,
      range: range,
    );
    _focusNode.requestFocus();
  }

  Future<void> _editImportedWordTable(
    BuildContext context,
    SmartEditorInteropTablePayload payload,
  ) async {
    final objectId = payload.objectId;
    if (objectId == null || objectId.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final updated = await SmartEditorDocxTableEditorSheet.show(context, payload);
    if (updated == null || !mounted || !context.mounted) return;
    final replaced = SmartEditorDocxStructureEditing.replaceEmbedByObjectId(
      _controller,
      keyName: SmartEditorInteropTableEmbedBuilder.keyName,
      objectId: objectId,
      encodedPayload: updated.encode(),
    );
    if (!replaced && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The imported Word object could not be updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    if (mounted) _focusNode.requestFocus();
  }

  Future<void> _editImportedWordImage(
    BuildContext context,
    SmartEditorInteropImagePayload payload,
  ) async {
    final objectId = payload.objectId;
    if (objectId == null || objectId.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final updated = await SmartEditorDocxImageEditorSheet.show(context, payload);
    if (updated == null || !mounted || !context.mounted) return;
    final replaced = SmartEditorDocxStructureEditing.replaceEmbedByObjectId(
      _controller,
      keyName: SmartEditorInteropImageEmbedBuilder.keyName,
      objectId: objectId,
      encodedPayload: updated.encode(),
    );
    if (!replaced && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The imported Word image could not be updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    if (mounted) _focusNode.requestFocus();
  }

  Future<void> _editImportedWordShape(
    BuildContext context,
    SmartEditorInteropShapePayload payload,
  ) async {
    final objectId = payload.objectId;
    if (objectId == null || objectId.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final updated = await SmartEditorDocxShapeEditorDialog.show(context, payload);
    if (updated == null || !mounted || !context.mounted) return;
    final replaced = SmartEditorDocxStructureEditing.replaceEmbedByObjectId(
      _controller,
      keyName: SmartEditorInteropShapeEmbedBuilder.keyName,
      objectId: objectId,
      encodedPayload: updated.encode(),
    );
    if (!replaced && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The imported Word shape could not be updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    if (mounted) _focusNode.requestFocus();
  }

  void _insertBreak(String type) {
    var start = _controller.selection.baseOffset;
    if (start < 0) start = _controller.document.length - 1;
    final plain = _controller.document.toPlainText();
    if (start > 0 && start <= plain.length && plain[start - 1] != '\n') {
      _controller.replaceText(start, 0, '\n', null);
      start += 1;
    }
    _controller.replaceText(
      start,
      0,
      BlockEmbed.custom(
        CustomBlockEmbed(SmartEditorBreakEmbedBuilder.keyName, type),
      ),
      null,
    );
    final after = start + 1;
    final updatedPlain = _controller.document.toPlainText();
    if (after >= updatedPlain.length || updatedPlain[after] != '\n') {
      _controller.replaceText(after, 0, '\n', null);
    }
    _controller.updateSelection(
      TextSelection.collapsed(offset: math.min(after + 1, _controller.document.length - 1)),
      ChangeSource.local,
    );
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    final desktopProperties = !compact && _showProperties;
    final layout = _document.pageLayout;

    return PopScope<void>(
      canPop: _exitApproved,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_close());
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyK, control: true):
              () => unawaited(_openCommandPalette()),
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
              () => unawaited(_openCommandPalette()),
          const SingleActivator(LogicalKeyboardKey.keyO, control: true):
              () => unawaited(_openWordDocument()),
          const SingleActivator(LogicalKeyboardKey.keyO, meta: true):
              () => unawaited(_openWordDocument()),
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              () => unawaited(_saveNow()),
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
              () => unawaited(_saveNow()),
          const SingleActivator(LogicalKeyboardKey.keyP, control: true):
              () => unawaited(_openPrintCenter()),
          const SingleActivator(LogicalKeyboardKey.keyP, meta: true):
              () => unawaited(_openPrintCenter()),
        },
        child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Save and close',
          onPressed: _close,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: TextField(
          key: const Key('smart-editor-title'),
          controller: _titleController,
          maxLines: 1,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Untitled Document',
          ),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('smart-editor-command-button'),
            tooltip: 'Commands (Ctrl+K)',
            onPressed: () => unawaited(_openCommandPalette()),
            icon: const Icon(Icons.search_rounded),
          ),
          if (!compact)
            IconButton(
              key: const Key('smart-editor-mode-toggle'),
              tooltip: _fullMode ? 'Switch to Smart mode' : 'Show full tools',
              onPressed: _toggleEditorMode,
              icon: Icon(
                _fullMode
                    ? Icons.auto_awesome_rounded
                    : Icons.dashboard_customize_outlined,
              ),
            ),
          if (!compact)
            IconButton(
              key: const Key('smart-editor-header-footer'),
              tooltip: 'Header & footer',
              onPressed: _editHeaderFooter,
              icon: const Icon(Icons.view_agenda_outlined),
            ),
          IconButton(
            key: const Key('smart-editor-properties'),
            tooltip: 'Properties',
            onPressed: () => _openProperties(compact: compact),
            icon: Icon(
              desktopProperties ? Icons.tune_rounded : Icons.tune_outlined,
            ),
          ),
          if (!compact)
            IconButton(
              key: const Key('smart-editor-layout'),
              tooltip: 'Page layout',
              onPressed: _editPageLayout,
              icon: const Icon(Icons.straighten_rounded),
            ),
          if (!compact)
            SmartEditorDesktopOpenDocxButton(
              busy: _openingDocx || _exporting,
              onOpen: () => unawaited(_openWordDocument()),
            ),
          if (!compact)
            PopupMenuButton<String>(
              key: const Key('smart-editor-export'),
              tooltip: 'Export',
              enabled: !_exporting && !_openingDocx,
              icon: _exporting || _openingDocx
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_outlined),
              onSelected: (value) => unawaited(_exportDocument(value)),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'docx',
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Export Word (.docx)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_outlined),
                      SizedBox(width: 10),
                      Text('Export PDF'),
                    ],
                  ),
                ),
              ],
            ),
          if (!compact)
            IconButton(
              key: const Key('smart-editor-print'),
              tooltip: 'Print (system dialog)',
              onPressed: _exporting || _openingDocx
                  ? null
                  : () => unawaited(_openPrintCenter()),
              icon: const Icon(Icons.print_outlined),
            ),
          if (!compact)
            IconButton(
              key: const Key('smart-editor-save'),
              tooltip: 'Save now',
              onPressed: _saveNow,
              icon: const Icon(Icons.save_outlined),
            ),
          if (compact)
            SmartEditorMobileDocumentMenu(
              fullMode: _fullMode,
              busy: _exporting || _openingDocx,
              onToggleMode: _toggleEditorMode,
              onOpenDocx: () => unawaited(_openWordDocument()),
              onExport: (value) => unawaited(_exportDocument(value)),
              onPrint: () => unawaited(_openPrintCenter()),
              onSave: () => unawaited(_saveNow()),
            ),
        ],
      ),
      body: Column(
        children: [
          _SmartEditorRibbon(
            controller: _controller,
            compact: compact,
            fullMode: _fullMode,
            onToggleMode: _toggleEditorMode,
            onCommandPalette: () => unawaited(_openCommandPalette()),
            onQuickInsert: () => unawaited(_openQuickInsert()),
            onInsertMath: _insertMath,
            onInsertGeometry: _insertGeometry,
          ),
          ValueListenableBuilder<String?>(
            valueListenable: _slashQueryNotifier,
            builder: (context, query, _) {
              if (query == null) return const SizedBox.shrink();
              return _SmartSlashCommandBar(
                query: query,
                onCommand: (command) async {
                  SmartEditorSmartCommands.removeSlashPrefix(_controller);
                  await _runSmartCommand(command);
                },
                onMore: () => unawaited(
                  _openCommandPalette(initialQuery: query, removeSlash: true),
                ),
              );
            },
          ),
          ValueListenableBuilder<SmartEditorSuggestion?>(
            valueListenable: _suggestionNotifier,
            builder: (context, suggestion, _) {
              if (suggestion == null) return const SizedBox.shrink();
              return _SmartSuggestionBar(
                suggestion: suggestion,
                onApply: () => _applySuggestion(suggestion),
                onIgnore: () => _ignoreSuggestion(suggestion),
              );
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            compact ? 8 : 28,
                            compact ? 10 : 24,
                            compact ? 8 : 28,
                            36,
                          ),
                          child: Center(
                            child: _SmartEditorPage(
                              controller: _controller,
                              focusNode: _focusNode,
                              editorScrollController: _editorScrollController,
                              document: _document,
                              availableWidth: constraints.maxWidth,
                              onEditMath: _editEmbeddedMath,
                              onEditImportedWordImage: _editImportedWordImage,
                              onEditImportedWordTable: _editImportedWordTable,
                              onEditImportedWordShape: _editImportedWordShape,
                              onEditWordAdvanced: _editImportedWordAdvanced,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (desktopProperties) ...[
                  const VerticalDivider(width: 1),
                  SmartEditorPropertiesPanel(
                    controller: _controller,
                    document: _document,
                    onLayout: _editPageLayout,
                    onHeaderFooter: _editHeaderFooter,
                    onBorderChanged: _setBorder,
                    onInsertPageBreak: () => _insertBreak('page'),
                    onInsertSectionBreak: () => _insertBreak('section'),
                  ),
                ],
              ],
            ),
          ),
          ValueListenableBuilder<AutosaveStatus>(
            valueListenable: _saveStatusNotifier,
            builder: (context, status, _) {
              return ValueListenableBuilder<int>(
                valueListenable: _wordCountNotifier,
                builder: (context, wordCount, _) => _SmartEditorStatusBar(
                  status: status,
                  wordCount: wordCount,
                  layout: layout,
                ),
              );
            },
          ),
        ],
      ),
        ),
      ),
    );
  }

  int _wordCount(String text) {
    var count = 0;
    final normalized = text.replaceAll('\uFFFC', ' ');
    for (final _ in RegExp(r'\S+').allMatches(normalized)) {
      count += 1;
    }
    return count;
  }
}

class _SmartEditorAcademicObjectBar extends StatelessWidget {
  const _SmartEditorAcademicObjectBar({
    required this.compact,
    required this.fullMode,
    required this.onToggleMode,
    required this.onCommandPalette,
    required this.onQuickInsert,
    required this.onInsertMath,
    required this.onInsertGeometry,
  });

  final bool compact;
  final bool fullMode;
  final VoidCallback onToggleMode;
  final VoidCallback onCommandPalette;
  final VoidCallback onQuickInsert;
  final Future<void> Function() onInsertMath;
  final Future<void> Function() onInsertGeometry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      key: const Key('smart-editor-academic-object-bar'),
      children: [
        IconButton.filledTonal(
          key: const Key('smart-editor-quick-insert'),
          tooltip: 'Quick insert',
          onPressed: onQuickInsert,
          icon: const Icon(Icons.add_rounded),
        ),
        const SizedBox(width: 6),
        if (!compact) ...[
          FilledButton.tonalIcon(
            key: const Key('smart-editor-insert-math'),
            onPressed: onInsertMath,
            icon: const Icon(Icons.functions_rounded, size: 18),
            label: const Text('Math'),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: 6),
          FilledButton.tonalIcon(
            key: const Key('smart-editor-insert-geometry'),
            onPressed: onInsertGeometry,
            icon: const Icon(Icons.change_history_rounded, size: 18),
            label: const Text('Geometry'),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ] else ...[
          IconButton.filledTonal(
            key: const Key('smart-editor-insert-math'),
            tooltip: 'Insert math equation',
            onPressed: onInsertMath,
            icon: const Icon(Icons.functions_rounded),
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            key: const Key('smart-editor-insert-geometry'),
            tooltip: 'Insert editable geometry',
            onPressed: onInsertGeometry,
            icon: const Icon(Icons.change_history_rounded),
          ),
        ],
        const SizedBox(width: 6),
        IconButton(
          key: const Key('smart-editor-command-palette-button'),
          tooltip: 'Commands (Ctrl+K)',
          onPressed: onCommandPalette,
          icon: const Icon(Icons.bolt_rounded),
        ),
        const Spacer(),
        if (!compact)
          Text(
            fullMode ? 'Full tools' : 'Smart mode',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          key: const Key('smart-editor-ribbon-mode-toggle'),
          onPressed: onToggleMode,
          icon: Icon(
            fullMode ? Icons.auto_awesome_rounded : Icons.dashboard_customize_outlined,
            size: 18,
          ),
          label: Text(fullMode ? 'Smart' : 'Full'),
          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }
}

class _SmartEditorRibbon extends StatelessWidget {
  const _SmartEditorRibbon({
    required this.controller,
    required this.compact,
    required this.fullMode,
    required this.onToggleMode,
    required this.onCommandPalette,
    required this.onQuickInsert,
    required this.onInsertMath,
    required this.onInsertGeometry,
  });

  final QuillController controller;
  final bool compact;
  final bool fullMode;
  final VoidCallback onToggleMode;
  final VoidCallback onCommandPalette;
  final VoidCallback onQuickInsert;
  final Future<void> Function() onInsertMath;
  final Future<void> Function() onInsertGeometry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 12,
          vertical: 5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SmartEditorAcademicObjectBar(
              compact: compact,
              fullMode: fullMode,
              onToggleMode: onToggleMode,
              onCommandPalette: onCommandPalette,
              onQuickInsert: onQuickInsert,
              onInsertMath: onInsertMath,
              onInsertGeometry: onInsertGeometry,
            ),
            const SizedBox(height: 4),
            SizedBox(
              key: const Key('smart-editor-toolbar'),
              width: double.infinity,
              child: QuillSimpleToolbar(
                controller: controller,
                config: fullMode
                    ? (compact ? _compactFullConfig : _desktopFullConfig)
                    : _smartConfig,
              ),
            ),
            if (!fullMode)
              AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  if (controller.selection.isCollapsed) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Tip: select text for Question / Section / Normal conversion, type / for commands.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      key: const Key('smart-editor-context-toolbar'),
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Selected text',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        ActionChip(
                          key: const Key('smart-editor-context-question'),
                          label: const Text('Question'),
                          onPressed: () => SmartEditorSmartCommands.applyAcademicStyle(
                            controller,
                            SmartEditorAcademicStyle.question,
                          ),
                        ),
                        ActionChip(
                          key: const Key('smart-editor-context-section'),
                          label: const Text('Section'),
                          onPressed: () => SmartEditorSmartCommands.applyAcademicStyle(
                            controller,
                            SmartEditorAcademicStyle.section,
                          ),
                        ),
                        ActionChip(
                          key: const Key('smart-editor-context-instruction'),
                          label: const Text('Instruction'),
                          onPressed: () => SmartEditorSmartCommands.applyAcademicStyle(
                            controller,
                            SmartEditorAcademicStyle.instruction,
                          ),
                        ),
                        ActionChip(
                          key: const Key('smart-editor-context-normal'),
                          label: const Text('Normal'),
                          onPressed: () => SmartEditorSmartCommands.applyAcademicStyle(
                            controller,
                            SmartEditorAcademicStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  static const _smartConfig = QuillSimpleToolbarConfig(
    showFontFamily: false,
    showFontSize: false,
    showBoldButton: true,
    showItalicButton: true,
    showUnderLineButton: true,
    showStrikeThrough: false,
    showInlineCode: false,
    showColorButton: false,
    showBackgroundColorButton: false,
    showClearFormat: true,
    showHeaderStyle: true,
    showListNumbers: true,
    showListBullets: true,
    showListCheck: false,
    showCodeBlock: false,
    showQuote: false,
    showIndent: true,
    showLineHeightButton: false,
    showLink: false,
    showUndo: true,
    showRedo: true,
    showDirection: false,
    showAlignmentButtons: true,
    showSubscript: false,
    showSuperscript: false,
    showSearchButton: false,
    multiRowsDisplay: false,
  );

  static const _compactFullConfig = QuillSimpleToolbarConfig(
    showFontFamily: false,
    showFontSize: true,
    showBoldButton: true,
    showItalicButton: true,
    showUnderLineButton: true,
    showStrikeThrough: false,
    showInlineCode: false,
    showColorButton: false,
    showBackgroundColorButton: false,
    showClearFormat: true,
    showHeaderStyle: true,
    showListNumbers: true,
    showListBullets: true,
    showListCheck: false,
    showCodeBlock: false,
    showQuote: false,
    showIndent: true,
    showLineHeightButton: true,
    showLink: false,
    showUndo: true,
    showRedo: true,
    showDirection: false,
    showAlignmentButtons: true,
    showSubscript: true,
    showSuperscript: true,
    showSearchButton: false,
    multiRowsDisplay: false,
  );

  static const _desktopFullConfig = QuillSimpleToolbarConfig(
    showFontFamily: true,
    showFontSize: true,
    showBoldButton: true,
    showItalicButton: true,
    showUnderLineButton: true,
    showStrikeThrough: true,
    showInlineCode: false,
    showColorButton: true,
    showBackgroundColorButton: true,
    showClearFormat: true,
    showHeaderStyle: true,
    showListNumbers: true,
    showListBullets: true,
    showListCheck: false,
    showCodeBlock: false,
    showQuote: true,
    showIndent: true,
    showLineHeightButton: true,
    showLink: true,
    showUndo: true,
    showRedo: true,
    showDirection: false,
    showAlignmentButtons: true,
    showSubscript: true,
    showSuperscript: true,
    showSearchButton: false,
    multiRowsDisplay: false,
  );
}

class _SmartSlashCommandBar extends StatelessWidget {
  const _SmartSlashCommandBar({
    required this.query,
    required this.onCommand,
    required this.onMore,
  });

  final String query;
  final Future<void> Function(SmartEditorCommandId command) onCommand;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final matches = smartEditorAllCommands
        .where((command) => command.matches(query))
        .take(4)
        .toList(growable: false);
    return Material(
      key: const Key('smart-editor-slash-bar'),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const SizedBox(width: 10),
            Text(
              '/$query',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 7),
                itemCount: matches.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final command = matches[index];
                  return ActionChip(
                    key: ValueKey('smart-editor-slash-${command.id.name}'),
                    avatar: Icon(command.icon, size: 16),
                    label: Text(command.title),
                    onPressed: () => onCommand(command.id),
                  );
                },
              ),
            ),
            IconButton(
              key: const Key('smart-editor-slash-more'),
              tooltip: 'All matching commands',
              onPressed: onMore,
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartSuggestionBar extends StatelessWidget {
  const _SmartSuggestionBar({
    required this.suggestion,
    required this.onApply,
    required this.onIgnore,
  });

  final SmartEditorSuggestion suggestion;
  final VoidCallback onApply;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('smart-editor-suggestion-bar'),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                suggestion.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              key: const Key('smart-editor-suggestion-ignore'),
              onPressed: onIgnore,
              child: const Text('Ignore'),
            ),
            FilledButton.tonal(
              key: const Key('smart-editor-suggestion-apply'),
              onPressed: onApply,
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartEditorPage extends StatelessWidget {
  const _SmartEditorPage({
    required this.controller,
    required this.focusNode,
    required this.editorScrollController,
    required this.document,
    required this.availableWidth,
    required this.onEditMath,
    required this.onEditImportedWordImage,
    required this.onEditImportedWordTable,
    required this.onEditImportedWordShape,
    required this.onEditWordAdvanced,
  });

  final QuillController controller;
  final FocusNode focusNode;
  final ScrollController editorScrollController;
  final SmartDocument document;
  final double availableWidth;
  final MathExpressionEditCallback onEditMath;
  final SmartEditorInteropImageEditCallback onEditImportedWordImage;
  final SmartEditorInteropTableEditCallback onEditImportedWordTable;
  final SmartEditorInteropShapeEditCallback onEditImportedWordShape;
  final SmartEditorWordAdvancedEditCallback onEditWordAdvanced;

  @override
  Widget build(BuildContext context) {
    final layout = document.pageLayout;
    final maxWidth = layout.logicalWidth;
    final pageWidth = math
        .min(maxWidth, math.max(180.0, availableWidth - 16))
        .toDouble();
    final scale = pageWidth / layout.logicalWidth;
    final minHeight = layout.logicalHeight * scale;
    final topMargin = layout.topMarginPoints * scale;
    final rightMargin = layout.rightMarginPoints * scale;
    final bottomMargin = layout.bottomMarginPoints * scale;
    final leftMargin = layout.leftMarginPoints * scale;
    final headerHeight = document.header.enabled ? 54.0 * scale : 0.0;
    final footerHeight = document.footer.enabled ? 54.0 * scale : 0.0;
    final minBodyHeight = math.max(
      120.0,
      minHeight - topMargin - bottomMargin - headerHeight - footerHeight,
    ).toDouble();

    return Container(
      key: const Key('smart-editor-page'),
      width: pageWidth,
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: BoxDecoration(
        color: _wordBackgroundColor(document.wordBackgroundColorHex),
        border: _pageBorder(layout.borderStyle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      foregroundDecoration: layout.borderStyle ==
              SmartDocumentPageBorderStyle.doubleLine
          ? BoxDecoration(
              border: Border.all(color: Colors.black54, width: 1),
            )
          : null,
      padding: EdgeInsets.fromLTRB(
        leftMargin,
        topMargin,
        rightMargin,
        bottomMargin,
      ),
      child: Container(
        decoration: layout.borderStyle == SmartDocumentPageBorderStyle.doubleLine
            ? BoxDecoration(
                border: Border.all(color: Colors.black38, width: 1),
              )
            : null,
        padding: layout.borderStyle == SmartDocumentPageBorderStyle.doubleLine
            ? EdgeInsets.all(math.max(5.0, 7 * scale).toDouble())
            : EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (document.header.enabled)
              _HeaderFooterView(
                key: const Key('smart-editor-page-header'),
                config: document.header,
                dividerBelow: true,
              ),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: minBodyHeight),
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  height: 1.35,
                ),
                child: QuillEditor(
                  controller: controller,
                  focusNode: focusNode,
                  scrollController: editorScrollController,
                  config: QuillEditorConfig(
                    placeholder: 'Start typing…',
                    scrollable: false,
                    padding: EdgeInsets.zero,
                    embedBuilders: [
                      SmartEditorBreakEmbedBuilder(),
                      SmartEditorInteropImageEmbedBuilder(
                        onEdit: onEditImportedWordImage,
                      ),
                      SmartEditorInteropShapeEmbedBuilder(
                        onEdit: onEditImportedWordShape,
                      ),
                      SmartEditorInteropTableEmbedBuilder(
                        onEdit: onEditImportedWordTable,
                      ),
                      SmartEditorWordAdvancedEmbedBuilder(
                        onEdit: onEditWordAdvanced,
                      ),
                      GeometryEmbedBuilder(),
                      MathExpressionEmbedBuilder(onEdit: onEditMath),
                    ],
                  ),
                ),
              ),
            ),
            if (document.footer.enabled)
              _HeaderFooterView(
                key: const Key('smart-editor-page-footer'),
                config: document.footer,
                dividerBelow: false,
              ),
          ],
        ),
      ),
    );
  }

  Color _wordBackgroundColor(String? rawHex) {
    final raw = rawHex?.replaceAll('#', '').trim();
    if (raw == null || !RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(raw)) {
      return Colors.white;
    }
    return Color(int.parse('FF$raw', radix: 16));
  }

  Border? _pageBorder(SmartDocumentPageBorderStyle style) => switch (style) {
    SmartDocumentPageBorderStyle.none => null,
    SmartDocumentPageBorderStyle.subtle => Border.all(color: Colors.black12),
    SmartDocumentPageBorderStyle.solid => Border.all(
        color: Colors.black54,
        width: 1.2,
      ),
    SmartDocumentPageBorderStyle.doubleLine => Border.all(
        color: Colors.black87,
        width: 1,
      ),
  };
}

class _HeaderFooterView extends StatelessWidget {
  const _HeaderFooterView({
    super.key,
    required this.config,
    required this.dividerBelow,
  });

  final SmartDocumentHeaderFooter config;
  final bool dividerBelow;

  @override
  Widget build(BuildContext context) {
    final alignment = switch (config.alignment) {
      SmartDocumentHeaderFooterAlignment.left => TextAlign.left,
      SmartDocumentHeaderFooterAlignment.center => TextAlign.center,
      SmartDocumentHeaderFooterAlignment.right => TextAlign.right,
    };
    final text = config.text.trim().isEmpty ? ' ' : config.text;
    final divider = Divider(
      height: 12,
      thickness: 0.8,
      color: Colors.black38,
    );
    return Padding(
      padding: EdgeInsets.only(
        bottom: dividerBelow ? 8 : 0,
        top: dividerBelow ? 0 : 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!dividerBelow && config.showDivider) divider,
          Text(
            text,
            textAlign: alignment,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 11.5,
              height: 1.25,
            ),
          ),
          if (dividerBelow && config.showDivider) divider,
        ],
      ),
    );
  }
}

class _SmartEditorStatusBar extends StatelessWidget {
  const _SmartEditorStatusBar({
    required this.status,
    required this.wordCount,
    required this.layout,
  });

  final AutosaveStatus status;
  final int wordCount;
  final SmartDocumentPageLayout layout;

  @override
  Widget build(BuildContext context) {
    final label = switch (status.phase) {
      AutosavePhase.idle => 'Ready',
      AutosavePhase.waiting => 'Saving…',
      AutosavePhase.saving => 'Saving…',
      AutosavePhase.saved => 'Saved',
      AutosavePhase.failed => 'Save failed',
    };
    final pageLabel = switch (layout.pageSize) {
      SmartDocumentPageSize.a4 => 'A4',
      SmartDocumentPageSize.letter => 'Letter',
    };
    return Semantics(
      liveRegion: true,
      label: status.accessibleLabel,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              return Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          status.phase == AutosavePhase.failed
                              ? Icons.error_outline_rounded
                              : Icons.save_outlined,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text('$wordCount words'),
                  if (!compact) ...[
                    const SizedBox(width: 14),
                    Flexible(
                      child: Text(
                        '$pageLabel · ${layout.orientation == SmartDocumentOrientation.portrait ? 'Portrait' : 'Landscape'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
  }
}
