import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/display_format.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final wasteSaved = state.waste.savedAt != null;
    final attendanceMarked = state.attendance.mark != AttendanceMark.none;
    final complaint = state.complaint.submitted;
    final hasAny = wasteSaved || attendanceMarked || complaint;

    return AppPage(
      title: 'Reports',
      showBack: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (!hasAny)
            const EmptyState(
              icon: Icons.assessment_outlined,
              title: 'No reports yet',
              message:
                  'Reports will appear here once field records are available.',
            ),
          if (wasteSaved)
            ListItem(
              title: wasteKindLabel(state.waste.kind),
              subtitle: state.waste.savedAt == null
                  ? 'Pending'
                  : formatDateTime(state.waste.savedAt!),
              trailing: const StatusBadge(
                label: 'Pending',
                color: AppColors.warning,
              ),
              onTap: () => context.push(AppRoutes.recordDetails),
            ),
          if (complaint) ...[
            if (wasteSaved) const SizedBox(height: 10),
            ListItem(
              title: 'Complaint',
              subtitle: state.complaint.description.trim().isEmpty
                  ? 'No description added'
                  : state.complaint.description,
              trailing: StatusBadge(
                label: complaintStatusLabel(state.complaint.status),
                color: complaintStatusColor(state.complaint.status),
              ),
              onTap: () => context.push(AppRoutes.complaintDetails),
            ),
          ],
          if (attendanceMarked) ...[
            if (wasteSaved || complaint) const SizedBox(height: 10),
            ListItem(
              title: 'Attendance mark',
              subtitle: state.attendance.markedAt == null
                  ? 'Worker not identified'
                  : 'Worker not identified · ${formatDateTime(state.attendance.markedAt!)}',
              trailing: StatusBadge(
                label: state.attendance.mark == AttendanceMark.checkedIn
                    ? 'Checked in'
                    : 'Checked out',
                color: state.attendance.mark == AttendanceMark.checkedIn
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
