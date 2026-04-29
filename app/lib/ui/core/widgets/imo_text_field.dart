import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../themes/design_tokens.dart';

class ImoTextField extends StatefulWidget {
  const ImoTextField({
    super.key,
    this.label,
    this.controller,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.clearable = false,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.onChanged,
    this.enabled = true,
  });

  final String? label;
  final TextEditingController? controller;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool clearable;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  State<ImoTextField> createState() => _ImoTextFieldState();
}

class _ImoTextFieldState extends State<ImoTextField> {
  late final TextEditingController _controller;
  late bool _obscureText;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _obscureText = widget.obscureText;
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleTextChanged() {
    if (widget.clearable && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final borderColor = hasError
        ? AppColors.error
        : _focused
            ? AppColors.primary
            : AppColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.xs),
        ],
        Focus(
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.enabled ? AppColors.cardSubtle : AppColors.disabledBg,
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              border: Border.all(
                color: borderColor,
                width: hasError ? 1.5 : AppSpacing.borderWidth,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.buttonHeight,
              ),
              child: Row(
                children: [
                  if (widget.prefixIcon != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    IconTheme(
                      data: const IconThemeData(
                        color: AppColors.textTertiary,
                        size: 18,
                      ),
                      child: widget.prefixIcon!,
                    ),
                  ],
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: widget.enabled,
                      keyboardType: widget.keyboardType,
                      inputFormatters: widget.inputFormatters,
                      obscureText: _obscureText,
                      onChanged: widget.onChanged,
                      style: AppTextStyles.bodyLg,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.md,
                        ),
                        hintText: widget.hint,
                        hintStyle: AppTextStyles.body.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  if (widget.clearable && _controller.text.isNotEmpty)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        _controller.clear();
                        widget.onChanged?.call('');
                      },
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  if (widget.obscureText)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          setState(() => _obscureText = !_obscureText),
                      icon: Icon(
                        _obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                    )
                  else if (widget.suffixIcon != null) ...[
                    IconTheme(
                      data: const IconThemeData(
                        color: AppColors.textTertiary,
                        size: 18,
                      ),
                      child: widget.suffixIcon!,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (widget.errorText != null || widget.helperText != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            widget.errorText ?? widget.helperText!,
            style: AppTextStyles.caption.copyWith(
              color: hasError ? AppColors.error : AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}
