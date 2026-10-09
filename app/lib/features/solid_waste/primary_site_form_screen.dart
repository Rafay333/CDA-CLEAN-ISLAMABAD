import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_routes.dart';
import '../../state/app_state.dart';
import 'waste_entry_form.dart';

class PrimarySiteFormScreen extends StatelessWidget {
  const PrimarySiteFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WasteEntryForm(
      title: 'Primary Sites',
      kind: WasteKind.primary,
      submitLabel: 'Continue',
      onSubmit: () => context.push(AppRoutes.primaryRecord),
    );
  }
}
