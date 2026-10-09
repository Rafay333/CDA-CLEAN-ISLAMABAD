import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

class ComplaintMapScreen extends StatefulWidget {
  const ComplaintMapScreen({super.key});

  @override
  State<ComplaintMapScreen> createState() => _ComplaintMapScreenState();
}

class _ComplaintMapScreenState extends State<ComplaintMapScreen> {
  final _search = TextEditingController();
  String _status = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final complaint = AppStateScope.of(context).complaint;
    return AppPage(
      title: 'Complaints Map',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          SearchBarField(
            controller: _search,
            hint: 'Search complaints',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          FilterChips(
            options: const ['All', 'New', 'In Processing', 'Resolved'],
            selected: _status,
            onSelected: (value) => setState(() => _status = value),
          ),
          const SizedBox(height: 14),
          MapContainer(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: EmptyState(
                icon: Icons.map_outlined,
                title: 'No complaints found',
                message: 'The map is ready for locations. Pins will appear once complaints are connected.',
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              StatusBadge(label: 'New', color: AppColors.info),
              StatusBadge(label: 'In Processing', color: AppColors.warning),
              StatusBadge(label: 'Resolved', color: AppColors.success),
            ],
          ),
          const SizedBox(height: 16),
          const InlineMessage(
            message: 'Map markers are not shown yet. You can still open the complaint details layout.',
          ),
          if (complaint.submitted) ...[
            const SizedBox(height: 12),
            ListItem(
              title: 'Complaint from this session',
              subtitle: complaint.description.trim().isEmpty
                  ? 'No description added'
                  : complaint.description,
              trailing: StatusBadge(
                label: complaintStatusLabel(complaint.status),
                color: complaintStatusColor(complaint.status),
              ),
              onTap: () => context.push(AppRoutes.complaintDetails),
            ),
          ],
          const SizedBox(height: 16),
          OutlineButton(
            label: 'Open complaint details',
            onPressed: () => context.push(AppRoutes.complaintDetails),
          ),
        ],
      ),
    );
  }
}
