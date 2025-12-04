import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable decimal input field widget with comma-to-period conversion
///
/// Automatically converts Turkish decimal separator (,) to English (.)
/// Maintains cursor position during conversion
class DecimalInputField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool enabled;
  final Widget? suffixIcon;
  final String? prefixText;
  final String? suffixText;
  final int? maxLines;
  final TextInputType keyboardType;
  final InputDecoration? decoration;

  const DecimalInputField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.suffixIcon,
    this.prefixText,
    this.suffixText,
    this.maxLines = 1,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: decoration ??
          InputDecoration(
            labelText: labelText,
            hintText: hintText,
            border: const OutlineInputBorder(),
            suffixIcon: suffixIcon,
            prefixText: prefixText,
            suffixText: suffixText,
          ),
      validator: validator,
      onChanged: (value) {
        // Convert comma to period automatically
        if (value.contains(',')) {
          final cursorPosition = controller.selection.base.offset;
          final newValue = value.replaceAll(',', '.');

          controller.value = TextEditingValue(
            text: newValue,
            selection: TextSelection.collapsed(
              offset: cursorPosition,
            ),
          );
        }

        // Call custom onChanged if provided
        if (onChanged != null) {
          onChanged!(controller.text);
        }
      },
      inputFormatters: [
        // Allow digits, period, and comma
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
      ],
    );
  }
}

/// Stepper widget for incrementing/decrementing decimal values
///
/// Useful for margin percentage and other numeric inputs
class DecimalInputWithStepper extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final double step;
  final double min;
  final double max;
  final String? suffixText;
  final String? Function(String?)? validator;

  const DecimalInputWithStepper({
    super.key,
    required this.controller,
    required this.labelText,
    this.step = 10.0,
    this.min = 0.0,
    this.max = 1000.0,
    this.suffixText,
    this.validator,
  });

  void _increment() {
    final current = double.tryParse(controller.text) ?? 0.0;
    final newValue = (current + step).clamp(min, max);
    controller.text = newValue.toStringAsFixed(0);
  }

  void _decrement() {
    final current = double.tryParse(controller.text) ?? 0.0;
    final newValue = (current - step).clamp(min, max);
    controller.text = newValue.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DecimalInputField(
            controller: controller,
            labelText: labelText,
            suffixText: suffixText,
            validator: validator,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _increment,
              tooltip: '+$step',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: _decrement,
              tooltip: '-$step',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }
}
