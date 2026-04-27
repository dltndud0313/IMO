import 'package:flutter/material.dart';

import '../themes/design_tokens.dart';

class ImoButton extends StatelessWidget {
  const ImoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isExpanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text(label),
            ],
          );

    final button = FilledButton(
      onPressed: onPressed,
      child: child,
    );

    if (!isExpanded) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}
