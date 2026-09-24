import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:edusheet/features/printing/application/file_print_source_factory.dart';
import 'package:edusheet/features/printing/domain/print_document_source.dart';
import 'package:edusheet/features/printing/services/global_print_service.dart';

/// Global, reusable print workspace for Windows and Android.
///
/// It intentionally keeps the final printer-specific choices in the native
/// system dialog. That is where copies, paper trays, duplex, colour, and
/// vendor-driver options are most accurate.
class PrintCenterScreen extends StatefulWidget {
  const PrintCenterScreen({
    super.key,
    this.source,
    this.allowChooseFile = true,
    this.printService = const GlobalPrintService(),
  });

  final PrintDocumentSource? source;
  final bool allowChooseFile;
  final GlobalPrintService printService;

  @override
  State<PrintCenterScreen> createState() => _PrintCenterScreenState();
}

class _PrintCenterScreenState extends State<PrintCenterScreen> {
  PrintDocumentSource? _source;
  List<Printer> _desktopPrinters = const <Printer>[];
  bool _loadingPrinters = false;
  bool _printing = false;
  bool _choosingFile = false;
  Object? _printerDiscoveryError;

  @override
  void initState() {
    super.initState();
    _source = widget.source;
    _refreshPrinters();
  }

  Future<void> _refreshPrinters() async {
    if (!Platform.isWindows) return;
    setState(() {
      _loadingPrinters = true;
      _printerDiscoveryError = null;
    });
    try {
      final printers = await widget.printService.discoverDesktopPrinters();
      if (!mounted) return;
      setState(() => _desktopPrinters = printers);
    } catch (error) {
      if (!mounted) return;
      setState(() => _printerDiscoveryError = error);
    } finally {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  Future<void> _chooseFile() async {
    if (_choosingFile) return;
    setState(() => _choosingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['pdf', 'docx'],
        withData: false,
      );
      if (!mounted || result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final path = picked.path;
      if (path == null) {
        _message('This file could not be read from the selected location.');
        return;
      }

      setState(() {
        _source = FilePrintSourceFactory.fromPath(
          path,
          displayName: picked.name,
        );
      });
    } catch (error) {
      if (mounted) _message('Unable to open file: $error');
    } finally {
      if (mounted) setState(() => _choosingFile = false);
    }
  }

  Future<void> _print() async {
    final source = _source;
    if (source == null || _printing) return;
    setState(() => _printing = true);
    try {
      final submitted = await widget.printService.openSystemPrintDialog(source);
      if (!mounted) return;
      if (!submitted) {
        _message('Print dialog closed without starting a print job.');
      }
    } catch (error) {
      if (mounted) _message('Printing failed: $error');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Print Center',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            if (source != null)
              Text(
                source.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          if (widget.allowChooseFile)
            IconButton(
              key: const Key('print-center-choose-file'),
              tooltip: source == null ? 'Choose file' : 'Choose another file',
              onPressed: _choosingFile ? null : _chooseFile,
              icon: _choosingFile
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_open_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: source == null
            ? _EmptyPrintCenter(onChooseFile: _chooseFile)
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 880;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _PrintPreviewPane(source: source),
                        ),
                        SizedBox(
                          width: 360,
                          child: _PrintControlPanel(
                            source: source,
                            loadingPrinters: _loadingPrinters,
                            printers: _desktopPrinters,
                            printerDiscoveryError: _printerDiscoveryError,
                            printing: _printing,
                            choosingFile: _choosingFile,
                            allowChooseFile: widget.allowChooseFile,
                            onPrint: _print,
                            onChooseFile: _chooseFile,
                            onRefreshPrinters: _refreshPrinters,
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      SizedBox(
                        height: constraints.maxHeight.clamp(360.0, 560.0).toDouble(),
                        child: _PrintPreviewPane(source: source),
                      ),
                      _PrintControlPanel(
                        source: source,
                        loadingPrinters: _loadingPrinters,
                        printers: _desktopPrinters,
                        printerDiscoveryError: _printerDiscoveryError,
                        printing: _printing,
                        choosingFile: _choosingFile,
                        allowChooseFile: widget.allowChooseFile,
                        onPrint: _print,
                        onChooseFile: _chooseFile,
                        onRefreshPrinters: _refreshPrinters,
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _PrintPreviewPane extends StatelessWidget {
  const _PrintPreviewPane({required this.source});

  final PrintDocumentSource source;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerLow,
      child: PdfPreview(
        key: ValueKey('print-preview-${source.pdfFileName}'),
        build: source.build,
        initialPageFormat: source.initialPageFormat,
        pdfFileName: source.pdfFileName,
        dynamicLayout: source.dynamicLayout,
        useActions: false,
        allowPrinting: false,
        allowSharing: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        padding: const EdgeInsets.all(16),
        loadingWidget: const Center(child: CircularProgressIndicator()),
        onError: (context, error) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 42,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Preview unavailable',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrintControlPanel extends StatelessWidget {
  const _PrintControlPanel({
    required this.source,
    required this.loadingPrinters,
    required this.printers,
    required this.printerDiscoveryError,
    required this.printing,
    required this.choosingFile,
    required this.allowChooseFile,
    required this.onPrint,
    required this.onChooseFile,
    required this.onRefreshPrinters,
  });

  final PrintDocumentSource source;
  final bool loadingPrinters;
  final List<Printer> printers;
  final Object? printerDiscoveryError;
  final bool printing;
  final bool choosingFile;
  final bool allowChooseFile;
  final VoidCallback onPrint;
  final VoidCallback onChooseFile;
  final VoidCallback onRefreshPrinters;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PanelSection(
              title: 'Document',
              icon: Icons.description_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (source.description != null &&
                      source.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      source.description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const _InfoRow(
                    icon: Icons.auto_awesome_motion_outlined,
                    text: 'Layout is preserved from the document',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _PanelSection(
              title: Platform.isWindows ? 'Windows printer' : 'Android printing',
              icon: Platform.isWindows
                  ? Icons.print_outlined
                  : Icons.phone_android_rounded,
              trailing: Platform.isWindows
                  ? IconButton(
                      tooltip: 'Refresh printers',
                      onPressed: loadingPrinters ? null : onRefreshPrinters,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                    )
                  : null,
              child: _printerStatus(context),
            ),
            const SizedBox(height: 14),
            _PanelSection(
              title: 'Print settings',
              icon: Icons.tune_rounded,
              child: Column(
                children: [
                  const _InfoRow(
                    icon: Icons.content_copy_rounded,
                    text: 'Copies and page range',
                  ),
                  const SizedBox(height: 8),
                  const _InfoRow(
                    icon: Icons.straighten_rounded,
                    text: 'Paper size and orientation',
                  ),
                  const SizedBox(height: 8),
                  const _InfoRow(
                    icon: Icons.flip_rounded,
                    text: 'Duplex, colour and printer options when supported',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'These stay in the native system print dialog so EduSheet uses the settings actually supported by your printer and driver.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('print-center-print-button'),
              onPressed: printing ? null : onPrint,
              icon: printing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print_rounded),
              label: Text(
                printing ? 'Opening print dialog…' : 'Print with system dialog',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            if (allowChooseFile) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: choosingFile ? null : onChooseFile,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Choose another file'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _printerStatus(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!Platform.isWindows) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            icon: Icons.check_circle_outline_rounded,
            text: 'Uses Android Print Service',
          ),
          SizedBox(height: 8),
          _InfoRow(
            icon: Icons.wifi_rounded,
            text: 'Select available local/network printer in the system sheet',
          ),
        ],
      );
    }

    if (loadingPrinters) {
      return const Row(
        children: [
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('Checking installed printers…'),
        ],
      );
    }

    if (printerDiscoveryError != null) {
      return Text(
        'Printer discovery was unavailable. The Windows print dialog can still be opened.',
        style: TextStyle(color: scheme.onSurfaceVariant),
      );
    }

    if (printers.isEmpty) {
      return Text(
        'No installed printer was reported yet. You can still open the Windows print dialog to add or select a printer.',
        style: TextStyle(color: scheme.onSurfaceVariant),
      );
    }

    Printer? defaultPrinter;
    for (final printer in printers) {
      if (printer.isDefault) {
        defaultPrinter = printer;
        break;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${printers.length} installed printer${printers.length == 1 ? '' : 's'} detected',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (defaultPrinter != null) ...[
          const SizedBox(height: 6),
          _InfoRow(
            icon: Icons.check_circle_outline_rounded,
            text: 'Default: ${defaultPrinter.name}',
          ),
        ],
      ],
    );
  }
}

class _PanelSection extends StatelessWidget {
  const _PanelSection({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _EmptyPrintCenter extends StatelessWidget {
  const _EmptyPrintCenter({required this.onChooseFile});

  final VoidCallback onChooseFile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  Icons.print_rounded,
                  size: 44,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Print from EduSheet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a PDF or Word (.docx) file here, or use Print inside Smart Editor, Create Paper, OMR, and Document Reader. EduSheet will preview it first and then hand it to the native Windows or Android print dialog.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                key: const Key('print-center-empty-choose-file'),
                onPressed: onChooseFile,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Choose file to print'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(220, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
