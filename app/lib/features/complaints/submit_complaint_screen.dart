import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';

class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  late final TextEditingController _description;
  late final TextEditingController _sector;
  late final TextEditingController _landmark;
  late final TextEditingController _activity;
  String? _error;
  String? _lat;
  String? _lng;
  bool _locating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController();
    _sector = TextEditingController();
    _landmark = TextEditingController();
    _activity = TextEditingController();
    AppStateScope.read(context).updateComplaint((draft) => draft.reset());
    _locate();
  }

  @override
  void dispose() {
    _description.dispose();
    _sector.dispose();
    _landmark.dispose();
    _activity.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final geo = await currentGeoTag();
    if (!mounted) return;
    String? lat;
    String? lng;
    if (geo != null && geo.contains(',')) {
      final parts = geo.split(',');
      lat = parts[0].trim();
      lng = parts[1].trim();
    }
    setState(() {
      _lat = lat;
      _lng = lng;
      _locating = false;
    });
  }

  void _addPhoto(LocalPhoto photo) {
    AppStateScope.read(context).updateComplaint((draft) {
      if (draft.photos.length >= 10) return;
      draft.photos.add(photo);
    });
  }

  void _removePhoto(String id) {
    AppStateScope.read(context).updateComplaint((draft) {
      draft.photos.removeWhere((photo) => photo.id == id);
    });
  }

  Future<void> _submit() async {
    final description = _description.text.trim();
    if (description.isEmpty) {
      setState(() => _error = 'Enter a description.');
      return;
    }
    final session = AppStateScope.read(context).session;
    if (session == null) {
      setState(() => _error = 'Sign in again.');
      return;
    }
    final photos = uploadPhotos(AppStateScope.read(context).complaint.photos);
    if (photos.length > 10) {
      setState(() => _error = 'Add at most 10 photos.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final message = await SupervisorApi().createComplaint(
        cnic: session.cnic,
        description: description,
        sector: _sector.text,
        landmark: _landmark.text,
        activity: _activity.text,
        latitude: _lat,
        longitude: _lng,
        photos: photos,
      );
      if (!mounted) return;
      AppStateScope.read(context).updateComplaint((draft) {
        draft.description = description;
        draft.sector = _sector.text.trim();
        draft.activity = _activity.text.trim();
        draft.submitted = true;
        draft.submittedAt = DateTime.now();
        draft.status = ComplaintStatus.fresh;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      context.go(AppRoutes.complaintList);
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = AppStateScope.of(context).complaint.photos;
    final location = _lat == null || _lng == null
        ? (_locating ? 'Finding location…' : 'Location not selected. You can still submit.')
        : '$_lat, $_lng';
    return AppPage(
      title: 'Submit Complaint',
      bottom: PrimaryButton(
        label: 'Submit',
        loading: _saving,
        onPressed: _saving ? null : _submit,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          InlineMessage(message: location),
          const SizedBox(height: 14),
          TextInput(
            label: 'Description',
            controller: _description,
            hint: 'Describe the complaint',
            maxLines: 4,
            errorText: _error,
          ),
          const SizedBox(height: 16),
          TextInput(
            label: 'Sector / UC',
            controller: _sector,
            hint: 'Optional',
          ),
          const SizedBox(height: 16),
          TextInput(
            label: 'Landmark',
            controller: _landmark,
            hint: 'Optional',
          ),
          const SizedBox(height: 16),
          TextInput(
            label: 'Activity',
            controller: _activity,
            hint: 'Optional',
          ),
          const SizedBox(height: 16),
          PhotoUploader(
            title: 'Photos',
            hint: 'Add photo',
            photos: photos,
            maxPhotos: 10,
            onAdd: _addPhoto,
            onRemove: _removePhoto,
          ),
        ],
      ),
    );
  }
}
