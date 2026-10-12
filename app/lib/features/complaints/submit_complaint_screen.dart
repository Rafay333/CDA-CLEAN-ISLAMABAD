import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_copy.dart';
import '../../constants/app_routes.dart';
import '../../state/app_state.dart';

class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  late final TextEditingController _description;
  String? _error;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  void _addPhoto(LocalPhoto photo) {
    AppStateScope.read(context).updateComplaint((draft) {
      draft.photos.add(photo);
    });
  }

  void _removePhoto(String id) {
    AppStateScope.read(context).updateComplaint((draft) {
      draft.photos.removeWhere((photo) => photo.id == id);
    });
  }

  void _submit() {
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New complaints are opened by the citizen app. Resolve an open complaint from the map.'),
      ),
    );
    context.go(AppRoutes.complaintMap);
  }

  @override
  Widget build(BuildContext context) {
    final photos = AppStateScope.of(context).complaint.photos;
    return AppPage(
      title: 'Submit Complaint',
      bottom: PrimaryButton(label: 'Submit', onPressed: _submit),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const InlineMessage(
            message:
                'Location not selected. Live location is not connected yet.',
          ),
          const SizedBox(height: 14),
          TextInput(
            label: 'Description',
            controller: _description,
            hint: 'Describe the complaint',
            maxLines: 4,
            errorText: _error,
          ),
          const SizedBox(height: 16),
          PhotoUploader(
            title: 'Photos',
            hint: 'Add photo',
            photos: photos,
            onAdd: _addPhoto,
            onRemove: _removePhoto,
          ),
          const SizedBox(height: 8),
          Text(
            AppCopy.locationNotSelected,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
