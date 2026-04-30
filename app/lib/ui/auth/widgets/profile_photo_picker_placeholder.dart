import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';

class ProfilePhotoPickerPlaceholder extends StatelessWidget {
  const ProfilePhotoPickerPlaceholder({
    super.key,
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : AppColors.cardSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(
              selected ? Icons.check_rounded : Icons.person_outline_rounded,
              color: selected
                  ? AppColors.primaryStrong
                  : AppColors.textTertiary,
              size: 64,
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.card, width: 4),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: AppColors.card,
              size: 17,
            ),
          ),
        ],
      ),
    );
  }
}
