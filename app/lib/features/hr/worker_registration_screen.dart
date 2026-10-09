import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'attendance_api.dart';
import 'employee_details.dart';
import 'face_capture.dart';

class WorkerRegistrationScreen extends StatefulWidget {
  const WorkerRegistrationScreen({super.key});

  @override
  State<WorkerRegistrationScreen> createState() => _WorkerRegistrationScreenState();
}

class _WorkerRegistrationScreenState extends State<WorkerRegistrationScreen> {
  static const _shifts = ['Day', 'Evening', 'Night'];

  final _api = AttendanceApi();
  List<Map<String, dynamic>> _employees = [];
  Map<String, dynamic>? _selected;
  Map<String, dynamic>? _attendance;
  String? _shift;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  String? _savedShift(Map<String, dynamic>? row) {
    final value = row?['shift']?.toString();
    return _shifts.contains(value) ? value : null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.employees();
      if (!mounted) return;
      setState(() {
        _employees = rows;
        _loading = false;
        if (_selected != null) {
          _selected = rows.cast<Map<String, dynamic>?>().firstWhere(
            (row) => row!['employeeId'] == _selected!['employeeId'],
            orElse: () => _selected,
          );
        }
      });
    } on AttendanceException catch (error) {
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
      _attendance = null;
      _shift = _savedShift(selected);
      _saving = true;
    });
    try {
      final detail = await _api.employee(selected['employeeId'] as int);
      if (!mounted) return;
      final employee = Map<String, dynamic>.from(detail['employee'] as Map);
      setState(() {
        _selected = employee;
        _shift = _savedShift(employee);
        _attendance = detail['attendance'] == null
            ? null
            : Map<String, dynamic>.from(detail['attendance'] as Map);
        _saving = false;
      });
    } on AttendanceException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _show(error.message, InlineTone.error);
    }
  }

  Future<void> _pickShift() async {
    if (_selected?['enrolled'] == true) return;
    final selected = await showAppSheet<String>(
      context,
      builder: (context) => SheetScaffold(
        title: 'Shift',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final shift in _shifts)
              ListTile(
                title: Text(shift, style: AppType.body),
                trailing: _shift == shift
                    ? const Icon(Icons.check_rounded, color: AppColors.emerald)
                    : null,
                onTap: () => Navigator.of(context).pop(shift),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _shift = selected);
  }

  Future<void> _register() async {
    final selected = _selected;
    final shift = _shift;
    if (selected == null || shift == null || selected['enrolled'] == true) return;
    final photos = await FaceCapturePage.open(
      context,
      title: 'Registration',
      burst: false,
    );
    if (photos == null || !mounted) return;
    if (photos.length < 3) {
      _show('The camera could not take all the pictures. Please try again.', InlineTone.error);
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await _api.enroll(selected['employeeId'] as int, photos, shift);
      if (!mounted) return;
      setState(() {
        _selected = Map<String, dynamic>.from(result['employee'] as Map);
        _saving = false;
      });
      _show('Face registered for ${_selected!['name']}.', InlineTone.success);
      await _load();
    } on AttendanceException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _show(error.message, InlineTone.error);
    }
  }

  Future<void> _reset() async {
    final selected = _selected;
    if (selected == null) return;
    final confirmed = await ConfirmationSheet.show(
      context,
      title: 'Reset this face?',
      message: 'The saved photos are removed. The employee can register again.',
      confirmLabel: 'Reset face',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      final person = await _api.resetFace(selected['employeeId'] as int);
      if (!mounted) return;
      setState(() {
        _selected = person;
        _shift = _savedShift(person);
        _saving = false;
      });
      await _load();
    } on AttendanceException catch (error) {
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
      title: 'Face registration',
      bottom: PrimaryButton(
        label: enrolled ? 'Face already registered' : 'Register face',
        loading: _saving,
        onPressed: selected == null || _shift == null || enrolled || _saving ? null : _register,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Choose an employee and a shift, then take three photos, 5 seconds apart, looking straight at the camera.',
            style: AppType.caption,
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LoadingSkeleton(height: 52)
          else
            _PickerField(
              label: selected == null
                  ? 'Select employee'
                  : '${selected['name']} · ${selected['cnic']}',
              enrolled: enrolled,
              onTap: _employees.isEmpty ? null : _pick,
            ),
          const SizedBox(height: 12),
          Text('Shift', style: AppType.caption.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          _PickerField(
            label: _shift ?? 'Select shift',
            enrolled: false,
            onTap: enrolled || _saving ? null : _pickShift,
          ),
          if (enrolled && _shift == null) ...[
            const SizedBox(height: 8),
            const InlineMessage(
              tone: InlineTone.warning,
              message: 'No shift is saved. Reset the face, choose Day, Evening, or Night, and register again.',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            InlineMessage(tone: InlineTone.error, message: _error!),
          ],
          if (_employees.isEmpty && !_loading && _error == null) ...[
            const SizedBox(height: 16),
            const EmptyState(
              icon: Icons.groups_outlined,
              title: 'No active employees',
              message: 'Active employees from SmartSWM will appear in this list.',
            ),
          ],
          if (selected != null) ...[
            const SizedBox(height: 16),
            EmployeeDetails(employee: selected, attendance: _attendance),
            if (enrolled)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: _saving ? null : _reset, child: const Text('Reset face')),
              ),
          ],
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({required this.label, required this.enrolled, required this.onTap});

  final String label;
  final bool enrolled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(child: Text(label, style: AppType.body)),
              if (enrolled) ...[
                const StatusBadge(label: 'Registered', color: AppColors.success),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
            ],
          ),
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
      title: 'Employee',
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
                          trailing: row['enrolled'] == true
                              ? const StatusBadge(label: 'Registered', color: AppColors.success)
                              : null,
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
