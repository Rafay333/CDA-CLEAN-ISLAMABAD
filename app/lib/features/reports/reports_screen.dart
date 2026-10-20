import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

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
    final hasAny = _issues.isNotEmpty ||
        (evidence != null && evidence.items.isNotEmpty) ||
        (records != null && records.items.isNotEmpty);
    return AppPage(
      title: 'Reports',
      showBack: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (_loading)
            const LoadingSkeletonGroup()
          else if (_error != null)
            InlineMessage(tone: InlineTone.error, message: _error!)
          else if (!hasAny)
            const EmptyState(
              icon: Icons.assessment_outlined,
              title: 'No reports yet',
              message: 'Complaints, field records, and evidence saved today will show here.',
            ),
          if (records != null && records.items.isNotEmpty) ...[
            Text('Field records · ${records.date}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final item in records.items) ...[
              ListItem(
                title: item.kind.isEmpty ? 'Record ${item.id}' : item.kind,
                subtitle: item.remarks ?? item.date,
                trailing: StatusBadge(
                  label: item.status.isEmpty ? 'Saved' : item.status,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
          if (evidence != null && evidence.items.isNotEmpty) ...[
            Text('Evidence · ${evidence.date}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final item in evidence.items) ...[
              ListItem(
                title: item.activity.isEmpty ? 'Evidence ${item.id}' : item.activity,
                subtitle: item.geoTag ?? item.dateCaptured,
                trailing: const StatusBadge(label: 'Saved', color: AppColors.success),
              ),
              const SizedBox(height: 10),
            ],
          ],
          if (_issues.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Complaints', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final issue in _issues) ...[
              ListItem(
                title: issue.activity.isEmpty ? 'Complaint ${issue.id}' : issue.activity,
                subtitle: issue.description.isEmpty ? issue.sector : issue.description,
                trailing: StatusBadge(
                  label: issue.resolved
                      ? 'Resolved'
                      : issue.inProcessing
                          ? 'In Processing'
                          : 'Pending',
                  color: issue.resolved
                      ? AppColors.success
                      : issue.inProcessing
                          ? AppColors.warning
                          : AppColors.info,
                ),
                onTap: () {
                  AppStateScope.read(context).openIssue(issue);
                  context.push(AppRoutes.complaintDetails);
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}
