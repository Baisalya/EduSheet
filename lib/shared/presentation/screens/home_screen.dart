import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../../features/editor/presentation/screens/create_paper_screen.dart';
import '../../../features/editor/presentation/screens/saved_papers_screen.dart';
import '../../../features/editor/presentation/providers/editor_provider.dart';
import '../../../features/guided_experience/guides/create_paper_guide.dart';
import '../../../features/guided_experience/guides/create_syllabus_guide.dart';
import '../../../features/guided_experience/presentation/widgets/guide_anchor.dart';
import '../../../features/omr/presentation/pages/omr_generator_page.dart';
import '../../../features/question_bank/presentation/screens/question_bank_screen.dart';
import '../../../features/document_reader/presentation/screens/document_reader_screen.dart';
import '../../../features/calculator/presentation/screens/calculator_screen.dart';
import '../../../features/word_converter/presentation/screens/word_converter_screen.dart';
import '../../../features/teaching_planner/presentation/screens/teaching_planner_screen.dart';
import '../../../features/premium/presentation/widgets/premium_badge_button.dart';
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

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  void _openCreatePaper() {
    ref.read(editorStateProvider.notifier).reset();
    _open(const CreatePaperScreen());
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
        title: 'Saved Papers',
        lottieAsset: 'assets/lottie/SavedFolder.json',
        icon: Icons.folder,
        color: Colors.purple,
        onTap: () => _open(const SavedPapersScreen()),
      ),
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
      GuideAnchor(
        targetId: CreateSyllabusGuideTargets.homeTeachingPlanner,
        reportPointerActivation: true,
        child: _HomeCard(
          title: 'Teaching Planner',
          lottieAsset: 'assets/lottie/teaching_planner_schedule.json',
          icon: Icons.calendar_month_rounded,
          color: Colors.deepPurple,
          onTap: () => _open(const TeachingPlannerScreen()),
        ),
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
        title: 'Settings',
        lottieAsset: 'assets/lottie/settingssliders.json',
        icon: Icons.settings,
        color: Colors.blueGrey,
        onTap: () => _open(const SettingsScreen()),
      ),
    ];

    return Scaffold(
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
        actions: const [PremiumBadgeButton()],
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
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columns,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: aspectRatio,
                    children: cards,
                  ),
                ),
              ),
            );
          },
        ),
      ),
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
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

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
