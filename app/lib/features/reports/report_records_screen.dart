import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Lists field records submitted by the signed-in supervisor only.
class ReportRecordsScreen extends StatefulWidget {
  const ReportRecordsScreen({super.key});

  @override
  State<ReportRecordsScreen> createState() => _ReportRecordsScreenState();
}

class _ReportRecordsScreenState extends State<ReportRecordsScreen> {
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
        _error = 'Sign in to see records.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await SupervisorApi().fieldRecords(
        session.cnic,
        date: supervisorToday(),
        mineOnly: true,
        session: session,
      );
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
        _records = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    final items = records?.items ?? const <FieldRecordSummary>[];

    return AppPage(
      title: 'Records',
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
                        icon: Icons.assignment_outlined,
                        title: 'Submitted records',
                        subtitle: records == null || records.date.isEmpty
                            ? 'Records where VerifiedBy is your supervisor login.'
                            : 'Verified by you · ${records.date}',
                        colors: ModulePalette.reports,
                      ),
                      const SizedBox(height: 16),
                      _SummaryRow(count: items.length),
                      const SizedBox(height: 16),
                      if (items.isEmpty)
                        const EmptyState(
                          icon: Icons.assignment_outlined,
                          title: 'No records yet',
                          message:
                              'When you submit activity or tagging in Solid Waste, those records show here.',
                        )
                      else
                        ModulePanel(
                          title: 'Your submissions',
                          subtitle: '${items.length} submitted',
                          accent: ModulePalette.reportsAccent,
                          child: Column(
                            children: [
                              for (var i = 0; i < items.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                _RecordTile(
                                  title: _recordTitle(items[i]),
                                  subtitle: _recordSubtitle(items[i]),
                                  badge: items[i].status.isEmpty ? 'Saved' : items[i].status,
                                  onTap: () => context.push(
                                    AppRoutes.reportRecordDetails,
                                    extra: items[i].id,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  String _recordTitle(FieldRecordSummary item) {
    final container = item.containerName?.trim() ?? '';
    if (item.isContainerActivity && container.isNotEmpty) return container;
    final activity = item.activity?.trim() ?? '';
    if (activity.isNotEmpty) return activity;
    if (item.kind.isEmpty) return 'Record ${item.id}';
    return item.kind;
  }

  String _recordSubtitle(FieldRecordSummary item) {
    final parts = <String>[];
    if (item.isContainerActivity) {
      final activity = item.activity?.trim() ?? '';
      if (activity.isNotEmpty) parts.add(activity);
    }
    final location = item.locationLabel;
    if (location != null && location.isNotEmpty) parts.add(location);
    if (item.date.isNotEmpty) parts.add(item.date);
    return parts.isEmpty ? 'Submitted by you' : parts.join(' · ');
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ModulePalette.line),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Text(
            '$count',
            style: AppType.title.copyWith(fontSize: 22, color: ModulePalette.reportsAccent),
          ),
          const SizedBox(width: 10),
          Text(
            count == 1 ? 'record you submitted' : 'records you submitted',
            style: AppType.caption.copyWith(color: ModulePalette.muted),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
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
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_outlined, color: AppColors.success, size: 20),
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
              ModuleStatusChip(label: badge, color: AppColors.success),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: ModulePalette.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
