import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/display_format.dart';

Future<void> showSyncSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    builder: (context) => const _SyncSheet(),
  );
}

class _SyncSheet extends StatefulWidget {
  const _SyncSheet();

  @override
  State<_SyncSheet> createState() => _SyncSheetState();
}

class _SyncSheetState extends State<_SyncSheet> {
  bool _syncing = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _syncing = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This copy is only on the phone. Open the form and save it again.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final items = <_PendingItem>[
      if (state.wastePendingSync)
        _PendingItem(
          title: wasteKindLabel(state.waste.kind),
          subtitle: state.waste.savedAt == null
              ? 'Saved on this device'
              : formatDateTime(state.waste.savedAt!),
        ),
      if (state.complaintPendingSync)
        _PendingItem(
          title: 'Complaint',
          subtitle: state.complaint.submittedAt == null
              ? 'Submitted on this device'
              : formatDateTime(state.complaint.submittedAt!),
        ),
    ];

    return SheetScaffold(
      title: 'Sync data',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              items.isEmpty
                  ? 'Saved records are already on the server.'
                  : '${items.length} record${items.length == 1 ? '' : 's'} stayed on this phone. Open the form and save again.',
              style: AppType.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              const EmptyState(
                icon: Icons.cloud_done_outlined,
                title: 'All caught up',
                message: 'New waste and complaint records will show here.',
              )
            else
              for (final item in items) ...[
                ListItem(
                  title: item.title,
                  subtitle: item.subtitle,
                  leading: const Icon(
                    Icons.cloud_upload_outlined,
                    color: AppColors.navy,
                  ),
                  trailing: const StatusBadge(
                    label: 'Pending',
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: 6),
              PrimaryButton(
                label: 'Sync now',
                icon: Icons.sync_rounded,
                loading: _syncing,
                onPressed: _syncing ? null : _sync,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingItem {
  const _PendingItem({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}
