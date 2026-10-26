import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'waste_catalog.dart';

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
    this.ruralOnly = false,
    this.modes = const [],
  });

  final String title;
  final WasteKind kind;
  final String submitLabel;
  final Future<void> Function() onSubmit;
  final bool showArea;
  final bool showUc;
  final bool showPrimarySite;
  final bool showBeforePhoto;
  final bool ruralOnly;
  final List<String> modes;

  @override
  State<WasteEntryForm> createState() => _WasteEntryFormState();
}

class _WasteEntryFormState extends State<WasteEntryForm> {
  late final TextEditingController _vehicleNumber;
  late String _area;
  String? _mode;
  String? _tcp;
  bool _saving = false;
  final List<LocalPhoto> _zeroBefore = [];
  final List<LocalPhoto> _zeroAfter = [];

  bool get _zeroWaste => _mode == 'Zero Waste';

  @override
  void initState() {
    super.initState();
    final waste = AppStateScope.read(context).waste;
    _vehicleNumber = TextEditingController(text: waste.vehicleNumber);
    _area = widget.ruralOnly ? 'Rural' : waste.area;
    if (widget.modes.isNotEmpty) _mode = widget.modes.first;
    final cnic = AppStateScope.read(context).session?.cnic;
    WasteCatalog.ensureLoaded(cnic: cnic).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _vehicleNumber.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _commit() {
    final state = AppStateScope.read(context);
    if (_zeroWaste) {
      state.updateWaste((draft) {
        draft.kind = widget.kind;
        draft.area = 'Rural';
        draft.zeroWaste = true;
        draft.tcpName = _tcp;
        draft.activity = null;
        draft.beforePhotos
          ..clear()
          ..addAll(_zeroBefore);
        draft.afterPhotos
          ..clear()
          ..addAll(_zeroAfter);
      });
      return;
    }

    state.updateWaste((draft) {
      draft.kind = widget.kind;
      draft.area = _area;
      draft.vehicleNumber = _vehicleNumber.text.trim();
      draft.zeroWaste = false;
      draft.tcpName = null;
    });
  }

  bool _ready() {
    if (_zeroWaste && (_tcp == null || _tcp!.trim().isEmpty)) {
      _snack('Select the name of the TCP.');
      return false;
    }
    return true;
  }

  Future<void> _locate() async {
    final state = AppStateScope.read(context);
    state.updateWaste((draft) => draft.locating = true);
    try {
      final geo = await currentGeoTag();
      if (!mounted) return;
      if (geo == null) {
        state.updateWaste((draft) => draft.locating = false);
        _snack('Enable live location, then try again.');
        return;
      }
      final parts = geo.split(',');
      state.updateWaste((draft) {
        draft.locating = false;
        draft.latitude = parts.first;
        draft.longitude = parts.length > 1 ? parts[1] : null;
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      state.updateWaste((draft) => draft.locating = false);
      _snack(error.message);
    }
  }

  void _addPhoto(LocalPhoto photo) {
    AppStateScope.read(context).updateWaste((draft) {
      draft.beforePhotos.add(photo);
    });
  }

  void _removePhoto(String id) {
    AppStateScope.read(context).updateWaste((draft) {
      draft.beforePhotos.removeWhere((photo) => photo.id == id);
    });
  }

  void _clear() {
    _vehicleNumber.clear();
    setState(() {
      _area = widget.ruralOnly ? 'Rural' : 'Urban';
      _tcp = null;
      _zeroBefore.clear();
      _zeroAfter.clear();
      if (widget.modes.isNotEmpty) _mode = widget.modes.first;
    });
    AppStateScope.read(context).updateWaste((draft) {
      draft.reset();
      if (widget.ruralOnly) draft.area = 'Rural';
    });
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
        loading: _saving,
        onPressed: _saving
            ? null
            : () async {
                if (!_ready()) return;
                _commit();
                setState(() => _saving = true);
                try {
                  await widget.onSubmit();
                } finally {
                  if (mounted) setState(() => _saving = false);
                }
              },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (widget.modes.isNotEmpty) ...[
            Text('Type', style: AppType.label),
            const SizedBox(height: 8),
            SegmentedControl(
              options: widget.modes,
              value: _mode ?? widget.modes.first,
              onChanged: (value) => setState(() => _mode = value),
            ),
            const SizedBox(height: 16),
          ],
          if (_zeroWaste) ...[
            Text(
              'Before and after pictures for the selected TCP.',
              style: AppType.body.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            DropdownField(
              label: 'Name of TCP',
              hint: 'Select TCP',
              items: WasteCatalog.tcpNames,
              value: _tcp,
              onChanged: (value) => setState(() => _tcp = value),
            ),
            const SizedBox(height: 16),
            PhotoUploader(
              title: 'Before Photo',
              hint: 'Upload Before Photo',
              photos: _zeroBefore,
              onAdd: (photo) => setState(() => _zeroBefore.add(photo)),
              onRemove: (id) {
                setState(
                  () => _zeroBefore.removeWhere((photo) => photo.id == id),
                );
              },
            ),
            const SizedBox(height: 16),
            PhotoUploader(
              title: 'After Photo',
              hint: 'Upload After Photo',
              photos: _zeroAfter,
              onAdd: (photo) => setState(() => _zeroAfter.add(photo)),
              onRemove: (id) {
                setState(
                  () => _zeroAfter.removeWhere((photo) => photo.id == id),
                );
              },
            ),
          ] else ...[
            if (widget.showArea && widget.ruralOnly) ...[
              Text('Area', style: AppType.label),
              const SizedBox(height: 8),
              IgnorePointer(
                child: SegmentedControl(
                  options: const ['Rural'],
                  value: 'Rural',
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(height: 16),
            ] else if (widget.showArea) ...[
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
              DropdownField(
                label: 'UC',
                hint: 'Select UC',
                items: WasteCatalog.allUcs,
                value: waste.uc,
                onChanged: (value) {
                  AppStateScope.read(context).updateWaste((draft) {
                    draft.uc = value;
                    draft.primarySite = null;
                    draft.primarySiteId = null;
                    draft.location = null;
                    draft.locationId = null;
                  });
                },
              ),
            if (widget.showUc) const SizedBox(height: 14),
            if (widget.showPrimarySite)
              DropdownField(
                label: 'Primary Site',
                hint: 'Select primary site',
                items: [for (final site in WasteCatalog.sitesFor(waste.uc)) site.name],
                value: waste.primarySite,
                onChanged: (value) {
                  CatalogSite? selected;
                  for (final site in WasteCatalog.sitesFor(waste.uc)) {
                    if (site.name == value) selected = site;
                  }
                  AppStateScope.read(context).updateWaste((draft) {
                    draft.primarySite = value;
                    draft.primarySiteId = selected?.id;
                  });
                },
              ),
            if (widget.showPrimarySite) const SizedBox(height: 14),
            DropdownField(
              label: 'Location',
              hint: 'Select location',
              items: [for (final place in WasteCatalog.locationsFor(waste.uc)) place.name],
              value: waste.location,
              onChanged: (value) {
                CatalogLocation? selected;
                for (final place in WasteCatalog.locationsFor(waste.uc)) {
                  if (place.name == value) selected = place;
                }
                AppStateScope.read(context).updateWaste((draft) {
                  draft.location = value;
                  draft.locationId = selected?.id;
                });
              },
            ),
            const SizedBox(height: 18),
            const SectionHeader(title: 'Vehicle'),
            const SizedBox(height: 12),
            DropdownField(
              label: 'Vehicle Type',
              hint: 'Select vehicle type',
              items: WasteCatalog.vehicleTypes,
              value: waste.vehicleType,
              onChanged: (value) {
                AppStateScope.read(context).updateWaste((draft) => draft.vehicleType = value);
              },
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
        ],
      ),
    );
  }
}
