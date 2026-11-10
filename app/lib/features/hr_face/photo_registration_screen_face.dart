import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/hr1_api_face.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../hr/face_capture.dart';
import '../hr/registered_enrollment_card.dart';
import '../hr1/photo_registration_screen_manual.dart';
import 'face_hr_ui.dart';

class PhotoRegistrationScreenFace extends StatefulWidget {
  const PhotoRegistrationScreenFace({super.key});

  @override
  State<PhotoRegistrationScreenFace> createState() => _PhotoRegistrationScreenFaceState();
}

class _PhotoRegistrationScreenFaceState extends State<PhotoRegistrationScreenFace> {
  static const _shifts = [
    ('Day', Icons.wb_sunny_outlined),
    ('Evening', Icons.wb_twilight_outlined),
    ('Night', Icons.nightlight_outlined),
  ];

  final _people = SupervisorApi();
  final _api = Hr1ApiFace();
  List<Map<String, dynamic>> _employees = [];
  Map<String, dynamic>? _selected;
  Map<String, dynamic>? _face;
  String? _shift;
  String _camera = 'front';
  String? _error;
  String? _message;
  InlineTone _tone = InlineTone.info;
  bool _loading = true;
  bool _saving = false;
  bool _justRegistered = false;

  int _id(Map<String, dynamic> row) {
    final value = row['employeeId'];
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
      _shift = _shifts.map((item) => item.$1).contains(selected['shift']) ? '${selected['shift']}' : null;
      _face = null;
      _message = null;
      _error = null;
      _justRegistered = false;
    });
    final session = AppStateScope.read(context).session;
    if (session == null) return;
    try {
      final detail = await _people.employee(session.cnic, _id(selected));
      if (!mounted) return;
      setState(() => _selected = {...selected, ...detail});
    } on SupervisorException {
      // List row is enough when detail is unavailable.
    }
    try {
      final face = await _api.registration(session.cnic, _id(selected));
      if (!mounted) return;
      setState(() {
        _face = face;
        final saved = face['shift']?.toString();
        if (_shifts.map((item) => item.$1).contains(saved)) _shift = saved;
        final camera = face['camera']?.toString();
        if (camera == 'front' || camera == 'back') _camera = camera!;
        if (face['registered'] == true) {
          _selected = {
            ...?_selected,
            'enrolled': true,
            if (face['created_at'] != null) 'faceRegisteredAt': face['created_at'],
            if (saved != null) 'shift': saved,
          };
          _message = null;
        }
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
        _tone = InlineTone.warning;
      });
    }
  }

  Future<void> _register() async {
    final selected = _selected;
    final shift = _shift;
    if (selected == null || shift == null || _saving) return;
    final photos = await FaceCapturePage.open(
      context,
      title: 'Face registration',
      burst: false,
    );
    if (!mounted) return;
    if (photos == null) return;
    if (photos.length != 3) {
      setState(() {
        _message = 'Exactly 3 photos required (image0, image1, image2).';
        _tone = InlineTone.error;
      });
      return;
    }
    await _save(selected, shift, photos);
  }

  Future<void> _save(Map<String, dynamic> selected, String shift, List<Uint8List> photos) async {
    setState(() {
      _saving = true;
      _message = 'Registering face (3 photos)...';
      _tone = InlineTone.info;
    });
    try {
      final session = AppStateScope.read(context).session;
      if (session == null) throw SupervisorException('Sign in again.');
      final result = await _api.registerFace(
        cnic: session.cnic,
        employeeId: _id(selected),
        shift: shift,
        camera: _camera,
        photos: photos,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _face = result;
        _justRegistered = true;
        _message = null;
        _selected = {
          ...selected,
          'enrolled': true,
          'shift': shift,
          if (result['created_at'] != null) 'faceRegisteredAt': result['created_at'],
        };
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = error.message;
        _tone = error.retry ? InlineTone.warning : InlineTone.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final registered = _face?['registered'] == true;
    final cnic = AppStateScope.of(context).session?.cnic ?? '';
    final photo = _api.absolute(_face?['photo_url']?.toString(), cnic);
    final name = '${selected?['name'] ?? ''}'.trim();
    final registeredAt = _face?['created_at'] ?? selected?['faceRegisteredAt'];
    final shift = _face?['shift']?.toString() ?? _shift ?? selected?['shift']?.toString();
    final role = '${selected?['role'] ?? ''}'.trim();
    final cnicNo = '${selected?['cnic'] ?? ''}'.trim();
    final contact = '${selected?['contact'] ?? ''}'.trim();

    return AppPage(
      title: 'Register face',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                const FaceHrHero(
                  icon: Icons.face_retouching_natural_rounded,
                  title: 'Face enrollment',
                  subtitle:
                      'Hold steady in brighter light — face fills the frame. Three photos, no extra poses.',
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  InlineMessage(message: _error!, tone: InlineTone.error),
                  const SizedBox(height: 12),
                ],
                FaceHrWorkerPicker(
                  name: selected == null ? null : (name.isEmpty ? 'Worker' : name),
                  hint: 'Select worker',
                  subtitle: cnicNo.isEmpty ? role : cnicNo,
                  enabled: _employees.isNotEmpty && !_saving,
                  onTap: _pick,
                ),
                if (selected != null && registered) ...[
                  const SizedBox(height: 18),
                  RegisteredEnrollmentCard(
                    name: name.isEmpty ? 'Worker' : name,
                    role: role,
                    cnicNo: cnicNo,
                    shift: shift,
                    registeredAt: registeredAt,
                    photoUrl: photo,
                    photoHeaders: _api.photoHeaders,
                    justRegistered: _justRegistered,
                  ),
                ] else if (selected != null) ...[
                  const SizedBox(height: 16),
                  FaceHrWorkerCard(
                    name: name,
                    role: role,
                    cnic: cnicNo,
                    shift: '${selected['shift'] ?? ''}'.trim(),
                    contact: contact,
                    badge: const FaceHrStatusChip(label: 'Not enrolled yet', ok: false),
                  ),
                  const SizedBox(height: 18),
                  const FaceHrSectionLabel('Choose shift'),
                  const SizedBox(height: 10),
                  FaceHrShiftPicker(
                    shifts: _shifts,
                    value: _shift,
                    enabled: !_saving,
                    onChanged: (value) => setState(() => _shift = value),
                  ),
                  const SizedBox(height: 18),
                  const FaceHrSectionLabel('How it works'),
                  const SizedBox(height: 10),
                  const FaceHrStepGuide(
                    steps: [
                      (
                        Icons.wb_sunny_outlined,
                        'Stand in brighter light',
                        'Face should be clear — not strict, but avoid dark corners.'
                      ),
                      (
                        Icons.crop_free_rounded,
                        'Face fills the frame',
                        'Hold the phone steady. No need to turn, blink, or change pose.'
                      ),
                      (
                        Icons.photo_camera_front_rounded,
                        '3 photos automatically',
                        'Same clear look three times. Server checks they are one person.'
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 18),
                  const FaceHrStepGuide(
                    steps: [
                      (Icons.person_search_rounded, 'Pick a worker', 'Search by name or CNIC from your list.'),
                      (Icons.schedule_rounded, 'Set the shift', 'Day, Evening or Night for this enrollment.'),
                      (
                        Icons.photo_camera_front_rounded,
                        'Capture 3 photos',
                        'Hold steady in brighter light — face fills the frame. No extra poses.'
                      ),
                    ],
                  ),
                ],
                if (_message != null && !registered) ...[
                  const SizedBox(height: 16),
                  InlineMessage(message: _message!, tone: _tone),
                ],
              ],
            ),
      bottom: selected == null || registered
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: PrimaryButton(
                  label: _shift == null ? 'Select a shift first' : 'Register face (3 photos)',
                  loading: _saving,
                  icon: Icons.face_retouching_natural_outlined,
                  onPressed: _shift == null || _saving ? null : _register,
                ),
              ),
            ),
    );
  }
}
