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

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: widget.color ?? const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(4),
              elevation: _isPressed ? 0 : 1,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.all(2),
                child: Center(
                  child: _buildContent(context, effectiveLabel, effectiveTex),
                ),
              ),
            ),
            if (_isPressed)
              Positioned(
                top: -40,
                left: -10,
                right: -10,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _buildContent(context, effectiveLabel, effectiveTex, preview: true),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, String? label, String? tex, {bool preview = false}) {
    final style = TextStyle(
      fontSize: (widget.fontSize ?? 18) * (preview ? 1.2 : 1.0), // Reduced preview multiplier slightly
      fontWeight: FontWeight.w500,
      color: widget.textColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
    );

    // Better detection for LaTeX: starts with \, contains ^ or _, or is a known fraction/root
    final isTex = tex != null && (tex.contains('\\') || tex.contains('^') || tex.contains('_') || tex.contains('{'));

    if (isTex) {
      // Clean up common LaTeX patterns for keyboard display
      String displayTex = tex
          .replaceAll(r'\frac{1}{2}', r'\frac{\square}{\square}')
          .replaceAll(r'\frac{d}{dx}', r'\frac{d}{dx}')
          .replaceAll(r'\frac{dy}{dx}', r'\frac{dy}{dx}')
          .replaceAll(r'\frac{d^2}{dx^2}', r'\frac{d^2}{dx^2}')
          .replaceAll(r'\int_{}^{}^{}', r'\int_{a}^{b}')
          .replaceAll('{}', '')
          .replaceAll('{ }', '')
          .replaceAll('&', '')
          .replaceAll(r'\begin{pmatrix}', r'\begin{matrix}') // Use simpler matrix for keys
          .replaceAll(r'\end{pmatrix}', r'\end{matrix}');

      // Special handling for templates that are too wide
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
            // Fallback to label if rendering fails
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
