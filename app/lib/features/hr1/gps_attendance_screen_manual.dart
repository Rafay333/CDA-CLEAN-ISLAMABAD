import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;

import '../../components/components.dart';
import '../../core/attendance_duty.dart';
import '../../core/hr1_api_manual.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../utils/display_format.dart';
import '../hr/duty_point_section.dart';
import '../hr_face/face_hr_ui.dart';
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
  List<SupervisorUc> _ucs = [];
  List<AttendancePoint> _points = [];
  bool _pointsLoading = false;
  Map<String, dynamic>? _selected;
  Map<String, dynamic>? _registration;
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
      final ucs = await _people.supervisorUcs(session.cnic);
      if (!mounted) return;
      setState(() {
        _employees = rows;
        _ucs = ucs;
        _loading = false;
      });
      await _loadPoints();
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
      _registration = null;
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
        _registration = registration;
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
        _registration = null;
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

  bool get _checkOut => attendanceHasCheckIn(_today);

  String? _ucLabelFor(AttendancePoint point) {
    for (final uc in _ucs) {
      if (uc.id == point.ucZoneId) return uc.label;
    }
    return null;
  }

  Future<void> _loadPoints() async {
    final session = AppStateScope.read(context).session;
    if (session == null) return;
    setState(() => _pointsLoading = true);
    try {
      final points = await _people.attendancePointsAcross(session.cnic, _ucs);
      if (!mounted) return;
      setState(() {
        _points = points;
        _pointsLoading = false;
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _pointsLoading = false;
        _message = error.message;
        _tone = InlineTone.error;
      });
    }
  }

  Future<void> _attend() async {
    final selected = _selected;
    if (selected == null || _saving || !_registered) return;
    final checkOut = _checkOut;
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
        type: checkOut ? 'check_out' : 'check_in',
        photo: shot.bytes!,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        mock: position.isMocked,
      );
      if (!mounted) return;
      final attendance = result['attendance'] as Map<String, dynamic>? ?? {};
      final msg = result['message'] as String? ?? 'Attendance saved.';
      setState(() {
        _saving = false;
        _message = msg;
        _tone = InlineTone.success;
      });
      await _showSaved(attendance, msg);
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
      builder: (context) => FaceHrResultSheet(
        message: message,
        photoUrl: url,
        photoHeaders: _api.photoHeaders,
        latitude: attendance['latitude'],
        longitude: attendance['longitude'],
        address: '${attendance['address'] ?? ''}',
        timestamp: '${attendance['timestamp'] ?? ''}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final sessionCnic = AppStateScope.of(context).session?.cnic ?? '';
    final name = '${selected?['name'] ?? ''}'.trim();
    final role = '${selected?['role'] ?? ''}'.trim();
    final cnicNo = '${selected?['cnic'] ?? ''}'.trim();
    final shift = '${_registration?['shift'] ?? selected?['shift'] ?? ''}'.trim();
    final contact = '${selected?['contact'] ?? ''}'.trim();
    final checkOut = _checkOut;
    final photoUrl = _registered
        ? _api.absolute(
            _registration?['photo_url']?.toString() ??
                (selected == null
                    ? null
                    : '/api/supervisor/hr-photo-manual/register/${_id(selected)}/photo'),
            sessionCnic,
          )
        : '';

    return AppPage(
      title: 'Attendance',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                FaceHrHero(
                  icon: Icons.location_on_rounded,
                  title: 'GPS photo attendance',
                  subtitle: 'One clear photo with live location. Check in and check out for the day.',
                  colors: checkOut && selected != null && _registered
                      ? const [Color(0xFF1D4ED8), Color(0xFF1E3A8A), Color(0xFF123B5D)]
                      : const [Color(0xFF0F766E), Color(0xFF0E7490), Color(0xFF123B5D)],
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  InlineMessage(message: _error!, tone: InlineTone.error),
                  const SizedBox(height: 12),
                ],
                DutyPointNotice(
                  points: _points,
                  ucLabel: _ucLabelFor,
                  loading: _pointsLoading,
                ),
                const SizedBox(height: 10),
                FaceHrWorkerPicker(
                  name: selected == null ? null : (name.isEmpty ? 'Worker' : name),
                  hint: 'Select worker',
                  subtitle: cnicNo.isEmpty ? role : cnicNo,
                  enabled: !_saving && _employees.isNotEmpty,
                  onTap: _pick,
                ),
                if (selected != null) ...[
                  const SizedBox(height: 16),
                  FaceHrWorkerCard(
                    name: name,
                    role: role,
                    cnic: cnicNo,
                    shift: shift,
                    contact: contact,
                    photo: photoUrl.isEmpty
                        ? null
                        : _RegisteredPhoto(url: photoUrl, headers: _api.photoHeaders),
                    badge: FaceHrStatusChip(
                      label: _registered ? 'Photo registered' : 'Photo not registered',
                      ok: _registered,
                    ),
                  ),
                  if (_registered) ...[
                    const SizedBox(height: 16),
                    FaceHrActionBanner(
                      tone: checkOut ? FaceHrActionTone.checkOut : FaceHrActionTone.checkIn,
                      icon: checkOut ? Icons.logout_rounded : Icons.login_rounded,
                      title: checkOut ? 'Next: Check out' : 'Next: Check in',
                      subtitle: 'Take one clear photo. GPS is stamped on the server.',
                    ),
                    const SizedBox(height: 18),
                    const FaceHrSectionLabel('Camera'),
                    const SizedBox(height: 10),
                    FaceHrShiftPicker(
                      shifts: const [
                        ('Front', Icons.photo_camera_front_outlined),
                        ('Back', Icons.photo_camera_back_outlined),
                      ],
                      value: _camera == 'back' ? 'Back' : 'Front',
                      enabled: !_saving,
                      onChanged: (value) => setState(() => _camera = value == 'Back' ? 'back' : 'front'),
                    ),
                    const SizedBox(height: 18),
                    const FaceHrSectionLabel("Today's marks"),
                    const SizedBox(height: 10),
                    FaceHrTodayTimeline(
                      rows: _today,
                      formatWhen: _when,
                      isSuspicious: (_) => false,
                      flagNote: (_) => '',
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: 18),
                  const FaceHrStepGuide(
                    steps: [
                      (Icons.person_search_rounded, 'Pick the worker', 'Must already have a registration photo.'),
                      (Icons.photo_camera_outlined, 'Take one photo', 'Front or back camera, good light.'),
                      (Icons.my_location_outlined, 'GPS stamp', 'Live location is saved with the mark.'),
                    ],
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 14),
                  InlineMessage(message: _message!, tone: _tone),
                ],
              ],
            ),
      bottom: selected == null || !_registered
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: PrimaryButton(
                  label: checkOut ? 'Mark check out' : 'Mark check in',
                  icon: checkOut ? Icons.logout_rounded : Icons.photo_camera_outlined,
                  loading: _saving,
                  onPressed: _saving ? null : _attend,
                ),
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

class _RegisteredPhoto extends StatelessWidget {
  const _RegisteredPhoto({required this.url, required this.headers});

  final String url;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: FaceHrPalette.accentLine, width: 2.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        headers: headers,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: FaceHrPalette.accentSoft,
          child: Icon(Icons.person_rounded, color: FaceHrPalette.accent, size: 34),
        ),
      ),
    );
  }
}
