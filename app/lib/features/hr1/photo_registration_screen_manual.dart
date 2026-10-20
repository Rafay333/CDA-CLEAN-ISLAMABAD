import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/hr1_api_manual.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../hr/employee_details.dart';
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
        _message = '${result['message'] ?? 'Photo registered.'} ${selected['name']}.';
        _tone = InlineTone.success;
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
    return AppPage(
      title: 'Register photo',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (_error != null) InlineMessage(message: _error!, tone: InlineTone.error),
                OutlinedButton.icon(
                  onPressed: _employees.isEmpty ? null : _pick,
                  icon: const Icon(Icons.person_search_outlined),
                  label: Text(selected == null ? 'Select name' : '${selected['name']}'),
                ),
                if (selected != null) ...[
                  const SizedBox(height: 16),
                  EmployeeDetails(employee: selected),
                  const SizedBox(height: 12),
                  Hr1RegistrationBadge(registered: registered),
                  if (registered && photo.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        photo,
                        headers: _api.photoHeaders,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const InlineMessage(
                      message: 'This worker is already registered.',
                      tone: InlineTone.success,
                    ),
                  ],
                  if (!registered) ...[
                  const SizedBox(height: 16),
                  Text('Shift', style: AppType.section.copyWith(fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final item in _shifts) ...[
                        Expanded(
                          child: _Choice(
                            label: item.$1,
                            icon: item.$2,
                            selected: _shift == item.$1,
                            onTap: _saving ? null : () => setState(() => _shift = item.$1),
                          ),
                        ),
                        if (item != _shifts.last) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Camera', style: AppType.section.copyWith(fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _Choice(
                          label: 'Front',
                          icon: Icons.photo_camera_front_outlined,
                          selected: _camera == 'front',
                          onTap: _saving ? null : () => setState(() => _camera = 'front'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Choice(
                          label: 'Back',
                          icon: Icons.photo_camera_back_outlined,
                          selected: _camera == 'back',
                          onTap: _saving ? null : () => setState(() => _camera = 'back'),
                        ),
                      ),
                    ],
                  ),
                  ],
                ],
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  InlineMessage(message: _message!, tone: _tone),
                ],
              ],
            ),
      bottom: selected == null || registered
          ? null
          : Padding(
              padding: const EdgeInsets.all(16),
              child: PrimaryButton(
                label: 'Register face',
                loading: _saving,
                icon: Icons.photo_camera_outlined,
                onPressed: _shift == null || _saving ? null : _register,
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
    final background = registered ? const Color(0xFF15803D) : const Color(0xFFF5C518);
    final foreground = registered ? Colors.white : const Color(0xFF3F2E00);
    return Container(
      width: compact ? null : double.infinity,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 6 : 13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(compact ? 999 : 14),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            registered ? Icons.check_circle_rounded : Icons.info_rounded,
            color: foreground,
            size: compact ? 14 : 20,
          ),
          SizedBox(width: compact ? 4 : 8),
          Text(
            registered ? 'Registered' : 'Not registered',
            style: AppType.body.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 11.5 : 16,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
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
      color: AppColors.white,
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
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF12304A)),
                ),
              ),
            ],
          ),
        ),
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
    final sheetHeight = (media.size.height * 0.72 - media.viewInsets.bottom).clamp(240.0, media.size.height * 0.72);
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
                decoration: const InputDecoration(
                  hintText: 'Search name or CNIC',
                  prefixIcon: Icon(Icons.search),
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
