import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;

import '../../components/components.dart';
import '../../core/hr1_api_manual.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_typography.dart';
import '../../utils/display_format.dart';
import '../hr/employee_details.dart';
import 'photo_capture_page_manual.dart';
import 'photo_registration_screen_manual.dart';

class GpsAttendanceScreenManual extends StatefulWidget {
  const GpsAttendanceScreenManual({super.key});

  @override
  State<GpsAttendanceScreenManual> createState() => _GpsAttendanceScreenManualState();
}

class _GpsAttendanceScreenManualState extends State<GpsAttendanceScreenManual> {
  final _people = SupervisorApi();
  final _api = Hr1ApiManual();
  List<Map<String, dynamic>> _employees = [];
  Map<String, dynamic>? _selected;
  bool _registered = false;
  List<Map<String, dynamic>> _today = [];
  String _camera = 'front';
  String? _error;
  String? _message;
  InlineTone _tone = InlineTone.info;
  bool _loading = true;
  bool _saving = false;

  int _id(Map<String, dynamic> row) {
    final value = row['employeeId'] ?? row['employee_id'];
    if (value is int) return value;
    return int.parse('$value');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = AppStateScope.read(context).session;
      if (session == null) throw SupervisorException('Sign in again.');
      final rows = await _people.faceEmployees(session.cnic);
      if (!mounted) return;
      setState(() {
        _employees = rows;
        _loading = false;
      });
      if (_selected != null) await _loadToday();
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _pick() async {
    final selected = await showAppSheet<Map<String, dynamic>>(
      context,
      builder: (context) => Hr1EmployeePickerManual(employees: _employees),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selected = selected;
      _registered = false;
      _message = null;
      _error = null;
      _today = [];
    });
    final session = AppStateScope.read(context).session;
    if (session == null) return;
    try {
      final detail = await _people.employee(session.cnic, _id(selected));
      if (!mounted) return;
      setState(() => _selected = {...selected, ...detail});
    } on SupervisorException {
      // The list row is enough when the detail card is unavailable.
    }
    try {
      final registration = await _api.registration(session.cnic, _id(selected));
      if (!mounted) return;
      final registered = registration['registered'] == true;
      setState(() {
        _registered = registered;
        if (!registered) {
          _message = 'Register this worker before marking attendance.';
          _tone = InlineTone.warning;
        }
      });
      if (registered) await _loadToday();
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _registered = false;
        _message = error.message;
        _tone = InlineTone.warning;
      });
    }
  }

  Future<void> _loadToday() async {
    final selected = _selected;
    final session = AppStateScope.read(context).session;
    if (selected == null || session == null) return;
    try {
      final rows = await _api.attendanceLog(
        session.cnic,
        date: supervisorToday(),
        employeeId: _id(selected),
      );
      if (!mounted) return;
      setState(() => _today = rows);
    } on SupervisorException {
      // The detail card still works when today's log cannot be loaded.
    }
  }

  String get _nextType {
    final latest = _today.isEmpty ? null : _today.first['type']?.toString();
    return latest == 'check_in' ? 'check_out' : 'check_in';
  }

  Future<void> _attend() async {
    final selected = _selected;
    if (selected == null || _saving || !_registered) return;
    final type = _nextType;
    setState(() {
      _saving = true;
      _message = 'Turn on location for this photo.';
      _tone = InlineTone.info;
    });
    try {
      final session = AppStateScope.read(context).session;
      if (session == null) throw SupervisorException('Sign in again.');
      await _ensureLocationOn();
      if (!mounted) return;
      final positionFuture = _position();
      setState(() => _message = 'Take the attendance photo.');
      final shot = await PhotoCapturePageManual.open(
        context,
        title: 'Attendance',
        lens: _camera == 'back' ? CameraLensDirection.back : CameraLensDirection.front,
        requireClearFace: false,
        allowSwitch: true,
      );
      if (!mounted) return;
      if (shot.error != null || shot.bytes == null) {
        positionFuture.ignore();
        setState(() {
          _saving = false;
          _message = shot.error;
          _tone = shot.error == null ? InlineTone.info : InlineTone.error;
        });
        return;
      }
      setState(() => _message = 'Reading location...');
      final position = await positionFuture;
      if (!mounted) return;
      setState(() => _message = 'Saving attendance...');
      final result = await _api.markAttendance(
        cnic: session.cnic,
        employeeId: _id(selected),
        type: type,
        photo: shot.bytes!,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        mock: position.isMocked,
      );
      if (!mounted) return;
      final attendance = result['attendance'] as Map<String, dynamic>? ?? {};
      setState(() {
        _saving = false;
        _message = result['message'] as String? ?? 'Attendance saved.';
        _tone = InlineTone.success;
      });
      await _showSaved(attendance, result['message'] as String? ?? 'Attendance saved.');
      if (!mounted) return;
      await _loadToday();
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = error.message;
        _tone = error.retry ? InlineTone.warning : InlineTone.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = 'Turn on location, then take the attendance photo again.';
        _tone = InlineTone.error;
      });
    }
  }

  Future<void> _ensureLocationOn() async {
    try {
      await ensureLiveLocationEnabled();
    } on SupervisorException catch (error) {
      final lower = error.message.toLowerCase();
      if (lower.contains('live location') || lower.contains('allow location')) {
        throw SupervisorException('${error.message} Then take the attendance photo again.');
      }
      rethrow;
    }
  }

  Future<Position> _position() async {
    try {
      return await supervisorFacePosition();
    } on SupervisorException catch (error) {
      final lower = error.message.toLowerCase();
      if (lower.contains('permission')) {
        throw SupervisorException('Location permission is required to mark attendance.');
      }
      if (lower.contains('fake') || lower.contains('mock')) {
        throw SupervisorException('Fake GPS detected. Turn off any fake-location app and try again.');
      }
      if (lower.contains('signal') || lower.contains('gps')) rethrow;
      throw SupervisorException('No GPS signal. Turn on location and try again.');
    }
  }

  Future<void> _showSaved(Map<String, dynamic> attendance, String message) async {
    final session = AppStateScope.read(context).session;
    final cnic = session?.cnic ?? '';
    final url = _api.absolute(attendance['photo_url']?.toString(), cnic);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(message),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (url.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    url,
                    headers: _api.photoHeaders,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Text('The stamped photo could not be loaded.'),
                  ),
                ),
              const SizedBox(height: 12),
              Text(attendance['address']?.toString() ?? '', style: AppType.body),
              const SizedBox(height: 4),
              Text(attendance['timestamp']?.toString() ?? '', style: AppType.caption),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return AppPage(
      title: 'Attendance',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (_error != null) InlineMessage(message: _error!, tone: InlineTone.error),
                OutlinedButton.icon(
                  onPressed: _saving || _employees.isEmpty ? null : _pick,
                  icon: const Icon(Icons.person_search_outlined),
                  label: Text(selected == null ? 'Select name or CNIC' : '${selected['name']}'),
                ),
                if (selected != null) ...[
                  const SizedBox(height: 16),
                  EmployeeDetails(employee: selected),
                  const SizedBox(height: 12),
                  Hr1RegistrationBadge(registered: _registered),
                  if (_registered) ...[
                  const SizedBox(height: 16),
                  Text('Camera', style: AppType.section.copyWith(fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _CameraChoice(
                          label: 'Front',
                          icon: Icons.photo_camera_front_outlined,
                          selected: _camera == 'front',
                          onTap: _saving ? null : () => setState(() => _camera = 'front'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CameraChoice(
                          label: 'Back',
                          icon: Icons.photo_camera_back_outlined,
                          selected: _camera == 'back',
                          onTap: _saving ? null : () => setState(() => _camera = 'back'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _nextType == 'check_out'
                        ? 'This photo will check out.'
                        : 'This photo will check in.',
                    style: AppType.caption,
                  ),
                  if (_today.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Today', style: AppType.section.copyWith(fontSize: 16)),
                    const SizedBox(height: 8),
                    for (final row in _today) ...[
                      InfoCard(
                        label: row['type'] == 'check_out' ? 'Check out' : 'Check in',
                        value: _when(row['timestamp']),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                  ],
                ],
                if (_message != null) ...[
                  const SizedBox(height: 8),
                  InlineMessage(message: _message!, tone: _tone),
                ],
              ],
            ),
      bottom: selected == null || !_registered
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: PrimaryButton(
                label: 'Attendance',
                icon: Icons.photo_camera_outlined,
                loading: _saving,
                onPressed: _saving ? null : _attend,
              ),
            ),
    );
  }

  String _when(Object? value) {
    final date = DateTime.tryParse('${value ?? ''}');
    if (date == null) return '${value ?? ''}';
    return formatDateTime(date.toLocal());
  }
}

class _CameraChoice extends StatelessWidget {
  const _CameraChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF0F766E) : const Color(0xFF8AA0B5);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? const Color(0xFF0F766E) : const Color(0xFFE3EDF3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(label, style: AppType.body.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
