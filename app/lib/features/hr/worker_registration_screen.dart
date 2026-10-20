import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'employee_details.dart';
import 'face_capture.dart';
import 'face_match.dart';

class WorkerRegistrationScreen extends StatefulWidget {
  const WorkerRegistrationScreen({super.key});

  @override
  State<WorkerRegistrationScreen> createState() => _WorkerRegistrationScreenState();
}

class _WorkerRegistrationScreenState extends State<WorkerRegistrationScreen> {
  static const _shifts = ['Day', 'Evening', 'Night'];
  static const _shiftChoices = [
    ('Day', 'Day shift', Icons.wb_sunny_outlined),
    ('Evening', 'Evening', Icons.wb_twilight_outlined),
    ('Night', 'Night shift', Icons.nightlight_outlined),
  ];

  final _api = SupervisorApi();
  List<Map<String, dynamic>> _employees = [];
  Map<String, dynamic>? _selected;
  String? _shift;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  String? _savedShift(Map<String, dynamic>? row) {
    final value = row?['shift']?.toString();
    return _shifts.contains(value) ? value : null;
  }

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
      final rows = await _api.faceEmployees(session.cnic);
      if (!mounted) return;
      setState(() {
        _employees = rows;
        _loading = false;
        if (_selected != null) {
          final currentId = _id(_selected!);
          _selected = rows.cast<Map<String, dynamic>?>().firstWhere(
            (row) => _id(row!) == currentId,
            orElse: () => _selected,
          );
          _shift = _savedShift(_selected);
        }
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
      builder: (context) => _EmployeePicker(employees: _employees),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selected = selected;
      _shift = _savedShift(selected);
      _error = null;
    });
    final session = AppStateScope.read(context).session;
    if (session == null) return;
    try {
      final detail = await _api.employee(session.cnic, _id(selected));
      if (!mounted) return;
      setState(() {
        _selected = {...selected, ...detail};
        _shift = _savedShift(_selected) ?? _shift;
      });
    } on SupervisorException {
      // List payload is enough when the detail card is unavailable.
    }
  }

  Future<void> _register({List<Uint8List>? photos, bool confirmDifferent = false}) async {
    final selected = _selected;
    final shift = _shift;
    if (selected == null || shift == null || _saving) return;
    if (selected['enrolled'] == true) {
      _show(alreadyRegisteredMessage, InlineTone.error);
      return;
    }
    final shots = photos ??
        await FaceCapturePage.open(
          context,
          title: 'Registration',
          burst: false,
        );
    if (shots == null || !mounted) return;
    if (shots.length < 3) {
      _show('The camera could not take all the pictures. Please try again.', InlineTone.error);
      return;
    }
    setState(() => _saving = true);
    try {
      final session = AppStateScope.read(context).session;
      if (session == null) throw SupervisorException('Sign in again.');
      final result = await _api.enrollFace(
        cnic: session.cnic,
        employeeId: _id(selected),
        shift: shift,
        photos: shots,
        confirmDifferent: confirmDifferent,
      );
      if (!mounted) return;
      final employee = result['employee'] is Map
          ? Map<String, dynamic>.from(result['employee'] as Map)
          : {...selected, 'enrolled': true, 'shift': shift};
      setState(() {
        _selected = employee;
        _shift = _savedShift(employee) ?? shift;
        _saving = false;
        _error = null;
        _employees = [
          for (final row in _employees)
            _id(row) == _id(employee) ? employee : row,
        ];
      });
      _show('$faceRegisteredSuccessMessage ${employee['name']}.', InlineTone.success);
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (isDuplicateOfOtherEmployeeError(error.message) && !confirmDifferent) {
        final other = otherEmployeeFromDuplicateError(error.message) ?? 'another worker';
        final name = '${selected['name']}';
        final proceed = await ConfirmationSheet.show(
          context,
          title: 'Different person?',
          message:
              '$name and $other are treated as the same face. If they are two people, register $name anyway. Do not reset the other worker.',
          confirmLabel: 'They are different — register',
        );
        if (!mounted) return;
        if (proceed == true) {
          await _register(photos: shots, confirmDifferent: true);
          return;
        }
        _show(
          '$name was not registered. Take three new photos in good light, face filling the oval.',
          InlineTone.error,
        );
        return;
      }
      if (isDuplicateOfOtherEmployeeError(error.message)) {
        _show(
          '${selected['name']} is a different person. Take three new photos in good light, face filling the oval, glasses off on photo 2.',
          InlineTone.error,
        );
        return;
      }
      if (isThisEmployeeAlreadyEnrolledError(error.message)) {
        final reset = await ConfirmationSheet.show(
          context,
          title: 'Face already on server',
          message:
              'This employee already has a stored face (the list may be outdated). Reset the face and register again.',
          confirmLabel: 'Reset and try again',
        );
        if (!mounted) return;
        if (reset == true) {
          await _resetFaceOnly();
        } else {
          _show(alreadyRegisteredMessage, InlineTone.error);
        }
        return;
      }
      _show(error.message, InlineTone.error);
    }
  }

  Future<void> _reset() async {
    final selected = _selected;
    if (selected == null || _saving) return;
    final confirmed = await ConfirmationSheet.show(
      context,
      title: 'Reset this face?',
      message: 'The saved photos are removed. The employee can register again.',
      confirmLabel: 'Reset face',
    );
    if (!confirmed || !mounted) return;
    await _resetFaceOnly();
  }

  Future<void> _resetFaceOnly() async {
    final selected = _selected;
    if (selected == null || _saving) return;
    setState(() => _saving = true);
    try {
      final session = AppStateScope.read(context).session;
      if (session == null) throw SupervisorException('Sign in again.');
      final person = await _api.resetFace(cnic: session.cnic, employeeId: _id(selected));
      if (!mounted) return;
      setState(() {
        _selected = person;
        _shift = _savedShift(person);
        _saving = false;
        _error = null;
      });
      _show('Face reset. Tap Register face and take three HD photos.', InlineTone.info);
      await _load();
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _show(error.message, InlineTone.error);
    }
  }

  void _show(String message, InlineTone tone) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    setState(() => _error = tone == InlineTone.error ? message : null);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final enrolled = selected?['enrolled'] == true;
    return AppPage(
      title: 'Workers Registration',
      centerTitle: true,
      bottom: PrimaryButton(
        label: enrolled ? 'Face already registered' : 'Register face',
        loading: _saving,
        onPressed: selected == null || _shift == null || enrolled || _saving ? null : _register,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (_loading)
            const LoadingSkeleton(height: 64)
          else
            _EmployeeField(
              label: selected == null ? 'Select employee' : '${selected['name']}',
              enrolled: enrolled,
              onTap: _employees.isEmpty ? null : _pick,
            ),
          const SizedBox(height: 8),
          Text('Employee', style: AppType.caption),
          if (selected != null) ...[
            const SizedBox(height: 16),
            EmployeeDetails(employee: selected),
          ],
          const SizedBox(height: 16),
          Text(
            'Shift',
            style: AppType.section.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < _shiftChoices.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _ShiftChip(
                    label: _shiftChoices[i].$2,
                    icon: _shiftChoices[i].$3,
                    selected: _shift == _shiftChoices[i].$1,
                    onTap: enrolled
                        ? null
                        : () => setState(() => _shift = _shiftChoices[i].$1),
                  ),
                ),
              ],
            ],
          ),
          if (enrolled && selected != null) ...[
            const SizedBox(height: 16),
            InlineMessage(
              tone: InlineTone.success,
              message: 'Face registered for ${selected['name']}. Use Reset face to register again.',
            ),
          ] else if (_error != null) ...[
            const SizedBox(height: 16),
            InlineMessage(tone: InlineTone.error, message: _error!),
          ],
          if (enrolled && _shift == null) ...[
            const SizedBox(height: 8),
            const InlineMessage(
              tone: InlineTone.warning,
              message: 'No shift is saved. Reset the face, choose Day, Evening, or Night, and register again.',
            ),
          ],
          if (_employees.isEmpty && !_loading && _error == null) ...[
            const SizedBox(height: 16),
            const EmptyState(
              icon: Icons.groups_outlined,
              title: 'No active employees',
              message: 'Active employees from SmartSWM will appear in this list.',
            ),
          ],
          if (enrolled)
            Align(
              alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _saving ? null : _reset,
                  child: const Text('Reset face'),
                ),
            ),
        ],
      ),
    );
  }
}

class _EmployeeField extends StatelessWidget {
  const _EmployeeField({required this.label, required this.enrolled, required this.onTap});

  final String label;
  final bool enrolled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3EDF3)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F4F8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline_rounded, color: Color(0xFF8AA0B5), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: AppType.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF12304A),
                  ),
                ),
              ),
              if (enrolled) ...[
                const _RegisteredPill(),
                const SizedBox(width: 8),
              ],
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF2F9E6B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftChip extends StatelessWidget {
  const _ShiftChip({
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
    final color = selected ? const Color(0xFF2F9E6B) : const Color(0xFF8AA0B5);
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? const Color(0xFF2F9E6B) : const Color(0xFFE3EDF3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF12304A),
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisteredPill extends StatelessWidget {
  const _RegisteredPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F6EE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Registered',
        style: AppType.caption.copyWith(
          color: const Color(0xFF2F9E6B),
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _EmployeePicker extends StatefulWidget {
  const _EmployeePicker({required this.employees});

  final List<Map<String, dynamic>> employees;

  @override
  State<_EmployeePicker> createState() => _EmployeePickerState();
}

class _EmployeePickerState extends State<_EmployeePicker> {
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
      title: 'Select Employee',
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
                        return ListTile(
                          title: Text('${row['name']}', style: AppType.body),
                          subtitle: Text('${row['cnic']} · ${row['role']}', style: AppType.caption),
                          trailing: row['enrolled'] == true ? const _RegisteredPill() : null,
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
