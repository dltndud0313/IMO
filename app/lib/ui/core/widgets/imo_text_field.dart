import 'package:flutter/material.dart';

import '../themes/design_tokens.dart';

class ImoTextField extends StatelessWidget {
  const ImoTextField({
    super.key,
    required this.label,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
  });

  final String label;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      minHeight: AppSpacing.buttonHeight,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: AppTextStyles.body,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
