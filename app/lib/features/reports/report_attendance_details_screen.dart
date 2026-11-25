import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/hr1_api_manual.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/pakistan_time.dart';

/// Attendance rows where Attendance.SupervisorCnic matches the logged-in supervisor.
class ReportAttendanceDetailsScreen extends StatefulWidget {
  const ReportAttendanceDetailsScreen({super.key});

  @override
  State<ReportAttendanceDetailsScreen> createState() => _ReportAttendanceDetailsScreenState();
}

class _ReportAttendanceDetailsScreenState extends State<ReportAttendanceDetailsScreen> {
  List<_EmployeeAttendance> _people = const [];
  String? _error;
  bool _loading = true;
  String _dateLabel = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final session = AppStateScope.read(context).session;
    if (session == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in to see attendance.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final today = supervisorToday();
    final api = SupervisorApi();
    final sessionCnic = session.cnic.replaceAll(RegExp(r'\D'), '');
    final byId = <int, _EmployeeAttendance>{};

    bool isThisSupervisor(Map<String, dynamic> row) {
      final raw =
          '${row['supervisorCnic'] ?? row['supervisor_cnic'] ?? row['SupervisorCnic'] ?? ''}';
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      if (sessionCnic.isEmpty) return false;
      // Row must belong to this supervisor (Attendance.SupervisorCnic).
      if (digits.isNotEmpty) return digits == sessionCnic;
      // API already scoped by supervisor_cnic query — keep when column omitted.
      return true;
    }

    void upsert({
      required int employeeId,
      String? name,
      String? role,
      String? checkIn,
      String? checkOut,
      String? cnic,
    }) {
      if (employeeId <= 0) return;
      final existing = byId[employeeId];
      if (existing == null) {
        byId[employeeId] = _EmployeeAttendance(
          employeeId: employeeId,
          name: (name ?? '').trim(),
          role: (role ?? '').trim(),
          cnic: (cnic ?? '').trim(),
          checkIn: _formatTime(checkIn),
          checkOut: _formatTime(checkOut),
        );
        return;
      }
      if ((name ?? '').trim().isNotEmpty) existing.name = name!.trim();
      if ((role ?? '').trim().isNotEmpty) existing.role = role!.trim();
      if ((cnic ?? '').trim().isNotEmpty) existing.cnic = cnic!.trim();
      final inTime = _formatTime(checkIn);
      final outTime = _formatTime(checkOut);
      if (inTime != null) existing.checkIn = inTime;
      if (outTime != null) existing.checkOut = outTime;
    }

    try {
      // Primary: GPS / face attendance logs for this supervisor login.
      try {
        final faceRows = await api.faceLog(session.cnic, date: today);
        for (final row in faceRows) {
          if (!isThisSupervisor(row)) continue;
          final id = int.tryParse('${row['employeeId'] ?? row['employee_id'] ?? ''}') ?? 0;
          final type = '${row['type'] ?? ''}'.toLowerCase();
          final stamp =
              '${row['timestamp'] ?? row['checkIn'] ?? row['check_in'] ?? row['checkOut'] ?? row['check_out'] ?? ''}';
          upsert(
            employeeId: id,
            name: '${row['name'] ?? ''}',
            cnic: '${row['cnic'] ?? row['EmployeeCnic'] ?? ''}',
            checkIn: type == 'check_out'
                ? null
                : (row['checkIn'] ?? row['check_in'] ?? stamp)?.toString(),
            checkOut: type == 'check_out'
                ? (row['checkOut'] ?? row['check_out'] ?? stamp)?.toString()
                : (row['checkOut'] ?? row['check_out'])?.toString(),
          );
        }
      } on SupervisorException {
        // Optional.
      }

      try {
        final manualRows = await Hr1ApiManual().attendanceLog(session.cnic, date: today);
        for (final row in manualRows) {
          if (!isThisSupervisor(row)) continue;
          final id = int.tryParse('${row['employee_id'] ?? row['user_id'] ?? ''}') ?? 0;
          final type = '${row['type'] ?? ''}'.toLowerCase();
          final stamp = '${row['timestamp'] ?? row['check_in'] ?? row['CheckIn'] ?? ''}';
          final outStamp = '${row['check_out'] ?? row['CheckOut'] ?? ''}';
          upsert(
            employeeId: id,
            name: '${row['name'] ?? ''}',
            cnic: '${row['cnic'] ?? row['EmployeeCnic'] ?? ''}',
            checkIn: type == 'check_out' ? null : (stamp.isEmpty ? null : stamp),
            checkOut: type == 'check_out'
                ? (stamp.isEmpty ? null : stamp)
                : (outStamp.isEmpty ? null : outStamp),
          );
        }
      } on SupervisorException {
        // Optional.
      }

      // Fallback roster for this supervisor when logs are empty.
      if (byId.isEmpty) {
        try {
          final rows = await api.attendance(session.cnic, date: today);
          for (final row in rows) {
            if (!row.present &&
                (row.checkIn ?? '').trim().isEmpty &&
                (row.checkOut ?? '').trim().isEmpty) {
              continue;
            }
            upsert(
              employeeId: row.employeeId,
              name: row.name,
              role: row.role,
              checkIn: row.checkIn,
              checkOut: row.checkOut,
            );
          }
        } on SupervisorException {
          // Optional.
        }
      }

      final people = byId.values.where((person) => person.isMarked).toList()
        ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _people = people;
        _dateLabel = today;
        _loading = false;
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
        _people = const [];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Attendance could not be loaded.';
        _people = const [];
      });
    }
  }

  String? _formatTime(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty || text == 'null') return null;
    final parsed = DateTime.tryParse(text) ?? parsePakistanDateTime(text);
    if (parsed != null) {
      final h = parsed.hour.toString().padLeft(2, '0');
      final m = parsed.minute.toString().padLeft(2, '0');
      final s = parsed.second.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    final match = RegExp(r'^(\d{1,2}:\d{2}(?::\d{2})?)').firstMatch(text);
    if (match != null) return match.group(1);
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final marked = _people.length;
    final checkedIn = _people.where((person) => (person.checkIn ?? '').isNotEmpty).length;
    final checkedOut = _people.where((person) => (person.checkOut ?? '').isNotEmpty).length;
    final supervisorName = AppStateScope.of(context).session?.fullName.trim() ?? 'Supervisor';

    return AppPage(
      title: 'Attendance',
      actions: [
        IconActionButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          light: true,
          busy: _loading,
          onPressed: _loading ? null : _load,
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    InlineMessage(tone: InlineTone.error, message: _error!),
                    const SizedBox(height: 12),
                    OutlineButton(label: 'Try again', onPressed: _load),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      ModuleHero(
                        icon: Icons.fingerprint_rounded,
                        title: 'Attendance',
                        subtitle: _dateLabel.isEmpty
                            ? 'Employees marked under $supervisorName.'
                            : 'Marked by $supervisorName · $_dateLabel',
                        colors: ModulePalette.profile,
                      ),
                      const SizedBox(height: 16),
                      _SummaryRow(
                        marked: marked,
                        checkedIn: checkedIn,
                        checkedOut: checkedOut,
                      ),
                      const SizedBox(height: 16),
                      if (_people.isEmpty)
                        const EmptyState(
                          icon: Icons.fingerprint_rounded,
                          title: 'No attendance yet',
                          message:
                              'When this supervisor marks employee attendance, name, check-in and check-out show here.',
                        )
                      else
                        ModulePanel(
                          title: 'Employees',
                          subtitle: '$marked marked',
                          accent: ModulePalette.profileAccent,
                          child: Column(
                            children: [
                              for (var i = 0; i < _people.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                _AttendanceCard(person: _people[i]),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _EmployeeAttendance {
  _EmployeeAttendance({
    required this.employeeId,
    required this.name,
    required this.role,
    required this.cnic,
    this.checkIn,
    this.checkOut,
  });

  final int employeeId;
  String name;
  String role;
  String cnic;
  String? checkIn;
  String? checkOut;

  bool get isMarked =>
      (checkIn ?? '').trim().isNotEmpty || (checkOut ?? '').trim().isNotEmpty;

  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (cnic.isNotEmpty) return 'Employee $cnic';
    return 'Employee $employeeId';
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.marked,
    required this.checkedIn,
    required this.checkedOut,
  });

  final int marked;
  final int checkedIn;
  final int checkedOut;

  @override
  Widget build(BuildContext context) {
    final stats = [
      (label: 'Marked', value: '$marked', color: AppColors.success),
      (label: 'Check in', value: '$checkedIn', color: AppColors.info),
      (label: 'Check out', value: '$checkedOut', color: AppColors.warning),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ModulePalette.line),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) Container(width: 1, height: 58, color: ModulePalette.line),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                child: Column(
                  children: [
                    Text(
                      stats[i].value,
                      style: AppType.title.copyWith(fontSize: 20, color: stats[i].color),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stats[i].label,
                      textAlign: TextAlign.center,
                      style: AppType.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.person});

  final _EmployeeAttendance person;

  @override
  Widget build(BuildContext context) {
    final checkIn = (person.checkIn ?? '').trim();
    final checkOut = (person.checkOut ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: ModulePalette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ModulePalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ModulePalette.profileAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: ModulePalette.profileAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.label.copyWith(fontSize: 14, color: ModulePalette.ink),
                    ),
                    if (person.cnic.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        person.cnic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.caption.copyWith(color: ModulePalette.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const ModuleStatusChip(label: 'Marked', color: AppColors.success),
            ],
          ),
          const SizedBox(height: 12),
          ModuleMetaCard(
            accent: ModulePalette.profileAccent,
            rows: [
              (
                Icons.login_rounded,
                'Check in',
                checkIn.isEmpty ? 'Not marked' : checkIn,
              ),
              (
                Icons.logout_rounded,
                'Check out',
                checkOut.isEmpty ? 'Not marked' : checkOut,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
