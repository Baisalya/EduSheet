import 'package:flutter/material.dart';
import 'package:math_keyboard/math_keyboard.dart';
import '../widgets/math_keyboard_view.dart';

class MathEditorDemoScreen extends StatefulWidget {
  const MathEditorDemoScreen({super.key});

  @override
  State<MathEditorDemoScreen> createState() => _MathEditorDemoScreenState();
}

class _MathEditorDemoScreenState extends State<MathEditorDemoScreen> {
  final _controller = MathFieldEditingController();
  final _focusNode = FocusNode();
  bool _showCustomKeyboard = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _showCustomKeyboard = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Math Keyboard Demo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: MathField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                labelText: 'Enter Equation',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // Handle TeX output here
              },
            ),
          ),
          const Spacer(),
          if (_showCustomKeyboard)
            MathKeyboardView(controller: _controller),
        ],
      ),
    );
  }
}
