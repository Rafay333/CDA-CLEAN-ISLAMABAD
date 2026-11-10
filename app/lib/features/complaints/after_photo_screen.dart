import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../core/pending_resolve_store.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../utils/pakistan_time.dart';

class AfterPhotoScreen extends StatefulWidget {
  const AfterPhotoScreen({super.key});

  @override
  State<AfterPhotoScreen> createState() => _AfterPhotoScreenState();
}

class _AfterPhotoScreenState extends State<AfterPhotoScreen> {
  late final TextEditingController _description;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(
      text: AppStateScope.read(context).complaint.followUp,
    );
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  void _add(LocalPhoto photo) {
    AppStateScope.read(context).updateComplaint((draft) {
      draft.afterPhotos.add(photo);
    });
  }

  void _remove(String id) {
    AppStateScope.read(context).updateComplaint((draft) {
      draft.afterPhotos.removeWhere((photo) => photo.id == id);
    });
  }

  void _markResolvedLocally(AppState state, String notes, DateTime resolvedAt) {
    state.updateComplaint((draft) {
      draft.followUp = notes;
      draft.status = ComplaintStatus.resolved;
      draft.timeline.add(
        TimelineEntry(
          title: 'Marked as Completed',
          at: resolvedAt,
          color: complaintStatusColor(ComplaintStatus.resolved),
        ),
      );
    });
  }

  Future<void> _queueOffline({
    required AppState state,
    required int issueId,
    required String cnic,
    required String notes,
    required String resolvedByName,
    required DateTime resolvedAt,
    required String resolvedAtIso,
    required List<UploadPhoto> uploads,
  }) async {
    final bytes = <Uint8List>[
      for (final photo in uploads) photo.bytes,
    ];
    final names = <String?>[
      for (final photo in uploads) photo.filename,
    ];
    await PendingResolveStore.enqueue(
      issueId: issueId,
      cnic: cnic,
      resolvedAtIso: resolvedAtIso,
      photoBytes: bytes,
      photoFilenames: names,
      notes: notes,
      resolvedByName: resolvedByName,
    );
    _markResolvedLocally(state, notes, resolvedAt);
    await state.refreshPendingResolves();
  }

  Future<void> _submit() async {
    final state = AppStateScope.read(context);
    final issueId = state.complaint.issueId;
    final session = state.session;
    final messenger = ScaffoldMessenger.of(context);
    if (session == null || issueId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Open a complaint from the map first.')));
      return;
    }
    final uploads = uploadPhotos(state.complaint.afterPhotos);
    if (uploads.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Add at least one after photo.')));
      return;
    }
    if (uploads.length > 10) {
      messenger.showSnackBar(const SnackBar(content: Text('The server accepts up to 10 after photos.')));
      return;
    }

    final notes = _description.text.trim();
    final resolvedAt = pakistanNow();
    final resolvedAtIso = toPakistanIso(resolvedAt);

    setState(() => _saving = true);
    try {
      final message = await SupervisorApi().resolveIssue(
        cnic: session.cnic,
        id: issueId,
        photos: uploads,
        notes: notes,
        resolvedByName: session.fullName,
        resolvedAtIso: resolvedAtIso,
      );
      if (!mounted) return;
      _markResolvedLocally(state, notes, resolvedAt);
      state.noteComplaintSynced();
      messenger.showSnackBar(SnackBar(content: Text(message)));
      context.pop();
    } on SupervisorException catch (error) {
      if (!mounted) return;
      if (error.retry) {
        try {
          await _queueOffline(
            state: state,
            issueId: issueId,
            cnic: session.cnic,
            notes: notes,
            resolvedByName: session.fullName,
            resolvedAt: resolvedAt,
            resolvedAtIso: resolvedAtIso,
            uploads: uploads,
          );
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Saved on this device. It will upload when Sync data runs online.'),
            ),
          );
          context.pop();
          return;
        } catch (_) {
          messenger.showSnackBar(
            SnackBar(content: Text('${error.message} Could not save offline either.')),
          );
          return;
        }
      }
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final complaint = AppStateScope.of(context).complaint;
    return AppPage(
      title: 'After Photos',
      bottom: PrimaryButton(
        label: 'Mark completed',
        loading: _saving,
        onPressed: _saving ? null : _submit,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          ModuleHero(
            icon: Icons.done_all_rounded,
            title: complaint.issueId == null
                ? 'Complete complaint'
                : 'Complete #${complaint.issueId}',
            subtitle: 'Add after photos and an optional note, then mark the complaint completed.',
            colors: ModulePalette.complaints,
          ),
          const SizedBox(height: 16),
          ModulePanel(
            title: 'Before photos',
            accent: ModulePalette.complaintsAccent,
            child: complaint.photos.isEmpty
                ? const PhotoCard(index: 0, emptyLabel: 'No before photos')
                : SizedBox(
                    height: 112,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: complaint.photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) => PhotoCard(index: index),
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          ModulePanel(
            title: 'After photos',
            subtitle: 'At least one photo is required.',
            accent: ModulePalette.complaintsAccent,
            child: PhotoUploader(
              title: 'After Photos',
              hint: 'Add More Photos',
              photos: complaint.afterPhotos,
              onAdd: _add,
              onRemove: _remove,
            ),
          ),
          const SizedBox(height: 14),
          ModulePanel(
            title: 'Notes',
            accent: ModulePalette.complaintsAccent,
            child: TextInput(
              label: 'Description',
              controller: _description,
              hint: 'Enter description',
              maxLines: 4,
            ),
          ),
        ],
      ),
    );
  }
}
