import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import 'waste_catalog.dart';
import 'waste_entry_form.dart';

class TransferStationScreen extends StatelessWidget {
  const TransferStationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WasteEntryForm(
      title: 'Transfer Stations',
      kind: WasteKind.transfer,
      submitLabel: 'Save Record',
      ruralOnly: true,
      modes: WasteCatalog.transferModes,
      onSubmit: () async {
        final state = AppStateScope.read(context);
        final draft = state.waste;
        final uploads = uploadPhotos([...draft.beforePhotos, ...draft.afterPhotos]);
        final messenger = ScaffoldMessenger.of(context);
        if (uploads.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Add a photo. Transfer station pictures are saved as TCP evidence.')),
          );
          return;
        }
        if (uploads.length > 10) {
          messenger.showSnackBar(const SnackBar(content: Text('The server accepts 10 photos at a time.')));
          return;
        }
        final session = state.session;
        if (session == null) {
          messenger.showSnackBar(const SnackBar(content: Text('Sign in again.')));
          return;
        }
        try {
          final saved = await SupervisorApi().uploadEvidence(
            cnic: session.cnic,
            activityCode: 'tcp',
            photos: uploads,
            geoTag: geoTagFrom(draft.latitude, draft.longitude) ?? await currentGeoTag(),
          );
          if (!context.mounted) return;
          state.updateWaste((item) => item.savedAt = DateTime.now());
          state.noteWasteSynced();
          messenger.showSnackBar(SnackBar(content: Text(saved.message)));
          context.push(AppRoutes.recordDetails);
        } on SupervisorException catch (error) {
          messenger.showSnackBar(SnackBar(content: Text(error.message)));
        }
      },
    );
  }
}
