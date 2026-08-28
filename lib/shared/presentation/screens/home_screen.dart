import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../../features/editor/presentation/screens/create_paper_screen.dart';
import '../../../features/editor/presentation/screens/saved_papers_screen.dart';
import '../../../features/editor/presentation/providers/editor_provider.dart';
import '../../../features/omr/presentation/pages/omr_generator_page.dart';
import '../../../features/question_bank/presentation/screens/question_bank_screen.dart';
import '../../../features/document_reader/presentation/screens/document_reader_screen.dart';
import '../../../features/calculator/presentation/screens/calculator_screen.dart';
import '../../../features/word_converter/presentation/screens/word_converter_screen.dart';
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cards = <Widget>[
      _HomeCard(
        title: 'Create Paper',
        lottieAsset: 'assets/lottie/WritePaper.json',
        icon: Icons.note_add,
        color: Colors.blue,
        onTap: _openCreatePaper,
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
      _HomeCard(
        title: 'Settings',
        lottieAsset: 'assets/lottie/settingssliders.json',
        icon: Icons.settings,
        color: Colors.blueGrey,
        onTap: () => _open(const SettingsScreen()),
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
        title: 'Calculator',
        lottieAsset: 'assets/lottie/calculator.json',
        icon: Icons.calculate,
        color: Colors.teal,
        onTap: () => _open(const CalculatorScreen()),
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
            const _AnimatedGradientTitle(),
          ],
        ),
        foregroundColor: isDark ? Colors.white : Colors.black,
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
                    : 2;
            final padding = width < 380 ? 14.0 : 24.0;
            final spacing = width < 380 ? 14.0 : 20.0;
            final aspectRatio = width < 380
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

class _AnimatedGradientTitle extends StatefulWidget {
  const _AnimatedGradientTitle();

  @override
  State<_AnimatedGradientTitle> createState() => _AnimatedGradientTitleState();
}

class _AnimatedGradientTitleState extends State<_AnimatedGradientTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Colors.blue,
                Colors.purple,
                Colors.pink,
                Colors.blue,
              ],
              stops: const [0.0, 0.33, 0.66, 1.0],
              begin: Alignment(-2.0 + (4.0 * _controller.value), 0.0),
              end: Alignment(0.0 + (4.0 * _controller.value), 0.0),
            ).createShader(bounds);
          },
          child: const Text(
            'EduSheet',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        );
      },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 170;
        final cardPadding = compact ? 14.0 : 18.0;
        final lottieSize = compact ? 76.0 : 90.0;
        final titleSize = compact ? 14.0 : 16.0;

        return GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isPressed ? 0.97 : 1,
            duration: const Duration(milliseconds: 140),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _isPressed ? 5 : 0, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(
                      widget.color,
                      isDark ? Colors.black : Colors.white,
                      0.88,
                    )!,
                    isDark
                        ? Theme.of(context).colorScheme.surfaceContainer
                        : Colors.white,
                  ],
                ),
                border: Border.all(color: widget.color.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    // soft glow
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color.withValues(
                            alpha: isDark ? 0.12 : 0.08,
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      bottom: -30,
                      left: -30,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (isDark ? Colors.black : Colors.white)
                              .withValues(alpha: 0.15),
                        ),
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.all(cardPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TOP ROW
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  'FEATURE',
                                  style: TextStyle(
                                    color: widget.color,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),

                              Icon(
                                Icons.arrow_outward_rounded,
                                size: 18,
                                color: widget.color,
                              ),
                            ],
                          ),

                          // CENTER EMPTY SPACE FOR LOTTIE
                          Expanded(
                            child: Center(
                              child: Lottie.asset(
                                widget.lottieAsset,
                                height: lottieSize,
                                width: lottieSize,
                                repeat: true,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    widget.icon,
                                    size: compact ? 50 : 60,
                                    color: widget.color,
                                  );
                                },
                              ),
                            ),
                          ),

                          // BOTTOM TITLE
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: titleSize,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap to explore',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
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
