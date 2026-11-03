import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'buttons.dart';

Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: builder,
  );
}

class SheetScaffold extends StatelessWidget {
  const SheetScaffold({super.key, this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    // Keep actions above system nav / gesture bar on all phones.
    final safeBottom = media.padding.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: media.size.height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title!,
                        style: AppType.section.copyWith(fontSize: 16),
                      ),
                    ),
                  ),
                child,
                SizedBox(height: safeBottom > 0 ? 4 : 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ConfirmationSheet {
  const ConfirmationSheet._();

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
  }) async {
    final result = await showAppSheet<bool>(
      context,
      builder: (context) {
        return SheetScaffold(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.emerald,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppType.section.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                const SizedBox(height: 10),
                OutlineButton(
                  label: cancelLabel,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }
}

class ConfirmationDialog {
  const ConfirmationDialog._();

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title, style: AppType.section),
          content: Text(
            message,
            style: AppType.body.copyWith(color: AppColors.textSecondary),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                const SizedBox(height: 8),
                OutlineButton(
                  label: cancelLabel,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
