import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/staff_access.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _recordCount = 0;
  int _attendanceMarked = 0;
  int _attendanceTeam = 0;
  String? _error;
  bool _loading = true;
  bool _wantRecords = false;
  bool _wantAttendance = false;

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
        _error = 'Sign in to see reports.';
      });
      return;
    }
    final wantRecords =
        session.can(StaffCapability.serveContainers) || session.canUseOtherFieldRecords;
    final wantAttendance = session.can(StaffCapability.markAttendance) ||
        session.can(StaffCapability.manageHr) ||
        wantRecords;
    setState(() {
      _loading = true;
      _error = null;
      _wantRecords = wantRecords;
      _wantAttendance = wantAttendance;
    });
    if (!wantRecords && !wantAttendance) {
      setState(() {
        _recordCount = 0;
        _attendanceMarked = 0;
        _attendanceTeam = 0;
        _loading = false;
      });
      return;
    }
    final api = SupervisorApi();
    final errors = <String>[];
    var recordCount = 0;
    var attendanceMarked = 0;
    var attendanceTeam = 0;
    if (wantRecords) {
      try {
        final records = await api.fieldRecords(
          session.cnic,
          mineOnly: true,
          session: session,
        );
        recordCount = records.items.length;
      } on SupervisorException catch (error) {
        errors.add(error.message);
      }
    }
    if (wantAttendance) {
      try {
        final rows = await api.attendance(session.cnic);
        attendanceTeam = rows.length;
        attendanceMarked = rows
            .where(
              (row) =>
                  (row.checkIn ?? '').trim().isNotEmpty ||
                  (row.checkOut ?? '').trim().isNotEmpty ||
                  row.present,
            )
            .length;
      } on SupervisorException catch (error) {
        errors.add(error.message);
      }
    }
    if (!mounted) return;
    final attempted = (wantRecords ? 1 : 0) + (wantAttendance ? 1 : 0);
    setState(() {
      _recordCount = recordCount;
      _attendanceMarked = attendanceMarked;
      _attendanceTeam = attendanceTeam;
      _loading = false;
      _error = errors.length >= attempted && errors.isNotEmpty ? errors.first : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasAny = _wantAttendance || _wantRecords;

    return AppPage(
      title: 'Reports',
      showBack: false,
      actions: [
        IconActionButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          light: true,
          busy: _loading,
          onPressed: _loading ? null : _load,
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            const ModuleHero(
              icon: Icons.assessment_outlined,
              title: 'Today’s reports',
              subtitle: 'Team attendance you marked, and field records you posted.',
              colors: ModulePalette.reports,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const LoadingSkeletonGroup()
            else if (_error != null) ...[
              InlineMessage(tone: InlineTone.error, message: _error!),
              const SizedBox(height: 12),
              OutlineButton(label: 'Try again', onPressed: _load),
            ] else ...[
              _SummaryStrip(
                records: _wantRecords ? _recordCount : null,
                attendance: _wantAttendance ? _attendanceMarked : null,
              ),
              const SizedBox(height: 16),
              if (!hasAny)
                const EmptyState(
                  icon: Icons.assessment_outlined,
                  title: 'No reports yet',
                  message: 'Attendance and your posted records will show here.',
                ),
              if (_wantAttendance) ...[
                ModulePanel(
                  title: 'Attendance',
                  accent: ModulePalette.profileAccent,
                  child: _ReportTile(
                    icon: Icons.fingerprint_rounded,
                    title: 'Attendance',
                    subtitle: _attendanceTeam == 0
                        ? 'Tap to view employees you marked'
                        : '$_attendanceMarked of $_attendanceTeam marked · tap to view',
                    badge: _attendanceBadge,
                    badgeColor: _attendanceBadgeColor,
                    onTap: () => context.push(AppRoutes.reportAttendanceDetails),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (_wantRecords) ...[
                ModulePanel(
                  title: 'Records',
                  accent: ModulePalette.reportsAccent,
                  child: _ReportTile(
                    icon: Icons.assignment_outlined,
                    title: 'Records',
                    subtitle: _recordCount == 0
                        ? 'Tap to view records you submitted'
                        : '$_recordCount submitted · tap to view',
                    badge: _recordCount == 0 ? 'None' : '$_recordCount',
                    badgeColor: _recordCount == 0 ? AppColors.warning : AppColors.success,
                    onTap: () => context.push(AppRoutes.reportRecords),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String get _attendanceBadge {
    if (_attendanceMarked > 0) return '$_attendanceMarked';
    return 'None';
  }

  Color get _attendanceBadgeColor {
    if (_attendanceMarked > 0) return AppColors.success;
    return AppColors.warning;
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.records,
    required this.attendance,
  });

  final int? records;
  final int? attendance;

  @override
  Widget build(BuildContext context) {
    final stats = <({String label, int value, Color color})>[
      if (records != null) (label: 'Records', value: records!, color: ModulePalette.reportsAccent),
      if (attendance != null) (label: 'Attendance', value: attendance!, color: ModulePalette.profileAccent),
    ];
    if (stats.isEmpty) return const SizedBox.shrink();
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
            _Stat(label: stats[i].label, value: stats[i].value, color: stats[i].color),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          children: [
            Text(
              '$value',
              style: AppType.title.copyWith(fontSize: 20, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ModulePalette.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: badgeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.label.copyWith(fontSize: 13.5, color: ModulePalette.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption.copyWith(color: ModulePalette.muted, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ModuleStatusChip(label: badge, color: badgeColor),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: ModulePalette.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
