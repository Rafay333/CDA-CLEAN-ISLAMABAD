import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';

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
    setState(() => _saving = true);
    try {
      final message = await SupervisorApi().resolveIssue(
        cnic: session.cnic,
        id: issueId,
        photos: uploads,
        notes: _description.text.trim(),
        resolvedByName: session.fullName,
      );
      if (!mounted) return;
      state.updateComplaint((draft) {
        draft.followUp = _description.text.trim();
        draft.status = ComplaintStatus.resolved;
        draft.timeline.add(
          TimelineEntry(
            title: 'Marked as Completed',
            at: DateTime.now(),
            color: complaintStatusColor(ComplaintStatus.resolved),
          ),
        );
      });
      state.noteComplaintSynced();
      messenger.showSnackBar(SnackBar(content: Text(message)));
      context.pop();
    } on SupervisorException catch (error) {
      if (!mounted) return;
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
      bottom: PrimaryButton(label: 'Submit', loading: _saving, onPressed: _saving ? null : _submit),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const SectionHeader(title: 'Before Photos'),
          const SizedBox(height: 8),
          if (complaint.photos.isEmpty)
            const PhotoCard(index: 0, emptyLabel: 'No before photos')
          else
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: complaint.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) => PhotoCard(index: index),
              ),
            ),
          const SizedBox(height: 16),
          PhotoUploader(
            title: 'After Photos',
            hint: 'Add More Photos',
            photos: complaint.afterPhotos,
            onAdd: _add,
            onRemove: _remove,
          ),
          const SizedBox(height: 16),
          TextInput(
            label: 'Description',
            controller: _description,
            hint: 'Enter description',
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}
