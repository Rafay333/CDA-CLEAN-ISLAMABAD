import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/gps_photo_stamp.dart';
import 'waste_catalog.dart';

enum _ActivityStep { before, after }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  _ActivityStep _step = _ActivityStep.before;

  String? _activity;
  String? _zone;
  String? _uc;
  TaggingContainer? _container;
  String? _containerType;
  CatalogVehicle? _vehicle;
  String? _vehicleType;
  final List<LocalPhoto> _beforePhotos = [];
  final List<LocalPhoto> _afterPhotos = [];
  String? _lat;
  String? _lng;

  static const _maxBeforePhotos = 2;
  static const _maxAfterPhotos = 2;
  static const _maxPlainPhotos = 2;
  static const _containerActivityCode = 'containers';
  static const _containerActivityName = 'Container Collection/Clearance';
  static const _transferActivityCode = 'tcp';
  static const _transferActivityName = 'Transfer Station Management';
  static const _bulkActivityCode = 'bulk';
  static const _bulkActivityName = 'Bulk Waste Collection';

  /// Inventory sizes only (same as portal / old Activity save). Not Open/Skip.
  static const _inventorySize1_1 = '1.1 m3';
  static const _inventorySize8 = '8 m3';

  late final TextEditingController _remarks;

  List<CatalogActivity> _activities = const [];
  List<String> _zones = const [];
  List<TaggingContainer> _containers = const [];
  List<CatalogVehicle> _vehicles = const [];

  bool _loadingCatalog = true;
  bool _loadingContainers = false;
  bool _loadingVehicles = false;
  bool _resolvingType = false;
  bool _resolvingVehicleType = false;
  bool _locating = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _remarks = TextEditingController();
    _prepare();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_gpsReady) _locate();
    });
  }

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  bool get _gpsReady =>
      (_lat?.trim().isNotEmpty ?? false) && (_lng?.trim().isNotEmpty ?? false);

  bool _matchesActivity(CatalogActivity selected, String code, String name) {
    return selected.code == code || selected.name == name;
  }

  /// Container Collection/Clearance — container + vehicle + before/after.
  bool get _isContainerFlow {
    final selected = _selectedActivity();
    if (selected == null) return false;
    return _matchesActivity(selected, _containerActivityCode, _containerActivityName);
  }

  /// Transfer Station + Bulk Waste — before/after (no container/vehicle).
  bool get _isTransferOrBulkFlow {
    final selected = _selectedActivity();
    if (selected == null) return false;
    return _matchesActivity(selected, _transferActivityCode, _transferActivityName) ||
        _matchesActivity(selected, _bulkActivityCode, _bulkActivityName);
  }

  /// The three activities that keep before + after pictures.
  bool get _isBeforeAfterFlow => _isContainerFlow || _isTransferOrBulkFlow;

  /// All remaining activities — zone, optional UC, GPS, 1–2 photos, remarks.
  bool get _isPhotosOnlyFlow =>
      _selectedActivity() != null && !_isBeforeAfterFlow;

  /// Container flow needs container + vehicle. Others only need a zone (UC optional).
  bool get _detailsReady =>
      _isContainerFlow ? (_container != null && _vehicle != null) : _zone != null;

  Future<void> _prepare() async {
    final session = AppStateScope.read(context).session;
    setState(() {
      _loadingCatalog = true;
      _error = null;
    });
    try {
      await WasteCatalog.ensureLoaded(cnic: session?.cnic, force: true);
      var activities = List<CatalogActivity>.from(WasteCatalog.activities);
      if (activities.isEmpty && session != null) {
        final evidence = await SupervisorApi().activities();
        activities = [
          for (final item in evidence)
            CatalogActivity(code: item.code, name: item.activity, unlimitedPictures: false),
        ];
      }
      if (!mounted) return;
      var vehicles = List<CatalogVehicle>.from(WasteCatalog.vehicles);
      if (vehicles.isEmpty && session != null) {
        try {
          vehicles = await SupervisorApi().vehicles(session.cnic);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _activities = activities;
        _zones = WasteCatalog.zones;
        _vehicles = vehicles;
        _loadingCatalog = false;
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCatalog = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCatalog = false;
        _error = 'Could not load activity catalog.';
      });
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _clear() {
    setState(() {
      _step = _ActivityStep.before;
      _activity = null;
      _zone = null;
      _uc = null;
      _container = null;
      _containerType = null;
      _vehicle = null;
      _vehicleType = null;
      _beforePhotos.clear();
      _afterPhotos.clear();
      _lat = null;
      _lng = null;
      _containers = const [];
      _error = null;
      _remarks.clear();
    });
  }

  CatalogActivity? _selectedActivity() {
    for (final item in _activities) {
      if (item.name == _activity || item.code == _activity) return item;
    }
    return null;
  }

  void _onActivity(String value) {
    setState(() {
      _step = _ActivityStep.before;
      _activity = value;
      _zone = null;
      _uc = null;
      _container = null;
      _containerType = null;
      _vehicle = null;
      _vehicleType = null;
      _beforePhotos.clear();
      _afterPhotos.clear();
      _containers = const [];
      _error = null;
      _remarks.clear();
    });
  }

  Future<void> _onZone(String value) async {
    setState(() {
      _zone = value;
      _uc = null;
      _container = null;
      _containerType = null;
      _vehicle = null;
      _vehicleType = null;
      _beforePhotos.clear();
      _containers = const [];
      _loadingContainers = _isContainerFlow;
      _loadingVehicles = _isContainerFlow;
      _error = null;
    });
    if (!_isContainerFlow) {
      setState(() {
        _loadingContainers = false;
        _loadingVehicles = false;
      });
      return;
    }
    final session = AppStateScope.read(context).session;
    if (session == null) {
      setState(() {
        _loadingContainers = false;
        _loadingVehicles = false;
      });
      _snack('Sign in again.');
      return;
    }
    _loadVehicles(session.cnic, zoneCode: value);
    try {
      final api = SupervisorApi();
      var rows = await api.containers(session.cnic, zoneCode: value);
      // Fallback: aggregate containers from sites if zone endpoint is empty/unavailable.
      if (rows.isEmpty) {
        try {
          final sites = await api.primarySites(session.cnic, zoneCode: value);
          final batches = await Future.wait([
            for (final site in sites) api.containersForPrimarySite(session.cnic, site.id),
          ]);
          final seen = <int>{};
          rows = [
            for (final batch in batches)
              for (final item in batch.items)
                if (seen.add(item.containerId)) item,
          ];
        } catch (_) {}
      }
      rows.sort((a, b) => a.containerName.compareTo(b.containerName));
      if (!mounted) return;
      setState(() {
        _containers = rows;
        _loadingContainers = false;
      });
      if (rows.isEmpty) _snack('No containers found for $value.');
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingContainers = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingContainers = false;
        _error = 'Could not load containers for this zone.';
      });
    }
  }

  Future<void> _loadVehicles(String cnic, {String? zoneCode}) async {
    try {
      var rows = await SupervisorApi().vehicles(cnic, zoneCode: zoneCode);
      if (rows.isEmpty) {
        rows = [
          for (final item in WasteCatalog.vehicles)
            if (zoneCode == null ||
                zoneCode.isEmpty ||
                item.zoneCode == null ||
                item.zoneCode == zoneCode)
              item,
        ];
      }
      rows.sort((a, b) => a.number.compareTo(b.number));
      if (!mounted) return;
      setState(() {
        _vehicles = rows;
        _loadingVehicles = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _vehicles = [
          for (final item in WasteCatalog.vehicles)
            if (zoneCode == null ||
                zoneCode.isEmpty ||
                item.zoneCode == null ||
                item.zoneCode == zoneCode)
              item,
        ];
        _loadingVehicles = false;
      });
    }
  }

  void _onVehicle(String number) {
    CatalogVehicle? selected;
    for (final item in _vehicles) {
      if (item.number == number) selected = item;
    }
    if (selected == null) return;
    final picked = selected;
    setState(() {
      _vehicle = picked;
      _vehicleType = picked.vehicleType;
      _resolvingVehicleType = false;
    });
  }

  Future<void> _onContainer(String name) async {
    TaggingContainer? selected;
    for (final item in _containers) {
      if (item.containerName == name) selected = item;
    }
    if (selected == null) return;
    final picked = selected;
    setState(() {
      _container = picked;
      _containerType = picked.containerType;
      _beforePhotos.clear();
      _resolvingType = picked.containerType == null || picked.containerType!.isEmpty;
    });
    if (!_resolvingType) return;
    final session = AppStateScope.read(context).session;
    if (session == null) {
      setState(() => _resolvingType = false);
      return;
    }
    try {
      final detail = await SupervisorApi().containerDetail(session.cnic, picked.containerId);
      if (!mounted) return;
      setState(() {
        _containerType = detail.containerType ?? _containerType;
        _resolvingType = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _resolvingType = false);
    }
  }

  void _goToAfter() {
    if (!_isBeforeAfterFlow) {
      _submitPhotosOnly();
      return;
    }
    final selected = _selectedActivity();
    if (selected == null) {
      _snack('Select an activity.');
      return;
    }
    if (_zone == null || _zone!.isEmpty) {
      _snack('Select a zone.');
      return;
    }
    if (_isContainerFlow) {
      if (_container == null) {
        _snack('Select a container.');
        return;
      }
      if (_containerType == null || _containerType!.trim().isEmpty) {
        _snack('Container type is missing for this container.');
        return;
      }
      if (_vehicle == null) {
        _snack('Select a vehicle.');
        return;
      }
      if (_vehicleType == null || _vehicleType!.trim().isEmpty) {
        _snack('Vehicle type is missing for this vehicle.');
        return;
      }
    }
    if (!_gpsReady) {
      _snack('Fetch your current GPS location.');
      return;
    }
    if (uploadPhotos(_beforePhotos).isEmpty) {
      _snack('Add at least one before picture.');
      return;
    }
    if (_beforePhotos.length > _maxBeforePhotos) {
      _snack('You can add up to $_maxBeforePhotos before pictures.');
      return;
    }

    _stampBeforeAndContinue();
  }

  Future<void> _stampBeforeAndContinue() async {
    final selected = _selectedActivity();
    final title = selected?.name ?? _container?.containerName ?? 'Activity before';
    final stamped = <LocalPhoto>[];
    for (final photo in _beforePhotos) {
      stamped.add(await _stampPhoto(photo, title));
    }
    if (!mounted) return;
    setState(() {
      _beforePhotos
        ..clear()
        ..addAll(stamped);
      _step = _ActivityStep.after;
      _afterPhotos.clear();
    });
    if (!_gpsReady) _locate();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final geo = await currentGeoTag();
      if (!mounted) return;
      if (geo == null) {
        setState(() => _locating = false);
        _snack('Enable live location, then try again.');
        return;
      }
      final parts = geo.split(',');
      setState(() {
        _locating = false;
        _lat = parts.first.trim();
        _lng = parts.length > 1 ? parts[1].trim() : null;
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() => _locating = false);
      _snack(error.message);
    }
  }

  String _stampedName(String? name, {String fallback = 'photo.jpg'}) {
    final raw = (name ?? fallback).trim();
    final lower = raw.toLowerCase();
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp')) {
      final dot = raw.lastIndexOf('.');
      return '${raw.substring(0, dot)}_gps.png';
    }
    return '${raw}_gps.png';
  }

  Future<LocalPhoto> _stampPhoto(LocalPhoto photo, String title) async {
    if (!_gpsReady || photo.bytes == null || photo.bytes!.isEmpty) return photo;
    final alreadyStamped = (photo.filename ?? '').toLowerCase().contains('_gps.');
    if (alreadyStamped) return photo;
    try {
      final stampedBytes = await stampGpsOnPhoto(
        photo.bytes!,
        latitude: _lat!,
        longitude: _lng!,
        title: title,
      );
      return LocalPhoto(
        photo.id,
        bytes: stampedBytes,
        filename: _stampedName(photo.filename, fallback: 'activity.jpg'),
      );
    } catch (_) {
      return photo;
    }
  }

  Future<void> _onBeforePhoto(LocalPhoto photo) async {
    if (!_gpsReady) {
      _snack('Fetch your current GPS location first.');
      return;
    }
    final max = _isPhotosOnlyFlow ? _maxPlainPhotos : _maxBeforePhotos;
    if (_beforePhotos.length >= max) {
      _snack('You can add up to $max pictures.');
      return;
    }
    final stamped = await _stampPhoto(
      photo,
      _selectedActivity()?.name ?? _container?.containerName ?? 'Activity photo',
    );
    if (!mounted) return;
    setState(() => _beforePhotos.add(stamped));
  }

  Future<void> _onAfterPhoto(LocalPhoto photo) async {
    if (!_gpsReady) {
      _snack('Fetch your current GPS location first.');
      return;
    }
    if (_afterPhotos.length >= _maxAfterPhotos) {
      _snack('You can add up to $_maxAfterPhotos after pictures.');
      return;
    }
    final stamped = await _stampPhoto(
      photo,
      _selectedActivity()?.name ?? _container?.containerName ?? 'Activity after',
    );
    if (!mounted) return;
    setState(() => _afterPhotos.add(stamped));
  }

  Future<void> _submitPhotosOnly() async {
    final selected = _selectedActivity();
    if (selected == null) {
      _snack('Select an activity.');
      return;
    }
    if (_zone == null || _zone!.isEmpty) {
      _snack('Select a zone.');
      return;
    }
    if (!_gpsReady) {
      _snack('Fetch your current GPS location.');
      return;
    }
    if (uploadPhotos(_beforePhotos).isEmpty) {
      _snack('Add at least one picture.');
      return;
    }
    if (_beforePhotos.length > _maxPlainPhotos) {
      _snack('You can add up to $_maxPlainPhotos pictures.');
      return;
    }
    await _saveActivity(
      selected: selected,
      before: _beforePhotos,
      after: const [],
      photosOnly: true,
    );
  }

  Future<void> _submit() async {
    if (_isPhotosOnlyFlow) {
      await _submitPhotosOnly();
      return;
    }
    final selected = _selectedActivity();
    final containerOk = !_isContainerFlow ||
        (_container != null &&
            _vehicle != null &&
            (_containerType?.trim().isNotEmpty ?? false) &&
            (_vehicleType?.trim().isNotEmpty ?? false));
    if (selected == null ||
        _zone == null ||
        _zone!.isEmpty ||
        !containerOk ||
        uploadPhotos(_beforePhotos).isEmpty) {
      _snack('Start again from the activity details.');
      setState(() => _step = _ActivityStep.before);
      return;
    }
    if (!_gpsReady) {
      _snack('Fetch your current GPS location.');
      return;
    }
    if (uploadPhotos(_afterPhotos).isEmpty) {
      _snack('Add at least one after picture.');
      return;
    }
    if (_afterPhotos.length > _maxAfterPhotos) {
      _snack('You can add up to $_maxAfterPhotos after pictures.');
      return;
    }
    await _saveActivity(
      selected: selected,
      before: _beforePhotos,
      after: _afterPhotos,
      photosOnly: false,
    );
  }

  Future<void> _saveActivity({
    required CatalogActivity selected,
    required List<LocalPhoto> before,
    required List<LocalPhoto> after,
    required bool photosOnly,
  }) async {
    final session = AppStateScope.read(context).session;
    if (session == null) {
      _snack('Sign in again.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final stampedBefore = <LocalPhoto>[];
      for (final photo in before) {
        stampedBefore.add(await _stampPhoto(photo, selected.name));
      }
      final stampedAfter = <LocalPhoto>[];
      for (final photo in after) {
        stampedAfter.add(await _stampPhoto(photo, selected.name));
      }
      if (!mounted) return;
      setState(() {
        _beforePhotos
          ..clear()
          ..addAll(stampedBefore);
        _afterPhotos
          ..clear()
          ..addAll(stampedAfter);
      });

      final beforeUploads = uploadPhotos(stampedBefore);
      final afterUploads = uploadPhotos(stampedAfter);
      if (beforeUploads.isEmpty) {
        _snack(photosOnly ? 'Add at least one picture.' : 'Before pictures are required.');
        return;
      }
      if (!photosOnly && afterUploads.isEmpty) {
        _snack('After pictures are required.');
        return;
      }

      final saved = await SupervisorApi().saveFieldRecord(
        cnic: session.cnic,
        kind: 'activity',
        activity: selected.name,
        activityCode: selected.code,
        zoneCode: _zone,
        ucCode: _isContainerFlow
            ? null
            : ((_uc != null && _uc!.isNotEmpty) ? _uc : null),
        containerId: _isContainerFlow ? _container!.containerId : null,
        containerName: _isContainerFlow ? _container!.containerName : null,
        containerType: _isContainerFlow ? _containerType : null,
        vehicleId: _isContainerFlow ? _vehicle!.id : null,
        vehicleNumber: _isContainerFlow ? _vehicle!.number : null,
        vehicleType: _isContainerFlow ? _vehicleType : null,
        latitude: _lat,
        longitude: _lng,
        geoTag: '${_lat!.trim()},${_lng!.trim()}',
        remarks: _remarks.text.trim(),
        verifiedBy: supervisorVerifiedBy(session),
        before: beforeUploads,
        after: afterUploads,
      );

      if (!mounted) return;
      AppStateScope.read(context).updateWaste((draft) {
        draft.reset();
        draft.kind = WasteKind.activity;
        draft.activity = selected.name;
        draft.zone = _zone;
        draft.uc = _isContainerFlow
            ? null
            : ((_uc != null && _uc!.isNotEmpty) ? _uc : null);
        if (_isContainerFlow) {
          draft.containerType = _containerType;
          draft.containerId = _container!.containerId;
          draft.containerName = _container!.containerName;
          draft.vehicleNumber = _vehicle!.number;
          draft.vehicleType = _vehicleType;
        }
        draft.beforePhotos.addAll(stampedBefore);
        draft.afterPhotos.addAll(stampedAfter);
        draft.remarks = _remarks.text.trim();
        draft.latitude = _lat;
        draft.longitude = _lng;
        draft.recordId = saved.id;
        draft.savedAt = DateTime.now();
      });
      AppStateScope.read(context).noteWasteSynced();

      if (!mounted) return;
      _snack(saved.message ?? 'Activity record saved.');
      context.go(AppRoutes.waste);
    } on SupervisorException catch (error) {
      if (!mounted) return;
      final msg = error.message.trim();
      final lower = msg.toLowerCase();
      if (!_isContainerFlow &&
          (lower.contains('container_id') || lower.contains('container is required'))) {
        _snack(
          'Server still requires a container for this activity. '
          'Ask backend to deploy optional UC / no-container for non-container activities.',
        );
      } else {
        _snack(msg.isEmpty ? 'Could not save activity.' : msg);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isBeforeAfterFlow && _step == _ActivityStep.after) {
      return _buildAfterStep();
    }
    return _buildBeforeStep();
  }

  Widget _buildBeforeStep() {
    final typeValue = (_containerType == null || _containerType!.isEmpty)
        ? (_resolvingType ? 'Fetching…' : '—')
        : _containerType!;
    final vehicleTypeValue = (_vehicleType == null || _vehicleType!.isEmpty)
        ? (_resolvingVehicleType ? 'Fetching…' : '—')
        : _vehicleType!;
    final photosOnly = _isPhotosOnlyFlow;
    final heroSubtitle = _isContainerFlow
        ? 'Container activity: zone, container, vehicle, GPS and before photos.'
        : (_isTransferOrBulkFlow
            ? 'Select activity and zone (UC optional), then capture GPS-stamped before photos.'
            : 'Zone, optional UC, live GPS, 1–2 photos and remarks.');

    return AppPage(
      title: 'Activity',
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
        label: photosOnly ? 'Submit' : 'Save & continue',
        loading: photosOnly && _submitting,
        onPressed: _loadingCatalog || (photosOnly && _submitting) ? null : _goToAfter,
      ),
      body: _loadingCatalog
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: LoadingSkeletonGroup(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _HeroCard(
                  title: 'Activity record',
                  subtitle: heroSubtitle,
                  icon: Icons.assignment_outlined,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  InlineMessage(tone: InlineTone.error, message: _error!),
                ],
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Details',
                  subtitle: _isContainerFlow
                      ? 'Container type and vehicle type fill automatically from your selection.'
                      : 'Pick a zone. Union council is optional.',
                  child: Column(
                    children: [
                      DropdownField(
                        label: 'Activity',
                        hint: 'Select activity',
                        items: [for (final item in _activities) item.name],
                        value: _activity,
                        onChanged: _onActivity,
                      ),
                      const SizedBox(height: 14),
                      DropdownField(
                        label: 'Zone',
                        hint: 'Select zone',
                        items: _zones,
                        value: _zone,
                        onChanged: _onZone,
                      ),
                      if (_isContainerFlow) ...[
                        const SizedBox(height: 14),
                        if (_loadingContainers)
                          const _InlineLoader(label: 'Loading containers…')
                        else
                          DropdownField(
                            label: 'Container',
                            hint: _zone == null
                                ? 'Select zone first'
                                : (_containers.isEmpty
                                    ? 'No containers in this zone'
                                    : 'Select container'),
                            items: [for (final item in _containers) item.containerName],
                            value: _container?.containerName,
                            enabled: _zone != null && _containers.isNotEmpty,
                            onChanged: _onContainer,
                          ),
                        const SizedBox(height: 14),
                        InfoCard(
                          label: 'Container type',
                          value: typeValue,
                          icon: Icons.category_outlined,
                        ),
                        const SizedBox(height: 14),
                        if (_loadingVehicles)
                          const _InlineLoader(label: 'Loading vehicles…')
                        else
                          DropdownField(
                            label: 'Vehicle',
                            hint: _vehicles.isEmpty ? 'No vehicles available' : 'Select vehicle',
                            items: [for (final item in _vehicles) item.number],
                            value: _vehicle?.number,
                            enabled: _vehicles.isNotEmpty,
                            onChanged: _onVehicle,
                          ),
                        const SizedBox(height: 14),
                        InfoCard(
                          label: 'Vehicle type',
                          value: vehicleTypeValue,
                          icon: Icons.local_shipping_outlined,
                        ),
                      ] else ...[
                        const SizedBox(height: 14),
                        DropdownField(
                          label: 'UC (optional)',
                          hint: _zone == null
                              ? 'Select zone first'
                              : (WasteCatalog.ucsFor(_zone).isEmpty
                                  ? 'No UCs in this zone'
                                  : 'Select UC (optional)'),
                          items: [
                            for (final code in WasteCatalog.ucsFor(_zone))
                              WasteCatalog.ucLabelForCode(code) ?? code,
                          ],
                          value: _uc == null ? null : (WasteCatalog.ucLabelForCode(_uc) ?? _uc),
                          enabled: _zone != null && WasteCatalog.ucsFor(_zone).isNotEmpty,
                          onChanged: (label) {
                            setState(() {
                              _uc = WasteCatalog.ucCodeForLabel(label) ?? label;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Live location',
                  subtitle: photosOnly
                      ? 'GPS is stamped on each picture.'
                      : 'GPS is stamped on the before picture (same as after).',
                  child: LocationCard(
                    latitude: _lat,
                    longitude: _lng,
                    loading: _locating,
                    onGetLocation: _locate,
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: photosOnly ? 'Pictures' : 'Before pictures',
                  subtitle: photosOnly
                      ? 'At least 1, up to $_maxPlainPhotos GPS-stamped photos.'
                      : 'Up to $_maxBeforePhotos GPS-stamped photos before the activity.',
                  child: Opacity(
                    opacity: !_detailsReady || !_gpsReady ? 0.55 : 1,
                    child: IgnorePointer(
                      ignoring: !_detailsReady || !_gpsReady,
                      child: PhotoUploader(
                        title: photosOnly ? 'Photos' : 'Before',
                        hint: photosOnly ? 'Take photo' : 'Take before photo',
                        caption: !_detailsReady
                            ? (_isContainerFlow
                                ? 'Select container and vehicle first.'
                                : 'Select a zone first.')
                            : (_gpsReady
                                ? (photosOnly
                                    ? 'Up to $_maxPlainPhotos photos. Each is stamped with lat/long.'
                                    : 'Up to $_maxBeforePhotos photos. Each is stamped with lat/long.')
                                : 'Fetch GPS first, then add pictures.'),
                        maxPhotos: photosOnly ? _maxPlainPhotos : _maxBeforePhotos,
                        photos: _beforePhotos,
                        onAdd: _onBeforePhoto,
                        onRemove: (id) => setState(
                          () => _beforePhotos.removeWhere((photo) => photo.id == id),
                        ),
                      ),
                    ),
                  ),
                ),
                if (photosOnly) ...[
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Remarks',
                    subtitle: 'Optional notes for this activity.',
                    child: TextInput(
                      label: 'Remarks',
                      controller: _remarks,
                      hint: 'Add remarks',
                      maxLines: 4,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildAfterStep() {
    return AppPage(
      title: 'After picture',
      actions: [
        TextButton(
          onPressed: () => setState(() => _step = _ActivityStep.before),
          child: Text(
            'Back',
            style: AppType.caption.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
      bottom: PrimaryButton(
        label: 'Submit',
        loading: _submitting,
        onPressed: _submitting ? null : _submit,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          const _HeroCard(
            title: 'Finish the record',
            subtitle: 'Add the after picture, remarks and live location, then submit.',
            icon: Icons.done_all_rounded,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Summary',
            subtitle: 'From the previous step.',
            child: Column(
              children: [
                InfoCard(
                  label: 'Activity',
                  value: _activity ?? '—',
                  icon: Icons.assignment_outlined,
                ),
                const SizedBox(height: 10),
                InfoCard(
                  label: 'Zone',
                  value: _zone ?? '—',
                  icon: Icons.map_outlined,
                ),
                if (_isContainerFlow) ...[
                  const SizedBox(height: 10),
                  InfoCard(
                    label: 'Container',
                    value: _container?.containerName ?? '—',
                    icon: Icons.delete_outline_rounded,
                  ),
                  if (_containerType != null && _containerType!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    InfoCard(
                      label: 'Container type',
                      value: _containerType!,
                      icon: Icons.category_outlined,
                    ),
                  ],
                  const SizedBox(height: 10),
                  InfoCard(
                    label: 'Vehicle',
                    value: _vehicle?.number ?? '—',
                    icon: Icons.directions_car_outlined,
                  ),
                  if (_vehicleType != null && _vehicleType!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    InfoCard(
                      label: 'Vehicle type',
                      value: _vehicleType!,
                      icon: Icons.local_shipping_outlined,
                    ),
                  ],
                ] else if (_uc != null && _uc!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  InfoCard(
                    label: 'UC',
                    value: WasteCatalog.ucLabelForCode(_uc) ?? _uc!,
                    icon: Icons.location_city_outlined,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Live location',
            subtitle: 'Device GPS is saved with this activity.',
            child: LocationCard(
              latitude: _lat,
              longitude: _lng,
              loading: _locating,
              onGetLocation: _locate,
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'After pictures',
            subtitle: 'Up to $_maxAfterPhotos GPS-stamped photos after the activity.',
            child: Opacity(
              opacity: _gpsReady ? 1 : 0.55,
              child: IgnorePointer(
                ignoring: !_gpsReady,
                child: PhotoUploader(
                  title: 'After',
                  hint: 'Take after photo',
                  caption: _gpsReady
                      ? 'Up to $_maxAfterPhotos photos. Each is stamped with lat/long.'
                      : 'Fetch GPS first, then add after pictures.',
                  maxPhotos: _maxAfterPhotos,
                  photos: _afterPhotos,
                  onAdd: _onAfterPhoto,
                  onRemove: (id) => setState(
                    () => _afterPhotos.removeWhere((photo) => photo.id == id),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Remarks',
            subtitle: 'Optional notes for this activity.',
            child: TextInput(
              label: 'Remarks',
              controller: _remarks,
              hint: 'Add remarks',
              maxLines: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B6B52), Color(0xFF0F766E), Color(0xFF134E4A)],
        ),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppType.section.copyWith(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: AppType.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.section.copyWith(fontSize: 15.5)),
          const SizedBox(height: 4),
          Text(subtitle, style: AppType.caption.copyWith(height: 1.35)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InlineLoader extends StatelessWidget {
  const _InlineLoader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(label, style: AppType.caption),
        ],
      ),
    );
  }
}
