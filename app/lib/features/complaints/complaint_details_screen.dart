import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_copy.dart';
import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_typography.dart';
import '../../utils/display_format.dart';

class ComplaintDetailsScreen extends StatefulWidget {
  const ComplaintDetailsScreen({super.key});

  @override
  State<ComplaintDetailsScreen> createState() => _ComplaintDetailsScreenState();
}

class _ComplaintDetailsScreenState extends State<ComplaintDetailsScreen> {
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() async {
    final state = AppStateScope.read(context);
    final id = state.complaint.issueId;
    final cnic = state.session?.cnic;
    if (id == null || cnic == null) return;
    try {
      final issue = await SupervisorApi().issue(cnic, id);
      if (!mounted) return;
      state.openIssue(issue, processing: issue.inProcessing);
    } on SupervisorException {
      // Keep the list payload if detail is unavailable.
    }
  }

  Future<void> _takeAction(ComplaintDraft complaint) async {
    if (complaint.issueId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open a complaint from the list first.')),
      );
      return;
    }
    if (complaint.status == ComplaintStatus.resolved) return;
    if (complaint.status == ComplaintStatus.inProcessing) {
      context.push(AppRoutes.afterPhotos);
      return;
    }
    final session = AppStateScope.read(context).session;
    if (session == null) return;
    setState(() => _acting = true);
    try {
      final message = await SupervisorApi().setIssueStatus(
        cnic: session.cnic,
        id: complaint.issueId!,
        portalStatus: 'in_processing',
      );
      if (!mounted) return;
      AppStateScope.read(context).updateComplaint((draft) {
        draft.status = ComplaintStatus.inProcessing;
        draft.timeline.add(
          TimelineEntry(
            title: 'Marked as In Processing',
            at: DateTime.now(),
            color: complaintStatusColor(ComplaintStatus.inProcessing),
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } on SupervisorException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final complaint = AppStateScope.of(context).complaint;
    final status = complaint.submitted ? complaint.status : ComplaintStatus.none;
    final statusColor = complaintStatusColor(status);
    final actionLabel = switch (complaint.status) {
      ComplaintStatus.resolved => 'Completed',
      ComplaintStatus.inProcessing => 'Add after photos',
      _ => 'Take action',
    };
    return AppPage(
      title: 'Complaint Details',
      bottom: PrimaryButton(
        label: actionLabel,
        loading: _acting,
        onPressed: complaint.issueId == null ||
                complaint.status == ComplaintStatus.resolved ||
                _acting
            ? null
            : () => _takeAction(complaint),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          ModuleHero(
            icon: Icons.report_outlined,
            title: complaint.issueId == null
                ? 'Complaint details'
                : 'Complaint #${complaint.issueId}',
            subtitle: displayOr(complaint.description, 'Open a complaint from the list, or submit a new one.'),
            colors: ModulePalette.complaints,
          ),
          const SizedBox(height: 16),
          if (complaint.issueId == null)
            const InlineMessage(
              tone: InlineTone.warning,
              message: 'Open a complaint from the list, or submit a new one.',
            )
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: ModuleStatusChip(
                label: complaintStatusLabel(status),
                color: statusColor,
              ),
            ),
            const SizedBox(height: 14),
            ModulePanel(
              title: 'Summary',
              accent: ModulePalette.complaintsAccent,
              child: ModuleMetaCard(
                accent: ModulePalette.complaintsAccent,
                rows: [
                  (Icons.tag_outlined, 'ID', complaint.issueId == null ? AppCopy.notAvailable : '${complaint.issueId}'),
                  (Icons.place_outlined, 'Location', displayOr(complaint.sector, AppCopy.locationNotSelected)),
                  (
                    Icons.schedule_outlined,
                    'Submitted',
                    complaint.submittedAt == null
                        ? AppCopy.notAvailable
                        : formatDateTime(complaint.submittedAt!)
                  ),
                  (Icons.flag_outlined, 'Status', complaintStatusLabel(status)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ModulePanel(
              title: 'Description',
              accent: ModulePalette.complaintsAccent,
              child: Text(
                displayOr(complaint.description, 'No description added'),
                style: AppType.body.copyWith(height: 1.45),
              ),
            ),
            if (complaint.followUp.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              ModulePanel(
                title: 'Follow-up note',
                accent: ModulePalette.complaintsAccent,
                child: Text(complaint.followUp, style: AppType.body.copyWith(height: 1.45)),
              ),
            ],
            const SizedBox(height: 14),
            ModulePanel(
              title: 'Before photos',
              accent: ModulePalette.complaintsAccent,
              child: complaint.remoteBefore.isNotEmpty
                  ? _RemotePhotos(paths: complaint.remoteBefore)
                  : _PhotoRow(photos: complaint.photos, emptyLabel: 'No photos added'),
            ),
            const SizedBox(height: 14),
            ModulePanel(
              title: 'After photos',
              accent: ModulePalette.complaintsAccent,
              child: complaint.remoteAfter.isNotEmpty
                  ? _RemotePhotos(paths: complaint.remoteAfter)
                  : _PhotoRow(photos: complaint.afterPhotos, emptyLabel: 'No after photos'),
            ),
            const SizedBox(height: 14),
            ModulePanel(
              title: 'Activity',
              accent: ModulePalette.complaintsAccent,
              child: Timeline(
                emptyLabel: 'No status updates yet',
                events: [
                  for (final event in complaint.timeline)
                    TimelineEvent(
                      title: event.title,
                      timeLabel: formatDateTime(event.at),
                      color: event.color,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.photos, required this.emptyLabel});

  final List<LocalPhoto> photos;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return PhotoCard(index: 0, emptyLabel: emptyLabel);
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => PhotoCard(index: index, photo: photos[index]),
      ),
    );
  }
}

class _RemotePhotos extends StatelessWidget {
  const _RemotePhotos({required this.paths});

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
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              supervisorMediaUrl(paths[index]),
              width: 104,
              height: 112,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 104,
                height: 112,
                child: ColoredBox(color: Color(0xFFEEF3F6)),
              ),
            ),
          );
        },
      ),
    );
  }
}
