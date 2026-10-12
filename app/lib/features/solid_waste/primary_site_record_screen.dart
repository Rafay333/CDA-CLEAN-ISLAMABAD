import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class PrimarySiteRecordScreen extends StatefulWidget {
  const PrimarySiteRecordScreen({super.key});

  @override
  State<PrimarySiteRecordScreen> createState() =>
      _PrimarySiteRecordScreenState();
}

class _PrimarySiteRecordScreenState extends State<PrimarySiteRecordScreen> {
  late final TextEditingController _remarks;
  List<EvidenceActivity> _activities = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _remarks = TextEditingController(
      text: AppStateScope.read(context).waste.remarks,
    );
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
      final rows = await SupervisorApi().activities();
      if (!mounted) return;
      setState(() => _activities = rows);
    } on SupervisorException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  void _add(bool after, LocalPhoto photo) {
    AppStateScope.read(context).updateWaste((draft) {
      final photos = after ? draft.afterPhotos : draft.beforePhotos;
      photos.add(photo);
    });
  }

  void _remove(bool after, String id) {
    AppStateScope.read(context).updateWaste((draft) {
      final photos = after ? draft.afterPhotos : draft.beforePhotos;
      photos.removeWhere((photo) => photo.id == id);
    });
  }

  Future<void> _save() async {
    final current = AppStateScope.read(context).waste;
    final messenger = ScaffoldMessenger.of(context);
    EvidenceActivity? selected;
    for (final item in _activities) {
      if (item.activity == current.containerType) selected = item;
    }
    if (current.kind != WasteKind.transfer && selected == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Select an activity.')));
      return;
    }
    final uploads = uploadPhotos([...current.beforePhotos, ...current.afterPhotos]);
    if (uploads.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Add a photo from the camera or gallery.')));
      return;
    }
    if (uploads.length > 10) {
      messenger.showSnackBar(const SnackBar(content: Text('The server accepts 10 photos at a time.')));
      return;
    }
    final session = AppStateScope.read(context).session;
    if (session == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Sign in again.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await SupervisorApi().uploadEvidence(
        cnic: session.cnic,
        activityCode: selected?.code ?? 'containers',
        photos: uploads,
        geoTag: geoTagFrom(current.latitude, current.longitude) ?? await currentGeoTag(),
      );
      if (!mounted) return;
      AppStateScope.read(context).updateWaste((draft) {
        if (draft.kind == WasteKind.none) draft.kind = WasteKind.primary;
        if (draft.kind == WasteKind.primary) draft.area = 'Rural';
        draft.remarks = _remarks.text.trim();
        draft.savedAt = DateTime.now();
      });
      AppStateScope.read(context).noteWasteSynced();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(saved.message)));
      context.push(AppRoutes.recordDetails);
    } on SupervisorException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final waste = AppStateScope.of(context).waste;
    return AppPage(
      title: 'Photo Evidence',
      bottom: PrimaryButton(
        label: 'Save Record',
        loading: _saving,
        onPressed: _saving ? null : _save,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (waste.kind != WasteKind.transfer) ...[
            Text(
              'Before and after pictures for the selected container.',
              style: AppType.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            DropdownField(
              label: 'Activity',
              hint: 'Select activity',
              items: [for (final item in _activities) item.activity],
              value: _activities.any((item) => item.activity == waste.containerType)
                  ? waste.containerType
                  : null,
              onChanged: (value) {
                AppStateScope.read(context)
                    .updateWaste((draft) => draft.containerType = value);
              },
            ),
            const SizedBox(height: 16),
          ],
          PhotoUploader(
            title: 'Before Photo',
            hint: 'Upload Before Photo',
            photos: waste.beforePhotos,
            onAdd: (photo) => _add(false, photo),
            onRemove: (id) => _remove(false, id),
          ),
          const SizedBox(height: 16),
          PhotoUploader(
            title: 'After Photo',
            hint: 'Upload After Photo',
            photos: waste.afterPhotos,
            onAdd: (photo) => _add(true, photo),
            onRemove: (id) => _remove(true, id),
          ),
          const SizedBox(height: 16),
          TextInput(
            label: 'Remarks',
            controller: _remarks,
            hint: 'Enter remarks...',
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
