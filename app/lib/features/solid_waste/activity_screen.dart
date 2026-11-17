import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/staff_access.dart';
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
  /// Vehicle is valid only for this container. Stops a previous visit's
  /// vehicle from being submitted with a different container.
  int? _vehicleBoundContainerId;
  DateTime? _vehiclePickedAt;
  final List<LocalPhoto> _beforePhotos = [];
  final List<LocalPhoto> _afterPhotos = [];
  String? _lat;
  String? _lng;
  DateTime? _fixAt;
  int? _fixContainerId;
  String? _fixZone;
  bool _fixFromPhoto = false;
  int _zoneToken = 0;
  int _containerToken = 0;
  int _fixToken = 0;
  FreshFixRequest? _fixRequest;

  /// Frozen at "Continue to after photo". Submit uses only this snapshot so a
  /// leftover vehicle/remarks cannot appear after the before step.
  _ActivityLock? _lock;

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
  /// True only after the worker types in remarks for the current stop.
  /// Stops a leftover "cl" from a previous container being submitted again.
  bool _remarksEntered = false;

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
    _fixRequest?.cancel();
    _remarks.dispose();
    super.dispose();
  }

  void _wipeFix() {
    _lat = null;
    _lng = null;
    _fixAt = null;
    _fixContainerId = null;
    _fixZone = null;
    _fixFromPhoto = false;
  }

  void _wipeVehicle() {
    _vehicle = null;
    _vehicleType = null;
    _vehicleBoundContainerId = null;
    _vehiclePickedAt = null;
  }

  void _wipeRemarks() {
    _remarks.clear();
    _remarksEntered = false;
  }

  void _wipeLock() {
    _lock = null;
  }

  void _wipeVisitFields() {
    _wipeVehicle();
    _wipeRemarks();
    _wipeFix();
    _wipeLock();
  }

  String _remarksForSave() {
    // If the worker never typed remarks for this container, do not send a
    // leftover value from a previous stop (the 5-day "cl" pattern).
    if (!_remarksEntered) return '';
    return _remarks.text.trim();
  }

  bool _vehiclePickedAfterLastSave() {
    final pickedAt = _vehiclePickedAt;
    if (pickedAt == null) return false;
    final lastAt = AppStateScope.read(context).lastActivitySavedAt;
    if (lastAt == null) return true;
    // Must choose the vehicle again after the previous successful save.
    return pickedAt.isAfter(lastAt);
  }

  bool _sameCarAsLast() {
    final lastVehicle = (AppStateScope.read(context).lastActivityVehicleNumber ?? '').trim();
    final vehicle = (_vehicle?.number ?? '').trim();
    if (lastVehicle.isEmpty || vehicle.isEmpty) return false;
    return vehicle == lastVehicle;
  }

  bool get _vehicleReady =>
      _vehicle != null &&
      (_vehicleType?.trim().isNotEmpty ?? false) &&
      _vehicleBoundContainerId != null &&
      _vehicleBoundContainerId == _container?.containerId &&
      _vehiclePickedAfterLastSave();

  /// Only a very recent fix for THIS container can back a failed live read.
  /// A longer window was letting a stuck phone pin be saved again.
  bool _recentFixUsable() {
    final at = _fixAt;
    if (at == null || !_gpsReady) return false;
    final age = DateTime.now().difference(at);
    if (_fixZone != _zone) return false;
    if (_isContainerFlow && _fixContainerId != _container?.containerId) return false;
    if (_fixFromPhoto) return age <= const Duration(seconds: 45);
    return age <= const Duration(seconds: 15);
  }

  /// Previous successful save on this phone — used to refuse a stuck GPS cache.
  ({String? lat, String? lng, int? containerId, DateTime? at}) _lastSavedPin() {
    final state = AppStateScope.read(context);
    return (
      lat: state.lastActivityLatitude,
      lng: state.lastActivityLongitude,
      containerId: state.lastActivityContainerId,
      at: state.lastActivitySavedAt,
    );
  }

  bool _shouldAvoidLastPin() {
    if (!_isContainerFlow || _container == null) return false;
    final last = _lastSavedPin();
    final at = last.at;
    if (at == null || last.lat == null || last.lng == null) return false;
    if (DateTime.now().difference(at) > const Duration(hours: 2)) return false;
    // Same container can keep the same pin. A different container must move.
    return last.containerId != _container!.containerId;
  }

  bool _pinMatchesLastSave() {
    final last = _lastSavedPin();
    return sameGeoTag(_lat, _lng, last.lat, last.lng);
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
      _isContainerFlow ? (_container != null && _vehicleReady) : _zone != null;

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
      final containerOnly = session != null && !session.canUseOtherFieldRecords;
      if (containerOnly) {
        activities = [
          for (final item in activities)
            if (isContainerClearanceActivity(code: item.code, name: item.name)) item,
        ];
        if (activities.isEmpty) {
          activities = const [
            CatalogActivity(
              code: 'containers',
              name: 'Container Collection/Clearance',
              unlimitedPictures: false,
            ),
          ];
        }
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
        if (containerOnly && activities.length == 1) _activity = activities.first.name;
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
    _fixRequest?.cancel();
    setState(() {
      _step = _ActivityStep.before;
      _activity = null;
      _zone = null;
      _uc = null;
      _container = null;
      _containerType = null;
      _beforePhotos.clear();
      _afterPhotos.clear();
      _containers = const [];
      _error = null;
      _wipeVisitFields();
    });
    _locate();
  }

  CatalogActivity? _selectedActivity() {
    for (final item in _activities) {
      if (item.name == _activity || item.code == _activity) return item;
    }
    return null;
  }

  void _onActivity(String value) {
    _fixRequest?.cancel();
    setState(() {
      _step = _ActivityStep.before;
      _activity = value;
      _zone = null;
      _uc = null;
      _container = null;
      _containerType = null;
      _beforePhotos.clear();
      _afterPhotos.clear();
      _containers = const [];
      _error = null;
      _wipeVisitFields();
    });
    _locate();
  }

  bool _zoneStill(int token, String zoneCode) =>
      mounted && token == _zoneToken && _zone == zoneCode;

  Future<void> _onZone(String value) async {
    final token = ++_zoneToken;
    _containerToken++;
    _fixRequest?.cancel();
    setState(() {
      _zone = value;
      _uc = null;
      _container = null;
      _containerType = null;
      _beforePhotos.clear();
      _afterPhotos.clear();
      _containers = const [];
      _loadingContainers = _isContainerFlow;
      _loadingVehicles = _isContainerFlow;
      _error = null;
      _wipeVisitFields();
    });
    _locate();
    if (!_isContainerFlow) {
      if (!_zoneStill(token, value)) return;
      setState(() {
        _loadingContainers = false;
        _loadingVehicles = false;
      });
      return;
    }
    final session = AppStateScope.read(context).session;
    if (session == null) {
      if (!_zoneStill(token, value)) return;
      setState(() {
        _loadingContainers = false;
        _loadingVehicles = false;
      });
      _snack('Sign in again.');
      return;
    }
    _loadVehicles(session.cnic, zoneCode: value, token: token);
    try {
      final api = SupervisorApi();
      // The zone list leaves out containers that are already 1/1.
      // Activity shows those collected containers, loaded from their sites.
      final fetched = List<TaggingContainer>.of(
        await api.containers(session.cnic, zoneCode: value),
      );
      if (!_zoneStill(token, value)) return;
      final rows = await _collectedContainers(session.cnic, value, fetched);
      if (!_zoneStill(token, value)) return;
      rows.sort((a, b) => a.containerName.compareTo(b.containerName));
      setState(() {
        _containers = rows;
        _loadingContainers = false;
        if (_container != null && !rows.any((item) => item.containerId == _container!.containerId)) {
          _container = null;
          _containerType = null;
          _beforePhotos.clear();
          _afterPhotos.clear();
          _wipeVisitFields();
        }
      });
      if (rows.isEmpty) _snack('No containers found for $value.');
    } on SupervisorException catch (error) {
      if (!_zoneStill(token, value)) return;
      setState(() {
        _loadingContainers = false;
        _error = error.message;
      });
    } catch (_) {
      if (!_zoneStill(token, value)) return;
      setState(() {
        _loadingContainers = false;
        _error = 'Could not load containers for this zone.';
      });
    }
  }

  /// Containers whose Container Collection/Clearance is already saved (1/1).
  Future<List<TaggingContainer>> _collectedContainers(
    String cnic,
    String zoneCode,
    List<TaggingContainer> zoneRows,
  ) async {
    final api = SupervisorApi();
    final sites = await api.primarySites(cnic, zoneCode: zoneCode);
    final batches = await Future.wait([
      for (final site in sites)
        () async {
          try {
            return (await api.containersForPrimarySite(cnic, site.id)).items;
          } catch (_) {
            return const <TaggingContainer>[];
          }
        }(),
    ]);
    final seen = <int>{};
    return [
      for (final item in zoneRows)
        if (item.activityDone && seen.add(item.containerId)) item,
      for (final batch in batches)
        for (final item in batch)
          if (item.activityDone && seen.add(item.containerId)) item,
    ];
  }

  Future<void> _loadVehicles(String cnic, {required String zoneCode, required int token}) async {
    List<CatalogVehicle> fallback() {
      return [
        for (final item in WasteCatalog.vehicles)
          if (zoneCode.isEmpty || item.zoneCode == null || item.zoneCode == zoneCode) item,
      ];
    }

    List<CatalogVehicle> rows;
    try {
      rows = await SupervisorApi().vehicles(cnic, zoneCode: zoneCode);
      if (rows.isEmpty) rows = fallback();
    } catch (_) {
      rows = fallback();
    }
    if (!_zoneStill(token, zoneCode)) return;
    rows.sort((a, b) => a.number.compareTo(b.number));
    setState(() {
      _vehicles = rows;
      _loadingVehicles = false;
      if (_vehicle != null && (!_vehicleStillListed(_vehicle!) || !_vehicleReady)) {
        _wipeVehicle();
        _wipeLock();
      }
    });
  }

  bool _vehicleStillListed(CatalogVehicle vehicle) {
    for (final item in _vehicles) {
      if (vehicle.id != null && item.id == vehicle.id) return true;
      if (item.id == vehicle.id &&
          item.number == vehicle.number &&
          item.vehicleType == vehicle.vehicleType &&
          item.zoneCode == vehicle.zoneCode) {
        return true;
      }
    }
    return false;
  }

  String _vehicleKey(CatalogVehicle item) {
    final id = item.id;
    if (id != null) return 'id:$id';
    return 'plate:${item.number}|${item.vehicleType ?? ''}|${item.zoneCode ?? ''}';
  }

  List<String> _vehicleChoiceValues() {
    final counts = <String, int>{};
    final values = <String>[];
    for (final item in _vehicles) {
      final base = _vehicleKey(item);
      final n = (counts[base] ?? 0) + 1;
      counts[base] = n;
      values.add(n == 1 ? base : '$base#$n');
    }
    return values;
  }

  String _vehicleChoiceLabel(CatalogVehicle item) {
    var sameNumber = 0;
    for (final other in _vehicles) {
      if (other.number == item.number) sameNumber++;
    }
    if (sameNumber < 2) return item.number;
    final type = item.vehicleType?.trim();
    if (type != null && type.isNotEmpty) {
      var sameType = 0;
      for (final other in _vehicles) {
        if (other.number == item.number && other.vehicleType?.trim() == type) sameType++;
      }
      if (sameType < 2) return '${item.number} · $type';
    }
    final id = item.id;
    return id == null ? '${item.number} · ${item.zoneCode ?? 'vehicle'}' : '${item.number} · $id';
  }

  String? _selectedVehicleValue() {
    final vehicle = _vehicle;
    if (vehicle == null) return null;
    final values = _vehicleChoiceValues();
    for (var i = 0; i < _vehicles.length && i < values.length; i++) {
      final item = _vehicles[i];
      if (vehicle.id != null && item.id == vehicle.id) return values[i];
      if (item.id == vehicle.id &&
          item.number == vehicle.number &&
          item.vehicleType == vehicle.vehicleType &&
          item.zoneCode == vehicle.zoneCode) {
        return values[i];
      }
    }
    return null;
  }

  void _onVehicle(String key) {
    if (_container == null) {
      _snack('Select a container first.');
      return;
    }
    final values = _vehicleChoiceValues();
    final index = values.indexOf(key);
    if (index < 0 || index >= _vehicles.length) {
      _snack('That vehicle is no longer in this zone. Choose it again.');
      return;
    }
    final picked = _vehicles[index];
    final type = picked.vehicleType?.trim();
    if (type == null || type.isEmpty) {
      _snack('Vehicle type is missing for this vehicle. Choose another.');
      return;
    }
    setState(() {
      _vehicle = picked;
      _vehicleType = type;
      _vehicleBoundContainerId = _container!.containerId;
      _vehiclePickedAt = DateTime.now();
      _resolvingVehicleType = false;
      _wipeLock();
    });
  }

  String _containerChoiceLabel(TaggingContainer item) {
    var sameName = 0;
    for (final other in _containers) {
      if (other.containerName == item.containerName) sameName++;
    }
    if (sameName < 2) return item.containerName;
    final site = item.primarySiteName?.trim();
    if (site != null && site.isNotEmpty) {
      var sameSite = 0;
      for (final other in _containers) {
        if (other.containerName == item.containerName && other.primarySiteName?.trim() == site) {
          sameSite++;
        }
      }
      if (sameSite < 2) return '${item.containerName} · $site';
    }
    return '${item.containerName} · ${item.containerId}';
  }

  Future<void> _onContainer(String idText) async {
    final id = int.tryParse(idText);
    TaggingContainer? selected;
    if (id != null) {
      for (final item in _containers) {
        if (item.containerId == id) {
          selected = item;
          break;
        }
      }
    }
    if (selected == null) {
      _snack('That container is no longer in this zone. Choose it again.');
      return;
    }
    final picked = selected;
    final token = ++_containerToken;
    final changed = _container?.containerId != picked.containerId;
    if (changed) _fixRequest?.cancel();
    setState(() {
      _container = picked;
      _containerType = picked.containerType;
      _resolvingType = picked.containerType == null || picked.containerType!.isEmpty;
      // Never inherit another stop's vehicle/remarks. GPS only resets when the
      // container actually changes (re-tapping the same row must not blank GPS).
      _wipeVehicle();
      _wipeRemarks();
      _wipeLock();
      if (changed) {
        _beforePhotos.clear();
        _afterPhotos.clear();
        _wipeFix();
      }
    });
    if (changed) _locate();
    if (!_resolvingType) return;
    final session = AppStateScope.read(context).session;
    if (session == null) {
      if (!mounted || token != _containerToken) return;
      setState(() => _resolvingType = false);
      return;
    }
    try {
      final detail = await SupervisorApi().containerDetail(session.cnic, picked.containerId);
      if (!mounted || token != _containerToken || _container?.containerId != picked.containerId) return;
      setState(() {
        _containerType = detail.containerType ?? _containerType;
        _resolvingType = false;
      });
    } catch (_) {
      if (!mounted || token != _containerToken || _container?.containerId != picked.containerId) return;
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
      if (!_vehicleReady) {
        _snack('Select the vehicle used for this container.');
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
    // Stay on Activity. Never navigate to Solid Waste from the before step.
    if (_isContainerFlow && !_vehicleReady) {
      _snack('Select the vehicle used for this container.');
      return;
    }
    final selected = _selectedActivity();
    final title = selected?.name ?? _container?.containerName ?? 'Activity before';
    final stamped = <LocalPhoto>[];
    for (final photo in _beforePhotos) {
      stamped.add(await _stampPhoto(photo, title));
    }
    if (!mounted) return;
    if (!_remarksEntered) _remarks.clear();
    final lock = _isContainerFlow
        ? _ActivityLock(
            containerId: _container!.containerId,
            containerName: _container!.containerName,
            containerType: _containerType,
            vehicleId: _vehicle!.id,
            vehicleNumber: _vehicle!.number,
            vehicleType: _vehicleType!,
          )
        : null;
    setState(() {
      _beforePhotos
        ..clear()
        ..addAll(stamped);
      _step = _ActivityStep.after;
      _afterPhotos.clear();
      _lock = lock;
    });
  }

  /// Reads a new satellite fix. A failed read leaves the previous fix in place
  /// so a photo that already locked this container is not replaced by an older stop.
  Future<bool> _locate({bool announce = true, bool fromPhoto = false}) async {
    _fixRequest?.cancel();
    final request = FreshFixRequest();
    _fixRequest = request;
    final token = ++_fixToken;
    if (!mounted) return false;
    setState(() => _locating = true);
    final avoid = _shouldAvoidLastPin() ? _lastSavedPin() : (lat: null, lng: null, containerId: null, at: null);
    try {
      final geo = await freshGeoTag(
        request: request,
        avoidLatitude: avoid.lat,
        avoidLongitude: avoid.lng,
      );
      if (!mounted || token != _fixToken || request.cancelled) return false;
      final parts = geo.split(',');
      final lat = parts.first.trim();
      final lng = parts.length > 1 ? parts[1].trim() : '';
      if (lat.isEmpty || lng.isEmpty) {
        setState(() => _locating = false);
        if (announce) _snack('Could not read a fresh GPS fix.');
        return false;
      }
      if (_shouldAvoidLastPin() && sameGeoTag(lat, lng, avoid.lat, avoid.lng)) {
        setState(() => _locating = false);
        if (announce) {
          _snack(
            'GPS is still on the previous container. Move closer to this bin in the open and try again.',
          );
        }
        return false;
      }
      setState(() {
        _locating = false;
        _lat = lat;
        _lng = lng;
        _fixAt = DateTime.now();
        _fixContainerId = _container?.containerId;
        _fixZone = _zone;
        _fixFromPhoto = fromPhoto;
      });
      return true;
    } on FreshFixCancelled {
      if (mounted && token == _fixToken) setState(() => _locating = false);
      return false;
    } on SupervisorException catch (error) {
      if (!mounted || token != _fixToken || request.cancelled) return false;
      setState(() => _locating = false);
      if (announce) _snack(error.message);
      return false;
    } catch (_) {
      if (!mounted || token != _fixToken || request.cancelled) return false;
      setState(() => _locating = false);
      if (announce) {
        _snack('Could not get a fresh GPS fix. Step into an open area and try again.');
      }
      return false;
    }
  }

  /// Reuse a fix only when it was just taken for this same stop.
  /// Five seconds is not long enough to reach another container.
  Future<bool> _ensurePhotoFix() async {
    final at = _fixAt;
    final sameStop = at != null &&
        _gpsReady &&
        _fixZone == _zone &&
        (!_isContainerFlow || _fixContainerId == _container?.containerId) &&
        DateTime.now().difference(at) <= const Duration(seconds: 5);
    if (sameStop) {
      if (!_fixFromPhoto && mounted) setState(() => _fixFromPhoto = true);
      return true;
    }
    return _locate(fromPhoto: true);
  }

  Future<bool> _captureFixForSave() async {
    final fallback = _recentFixUsable();
    final ok = await _locate(announce: !fallback);
    if (ok) return true;
    if (fallback && mounted) {
      // Never reuse a pin that already belongs to a different saved container.
      if (_shouldAvoidLastPin() && _pinMatchesLastSave()) {
        _snack(
          'GPS is still on the previous container. Move closer to this bin in the open and try again.',
        );
        return false;
      }
      _snack('Live GPS did not update. Saved the fix from this visit.');
      return true;
    }
    return false;
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
    final max = _isPhotosOnlyFlow ? _maxPlainPhotos : _maxBeforePhotos;
    if (_beforePhotos.length >= max) {
      _snack('You can add up to $max pictures.');
      return;
    }
    final located = await _ensurePhotoFix();
    if (!mounted || !located) return;
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
    if (_afterPhotos.length >= _maxAfterPhotos) {
      _snack('You can add up to $_maxAfterPhotos after pictures.');
      return;
    }
    final located = await _ensurePhotoFix();
    if (!mounted || !located) return;
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
    if (selected == null) {
      _snack('Start again from the activity details.');
      setState(() => _step = _ActivityStep.before);
      return;
    }
    final containerOk = !_isContainerFlow ||
        (_container != null &&
            _vehicleReady &&
            (_containerType?.trim().isNotEmpty ?? false));
    if (_zone == null ||
        _zone!.isEmpty ||
        !containerOk ||
        uploadPhotos(_beforePhotos).isEmpty) {
      _snack('Start again from the activity details.');
      setState(() => _step = _ActivityStep.before);
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
    // Fresh GPS first, then confirm the exact values that will be saved.
    if (!await _captureFixForSave()) return;
    if (!mounted) return;
    if (_isContainerFlow && _shouldAvoidLastPin() && _pinMatchesLastSave()) {
      _wipeFix();
      _snack(
        'GPS pin matches the previous container. Stand at this bin, tap Get Live Location, then submit again.',
      );
      setState(() => _step = _ActivityStep.before);
      return;
    }
    if (_isContainerFlow) {
      final lock = _lock;
      if (!_vehicleReady ||
          lock == null ||
          lock.containerId != _container?.containerId ||
          lock.vehicleNumber != _vehicle?.number ||
          lock.vehicleId != _vehicle?.id) {
        _wipeLock();
        _snack('Start again from the activity details and confirm the vehicle.');
        setState(() => _step = _ActivityStep.before);
        return;
      }
      final remarks = _remarksForSave();
      final confirmed = await ConfirmationSheet.show(
        context,
        title: 'Confirm this container',
        message:
            'Container: ${lock.containerName}\n'
            'Vehicle: ${lock.vehicleNumber} · ${lock.vehicleType}\n'
            'GPS: ${_lat ?? '—'}, ${_lng ?? '—'}\n'
            'Remarks: ${remarks.isEmpty ? '(none)' : remarks}\n\n'
            'If the vehicle is wrong, tap Cancel and choose the correct one.',
        confirmLabel: 'Submit',
        cancelLabel: 'Cancel',
      );
      if (!confirmed || !mounted) return;
    }
    await _saveActivity(
      selected: selected,
      before: _beforePhotos,
      after: _afterPhotos,
      photosOnly: false,
      alreadyFixed: true,
    );
  }

  Future<void> _saveActivity({
    required CatalogActivity selected,
    required List<LocalPhoto> before,
    required List<LocalPhoto> after,
    required bool photosOnly,
    bool alreadyFixed = false,
  }) async {
    final session = AppStateScope.read(context).session;
    if (session == null) {
      _snack('Sign in again.');
      return;
    }
    if (!session.canUseOtherFieldRecords &&
        !isContainerClearanceActivity(code: selected.code, name: selected.name)) {
      _snack('This activity is not available for your account.');
      return;
    }

    if (_isContainerFlow && !_vehicleReady) {
      _snack('Select the vehicle used for this container.');
      setState(() => _step = _ActivityStep.before);
      return;
    }

    setState(() => _submitting = true);
    try {
      if (!alreadyFixed) {
        if (!await _captureFixForSave()) return;
        if (!mounted) return;
      }
      // Re-check after the GPS wait — container/vehicle can change meanwhile.
      if (_isContainerFlow && !_vehicleReady) {
        _snack('Select the vehicle used for this container.');
        setState(() => _step = _ActivityStep.before);
        return;
      }
      // Same GPS pin on a different container = stuck/leftover location.
      // Same truck is allowed only if he picks it again after the last save.
      if (_isContainerFlow && _shouldAvoidLastPin() && _pinMatchesLastSave()) {
        _wipeFix();
        _snack(
          'GPS pin matches the previous container. Stand at this bin, tap Get Live Location, then submit again.',
        );
        setState(() => _step = _ActivityStep.before);
        return;
      }
      if (_isContainerFlow &&
          _shouldAvoidLastPin() &&
          _sameCarAsLast() &&
          !_vehiclePickedAfterLastSave()) {
        _wipeVisitFields();
        _snack(
          'Previous vehicle was still filled. Select the vehicle for this container again.',
        );
        setState(() => _step = _ActivityStep.before);
        return;
      }
      if (_isContainerFlow && !_vehiclePickedAfterLastSave()) {
        _wipeVehicle();
        _wipeLock();
        _snack('Select the vehicle again for this container.');
        setState(() => _step = _ActivityStep.before);
        return;
      }

      _ActivityLock? locked;
      if (_isContainerFlow) {
        final lock = _lock;
        if (lock == null ||
            lock.containerId != _container?.containerId ||
            lock.vehicleNumber != _vehicle?.number ||
            lock.vehicleId != _vehicle?.id ||
            !_vehicleReady) {
          _wipeLock();
          _snack('Start again from the activity details and confirm the vehicle.');
          setState(() => _step = _ActivityStep.before);
          return;
        }
        locked = lock;
      }

      final saveContainerId = locked?.containerId;
      final saveContainerName = locked?.containerName;
      final saveContainerType = locked?.containerType;
      final saveVehicleId = locked?.vehicleId;
      final saveVehicleNumber = locked?.vehicleNumber;
      final saveVehicleType = locked?.vehicleType;
      // Remarks only if typed for this stop — never a leftover "cl".
      final savedRemarks = _remarksForSave();
      final saveLat = _lat!.trim();
      final saveLng = _lng!.trim();

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
        containerId: saveContainerId,
        containerName: saveContainerName,
        containerType: saveContainerType,
        vehicleId: saveVehicleId,
        vehicleNumber: saveVehicleNumber,
        vehicleType: saveVehicleType,
        latitude: saveLat,
        longitude: saveLng,
        geoTag: '$saveLat,$saveLng',
        remarks: savedRemarks,
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
          draft.containerType = saveContainerType;
          draft.containerId = saveContainerId;
          draft.containerName = saveContainerName;
          draft.vehicleNumber = saveVehicleNumber ?? '';
          draft.vehicleType = saveVehicleType;
        }
        draft.beforePhotos.addAll(stampedBefore);
        draft.afterPhotos.addAll(stampedAfter);
        draft.remarks = savedRemarks;
        draft.latitude = saveLat;
        draft.longitude = saveLng;
        draft.recordId = saved.id;
        draft.savedAt = DateTime.now();
      });
      final appState = AppStateScope.read(context);
      appState.noteWasteSynced();
      appState.rememberActivitySave(
        latitude: saveLat,
        longitude: saveLng,
        containerId: saveContainerId,
        vehicleNumber: saveVehicleNumber,
        remarks: savedRemarks,
      );

      if (!mounted) return;
      // Only leave Activity after a successful save. Before/after photo steps
      // never call this path, so they stay on this screen.
      final message = (saved.message ?? '').trim().isEmpty
          ? 'Activity saved successfully.'
          : saved.message!.trim();
      appState.setFlashNotice(message);
      _fixRequest?.cancel();
      setState(() {
        _step = _ActivityStep.before;
        _zone = null;
        _uc = null;
        _container = null;
        _containerType = null;
        _beforePhotos.clear();
        _afterPhotos.clear();
        _containers = const [];
        _error = null;
        _wipeVisitFields();
      });
      if (!mounted) return;
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
        label: photosOnly ? 'Submit' : 'Continue to after photo',
        loading: _locating || (photosOnly && _submitting),
        onPressed: _loadingCatalog || _locating || (photosOnly && _submitting) ? null : _goToAfter,
      ),
      body: _loadingCatalog
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: LoadingSkeletonGroup(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                ModuleHero(
                  icon: Icons.assignment_outlined,
                  title: 'Activity record',
                  subtitle: heroSubtitle,
                  colors: ModulePalette.waste,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  InlineMessage(tone: InlineTone.error, message: _error!),
                ],
                const SizedBox(height: 16),
                ModulePanel(
                  title: 'Details',
                  subtitle: _isContainerFlow
                      ? 'Pick the container and vehicle for this visit. Changing the container clears the vehicle, remarks and location.'
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
                            items: [for (final item in _containers) _containerChoiceLabel(item)],
                            values: [for (final item in _containers) '${item.containerId}'],
                            value: _container == null ? null : '${_container!.containerId}',
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
                            hint: _zone == null
                                ? 'Select zone first'
                                : (_container == null
                                    ? 'Select container first'
                                    : (_vehicles.isEmpty
                                        ? 'No vehicles available'
                                        : 'Select vehicle for this container')),
                            items: [for (final item in _vehicles) _vehicleChoiceLabel(item)],
                            values: _vehicleChoiceValues(),
                            value: _vehicleReady ? _selectedVehicleValue() : null,
                            enabled: _zone != null &&
                                _container != null &&
                                _vehicles.isNotEmpty &&
                                !_loadingVehicles,
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
                ModulePanel(
                  title: 'Live location',
                  subtitle: 'Each photo and the saved record take a new GPS fix. A previous stop is not reused.',
                  child: LocationCard(
                    latitude: _lat,
                    longitude: _lng,
                    loading: _locating,
                    onGetLocation: _locate,
                  ),
                ),
                const SizedBox(height: 14),
                ModulePanel(
                  title: photosOnly ? 'Pictures' : 'Before pictures',
                  subtitle: photosOnly
                      ? 'At least 1, up to $_maxPlainPhotos GPS-stamped photos.'
                      : 'Up to $_maxBeforePhotos GPS-stamped photos before the activity.',
                  child: Opacity(
                    opacity: !_detailsReady || !_gpsReady || _locating ? 0.55 : 1,
                    child: IgnorePointer(
                      ignoring: !_detailsReady || !_gpsReady || _locating || _submitting,
                      child: PhotoUploader(
                        title: photosOnly ? 'Photos' : 'Before',
                        hint: photosOnly ? 'Take photo' : 'Take before photo',
                        caption: !_detailsReady
                            ? (_isContainerFlow
                                ? 'Select container and vehicle first.'
                                : 'Select a zone first.')
                            : (_locating
                                ? 'Reading a fresh GPS fix…'
                                : (_gpsReady
                                    ? 'Each photo is stamped with a new GPS fix from where you are standing.'
                                    : 'Fetch GPS first, then add pictures.')),
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
                  ModulePanel(
                    title: 'Remarks',
                    subtitle: 'Notes for this visit only. Changing the container or zone clears them.',
                    child: TextInput(
                      label: 'Remarks',
                      controller: _remarks,
                      hint: 'Add remarks',
                      maxLines: 4,
                      enableSuggestions: false,
                      autocorrect: false,
                      autofillHints: const [],
                      onChanged: (_) => _remarksEntered = true,
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
          onPressed: () => setState(() {
            _step = _ActivityStep.before;
            _wipeLock();
          }),
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
        loading: _submitting || _locating,
        onPressed: _submitting || _locating ? null : _submit,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          ModuleHero(
            icon: Icons.done_all_rounded,
            title: 'Finish the record',
            subtitle: _lock == null
                ? 'Add the after picture, remarks and live location, then submit.'
                : 'Vehicle locked: ${_lock!.vehicleNumber}. If wrong, tap Back and choose again.',
            colors: ModulePalette.waste,
          ),
          const SizedBox(height: 16),
          ModulePanel(
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
                    value: _container == null ? '—' : _containerChoiceLabel(_container!),
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
                    value: _vehicle == null ? '—' : _vehicleChoiceLabel(_vehicle!),
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
          ModulePanel(
            title: 'Live location',
            subtitle: 'Submit reads GPS again. It does not keep the previous container’s pin.',
            child: LocationCard(
              latitude: _lat,
              longitude: _lng,
              loading: _locating,
              onGetLocation: _locate,
            ),
          ),
          const SizedBox(height: 14),
          ModulePanel(
            title: 'After pictures',
            subtitle: 'Up to $_maxAfterPhotos GPS-stamped photos after the activity.',
            child: Opacity(
              opacity: !_gpsReady || _locating ? 0.55 : 1,
              child: IgnorePointer(
                ignoring: !_gpsReady || _locating || _submitting,
                child: PhotoUploader(
                  title: 'After',
                  hint: 'Take after photo',
                  caption: _locating
                      ? 'Reading a fresh GPS fix…'
                      : (_gpsReady
                          ? 'Each photo is stamped with a new GPS fix from where you are standing.'
                          : 'Fetch GPS first, then add after pictures.'),
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
          ModulePanel(
            title: 'Remarks',
            subtitle: 'Notes for this visit only. Changing the container or zone clears them.',
            child: TextInput(
              label: 'Remarks',
              controller: _remarks,
              hint: 'Add remarks',
              maxLines: 4,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [],
              onChanged: (_) => _remarksEntered = true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityLock {
  const _ActivityLock({
    required this.containerId,
    required this.containerName,
    required this.containerType,
    required this.vehicleId,
    required this.vehicleNumber,
    required this.vehicleType,
  });

  final int containerId;
  final String containerName;
  final String? containerType;
  final int? vehicleId;
  final String vehicleNumber;
  final String vehicleType;
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
