import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/pending_resolve_store.dart';
import '../../core/supervisor_api.dart';
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
    final state = AppStateScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _syncing = true);

    var uploaded = 0;
    var failed = 0;
    String? lastError;

    final pending = List<PendingResolve>.from(state.pendingResolves);
    for (final item in pending) {
      try {
        final photos = await item.loadPhotos();
        if (photos.isEmpty) {
          failed++;
          lastError = 'Missing after photos for complaint #${item.issueId}.';
          continue;
        }
        await SupervisorApi().resolveIssue(
          cnic: item.cnic,
          id: item.issueId,
          photos: photos,
          notes: item.notes,
          resolvedByName: item.resolvedByName,
          // Original resolve time — never DateTime.now() at sync.
          resolvedAtIso: item.resolvedAtIso,
        );
        await PendingResolveStore.remove(item.id);
        uploaded++;
      } on SupervisorException catch (error) {
        failed++;
        lastError = error.message;
        if (!error.retry) {
          // Non-retryable (e.g. already resolved): drop so it does not block forever.
          final lower = error.message.toLowerCase();
          if (lower.contains('already') || lower.contains('resolved')) {
            await PendingResolveStore.remove(item.id);
            uploaded++;
            failed--;
          }
        }
      } catch (error) {
        failed++;
        lastError = error.toString();
      }
    }

    await state.refreshPendingResolves();
    if (state.pendingResolveCount == 0) {
      state.noteComplaintSynced();
    }

    if (!mounted) return;
    setState(() => _syncing = false);

    if (uploaded > 0 && failed == 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            uploaded == 1
                ? '1 complaint uploaded with its original resolve time.'
                : '$uploaded complaints uploaded with their original resolve times.',
          ),
        ),
      );
    } else if (uploaded > 0 && failed > 0) {
      messenger.showSnackBar(
        SnackBar(content: Text('Uploaded $uploaded. $failed still pending. ${lastError ?? ''}'.trim())),
      );
    } else if (failed > 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(lastError ?? 'Could not sync. Try again when online.')),
      );
    } else if (state.wastePendingSync) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Complaint queue is empty. Open the waste form and save again to upload it.'),
        ),
      );
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('Nothing to sync.')));
    }
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
      for (final pending in state.pendingResolves)
        _PendingItem(
          title: 'Complaint #${pending.issueId}',
          subtitle: 'Resolved ${formatDateTime(pending.resolvedAt)} · pending upload',
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
                  : '${items.length} record${items.length == 1 ? '' : 's'} on this phone. Sync uploads them with the original resolve time.',
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
