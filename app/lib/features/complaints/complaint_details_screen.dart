import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_copy.dart';
import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../utils/display_format.dart';

class ComplaintDetailsScreen extends StatelessWidget {
  const ComplaintDetailsScreen({super.key});

  void _takeAction(BuildContext context, ComplaintDraft complaint) {
    if (complaint.issueId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open a complaint from the list first.')),
      );
      return;
    }
    if (complaint.status == ComplaintStatus.resolved) return;
    context.push(AppRoutes.afterPhotos);
  }

  @override
  Widget build(BuildContext context) {
    final complaint = AppStateScope.of(context).complaint;
    final actionLabel = complaint.status == ComplaintStatus.resolved
        ? 'Completed'
        : 'Add after photos';
    return AppPage(
      title: 'Complaint Details',
      bottom: PrimaryButton(
        label: actionLabel,
        onPressed: complaint.issueId == null || complaint.status == ComplaintStatus.resolved
            ? null
            : () => _takeAction(context, complaint),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (complaint.issueId == null)
            const InlineMessage(
              tone: InlineTone.warning,
              message: 'Open a complaint from the list. New complaints are created by the citizen app.',
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
          InfoCard(
            label: 'Complaint ID',
            value: complaint.issueId == null ? AppCopy.notAvailable : '${complaint.issueId}',
          ),
          const SizedBox(height: 8),
          InfoCard(
            label: 'Location',
            value: displayOr(complaint.sector, AppCopy.locationNotSelected),
          ),
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
          if (complaint.remoteBefore.isNotEmpty)
            _RemotePhotos(paths: complaint.remoteBefore)
          else
            _PhotoRow(photos: complaint.photos, emptyLabel: 'No photos added'),
          const SizedBox(height: 16),
          const SectionHeader(title: 'After Photos'),
          const SizedBox(height: 8),
          if (complaint.remoteAfter.isNotEmpty)
            _RemotePhotos(paths: complaint.remoteAfter)
          else
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
            borderRadius: BorderRadius.circular(12),
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
