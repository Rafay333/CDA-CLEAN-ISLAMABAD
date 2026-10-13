import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../components/components.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'employee_details.dart';
import 'face_capture.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _api = SupervisorApi();
  Map<String, dynamic>? _employee;
  Map<String, dynamic>? _attendance;
  int? _match;
  String? _message;
  InlineTone _tone = InlineTone.info;
  bool _saving = false;
  Map<String, dynamic>? _lastEmployee;
  String? _lastDetail;

  Future<void> _scan() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final session = AppStateScope.read(context).session;
      if (session == null) throw SupervisorException('Sign in again.');
      final position = await supervisorFacePosition();
      if (!mounted) return;
      final photos = await FaceCapturePage.open(context, title: 'Attendance', burst: true);
      if (photos == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      if (photos.length < 3) {
        throw SupervisorException('The camera could not take all the pictures. Please try again.');
      }
      final deviceId = await supervisorDeviceId();
      final preview = await _mark(
        cnic: session.cnic,
        photos: photos,
        position: position,
        deviceId: deviceId,
        confirm: false,
      );
      if (!mounted) return;

      var result = preview;
      final needsConfirm = preview['requiresConfirm'] == true;
      final action = preview['action'] as String?;
      final employee = Map<String, dynamic>.from(preview['employee'] as Map);
      final match = preview['matchPercent'] as int?;

      if (needsConfirm && (action == 'checkin' || action == 'checkout')) {
        setState(() {
          _employee = employee;
          _match = match;
          _attendance = preview['attendance'] == null
              ? null
              : Map<String, dynamic>.from(preview['attendance'] as Map);
          _message = action == 'checkin'
              ? 'Confirm check-in for ${employee['name']}?'
              : 'Confirm check-out for ${employee['name']}?';
          _tone = InlineTone.info;
          _saving = false;
        });
        final accepted = await _AttendanceConfirmDialog.show(
          context,
          employee: employee,
          action: action!,
          matchPercent: match,
          shift: preview['shift'] as String?,
        );
        if (!mounted) return;
        if (accepted != true) {
          setState(() {
            _employee = null;
            _attendance = null;
            _match = null;
            _message = 'Attendance was not marked.';
            _tone = InlineTone.warning;
            _saving = false;
          });
          return;
        }
        setState(() {
          _saving = true;
          _message = action == 'checkin' ? 'Marking check-in…' : 'Marking check-out…';
          _tone = InlineTone.info;
        });
        result = await _mark(
          cnic: session.cnic,
          photos: photos,
          position: position,
          deviceId: deviceId,
          confirm: true,
        );
        if (!mounted) return;
      }

      final finalAction = result['action'] as String?;
      final finalEmployee = Map<String, dynamic>.from(result['employee'] as Map);
      final attendance = result['attendance'] == null
          ? null
          : Map<String, dynamic>.from(result['attendance'] as Map);
      final finalMatch = result['matchPercent'] as int?;
      final marked = finalAction == 'checkin' || finalAction == 'checkout';
      setState(() {
        _employee = finalEmployee;
        _attendance = attendance;
        _match = finalMatch;
        _message = result['message'] as String? ?? 'Attendance recorded.';
        _tone = marked ? InlineTone.success : InlineTone.warning;
        _saving = false;
        _lastEmployee = finalEmployee;
        _lastDetail = finalAction == 'checkin'
            ? 'Checked in ${_clock(attendance?['checkIn'])} · ${result['shift']} shift'
            : finalAction == 'checkout'
                ? 'Checked out ${_clock(attendance?['checkOut'])} · ${result['shift']} shift'
                : 'Already in and out · ${result['shift']} shift';
      });
      if (marked) {
        AppStateScope.read(context).updateAttendance((ui) {
          ui.mark = finalAction == 'checkin' ? AttendanceMark.checkedIn : AttendanceMark.checkedOut;
          ui.markedAt = DateTime.now();
          ui.phase = ScanPhase.complete;
        });
      }
      await _AttendanceResultDialog.show(
        context,
        employee: finalEmployee,
        attendance: attendance,
        action: finalAction,
        matchPercent: finalMatch,
      );
      if (!mounted) return;
      setState(() {
        _employee = null;
        _attendance = null;
        _match = null;
        _message = null;
        _tone = InlineTone.info;
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = error.message;
        _tone = error.retry ? InlineTone.warning : InlineTone.error;
        if (!error.retry) {
          _employee = null;
          _attendance = null;
        }
      });
    }
  }

  Future<Map<String, dynamic>> _mark({
    required String cnic,
    required List<Uint8List> photos,
    required Position position,
    required String deviceId,
    required bool confirm,
  }) {
    return _api.markFace(
      cnic: cnic,
      photos: photos,
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
      mock: position.isMocked,
      deviceId: deviceId,
      confirm: confirm,
    );
  }

  @override
  Widget build(BuildContext context) {
    final employee = _employee;
    final checkedOut = _attendance?['checkOut'] != null;
    return AppPage(
      title: 'Attendance',
      bottom: PrimaryButton(
        label: _saving ? 'Checking face' : 'Mark attendance',
        loading: _saving,
        onPressed: _saving ? null : _scan,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (_lastEmployee != null) ...[
            _MatchedBanner(employee: _lastEmployee!, detail: _lastDetail, live: employee != null),
            const SizedBox(height: 12),
          ],
          const ScanFrame(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_camera_outlined, color: AppColors.lime, size: 42),
                SizedBox(height: 12),
                Text(
                  'Look at the camera for 5 seconds',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 16),
                ),
                SizedBox(height: 6),
                Text(
                  'The first scan today is check-in',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InlineMessage(
            tone: _message == null ? InlineTone.info : _tone,
            message: _message ?? 'The face is shown for 5 seconds, then matched to a registered employee.',
          ),
          if (_saving) ...[
            const SizedBox(height: 16),
            const LoadingSkeleton(height: 18, width: 160),
            const SizedBox(height: 10),
            const LoadingSkeleton(height: 64, radius: 14),
          ],
          if (employee != null) ...[
            const SizedBox(height: 16),
            if (_attendance?['checkIn'] != null)
              StatusBadge(
                label: checkedOut ? 'Checked out' : 'Checked in',
                color: checkedOut ? AppColors.warning : AppColors.success,
              ),
            if (_attendance?['checkIn'] != null) ...[
              const SizedBox(height: 6),
              Text(
                checkedOut
                    ? 'Out ${_clock(_attendance!['checkOut'])}'
                    : 'In ${_clock(_attendance!['checkIn'])}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
            EmployeeDetails(
              employee: employee,
              attendance: _attendance,
              matchPercent: _match,
            ),
          ],
        ],
      ),
    );
  }

  String _clock(Object? value) {
    final text = value?.toString() ?? '';
    if (text.length >= 5) return text.substring(0, 5);
    return text.isEmpty ? '' : text;
  }
}

class _MatchedBanner extends StatelessWidget {
  const _MatchedBanner({required this.employee, required this.detail, required this.live});

  final Map<String, dynamic> employee;
  final String? detail;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          EmployeePhoto(
            employeeId: employee['employeeId'] as int,
            registeredAt: employee['faceRegisteredAt'] as String?,
            enrolled: employee['enrolled'] == true,
            size: 52,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  live ? 'Face matched' : 'Last matched',
                  style: AppType.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${employee['name']} (${employee['employeeId']})',
                  style: AppType.section.copyWith(fontSize: 18),
                ),
                if (detail != null) Text(detail!, style: AppType.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceConfirmDialog extends StatelessWidget {
  const _AttendanceConfirmDialog({
    required this.employee,
    required this.action,
    required this.matchPercent,
    required this.shift,
  });

  final Map<String, dynamic> employee;
  final String action;
  final int? matchPercent;
  final String? shift;

  static Future<bool?> show(
    BuildContext context, {
    required Map<String, dynamic> employee,
    required String action,
    required int? matchPercent,
    required String? shift,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AttendanceConfirmDialog(
        employee: employee,
        action: action,
        matchPercent: matchPercent,
        shift: shift,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCheckIn = action == 'checkin';
    final title = isCheckIn ? 'Confirm check-in' : 'Confirm check-out';
    final color = isCheckIn ? AppColors.success : AppColors.warning;
    final shiftLabel = (shift == null || shift!.isEmpty) ? '' : ' · $shift shift';
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppType.title.copyWith(fontSize: 20, color: color),
          ),
          const SizedBox(height: 16),
          EmployeePhoto(
            employeeId: employee['employeeId'] as int,
            registeredAt: employee['faceRegisteredAt'] as String?,
            enrolled: employee['enrolled'] == true,
            size: 96,
          ),
          const SizedBox(height: 14),
          Text(
            '${employee['name']}',
            textAlign: TextAlign.center,
            style: AppType.section.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            'ID ${employee['employeeId']} · ${employee['role']}$shiftLabel',
            textAlign: TextAlign.center,
            style: AppType.caption,
          ),
          if (matchPercent != null) ...[
            const SizedBox(height: 4),
            Text('Face match: $matchPercent%', style: AppType.caption),
          ],
          const SizedBox(height: 12),
          Text(
            isCheckIn
                ? 'Mark check-in for this worker?'
                : 'Mark check-out for this worker?',
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrimaryButton(
              label: 'Yes, mark attendance',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 8),
            OutlineButton(
              label: 'No',
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ],
    );
  }
}

class _AttendanceResultDialog extends StatelessWidget {
  const _AttendanceResultDialog({
    required this.employee,
    required this.attendance,
    required this.action,
    required this.matchPercent,
  });

  final Map<String, dynamic> employee;
  final Map<String, dynamic>? attendance;
  final String? action;
  final int? matchPercent;

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> employee,
    required Map<String, dynamic>? attendance,
    required String? action,
    required int? matchPercent,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AttendanceResultDialog(
        employee: employee,
        attendance: attendance,
        action: action,
        matchPercent: matchPercent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final marked = action == 'checkin' || action == 'checkout';
    final title = marked ? 'Attendance marked successfully' : 'Already marked today';
    final detail = action == 'checkin'
        ? 'Checked in at ${_clock(attendance?['checkIn'])}'
        : action == 'checkout'
            ? 'Checked out at ${_clock(attendance?['checkOut'])}'
            : 'In ${_clock(attendance?['checkIn'])} · Out ${_clock(attendance?['checkOut'])}';
    final color = marked ? AppColors.success : AppColors.warning;
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${employee['name']}',
            textAlign: TextAlign.center,
            style: AppType.title.copyWith(fontSize: 22, color: color),
          ),
          const SizedBox(height: 8),
          Icon(
            marked ? Icons.check_circle_rounded : Icons.info_rounded,
            color: color,
            size: 56,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppType.section.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              EmployeePhoto(
                employeeId: employee['employeeId'] as int,
                registeredAt: employee['faceRegisteredAt'] as String?,
                enrolled: employee['enrolled'] == true,
                size: 72,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${employee['name']} (${employee['employeeId']})',
                      style: AppType.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text('Employee ID: ${employee['employeeId']}', style: AppType.caption),
                    Text('CNIC: ${employee['cnic']}', style: AppType.caption),
                    Text('${employee['role']}', style: AppType.caption),
                    if (matchPercent != null) Text('Face match: $matchPercent%', style: AppType.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        PrimaryButton(
          label: 'OK, next worker',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  static String _clock(Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty || text == 'null') return '—';
    return text.length >= 5 ? text.substring(0, 5) : text;
  }
}
