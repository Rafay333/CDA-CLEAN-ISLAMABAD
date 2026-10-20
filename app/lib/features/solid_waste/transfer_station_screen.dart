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
            const SnackBar(content: Text('Add a photo.')),
          );
          return;
        }
        final session = state.session;
        if (session == null) {
          messenger.showSnackBar(const SnackBar(content: Text('Sign in again.')));
          return;
        }
        try {
          final saved = await SupervisorApi().saveFieldRecord(
            cnic: session.cnic,
            kind: 'transfer',
            area: 'Rural',
            ucCode: draft.uc,
            primarySiteId: draft.primarySiteId,
            locationId: draft.locationId,
            vehicleType: draft.vehicleType,
            vehicleNumber: draft.vehicleNumber,
            mode: draft.zeroWaste ? 'zero_waste' : 'vehicle_trips',
            tcpName: draft.tcpName,
            latitude: draft.latitude,
            longitude: draft.longitude,
            before: uploadPhotos(draft.beforePhotos),
            after: uploadPhotos(draft.afterPhotos),
          );
          if (!context.mounted) return;
          state.updateWaste((item) {
            item.savedAt = DateTime.now();
            item.recordId = saved.id;
          });
          state.noteWasteSynced();
          messenger.showSnackBar(SnackBar(content: Text(saved.message ?? 'Record saved.')));
          context.push(AppRoutes.recordDetails);
        } on SupervisorException catch (error) {
          messenger.showSnackBar(SnackBar(content: Text(error.message)));
        }
      },
    );
  }
}
