import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class BulkWasteScreen extends StatefulWidget {
  const BulkWasteScreen({super.key});

  @override
  State<BulkWasteScreen> createState() => _BulkWasteScreenState();
}

class _BulkWasteScreenState extends State<BulkWasteScreen> {
  final List<LocalPhoto> _photos = [];
  bool _saving = false;

  void _clear() => setState(_photos.clear);

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final uploads = uploadPhotos(_photos);
    if (uploads.isEmpty) {
      _snack('Add a photo from the camera or gallery.');
      return;
    }
    if (uploads.length > 30) {
      _snack('The server accepts up to 30 bulk photos.');
      return;
    }
    final session = AppStateScope.read(context).session;
    if (session == null) {
      _snack('Sign in again.');
      return;
    }
    setState(() => _saving = true);
    try {
      final geo = await currentGeoTag();
      final saved = await SupervisorApi().saveFieldRecord(
        cnic: session.cnic,
        kind: 'bulk',
        latitude: geo?.split(',').first,
        longitude: geo != null && geo.contains(',') ? geo.split(',')[1] : null,
        bulk: uploads,
      );
      if (!mounted) return;
      AppStateScope.read(context).updateWaste((draft) {
        draft.reset();
        draft.kind = WasteKind.bulk;
        draft.area = 'Rural';
        draft.recordId = saved.id;
        draft.beforePhotos.addAll(_photos);
        draft.savedAt = DateTime.now();
      });
      AppStateScope.read(context).noteWasteSynced();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved.message ?? 'Record saved.')));
      context.push(AppRoutes.recordDetails);
    } on SupervisorException catch (error) {
      if (!mounted) return;
      _snack(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Bulk Waste',
      actions: [
        TextButton(
          onPressed: _clear,
          child: Text(
            'Clear',
            style: AppType.caption.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
      bottom: PrimaryButton(label: 'Save Record', loading: _saving, onPressed: _saving ? null : _save),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Pictorial evidence is general and is not grouped by union council.',
            style: AppType.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          PhotoUploader(
            title: 'Pictorial Evidence',
            hint: 'Upload picture',
            caption: 'Up to 30 photos. They are saved as a bulk field record.',
            maxPhotos: 30,
            photos: _photos,
            onAdd: (photo) => setState(() => _photos.add(photo)),
            onRemove: (id) {
              setState(() => _photos.removeWhere((photo) => photo.id == id));
            },
          ),
        ],
      ),
    );
  }
}
