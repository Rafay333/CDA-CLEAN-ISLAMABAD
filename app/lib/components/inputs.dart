import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class SearchBarField extends StatelessWidget {
  const SearchBarField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppType.body,
      cursorColor: AppColors.emerald,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppType.body.copyWith(color: AppColors.disabledText),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
          size: 22,
        ),
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        enabledBorder: _border(AppColors.border),
        focusedBorder: _border(AppColors.emerald),
        border: _border(AppColors.border),
      ),
    );
  }

  OutlineInputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: color),
    );
  }
}

class TextInput extends StatefulWidget {
  const TextInput({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.maxLines = 1,
    this.obscure = false,
    this.canToggleObscure = false,
    this.textInputAction,
    this.dense = false,
    this.onChanged,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.autofillHints,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool obscure;
  final bool canToggleObscure;
  final TextInputAction? textInputAction;
  final bool dense;
  final ValueChanged<String>? onChanged;
  final bool enableSuggestions;
  final bool autocorrect;
  final Iterable<String>? autofillHints;

  @override
  State<TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<TextInput> {
  late bool _hidden = widget.obscure || widget.canToggleObscure;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: widget.dense ? AppType.label.copyWith(fontSize: 12) : AppType.label),
        SizedBox(height: widget.dense ? 4 : 8),
        TextField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          maxLines: widget.canToggleObscure ? 1 : widget.maxLines,
          obscureText: widget.canToggleObscure ? _hidden : widget.obscure,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          enableSuggestions: widget.enableSuggestions,
          autocorrect: widget.autocorrect,
          autofillHints: widget.autofillHints,
          style: AppType.body,
          cursorColor: AppColors.emerald,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppType.body.copyWith(color: AppColors.disabledText),
            isDense: widget.dense,
            filled: true,
            fillColor: AppColors.white,
            errorText: hasError ? widget.errorText : null,
            errorStyle: AppType.caption.copyWith(color: AppColors.error),
            suffixIcon: widget.canToggleObscure
                ? IconButton(
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _hidden = !_hidden),
                    visualDensity: widget.dense ? VisualDensity.compact : VisualDensity.standard,
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                      size: widget.dense ? 20 : 24,
                    ),
                  )
                : null,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: widget.dense ? 10 : 14,
            ),
            enabledBorder: _border(
              hasError ? AppColors.error : AppColors.border,
            ),
            focusedBorder: _border(
              hasError ? AppColors.error : AppColors.emerald,
            ),
            errorBorder: _border(AppColors.error),
            focusedErrorBorder: _border(AppColors.error),
            border: _border(AppColors.border),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: color),
    );
  }
}
