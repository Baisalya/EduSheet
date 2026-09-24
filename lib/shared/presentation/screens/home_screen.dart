import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../../features/editor/presentation/screens/create_paper_screen.dart';
import '../../../features/editor/presentation/screens/saved_papers_screen.dart';
import '../../../features/editor/presentation/providers/editor_provider.dart';
import '../../../features/advertising/presentation/widgets/home_sponsored_banner.dart';
import '../../../features/advertising/application/home_interstitial_controller.dart';
import '../../../features/guided_experience/guides/create_paper_guide.dart';
import '../../../features/guided_experience/guides/create_syllabus_guide.dart';
import '../../../features/guided_experience/domain/contextual_help.dart';
import '../../../features/guided_experience/presentation/screens/user_manual_screen.dart';
import '../../../features/guided_experience/presentation/widgets/contextual_help_prompt.dart';
import '../../../features/guided_experience/presentation/widgets/guide_anchor.dart';
import '../../../features/omr/presentation/pages/omr_generator_page.dart';
import '../../../features/question_bank/presentation/screens/question_bank_screen.dart';
import 'package:edusheet/features/document_reader/presentation/screens/document_reader_screen.dart';
import '../../../core/files/recent_native_file_store.dart';
import 'package:edusheet/features/document_reader/domain/models/document_open_request.dart';
import 'package:edusheet/features/document_reader/presentation/providers/document_provider.dart';
import 'package:edusheet/features/document_reader/presentation/screens/file_preview_screen.dart';
import '../../../features/eds_import/presentation/screens/eds_import_center_screen.dart';
import '../../../features/teaching_planner/presentation/screens/teaching_workspace_screen.dart';
import '../../../features/calculator/presentation/screens/calculator_screen.dart';
import '../../../features/word_converter/presentation/screens/word_converter_screen.dart';
import '../../../features/printing/presentation/screens/print_center_screen.dart';
import '../../../features/teaching_planner/presentation/screens/teaching_planner_screen.dart';
import 'package:edusheet/features/smart_editor/presentation/screens/smart_editor_library_screen.dart';
import '../../../features/premium/presentation/widgets/premium_badge_button.dart';
import '../../../features/premium/application/premium_controller.dart';
import '../../../features/premium/domain/freemium_policy.dart';
import '../../../features/premium/presentation/widgets/premium_gate_dialog.dart';
import '../../services/review_service.dart';
import '../providers/privacy_provider.dart';
import '../widgets/privacy_policy_dialog.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _privacyDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ReviewService.instance.registerLaunch());
      _checkPrivacyPolicy();
    });
  }

  void _checkPrivacyPolicy() {
    final privacyState = ref.read(privacyProvider);
    privacyState.whenData((version) {
      _showPrivacyDialogIfNeeded();
    });
  }

  Future<void> _showPrivacyDialogIfNeeded() async {
    if (!mounted || _privacyDialogOpen) return;
    if (!ref.read(privacyProvider.notifier).needsApproval) return;

    _privacyDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PrivacyPolicyDialog(),
    );
    _privacyDialogOpen = false;
  }

  Future<void> _open(Widget page) async {
    final interstitial = ref.read(homeInterstitialControllerProvider);
    unawaited(interstitial.prepare());
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (context) => page),
    );
    if (!mounted) return;
    await interstitial.onReturnedHome();
  }

  Future<void> _openManual({EduSheetManualSection? focus}) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => EduSheetUserManualScreen(focus: focus),
      ),
    );
  }

  Future<void> _showRecentFiles() async {
    final store = ref.read(recentNativeFileStoreProvider);
    final entries = await store.load();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        if (entries.isEmpty) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, size: 42),
                  SizedBox(height: 12),
                  Text('No recent files yet'),
                  SizedBox(height: 6),
                  Text(
                    'Files opened with EduSheet will appear here while they remain available.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Recent files',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final entry = entries[index];
                      return ListTile(
                        leading: Icon(_recentFileIcon(entry.extension)),
                        title: Text(
                          entry.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          entry.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          await _openRecentFile(entry);
                        },
                      );
                    },
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await store.clear();
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.clear_all_rounded),
                  label: const Text('Clear recent files'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _recentFileIcon(String extension) => switch (extension) {
    '.eds' => Icons.inventory_2_outlined,
    '.edtp' => Icons.school_outlined,
    '.pdf' => Icons.picture_as_pdf_outlined,
    '.doc' || '.docx' || '.rtf' || '.odt' => Icons.description_outlined,
    '.xls' || '.xlsx' || '.csv' || '.ods' => Icons.grid_on_outlined,
    '.ppt' || '.pptx' || '.odp' => Icons.slideshow_outlined,
    _ => Icons.insert_drive_file_outlined,
  };

  Future<void> _openRecentFile(RecentNativeFileEntry entry) async {
    final request = DocumentOpenRequest.fromReader(entry.path);
    if (entry.extension == '.eds') {
      await _open(
        EdsImportCenterScreen(
          initialFilePath: entry.path,
          initialDisplayName: entry.displayName,
        ),
      );
      return;
    }
    if (entry.extension == '.edtp') {
      await _open(TeachingWorkspaceScreen(initialTeachingPackPath: entry.path));
      return;
    }

    final result = await ref.read(documentOpenCoordinatorProvider).resolve(request);
    if (!mounted || result.duplicate) return;
    final session = result.session;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Unable to open this file.')),
      );
      return;
    }
    await _open(FilePreviewScreen(document: session.document));
  }

  Future<void> _openCreatePaper() async {
    final premium = ref.read(premiumProvider);
    final savedPapers = await ref.read(savedPapersProvider.future);
    if (!mounted) return;
    if (!FreemiumPolicy.canCreatePaper(
      premium: premium,
      savedPaperCount: savedPapers.length,
    )) {
      await showPremiumGateDialog(
        context,
        title: 'Free paper limit reached',
        message:
            'Free includes up to ${FreemiumPolicy.freeSavedPaperLimit} saved papers. Existing papers stay editable and personal .eds backups remain available. Premium adds unlimited new papers.',
      );
      return;
    }
    ref.read(editorStateProvider.notifier).reset();
    await _open(const CreatePaperScreen());
  }

  @override
  Widget build(BuildContext context) {
    // Listen for privacy changes to show dialog if state updates asynchronously.
    ref.listen(privacyProvider, (previous, next) {
      next.whenData((version) {
        _showPrivacyDialogIfNeeded();
      });
    });

    final cards = <Widget>[
      GuideAnchor(
        targetId: CreateSyllabusGuideTargets.homeTeachingPlanner,
        reportPointerActivation: true,
        child: _HomeCard(
          title: 'Teaching Planner',
          lottieAsset:
          'assets/lottie/teacher_syllabus_planner_final_embedded.json',
          icon: Icons.calendar_month_rounded,
          color: Colors.deepPurple,
          onTap: () => _open(const TeachingPlannerScreen()),
        ),
      ),
      GuideAnchor(
        targetId: CreatePaperGuideTargets.homeCreatePaper,
        reportPointerActivation: true,
        child: _HomeCard(
          title: 'Create Paper',
          lottieAsset: 'assets/lottie/WritePaper.json',
          icon: Icons.note_add,
          color: Colors.blue,
          onTap: _openCreatePaper,
        ),
      ),
      _HomeCard(
        title: 'Smart Editor',
        lottieAsset: 'assets/lottie/WritePaper.json',
        icon: Icons.edit_note_rounded,
        color: Colors.blueAccent,
        onTap: () => _open(const SmartEditorLibraryScreen()),
      ),
      _HomeCard(
        title: 'Saved Papers',
        lottieAsset: 'assets/lottie/SavedFolder.json',
        icon: Icons.folder,
        color: Colors.purple,
        onTap: () => _open(const SavedPapersScreen()),
      ),
      /*    _HomeCard(
        title: 'Import EduSheet File',
        lottieAsset: 'assets/lottie/SavedFolder.json',
        icon: Icons.file_open_outlined,
        color: Colors.cyan,
        onTap: () => _open(const EdsImportCenterScreen()),
      ),*/
      _HomeCard(
        title: 'OMR Generator',
        lottieAsset: 'assets/lottie/selectoption.json',
        icon: Icons.grid_on,
        color: Colors.orange,
        onTap: () => _open(const OmrGeneratorPage()),
      ),
      _HomeCard(
        title: 'Question Bank',
        lottieAsset: 'assets/lottie/Exams.json',
        icon: Icons.account_balance,
        color: Colors.green,
        onTap: () => _open(const QuestionBankScreen()),
      ),

      _HomeCard(
        title: 'Calculator',
        lottieAsset: 'assets/lottie/calculator.json',
        icon: Icons.calculate,
        color: Colors.teal,
        onTap: () => _open(const CalculatorScreen()),
      ),
      _HomeCard(
        title: 'PDF/Word Reader',
        lottieAsset: 'assets/lottie/DocumentReader.json',
        icon: Icons.description,
        color: Colors.redAccent,
        onTap: () => _open(const DocumentReaderScreen()),
      ),
      _HomeCard(
        title: 'Word Converter',
        lottieAsset: 'assets/lottie/convert.json',
        icon: Icons.transform,
        color: Colors.indigo,
        onTap: () => _open(const WordConverterScreen()),
      ),

      _HomeCard(
        title: 'Print Center',
        lottieAsset: 'assets/lottie/DocumentReader.json',
        icon: Icons.print_rounded,
        color: Colors.blueGrey,
        onTap: () => _open(const PrintCenterScreen()),
      ),

      _HomeCard(
        title: 'Settings',
        lottieAsset: 'assets/lottie/settingssliders.json',
        icon: Icons.settings,
        color: Colors.blueGrey,
        onTap: () => _open(const SettingsScreen()),
      ),
    ];

    final scaffold = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/branding/edusheet_brand_mark.png',
              key: const ValueKey('edusheet-brand-logo'),
              width: 36,
              height: 36,
              filterQuality: FilterQuality.high,
              semanticLabel: 'EduSheet brand logo',
            ),
            const SizedBox(width: 10),
            const _BrandTitle(),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'User manual and safe demos',
            onPressed: () => _openManual(),
            icon: const Icon(Icons.help_outline_rounded),
          ),
          IconButton(
            tooltip: 'Recent files',
            onPressed: _showRecentFiles,
            icon: const Icon(Icons.history_rounded),
          ),
          const PremiumBadgeButton(),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1100
                ? 4
                : width >= 760
                ? 3
                : width < 280
                ? 1
                : 2;
            final padding = width < 280
                ? 8.0
                : width < 380
                ? 14.0
                : 24.0;
            final spacing = width < 280
                ? 10.0
                : width < 380
                ? 14.0
                : 20.0;
            final aspectRatio = width < 280
                ? 0.9
                : width < 380
                ? 0.82
                : width >= 760
                ? 0.96
                : 0.9;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.all(padding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: columns,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        childAspectRatio: aspectRatio,
                        children: cards,
                      ),
                      const HomeSponsoredBanner(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    return ContextualHelpOffer(
      suggestion: const ContextualHelpSuggestion(
        id: 'home.quick_start_help',
        screen: GuidedScreenContext.home,
        title: 'Not sure where to start?',
        message:
            'I can open a short User Manual with simple steps and safe practice demos. Your real work will not be changed.',
        primaryLabel: 'Open quick help',
        minimumInactivity: Duration(seconds: 75),
        suppressWhenRelatedGuideCompleted: false,
      ),
      signals: const ContextualHelpSignals(
        currentScreen: GuidedScreenContext.home,
      ),
      onShowMe: () => _openManual(focus: EduSheetManualSection.start),
      child: scaffold,
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'EduSheet',
      style: theme.textTheme.titleLarge?.copyWith(
        color: theme.colorScheme.onSurface,
        fontSize: 25,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
    );
  }
}

class _HomeCard extends StatefulWidget {
  final String title;
  final String lottieAsset;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HomeCard({
    required this.title,
    required this.lottieAsset,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 170;
        final cardPadding = compact ? 13.0 : 17.0;
        final visualSize = compact ? 72.0 : 88.0;
        final titleSize = compact ? 14.0 : 16.0;
        final radius = BorderRadius.circular(20);
        final workspaceSurface = Color.alphaBlend(
          scheme.primary.withValues(alpha: isDark ? 0.055 : 0.03),
          scheme.surface,
        );
        final surface = Color.alphaBlend(
          widget.color.withValues(alpha: isDark ? 0.045 : 0.025),
          workspaceSurface,
        );
        final border = Color.alphaBlend(
          scheme.primary.withValues(alpha: isDark ? 0.16 : 0.10),
          scheme.outlineVariant,
        );

        return AnimatedScale(
          scale: _isPressed ? 0.985 : 1,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Material(
            color: surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (value) {
                if (_isPressed != value) {
                  setState(() => _isPressed = value);
                }
              },
              borderRadius: radius,
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: compact ? 32 : 36,
                          height: compact ? 32 : 36,
                          decoration: BoxDecoration(
                            color: widget.color.withValues(
                              alpha: isDark ? 0.18 : 0.11,
                            ),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            widget.icon,
                            size: compact ? 17 : 19,
                            color: widget.color,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                      ],
                    ),
                    Expanded(
                      child: Center(
                        child: reduceMotion
                            ? Icon(
                                widget.icon,
                                size: compact ? 48 : 58,
                                color: widget.color,
                              )
                            : Lottie.asset(
                                widget.lottieAsset,
                                height: visualSize,
                                width: visualSize,
                                fit: BoxFit.contain,
                                repeat: true,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    widget.icon,
                                    size: compact ? 48 : 58,
                                    color: widget.color,
                                  );
                                },
                              ),
                      ),
                    ),
                    Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: titleSize,
                        height: 1.18,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Open',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
