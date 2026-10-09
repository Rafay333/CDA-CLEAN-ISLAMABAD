import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_copy.dart';
import '../../constants/app_routes.dart';
import '../../state/app_state.dart';
import '../../utils/display_format.dart';

class ComplaintDetailsScreen extends StatelessWidget {
  const ComplaintDetailsScreen({super.key});

  Future<void> _takeAction(
    BuildContext context,
    ComplaintDraft complaint,
  ) async {
    if (!complaint.submitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Submit a complaint before taking action.'),
        ),
      );
      return;
    }
    final next = complaint.status == ComplaintStatus.inProcessing
        ? ComplaintStatus.resolved
        : ComplaintStatus.inProcessing;
    final title = next == ComplaintStatus.resolved
        ? 'Mark complaint as Resolved?'
        : 'Mark complaint as In Processing?';
    final confirmed = await ConfirmationSheet.show(
      context,
      title: title,
      message: 'Once confirmed, the complaint status will be updated.',
    );
    if (!confirmed || !context.mounted) return;
    AppStateScope.read(context).updateComplaint((draft) {
      draft.status = next;
      draft.timeline.add(
        TimelineEntry(
          title: next == ComplaintStatus.resolved
              ? 'Marked as Resolved'
              : 'Marked as In Processing',
          at: DateTime.now(),
          color: complaintStatusColor(next),
        ),
      );
    });
    if (next == ComplaintStatus.inProcessing && context.mounted) {
      context.push(AppRoutes.afterPhotos);
    }
  }

  @override
  Widget build(BuildContext context) {
    final complaint = AppStateScope.of(context).complaint;
    final actionLabel = complaint.status == ComplaintStatus.inProcessing
        ? 'Mark as Resolved'
        : 'Take Action';
    return AppPage(
      title: 'Complaint Details',
      bottom: PrimaryButton(
        label: actionLabel,
        onPressed: complaint.submitted
            ? () => _takeAction(context, complaint)
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (!complaint.submitted)
            const InlineMessage(
              tone: InlineTone.warning,
              message: 'No complaint is open. Submit one to update its status on this device.',
            ),
          if (!complaint.submitted) const SizedBox(height: 12),
          Row(
            children: [
              StatusBadge(
                label: complaintStatusLabel(
                  complaint.submitted ? complaint.status : ComplaintStatus.none,
                ),
                color: complaintStatusColor(
                  complaint.submitted ? complaint.status : ComplaintStatus.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const InfoCard(label: 'Complaint ID', value: AppCopy.notAvailable),
          const SizedBox(height: 8),
          const InfoCard(label: 'Location', value: AppCopy.locationNotSelected),
          const SizedBox(height: 8),
          InfoCard(
            label: 'Submitted On',
            value: complaint.submittedAt == null
                ? AppCopy.notAvailable
                : formatDateTime(complaint.submittedAt!),
          ),
          const SizedBox(height: 8),
          InfoCard(
            label: 'Status',
            value: complaintStatusLabel(
              complaint.submitted ? complaint.status : ComplaintStatus.none,
            ),
          ),
          const SizedBox(height: 8),
          InfoCard(
            label: 'Description',
            value: displayOr(complaint.description, 'No description added'),
          ),
          if (complaint.followUp.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            InfoCard(label: 'Follow-up note', value: complaint.followUp),
          ],
          const SizedBox(height: 18),
          const SectionHeader(title: 'Photos'),
          const SizedBox(height: 8),
          _PhotoRow(photos: complaint.photos, emptyLabel: 'No photos added'),
          const SizedBox(height: 16),
          const SectionHeader(title: 'After Photos'),
          const SizedBox(height: 8),
          _PhotoRow(
            photos: complaint.afterPhotos,
            emptyLabel: 'No after photos',
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Activity'),
          const SizedBox(height: 10),
          Timeline(
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
        itemBuilder: (context, index) => PhotoCard(index: index),
      ),
    );
  }
}
