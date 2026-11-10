import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
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
  List<SupervisorIssue> _issues = const [];
  EvidenceDay? _evidence;
  FieldRecordDay? _records;
  String? _error;
  bool _loading = true;

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = SupervisorApi();
      final issues = await api.issues(session.cnic);
      EvidenceDay? evidence;
      FieldRecordDay? records;
      try {
        evidence = await api.evidence(session.cnic);
      } on SupervisorException {
        evidence = null;
      }
      try {
        records = await api.fieldRecords(session.cnic);
      } on SupervisorException {
        records = null;
      }
      if (!mounted) return;
      setState(() {
        _issues = issues;
        _evidence = evidence;
        _records = records;
        _loading = false;
        _error = null;
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final evidence = _evidence;
    final records = _records;
    final recordCount = records?.items.length ?? 0;
    final evidenceCount = evidence?.items.length ?? 0;
    final openCount = _issues.where((issue) => !issue.resolved).length;
    final resolvedCount = _issues.where((issue) => issue.resolved).length;
    final hasAny = _issues.isNotEmpty || recordCount > 0 || evidenceCount > 0;

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
              title: 'Today’s field reports',
              subtitle:
                  'Field records, pictorial evidence and complaints linked to your supervisor account.',
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
                records: recordCount,
                evidence: evidenceCount,
                open: openCount,
                resolved: resolvedCount,
              ),
              const SizedBox(height: 16),
              if (!hasAny)
                const EmptyState(
                  icon: Icons.assessment_outlined,
                  title: 'No reports yet',
                  message:
                      'Complaints, field records, and evidence saved today will show here.',
                ),
              if (records != null && records.items.isNotEmpty) ...[
                ModulePanel(
                  title: 'Field records',
                  subtitle: records.date,
                  accent: ModulePalette.reportsAccent,
                  child: Column(
                    children: [
                      for (var i = 0; i < records.items.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _ReportTile(
                          icon: Icons.assignment_outlined,
                          title: records.items[i].kind.isEmpty
                              ? 'Record ${records.items[i].id}'
                              : records.items[i].kind,
                          subtitle: records.items[i].remarks ?? records.items[i].date,
                          badge: records.items[i].status.isEmpty
                              ? 'Saved'
                              : records.items[i].status,
                          badgeColor: AppColors.success,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (evidence != null && evidence.items.isNotEmpty) ...[
                ModulePanel(
                  title: 'Evidence',
                  subtitle: evidence.date,
                  accent: ModulePalette.wasteAccent,
                  child: Column(
                    children: [
                      for (var i = 0; i < evidence.items.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _ReportTile(
                          icon: Icons.photo_camera_outlined,
                          title: evidence.items[i].activity.isEmpty
                              ? 'Evidence ${evidence.items[i].id}'
                              : evidence.items[i].activity,
                          subtitle:
                              evidence.items[i].geoTag ?? evidence.items[i].dateCaptured,
                          badge: 'Saved',
                          badgeColor: AppColors.success,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (_issues.isNotEmpty)
                ModulePanel(
                  title: 'Complaints',
                  subtitle: '${_issues.length} total · $openCount open',
                  accent: ModulePalette.complaintsAccent,
                  child: Column(
                    children: [
                      for (var i = 0; i < _issues.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _ReportTile(
                          icon: Icons.report_outlined,
                          title: _issues[i].activity.isEmpty
                              ? 'Complaint ${_issues[i].id}'
                              : _issues[i].activity,
                          subtitle: _issues[i].description.isEmpty
                              ? _issues[i].sector
                              : _issues[i].description,
                          badge: _issues[i].resolved
                              ? 'Resolved'
                              : _issues[i].inProcessing
                                  ? 'In Processing'
                                  : 'Pending',
                          badgeColor: _issues[i].resolved
                              ? AppColors.success
                              : _issues[i].inProcessing
                                  ? AppColors.warning
                                  : AppColors.info,
                          onTap: () {
                            AppStateScope.read(context).openIssue(_issues[i]);
                            context.push(AppRoutes.complaintDetails);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.records,
    required this.evidence,
    required this.open,
    required this.resolved,
  });

  final int records;
  final int evidence;
  final int open;
  final int resolved;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ModulePalette.line),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          _Stat(label: 'Records', value: records, color: ModulePalette.reportsAccent),
          _divider(),
          _Stat(label: 'Evidence', value: evidence, color: ModulePalette.wasteAccent),
          _divider(),
          _Stat(label: 'Open', value: open, color: AppColors.warning),
          _divider(),
          _Stat(label: 'Done', value: resolved, color: AppColors.success),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 58, color: ModulePalette.line);
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
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback? onTap;

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
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: ModulePalette.muted, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
