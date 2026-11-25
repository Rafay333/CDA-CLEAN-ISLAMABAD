import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class ReportRecordDetailsScreen extends StatefulWidget {
  const ReportRecordDetailsScreen({super.key, required this.recordId});

  final int recordId;

  @override
  State<ReportRecordDetailsScreen> createState() => _ReportRecordDetailsScreenState();
}

class _ReportRecordDetailsScreenState extends State<ReportRecordDetailsScreen> {
  FieldRecordSummary? _record;
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
        _error = 'Sign in to see this record.';
      });
      return;
    }
    if (widget.recordId <= 0) {
      setState(() {
        _loading = false;
        _error = 'Record not found.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final record = await SupervisorApi().fieldRecord(
        session.cnic,
        widget.recordId,
        session: session,
      );
      if (!mounted) return;
      setState(() {
        _record = record;
        _loading = false;
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
        _record = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return AppPage(
      title: 'Record details',
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
              : record == null
                  ? const EmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'Record not found',
                      message: 'This field record could not be loaded.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      children: [
                        ModuleHero(
                          icon: Icons.assignment_outlined,
                          title: _title(record),
                          subtitle: record.date.isEmpty
                              ? 'Saved field record for your supervisor account'
                              : 'Saved on ${record.date}',
                          colors: ModulePalette.reports,
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ModuleStatusChip(
                            label: record.status.isEmpty ? 'Saved' : record.status,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ModulePanel(
                          title: 'Record',
                          accent: ModulePalette.reportsAccent,
                          child: ModuleMetaCard(
                            rows: [
                              (
                                Icons.category_outlined,
                                'Activity',
                                _value(record.activity) ?? _value(record.kind) ?? '—',
                              ),
                              if (_value(record.containerName) != null)
                                (
                                  Icons.delete_outline,
                                  'Container',
                                  record.containerName!,
                                ),
                              if (_value(record.zoneCode) != null)
                                (Icons.map_outlined, 'Zone', record.zoneCode!),
                              if (_value(record.ucCode) != null)
                                (Icons.location_city_outlined, 'UC', record.ucCode!),
                              (
                                Icons.my_location_outlined,
                                'Location',
                                record.locationLabel ?? 'Not available',
                              ),
                              if (_value(record.supervisorName) != null ||
                                  _value(record.supervisorCnic) != null)
                                (
                                  Icons.person_outline_rounded,
                                  'Submitted by',
                                  [
                                    if (_value(record.supervisorName) != null) record.supervisorName!,
                                    if (_value(record.supervisorCnic) != null) record.supervisorCnic!,
                                  ].join(' · '),
                                ),
                              if (_value(record.remarks) != null)
                                (Icons.notes_outlined, 'Remarks', record.remarks!),
                            ],
                          ),
                        ),
                        if (record.beforePictures.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          ModulePanel(
                            title: record.afterPictures.isEmpty ? 'Pictures' : 'Before',
                            child: _PhotoStrip(paths: record.beforePictures),
                          ),
                        ],
                        if (record.afterPictures.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          ModulePanel(
                            title: 'After',
                            child: _PhotoStrip(paths: record.afterPictures),
                          ),
                        ],
                      ],
                    ),
    );
  }

  String _title(FieldRecordSummary item) {
    final container = item.containerName?.trim() ?? '';
    if (item.isContainerActivity && container.isNotEmpty) return container;
    final activity = item.activity?.trim() ?? '';
    if (activity.isNotEmpty) return activity;
    if (item.kind.isEmpty) return 'Record ${item.id}';
    return item.kind;
  }

  String? _value(String? raw) {
    final text = (raw ?? '').trim();
    return text.isEmpty ? null : text;
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.paths});

  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final url = supervisorMediaUrl(paths[index]);
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              width: 148,
              height: 112,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 148,
                height: 112,
                color: ModulePalette.panel,
                alignment: Alignment.center,
                child: Text('Photo ${index + 1}', style: AppType.caption),
              ),
            ),
          );
        },
      ),
    );
  }
}
