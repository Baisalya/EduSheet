import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:edusheet/features/math_keyboard/domain/models/math_symbol.dart';

class MathKey extends StatefulWidget {
  final MathSymbol? symbol;
  final String? label;
  final String? tex;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Color? textColor;
  final double? fontSize;
  final Widget? child;

  const MathKey({
    super.key,
    this.symbol,
    this.label,
    this.tex,
    required this.onTap,
    this.onLongPress,
    this.color,
    this.textColor,
    this.fontSize,
    this.child,
  });

  @override
  State<MathKey> createState() => _MathKeyState();
}

class _MathKeyState extends State<MathKey> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = widget.label ?? widget.symbol?.label;
    final effectiveTex = widget.tex ?? widget.symbol?.tex;
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Material(
              color: widget.color ?? (_isPressed 
                  ? theme.colorScheme.surfaceContainerHighest 
                  : theme.colorScheme.surfaceContainerHigh),
              borderRadius: BorderRadius.circular(8),
              elevation: _isPressed ? 0 : 1,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.1), 
                    width: 0.5
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(2),
                child: Center(
                  child: widget.child ?? _buildContent(context, effectiveLabel, effectiveTex),
                ),
              ),
            ),
          ),
          if (_isPressed)
            Positioned(
              top: -60,
              left: -12,
              right: -12,
              child: _buildPreviewBubble(context, effectiveLabel, effectiveTex),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewBubble(BuildContext context, String? label, String? tex) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 100),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: widget.child ?? _buildContent(context, label, tex, preview: true),
                ),
              ),
              CustomPaint(
                size: const Size(16, 10),
                painter: _BubbleTrianglePainter(
                  color: theme.colorScheme.primaryContainer,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, String? label, String? tex, {bool preview = false}) {
    final theme = Theme.of(context);
    final style = TextStyle(
      fontSize: (widget.fontSize ?? 18) * (preview ? 1.2 : 1.0),
      fontWeight: FontWeight.w500,
      color: widget.textColor ?? theme.colorScheme.onSurfaceVariant,
    );

    final isTex = tex != null && (tex.contains('\\') || tex.contains('^') || tex.contains('_') || tex.contains('{'));

    if (isTex) {
      String displayTex = tex
          .replaceAll(r'\frac{1}{2}', r'\frac{1}{2}')
          .replaceAll(r'\frac{d}{dx}', r'\frac{d}{dx}')
          .replaceAll(r'\frac{dy}{dx}', r'\frac{dy}{dx}')
          .replaceAll(r'\frac{d^2}{dx^2}', r'\frac{d^2}{dx^2}')
          .replaceAll(r'\int_{}^{}^{}', r'\int_{a}^{b}')
          .replaceAll(r'\sqrt{}', r'\sqrt{\square}')
          .replaceAll(r'\sqrt[3]{}', r'\sqrt[3]{\square}')
          .replaceAll(r'\sqrt[]{}', r'\sqrt[n]{\square}')
          .replaceAll(r'^{}', r'x^{\square}')
          .replaceAll(r'_{}', r'x_{\square}')
          .replaceAll(r'\frac{}{}', r'\frac{\square}{\square}')
          .replaceAll(r'\sum_{}^{}', r'\sum_{n=1}^{\infty}')
          .replaceAll(r'\prod_{}^{}', r'\prod_{n=1}^{\infty}')
          .replaceAll(r'\int_{}^{}', r'\int_{a}^{b}')
          .replaceAll(r'|{}|', r'|x|')
          .replaceAll('{}', '')
          .replaceAll('{ }', '')
          .replaceAll('&', '')
          .replaceAll(r'\begin{pmatrix}', r'\begin{matrix}')
          .replaceAll(r'\end{pmatrix}', r'\end{matrix}');

      if (!preview && displayTex.length > 20) {
        return Text(
          label ?? 'Temp',
          textAlign: TextAlign.center,
          style: style.copyWith(fontSize: 10),
        );
      }

      return IgnorePointer(
        child: Math.tex(
          displayTex,
          mathStyle: MathStyle.display,
          textStyle: style,
          onErrorFallback: (err) {
            return Text(
              label ?? '?',
              textAlign: TextAlign.center,
              style: style,
            );
          },
        ),
      );
    }

    return Text(
      label ?? tex ?? '',
      textAlign: TextAlign.center,
      style: style,
    );
  }
}

class _BubbleTrianglePainter extends CustomPainter {
  final Color color;
  _BubbleTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
