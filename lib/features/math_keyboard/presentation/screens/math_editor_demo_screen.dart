import 'package:flutter/material.dart';
import 'package:math_keyboard/math_keyboard.dart';
import '../widgets/math_keyboard_field.dart';

class MathEditorDemoScreen extends StatefulWidget {
  const MathEditorDemoScreen({super.key});

  @override
  State<MathEditorDemoScreen> createState() => _MathEditorDemoScreenState();
}

class _MathEditorDemoScreenState extends State<MathEditorDemoScreen> {
  final _controller = MathFieldEditingController();

  @override
  void dispose() {
    _controller.dispose();
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
            child: MathKeyboardField(
              controller: _controller,
              builder: (context, fieldFocusNode, isMathActive) => MathField(
                controller: _controller,
                focusNode: fieldFocusNode,
                opensKeyboard: !isMathActive,
                decoration: const InputDecoration(
                  labelText: 'Enter Equation',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  // Handle TeX output here
                },
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
