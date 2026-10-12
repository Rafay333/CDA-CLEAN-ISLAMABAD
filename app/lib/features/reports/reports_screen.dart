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
      final evidence = await api.evidence(session.cnic);
      if (!mounted) return;
      setState(() {
        _issues = issues;
        _evidence = evidence;
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
    final hasAny = _issues.isNotEmpty || (evidence != null && evidence.items.isNotEmpty);
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
              message: 'Complaints and evidence saved today will show here.',
            ),
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
                  label: issue.resolved ? 'Resolved' : 'Pending',
                  color: issue.resolved ? AppColors.success : AppColors.info,
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
