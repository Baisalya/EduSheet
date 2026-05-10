import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/math_keyboard_controller.dart';
import 'math_keyboard_field.dart';

class FloatingElementManager extends ConsumerWidget {
  const FloatingElementManager({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elements = ref.watch(mathKeyboardControllerProvider.select((s) => s.floatingElements));
    
    return Stack(
      children: elements.map((e) => FloatingElementWidget(element: e, key: ValueKey(e.id))).toList(),
    );
  }
}

class FloatingElementWidget extends ConsumerStatefulWidget {
  final FloatingElement element;

  const FloatingElementWidget({super.key, required this.element});

  @override
  ConsumerState<FloatingElementWidget> createState() => _FloatingElementWidgetState();
}

class _FloatingElementWidgetState extends ConsumerState<FloatingElementWidget> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.element.content);
    _textController.addListener(() {
      ref.read(mathKeyboardControllerProvider.notifier).updateElement(
        widget.element.id,
        content: _textController.text,
      );
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(mathKeyboardControllerProvider.notifier);
    final theme = Theme.of(context);

    return Positioned(
      left: widget.element.position.dx,
      top: widget.element.position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          controller.updateElement(
            widget.element.id,
            position: widget.element.position + details.delta,
          );
        },
        child: Container(
          width: widget.element.size.width,
          height: widget.element.size.height,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
            color: widget.element.type == FloatingElementType.textBox 
                ? theme.colorScheme.surface.withValues(alpha: 0.8)
                : Colors.transparent,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Content
              Center(
                child: widget.element.type == FloatingElementType.shape
                    ? Icon(widget.element.icon, size: widget.element.size.shortestSide, color: theme.colorScheme.primary)
                    : _buildTextBox(context),
              ),

              // Delete button (on long press or small button?)
              Positioned(
                right: -10,
                top: -10,
                child: GestureDetector(
                  onTap: () => controller.removeElement(widget.element.id),
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: theme.colorScheme.error,
                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ),

              // Resize Handle
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    controller.updateElement(
                      widget.element.id,
                      size: Size(
                        (widget.element.size.width + details.delta.dx).clamp(40.0, 500.0),
                        (widget.element.size.height + details.delta.dy).clamp(40.0, 500.0),
                      ),
                    );
                  },
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
                    ),
                    child: const Icon(Icons.open_in_full, size: 10, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextBox(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: MathKeyboardField(
        controller: _textController,
        builder: (context, focusNode, isMathActive) {
          return TextField(
            controller: _textController,
            focusNode: focusNode,
            maxLines: null,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          );
        },
      ),
    );
  }
}
