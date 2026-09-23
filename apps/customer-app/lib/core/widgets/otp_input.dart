import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 6-box OTP entry: auto-focus, backspace navigation, per the Figma
/// reference. Backspace navigation works by watching for a field becoming
/// empty in [TextField.onChanged] (which fires on that transition) rather
/// than a raw-key listener racing the TextField's own focus — simpler, and
/// jumps back the moment a digit is cleared instead of needing a second
/// backspace press on an already-empty box.
class OtpInput extends StatefulWidget {
  final int length;
  final ValueChanged<String> onChanged;
  const OtpInput({super.key, this.length = 6, required this.onChanged});

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _handleChanged(int index, String value) {
    if (value.length > 1) {
      // Pasting a full code into one box: keep just the last character here.
      value = value.characters.last;
      _controllers[index].value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
    }
    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    widget.onChanged(_controllers.map((c) => c.text).join());
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (i) {
        return SizedBox(
          width: 44,
          height: 52,
          child: TextField(
            controller: _controllers[i],
            focusNode: _focusNodes[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: Theme.of(context).textTheme.titleLarge,
            decoration: const InputDecoration(counterText: '', contentPadding: EdgeInsets.zero),
            onChanged: (value) => _handleChanged(i, value),
          ),
        );
      }),
    );
  }
}
