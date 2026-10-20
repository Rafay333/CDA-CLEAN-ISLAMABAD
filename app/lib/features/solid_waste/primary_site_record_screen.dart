import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import 'waste_catalog.dart';
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
  List<String> _activities = const [];
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
    final cnic = AppStateScope.read(context).session?.cnic;
    try {
      await WasteCatalog.ensureLoaded(cnic: cnic);
      if (!mounted) return;
      setState(() {
        _activities = [
          ...WasteCatalog.containerTypes,
          for (final item in WasteCatalog.activities) item.name,
        ];
      });
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
    if (current.kind != WasteKind.transfer && (current.containerType == null || current.containerType!.isEmpty)) {
      messenger.showSnackBar(const SnackBar(content: Text('Select an activity.')));
      return;
    }
    if (uploadPhotos([...current.beforePhotos, ...current.afterPhotos]).isEmpty && current.recordId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Add a photo from the camera or gallery.')));
      return;
    }
    final session = AppStateScope.read(context).session;
    if (session == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Sign in again.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final SavedFieldRecord saved;
      if (current.recordId != null && current.afterPhotos.isNotEmpty) {
        saved = await SupervisorApi().patchFieldRecord(
          cnic: session.cnic,
          id: current.recordId!,
          after: uploadPhotos(current.afterPhotos),
          remarks: _remarks.text.trim(),
        );
      } else {
        saved = await SupervisorApi().saveFieldRecord(
          cnic: session.cnic,
          kind: current.kind == WasteKind.transfer ? 'transfer' : 'primary',
          area: 'Rural',
          ucCode: current.uc,
          primarySiteId: current.primarySiteId,
          locationId: current.locationId,
          vehicleType: current.vehicleType,
          vehicleNumber: current.vehicleNumber,
          containerActivity: current.containerType,
          latitude: current.latitude,
          longitude: current.longitude,
          remarks: _remarks.text.trim(),
          before: uploadPhotos(current.beforePhotos),
          after: uploadPhotos(current.afterPhotos),
        );
      }
      if (!mounted) return;
      AppStateScope.read(context).updateWaste((draft) {
        if (draft.kind == WasteKind.none) draft.kind = WasteKind.primary;
        if (draft.kind == WasteKind.primary) draft.area = 'Rural';
        draft.remarks = _remarks.text.trim();
        draft.recordId = saved.id;
        draft.savedAt = DateTime.now();
      });
      AppStateScope.read(context).noteWasteSynced();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(saved.message ?? 'Record saved.')));
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
              items: _activities,
              value: _activities.contains(waste.containerType) ? waste.containerType : null,
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
