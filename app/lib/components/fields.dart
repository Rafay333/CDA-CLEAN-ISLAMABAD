import 'package:flutter/material.dart';

import '../constants/app_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/display_format.dart';
import 'bottom_sheet.dart';
import 'feedback.dart';

class DropdownField extends StatelessWidget {
  const DropdownField({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    this.values,
    this.value,
    this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  final String label;
  final String hint;
  final List<String> items;

  /// Stable ids, one per [items] entry. The sheet still shows [items].
  /// [value] and [onChanged] use these ids so two rows with the same label
  /// cannot collapse into one record.
  final List<String>? values;
  final String? value;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool enabled;

  List<String>? get _ids {
    final ids = values;
    if (ids == null || ids.length != items.length) return null;
    return ids;
  }

  String? get _closedLabel {
    final current = value;
    if (current == null || current.isEmpty) return null;
    final ids = _ids;
    if (ids == null) return current;
    final index = ids.indexOf(current);
    if (index < 0) return null;
    return items[index];
  }

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.label),
        const SizedBox(height: 8),
        Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: enabled ? () => _open(context) : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: hasError ? AppColors.error : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayOr(_closedLabel, hint),
                      style: AppType.body.copyWith(
                        color: _closedLabel == null
                            ? AppColors.disabledText
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: AppType.caption.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }

  Future<void> _open(BuildContext context) async {
    if (!enabled) return;
    final selected = await showAppSheet<String>(
      context,
      builder: (context) {
        return _OptionSheet(
          title: label,
          items: items,
          values: _ids,
          selected: value,
        );
      },
    );
    if (selected != null) onChanged?.call(selected);
  }
}

class _OptionSheet extends StatefulWidget {
  const _OptionSheet({
    required this.title,
    required this.items,
    required this.selected,
    this.values,
  });

  final String title;
  final List<String> items;
  final List<String>? values;
  final String? selected;

  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return SheetScaffold(
        title: widget.title,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 12),
          child: EmptyState(
            icon: Icons.inbox_outlined,
            title: AppCopy.noOptions,
            message: AppCopy.noOptionsHint,
          ),
        ),
      );
    }

    final query = _query.text.trim().toLowerCase();
    final visible = <int>[
      for (var i = 0; i < widget.items.length; i++)
        if (query.isEmpty || widget.items[i].toLowerCase().contains(query)) i,
    ];
    final media = MediaQuery.of(context);
    final maxHeight = (media.size.height - media.viewInsets.bottom) * 0.42;
    final height = visible.isEmpty
        ? 120.0
        : (visible.length * 56.0).clamp(56.0, maxHeight);

    return SheetScaffold(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.items.length > 12)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                style: AppType.body,
                cursorColor: AppColors.emerald,
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: AppType.body.copyWith(
                    color: AppColors.disabledText,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: _searchBorder(AppColors.border),
                  enabledBorder: _searchBorder(AppColors.border),
                  focusedBorder: _searchBorder(AppColors.emerald),
                ),
              ),
            ),
          SizedBox(
            height: height,
            child: visible.isEmpty
                ? Center(child: Text('No matches', style: AppType.caption))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final itemIndex = visible[index];
                      final item = widget.items[itemIndex];
                      final ids = widget.values;
                      final id = ids != null && itemIndex < ids.length
                          ? ids[itemIndex]
                          : item;
                      final chosen = id == widget.selected;
                      return ListTile(
                        title: Text(item, style: AppType.body),
                        trailing: chosen
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.emerald,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _searchBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: BorderSide(color: color),
    );
  }
}

class DatePickerField extends StatelessWidget {
  const DatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint = 'Select date',
    this.firstDate,
    this.lastDate,
    this.errorText,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String hint;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.label),
        const SizedBox(height: 8),
        Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: () => _pick(context),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: hasError ? AppColors.error : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: AppColors.teal,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      value == null ? hint : formatDate(value!),
                      style: AppType.body.copyWith(
                        color: value == null
                            ? AppColors.disabledText
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: AppType.caption.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: firstDate ?? DateTime(1950),
      lastDate: lastDate ?? DateTime(now.year + 1),
    );
    if (picked != null) onChanged(picked);
  }
}

class RadioGroup extends StatelessWidget {
  const RadioGroup({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final option in options)
              _Choice(
                label: option,
                selected: value == option,
                onTap: () => onChanged(option),
              ),
          ],
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.emerald.withValues(alpha: 0.08)
          : AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected ? AppColors.emerald : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.emerald : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppType.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (next) => onChanged(next ?? false),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppType.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Material(
                color: value == option ? AppColors.navy : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onChanged(option),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      option,
                      textAlign: TextAlign.center,
                      style: AppType.button.copyWith(
                        color: value == option
                            ? AppColors.white
                            : AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FilterChips extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          FilterChip(
            label: Text(option),
            selected: selected == option,
            showCheckmark: false,
            onSelected: (_) => onSelected(option),
            labelStyle: AppType.caption.copyWith(
              color: selected == option ? AppColors.white : AppColors.navy,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: AppColors.teal,
            backgroundColor: AppColors.white,
            side: BorderSide(
              color: selected == option ? AppColors.teal : AppColors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
      ],
    );
  }
}
