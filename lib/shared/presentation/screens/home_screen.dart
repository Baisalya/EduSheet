import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../../features/editor/presentation/screens/create_paper_screen.dart';
import '../../../features/editor/presentation/screens/saved_papers_screen.dart';
import '../../../features/editor/presentation/providers/editor_provider.dart';
import '../../../features/omr/presentation/pages/omr_generator_page.dart';
import '../../../features/question_bank/presentation/screens/question_bank_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 12),
            _AnimatedGradientTitle(),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 0.9,
          children: [
            _HomeCard(
              title: 'Create Paper',
              lottieAsset: 'assets/lottie/WritePaper.json',
              icon: Icons.note_add,
              color: Colors.blue,
              onTap: () {
                ref.read(editorStateProvider.notifier).reset();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreatePaperScreen()),
                );
              },
            ),
            _HomeCard(
              title: 'Saved Papers',
              lottieAsset: 'assets/lottie/SavedFolder.json',
              icon: Icons.folder,
              color: Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SavedPapersScreen()),
              ),
            ),
            _HomeCard(
              title: 'OMR Generator',
              lottieAsset: 'assets/lottie/selectoption.json',
              icon: Icons.grid_on,
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OmrGeneratorPage()),
              ),
            ),
            _HomeCard(
              title: 'Question Bank',
              lottieAsset: 'assets/lottie/Exams.json',
              icon: Icons.account_balance,
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QuestionBankScreen()),
              ),
            ),
            _HomeCard(
              title: 'Settings',
              lottieAsset: 'assets/lottie/settingssliders.json',
              icon: Icons.settings,
              color: Colors.blueGrey,
              onTap: () {},
              isComingSoon: true,
            ),
            _HomeCard(
              title: 'PDF/Word Reader',
              lottieAsset: 'assets/lottie/DocumentReader.json',
              icon: Icons.description,
              color: Colors.redAccent,
              onTap: () {},
              isComingSoon: true,
            ),
            _HomeCard(
              title: 'Word Converter',
              lottieAsset: 'assets/lottie/convert.json',
              icon: Icons.transform,
              color: Colors.indigo,
              onTap: () {},
              isComingSoon: true,
            ),
            _HomeCard(
              title: 'Calculator',
              lottieAsset: 'assets/lottie/calculator.json',
              icon: Icons.calculate,
              color: Colors.teal,
              onTap: () {},
              isComingSoon: true,
            ),
          ],
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
  final bool isComingSoon;

  const _HomeCard({
    required this.title,
    required this.lottieAsset,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isComingSoon = false,
  });

  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isComingSoon ? Colors.grey : widget.color;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.isComingSoon
          ? () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.title} is coming soon!'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
          : widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 140),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            _isPressed ? 5 : 0,
            0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isComingSoon
                  ? [
                Colors.grey.shade100,
                Colors.grey.shade50,
              ]
                  : [
                Color.lerp(widget.color, Colors.white, 0.88)!,
                Colors.white,
              ],
            ),
            border: Border.all(
              color: widget.isComingSoon
                  ? Colors.grey.shade200
                  : widget.color.withOpacity(0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 22,
                offset: const Offset(0, 10),
                spreadRadius: -6,
              ),
              BoxShadow(
                color: widget.color.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                      color: widget.color.withOpacity(0.08),
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
                      color: Colors.white.withOpacity(0.25),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TOP ROW
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (widget.isComingSoon)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text(
                                "SOON",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: widget.color.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                "FEATURE",
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
                            color: widget.isComingSoon
                                ? Colors.grey
                                : widget.color,
                          ),
                        ],
                      ),

                      // CENTER EMPTY SPACE FOR LOTTIE
                      Expanded(
                        child: Center(
                          child: Lottie.asset(
                            widget.lottieAsset,
                            height: 90,
                            width: 90,
                            repeat: true,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                widget.icon,
                                size: 60,
                                color: baseColor,
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
                              fontSize: 16,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: widget.isComingSoon
                                  ? Colors.grey.shade700
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.isComingSoon
                                ? "Launching soon"
                                : "Tap to explore",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: widget.isComingSoon
                                  ? Colors.grey
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
  }
}