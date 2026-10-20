import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/display_format.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<SupervisorNotice> _items = const [];
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
        _error = 'Sign in again.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupervisorApi().notifications(session.cnic);
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
      await AppStateScope.read(context).refreshAccount();
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _open(SupervisorNotice notice) async {
    final session = AppStateScope.read(context).session;
    if (session == null) return;
    try {
      if (!notice.read) {
        await SupervisorApi().markNotificationRead(session.cnic, notice.id);
      }
      if (notice.issueId != null) {
        final issue = await SupervisorApi().issue(session.cnic, notice.issueId!);
        if (!mounted) return;
        AppStateScope.read(context).openIssue(issue, processing: issue.inProcessing);
        await context.push(AppRoutes.complaintDetails);
      }
      if (mounted) await _load();
    } on SupervisorException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Notifications',
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (_loading)
              const LoadingSkeletonGroup()
            else if (_error != null)
              InlineMessage(tone: InlineTone.error, message: _error!)
            else if (_items.isEmpty)
              const EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'No notifications',
                message: 'SLA and penalty alerts for open complaints appear here.',
              )
            else
              for (final notice in _items) ...[
                _NoticeTile(notice: notice, onTap: () => _open(notice)),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice, required this.onTap});

  final SupervisorNotice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final at = DateTime.tryParse(notice.at ?? '');
    return ListItem(
      title: notice.title.isEmpty ? 'Alert' : notice.title,
      subtitle: [
        notice.body,
        if (at != null) formatDateTime(at),
      ].where((item) => item.trim().isNotEmpty).join('\n'),
      leading: Icon(
        notice.read ? Icons.notifications_none_rounded : Icons.notifications_active_outlined,
        color: notice.read ? AppColors.textSecondary : AppColors.navy,
      ),
      trailing: notice.read
          ? null
          : Text(
              'New',
              style: AppType.caption.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
      onTap: onTap,
    );
  }
}
