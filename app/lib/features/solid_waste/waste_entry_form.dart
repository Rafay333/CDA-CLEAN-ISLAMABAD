import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class WasteEntryForm extends StatefulWidget {
  const WasteEntryForm({
    super.key,
    required this.title,
    required this.kind,
    required this.submitLabel,
    required this.onSubmit,
    this.showArea = true,
    this.showUc = true,
    this.showPrimarySite = true,
    this.showBeforePhoto = true,
  });

  final String title;
  final WasteKind kind;
  final String submitLabel;
  final VoidCallback onSubmit;
  final bool showArea;
  final bool showUc;
  final bool showPrimarySite;
  final bool showBeforePhoto;

  @override
  State<WasteEntryForm> createState() => _WasteEntryFormState();
}

class _WasteEntryFormState extends State<WasteEntryForm> {
  late final TextEditingController _vehicleNumber;
  late String _area;

  @override
  void initState() {
    super.initState();
    final waste = AppStateScope.read(context).waste;
    _vehicleNumber = TextEditingController(text: waste.vehicleNumber);
    _area = waste.area;
  }

  @override
  void dispose() {
    _vehicleNumber.dispose();
    super.dispose();
  }

  void _commit() {
    AppStateScope.read(context).updateWaste((draft) {
      draft.kind = widget.kind;
      draft.area = _area;
      draft.vehicleNumber = _vehicleNumber.text.trim();
    });
  }

  Future<void> _locate() async {
    final state = AppStateScope.read(context);
    state.updateWaste((draft) => draft.locating = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    state.updateWaste((draft) => draft.locating = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Live location is not connected yet.')),
    );
  }

  void _addPhoto() {
    AppStateScope.read(context).updateWaste((draft) {
      draft.beforePhotos.add(
        LocalPhoto(DateTime.now().microsecondsSinceEpoch.toString()),
      );
    });
  }

  void _removePhoto(String id) {
    AppStateScope.read(context).updateWaste((draft) {
      draft.beforePhotos.removeWhere((photo) => photo.id == id);
    });
  }

  void _clear() {
    _vehicleNumber.clear();
    setState(() => _area = 'Urban');
    AppStateScope.read(context).updateWaste((draft) => draft.reset());
  }

  @override
  Widget build(BuildContext context) {
    final waste = AppStateScope.of(context).waste;
    return AppPage(
      title: widget.title,
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
      bottom: PrimaryButton(
        label: widget.submitLabel,
        onPressed: () {
          _commit();
          widget.onSubmit();
        },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (widget.showArea) ...[
            SegmentedControl(
              options: const ['Urban', 'Rural'],
              value: _area,
              onChanged: (value) => setState(() => _area = value),
            ),
            const SizedBox(height: 16),
          ],
          const SectionHeader(title: 'Site'),
          const SizedBox(height: 12),
          if (widget.showUc)
            const DropdownField(label: 'UC', hint: 'Select UC', items: []),
          if (widget.showUc) const SizedBox(height: 14),
          if (widget.showPrimarySite)
            const DropdownField(
              label: 'Primary Site',
              hint: 'Select primary site',
              items: [],
            ),
          if (widget.showPrimarySite) const SizedBox(height: 14),
          const DropdownField(
            label: 'Location',
            hint: 'Select location',
            items: [],
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Vehicle'),
          const SizedBox(height: 12),
          const DropdownField(
            label: 'Vehicle Type',
            hint: 'Select vehicle type',
            items: [],
          ),
          const SizedBox(height: 14),
          TextInput(
            label: 'Vehicle Number',
            controller: _vehicleNumber,
            hint: 'Enter vehicle number',
          ),
          const SizedBox(height: 18),
          LocationCard(
            latitude: waste.latitude,
            longitude: waste.longitude,
            loading: waste.locating,
            onGetLocation: _locate,
          ),
          if (widget.showBeforePhoto) ...[
            const SizedBox(height: 18),
            PhotoUploader(
              title: 'Before Photo',
              hint: 'Upload Before Photo',
              photos: waste.beforePhotos,
              onAdd: _addPhoto,
              onRemove: _removePhoto,
            ),
          ],
        ],
      ),
    );
  }
}
