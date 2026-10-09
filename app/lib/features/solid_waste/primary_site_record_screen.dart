import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../state/app_state.dart';

class PrimarySiteRecordScreen extends StatefulWidget {
  const PrimarySiteRecordScreen({super.key});

  @override
  State<PrimarySiteRecordScreen> createState() =>
      _PrimarySiteRecordScreenState();
}

class _PrimarySiteRecordScreenState extends State<PrimarySiteRecordScreen> {
  late final TextEditingController _remarks;

  @override
  void initState() {
    super.initState();
    _remarks = TextEditingController(
      text: AppStateScope.read(context).waste.remarks,
    );
  }

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  void _add(bool after) {
    AppStateScope.read(context).updateWaste((draft) {
      final photos = after ? draft.afterPhotos : draft.beforePhotos;
      photos.add(LocalPhoto(DateTime.now().microsecondsSinceEpoch.toString()));
    });
  }

  void _remove(bool after, String id) {
    AppStateScope.read(context).updateWaste((draft) {
      final photos = after ? draft.afterPhotos : draft.beforePhotos;
      photos.removeWhere((photo) => photo.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final waste = AppStateScope.of(context).waste;
    return AppPage(
      title: 'Photo Evidence',
      bottom: PrimaryButton(
        label: 'Save Record',
        onPressed: () {
          AppStateScope.read(context).updateWaste((draft) {
            if (draft.kind == WasteKind.none) draft.kind = WasteKind.primary;
            draft.remarks = _remarks.text.trim();
            draft.savedAt = DateTime.now();
          });
          context.push(AppRoutes.recordDetails);
        },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          PhotoUploader(
            title: 'Before Photo',
            hint: 'Upload Before Photo',
            photos: waste.beforePhotos,
            onAdd: () => _add(false),
            onRemove: (id) => _remove(false, id),
          ),
          const SizedBox(height: 16),
          PhotoUploader(
            title: 'After Photo',
            hint: 'Upload After Photo',
            photos: waste.afterPhotos,
            onAdd: () => _add(true),
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
