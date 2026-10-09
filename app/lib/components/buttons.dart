import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final active = onPressed != null;
    return _ButtonSurface(
      onPressed: active && !loading ? onPressed : null,
      decoration: BoxDecoration(
        gradient: active ? AppGradients.primary : null,
        color: active ? null : AppColors.disabled,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      height: height,
      child: _ButtonLabel(
        label: label,
        loading: loading,
        icon: icon,
        color: active ? AppColors.white : AppColors.disabledText,
        spinnerColor: AppColors.white,
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return _ButtonSurface(
      onPressed: onPressed,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.emerald),
      ),
      child: _ButtonLabel(label: label, icon: icon, color: AppColors.emerald),
    );
  }
}

class OutlineButton extends StatelessWidget {
  const OutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return _ButtonSurface(
      onPressed: onPressed,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: _ButtonLabel(label: label, icon: icon, color: AppColors.navy),
    );
  }
}

class _ButtonSurface extends StatelessWidget {
  const _ButtonSurface({
    required this.decoration,
    required this.child,
    this.onPressed,
    this.height = 52,
  });

  final BoxDecoration decoration;
  final Widget child;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({
    required this.label,
    required this.color,
    this.loading = false,
    this.icon,
    this.spinnerColor,
  });

  final String label;
  final Color color;
  final bool loading;
  final IconData? icon;
  final Color? spinnerColor;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: spinnerColor ?? color,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.button.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
