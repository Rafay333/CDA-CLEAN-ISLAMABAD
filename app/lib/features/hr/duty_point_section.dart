import 'dart:async';

import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/attendance_duty.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/pakistan_time.dart';
import '../hr_face/face_hr_ui.dart';

mixin AttendanceDutyTick<T extends StatefulWidget> on State<T> {
  Timer? _attendanceDutyTick;

  /// Rebuild when the Pakistan minute changes, so the button follows the window.
  void startAttendanceDutyTick() {
    _scheduleAttendanceDutyTick();
  }

  void _scheduleAttendanceDutyTick() {
    _attendanceDutyTick?.cancel();
    final secondsLeft = 60 - pakistanNow().second;
    _attendanceDutyTick = Timer(Duration(seconds: secondsLeft == 0 ? 60 : secondsLeft), () {
      if (!mounted) return;
      setState(() {});
      _scheduleAttendanceDutyTick();
    });
  }

  @override
  void dispose() {
    _attendanceDutyTick?.cancel();
    super.dispose();
  }
}

/// Union council and attendance point, shown only. Marking does not use them yet.
class DutyPointNotice extends StatelessWidget {
  const DutyPointNotice({
    super.key,
    required this.points,
    required this.ucLabel,
    required this.loading,
  });

  final List<AttendancePoint> points;
  final String? Function(AttendancePoint point) ucLabel;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (points.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final point in points) ...[
          _DutyPointNote(point: point, uc: ucLabel(point)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DutyPointNote extends StatelessWidget {
  const _DutyPointNote({required this.point, required this.uc});

  final AttendancePoint point;
  final String? uc;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Union council', style: AppType.caption.copyWith(color: FaceHrPalette.muted)),
          const SizedBox(height: 2),
          Text(uc ?? '—', style: AppType.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Attendance point', style: AppType.caption.copyWith(color: FaceHrPalette.muted)),
          const SizedBox(height: 2),
          Text(point.name, style: AppType.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(point.windowSummary, style: AppType.caption.copyWith(color: FaceHrPalette.muted)),
          const SizedBox(height: 6),
          Text('Not required to mark', style: AppType.caption.copyWith(color: FaceHrPalette.muted)),
        ],
      ),
    );
  }
}

Future<T?> showDutyChoices<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T item) label,
  String Function(T item)? detail,
}) {
  return showAppSheet<T>(
    context,
    builder: (context) => _DutyChoiceSheet<T>(
      title: title,
      options: options,
      label: label,
      detail: detail,
    ),
  );
}

class _DutyChoiceSheet<T> extends StatefulWidget {
  const _DutyChoiceSheet({
    required this.title,
    required this.options,
    required this.label,
    required this.detail,
  });

  final String title;
  final List<T> options;
  final String Function(T item) label;
  final String Function(T item)? detail;

  @override
  State<_DutyChoiceSheet<T>> createState() => _DutyChoiceSheetState<T>();
}

class _DutyChoiceSheetState<T> extends State<_DutyChoiceSheet<T>> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final rows = widget.options.where((item) {
      if (query.isEmpty) return true;
      final note = widget.detail?.call(item) ?? '';
      return '${widget.label(item)} $note'.toLowerCase().contains(query);
    }).toList();
    final media = MediaQuery.of(context);
    final sheetHeight =
        (media.size.height * 0.72 - media.viewInsets.bottom).clamp(240.0, media.size.height * 0.72);
    return SheetScaffold(
      title: widget.title,
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matches',
                      message: 'Try another name.',
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final item = rows[index];
                        final note = widget.detail?.call(item);
                        return ListTile(
                          title: Text(
                            widget.label(item),
                            style: AppType.body.copyWith(fontWeight: FontWeight.w700),
                          ),
                          subtitle: note == null || note.isEmpty ? null : Text(note, style: AppType.caption),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
