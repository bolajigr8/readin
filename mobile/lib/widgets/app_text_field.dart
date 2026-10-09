import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../theme/app_typography.dart';

/// RN `ui/Input`: label above, 56px box, left icon, password eye, error text.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.error,
    this.leftIcon,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.enabled = true,
    this.autofillHints,
    this.inputFormatters,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? error;
  final IconData? leftIcon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null && widget.error!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              widget.label!,
              style: AppTypography.label(
                size: 14,
                weight: FontWeight.w500,
                color: AppColors.textSecondary,
                lineHeight: 20,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          height: AppDimensions.inputHeight,
          // Password: the eye button carries 10px of hit-slop padding, so the
          // container's right padding shrinks by the same amount (icon stays
          // exactly 16px from the edge like RN).
          padding: EdgeInsets.only(
            left: 16,
            right: widget.isPassword ? 6 : 16,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: hasError ? AppColors.error500 : AppColors.borderDefault,
            ),
          ),
          child: Row(
            children: [
              if (widget.leftIcon != null) ...[
                Icon(widget.leftIcon, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  enabled: widget.enabled,
                  obscureText: widget.isPassword && !_visible,
                  autocorrect: false,
                  enableSuggestions: !widget.isPassword,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  textCapitalization: TextCapitalization.none,
                  autofillHints: widget.autofillHints,
                  inputFormatters: widget.inputFormatters,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  cursorColor: AppColors.primary500,
                  style: AppTypography.body16,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: widget.hint,
                    hintStyle: AppTypography.label(
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              if (widget.isPassword)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _visible = !_visible),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      _visible ? Ionicons.eye_off_outline : Ionicons.eye_outline,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              widget.error!,
              style: AppTypography.label(
                size: 12,
                color: AppColors.error500,
                lineHeight: 16,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
