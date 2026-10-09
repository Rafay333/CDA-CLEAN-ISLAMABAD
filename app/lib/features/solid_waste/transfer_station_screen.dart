import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_routes.dart';
import '../../state/app_state.dart';
import 'waste_entry_form.dart';

class TransferStationScreen extends StatelessWidget {
  const TransferStationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WasteEntryForm(
      title: 'Transfer Stations',
      kind: WasteKind.transfer,
      submitLabel: 'Save Record',
      onSubmit: () {
        AppStateScope.read(context)
            .updateWaste((draft) => draft.savedAt = DateTime.now());
        context.push(AppRoutes.recordDetails);
      },
    );
  }
}
