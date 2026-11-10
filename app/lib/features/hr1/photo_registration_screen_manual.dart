import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/hr1_api_manual.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../hr/registered_enrollment_card.dart';
import '../hr_face/face_hr_ui.dart';
import 'photo_capture_page_manual.dart';

class PhotoRegistrationScreenManual extends StatefulWidget {
  const PhotoRegistrationScreenManual({super.key});

  @override
  State<PhotoRegistrationScreenManual> createState() => _PhotoRegistrationScreenManualState();
}

class _PhotoRegistrationScreenManualState extends State<PhotoRegistrationScreenManual> {
  static const _shifts = [
    ('Day', Icons.wb_sunny_outlined),
    ('Evening', Icons.wb_twilight_outlined),
    ('Night', Icons.nightlight_outlined),
  ];

  static const _cameras = [
    ('front', Icons.photo_camera_front_outlined),
    ('back', Icons.photo_camera_back_outlined),
  ];

  final _people = SupervisorApi();
  final _api = Hr1ApiManual();
  List<Map<String, dynamic>> _employees = [];
  Map<String, dynamic>? _selected;
  Map<String, dynamic>? _manual;
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
      _manual = null;
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
      // The list row is enough when the detail card is unavailable.
    }
    try {
      final manual = await _api.registration(session.cnic, _id(selected));
      if (!mounted) return;
      setState(() {
        _manual = manual;
        final saved = manual['shift']?.toString();
        if (_shifts.map((item) => item.$1).contains(saved)) _shift = saved;
        final camera = manual['camera']?.toString();
        if (camera == 'front' || camera == 'back') _camera = camera!;
        if (manual['registered'] == true) {
          _selected = {
            ...?_selected,
            'enrolled': true,
            if (manual['created_at'] != null) 'faceRegisteredAt': manual['created_at'],
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
    final shot = await PhotoCapturePageManual.open(
      context,
      title: 'Registration',
      lens: _camera == 'back' ? CameraLensDirection.back : CameraLensDirection.front,
      requireClearFace: true,
    );
    if (!mounted) return;
    if (shot.error != null) {
      setState(() {
        _message = shot.error;
        _tone = InlineTone.error;
      });
      return;
    }
    final bytes = shot.bytes;
    if (bytes == null) return;
    await _save(selected, shift, bytes);
  }

  Future<void> _save(Map<String, dynamic> selected, String shift, Uint8List bytes) async {
    setState(() {
      _saving = true;
      _message = 'Saving the photo...';
      _tone = InlineTone.info;
    });
    try {
      final session = AppStateScope.read(context).session;
      if (session == null) throw SupervisorException('Sign in again.');
      final result = await _api.registerPhoto(
        cnic: session.cnic,
        employeeId: _id(selected),
        shift: shift,
        camera: _camera,
        photo: bytes,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _manual = result;
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
    final registered = _manual?['registered'] == true;
    final cnic = AppStateScope.of(context).session?.cnic ?? '';
    final photo = _api.absolute(_manual?['photo_url']?.toString(), cnic);
    final name = '${selected?['name'] ?? ''}'.trim();
    final registeredAt = _manual?['created_at'] ?? selected?['faceRegisteredAt'];
    final shift = _manual?['shift']?.toString() ?? _shift ?? selected?['shift']?.toString();
    final role = '${selected?['role'] ?? ''}'.trim();
    final cnicNo = '${selected?['cnic'] ?? ''}'.trim();
    final contact = '${selected?['contact'] ?? ''}'.trim();

    return AppPage(
      title: 'Register photo',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                const FaceHrHero(
                  icon: Icons.photo_camera_front_rounded,
                  title: 'Photo enrollment',
                  subtitle: 'Save one clear face photo so this worker can mark GPS attendance.',
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
                    alreadyHint:
                        'This worker already has a registration photo on file. No further registration needed.',
                    successHint: 'Photo saved. This worker is ready for GPS attendance.',
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
                  const FaceHrSectionLabel('Camera'),
                  const SizedBox(height: 10),
                  FaceHrShiftPicker(
                    shifts: [
                      ('Front', _cameras[0].$2),
                      ('Back', _cameras[1].$2),
                    ],
                    value: _camera == 'back' ? 'Back' : 'Front',
                    enabled: !_saving,
                    onChanged: (value) => setState(() => _camera = value == 'Back' ? 'back' : 'front'),
                  ),
                  const SizedBox(height: 18),
                  const FaceHrSectionLabel('How it works'),
                  const SizedBox(height: 10),
                  const FaceHrStepGuide(
                    steps: [
                      (Icons.person_search_rounded, 'Pick the worker', 'Search by name or CNIC from your list.'),
                      (Icons.schedule_rounded, 'Set shift and camera', 'Day / Evening / Night, then front or back camera.'),
                      (Icons.photo_camera_outlined, 'Take one clear photo', 'Good light, face filling the frame.'),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 18),
                  const FaceHrStepGuide(
                    steps: [
                      (Icons.person_search_rounded, 'Pick a worker', 'Search by name or CNIC from your list.'),
                      (Icons.schedule_rounded, 'Choose shift', 'Day, Evening or Night for this enrollment.'),
                      (Icons.photo_camera_front_rounded, 'Capture one photo', 'Manual GPS attendance uses this photo.'),
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
                  label: _shift == null ? 'Select a shift first' : 'Register photo',
                  loading: _saving,
                  icon: Icons.photo_camera_outlined,
                  onPressed: _shift == null || _saving ? null : _register,
                ),
              ),
            ),
    );
  }
}

class Hr1RegistrationBadge extends StatelessWidget {
  const Hr1RegistrationBadge({super.key, required this.registered, this.compact = false});

  final bool registered;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return FaceHrStatusChip(
        label: registered ? 'Registered' : 'Not registered',
        ok: registered,
      );
    }
    final background = registered ? const Color(0xFF15803D) : const Color(0xFFF5C518);
    final foreground = registered ? Colors.white : const Color(0xFF3F2E00);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            registered ? Icons.check_circle_rounded : Icons.info_rounded,
            color: foreground,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            registered ? 'Registered' : 'Not registered',
            style: AppType.body.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class Hr1EmployeePickerManual extends StatefulWidget {
  const Hr1EmployeePickerManual({super.key, required this.employees});

  final List<Map<String, dynamic>> employees;

  @override
  State<Hr1EmployeePickerManual> createState() => _Hr1EmployeePickerManualState();
}

class _Hr1EmployeePickerManualState extends State<Hr1EmployeePickerManual> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final rows = widget.employees.where((row) {
      if (query.isEmpty) return true;
      return '${row['name']} ${row['cnic']} ${row['role']}'.toLowerCase().contains(query);
    }).toList();
    final media = MediaQuery.of(context);
    final sheetHeight =
        (media.size.height * 0.72 - media.viewInsets.bottom).clamp(240.0, media.size.height * 0.72);
    return SheetScaffold(
      title: 'Select name or CNIC',
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search name or CNIC',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matching employees',
                      message: 'Try another name or CNIC.',
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final enrolled = row['enrolled'] == true;
                        return ListTile(
                          title: Text('${row['name']}', style: AppType.body.copyWith(fontWeight: FontWeight.w700)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${row['cnic']} · ${row['role']}', style: AppType.caption),
                                const SizedBox(height: 6),
                                Hr1RegistrationBadge(registered: enrolled, compact: true),
                              ],
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop(row),
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
