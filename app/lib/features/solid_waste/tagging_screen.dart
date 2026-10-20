import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'waste_catalog.dart';

class TaggingScreen extends StatefulWidget {
  const TaggingScreen({super.key});

  @override
  State<TaggingScreen> createState() => _TaggingScreenState();
}

class _TaggingScreenState extends State<TaggingScreen> {
  String? _tagging = WasteCatalog.containerTagging;
  String? _containerType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final cnic = AppStateScope.read(context).session?.cnic;
    WasteCatalog.ensureLoaded(cnic: cnic).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _clear() {
    setState(() {
      _tagging = WasteCatalog.containerTagging;
      _containerType = null;
    });
  }

  Future<void> _save() async {
    if (_tagging == null) {
      _snack('Select tagging of containers.');
      return;
    }
    if (_containerType == null) {
      _snack('Select the container type.');
      return;
    }
    final session = AppStateScope.read(context).session;
    if (session == null) {
      _snack('Sign in again.');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await SupervisorApi().saveFieldRecord(
        cnic: session.cnic,
        kind: 'tagging',
        tagging: _tagging,
        containerType: _containerType,
      );
      if (!mounted) return;
      AppStateScope.read(context).updateWaste((draft) {
        draft.reset();
        draft.kind = WasteKind.tagging;
        draft.containerType = _containerType;
        draft.recordId = saved.id;
        draft.savedAt = DateTime.now();
      });
      AppStateScope.read(context).noteWasteSynced();
      if (!mounted) return;
      _snack(saved.message ?? 'Record saved.');
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
      title: 'Tagging',
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
            'Tagging of containers is selected once for this record.',
            style: AppType.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          DropdownField(
            label: 'Tagging',
            hint: 'Select tagging',
            items: const [WasteCatalog.containerTagging],
            value: _tagging,
            onChanged: (value) => setState(() => _tagging = value),
          ),
          const SizedBox(height: 14),
          DropdownField(
            label: 'Container Type',
            hint: 'Select container type',
            items: WasteCatalog.containerTypes,
            value: _containerType,
            onChanged: (value) => setState(() => _containerType = value),
          ),
        ],
      ),
    );
  }
}
