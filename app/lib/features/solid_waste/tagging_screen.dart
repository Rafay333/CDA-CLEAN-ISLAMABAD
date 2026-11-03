import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/gps_photo_stamp.dart';
import 'waste_catalog.dart';

/// Zone → Site → auto type → Container (if any) → GPS + 1 photo (no UC gate).
class TaggingScreen extends StatefulWidget {
  const TaggingScreen({super.key});

  @override
  State<TaggingScreen> createState() => _TaggingScreenState();
}

class _TaggingScreenState extends State<TaggingScreen> {
  String? _zone;
  String? _containerType;
  TaggingPrimarySite? _site;
  TaggingContainer? _container;
  String? _deviceLat;
  String? _deviceLng;
  LocalPhoto? _photo;

  List<String> _zones = const [];
  List<String> _types = WasteCatalog.inventoryContainerTypes;
  List<TaggingPrimarySite> _sites = const [];
  List<TaggingContainer> _containers = const [];

  bool _loadingCatalog = true;
  bool _loadingSites = false;
  bool _loadingContainers = false;
  bool _locating = false;
  bool _saving = false;
  String? _error;

  bool get _zoneDone => _zone != null && _zone!.isNotEmpty;
  bool get _typeDone => _containerType != null && _containerType!.isNotEmpty;
  /// Compulsory: only 1.1 m3 / 8 m3 count as selected.
  bool get _typeValid => _normalizedContainerType(_containerType) != null;
  bool get _siteDone => _site != null;
  bool get _containerDone => _container != null;
  /// Site with no child inventory rows → tag the primary site itself (old way).
  bool get _siteOnlyMode =>
      _siteDone && !_loadingContainers && _containers.isEmpty && _container == null;
  bool get _targetReady => _containerDone || _siteOnlyMode;
  bool get _gpsDone =>
      (_deviceLat?.trim().isNotEmpty ?? false) && (_deviceLng?.trim().isNotEmpty ?? false);
  bool get _canSubmit =>
      !_saving &&
      !_loadingCatalog &&
      _typeValid &&
      _zoneDone &&
      _siteDone &&
      _targetReady &&
      _gpsDone &&
      _photo != null &&
      (_photo!.bytes?.isNotEmpty ?? false);

  double? get _pinLat => _container?.displayLat ?? _site?.latitude;
  double? get _pinLng => _container?.displayLng ?? _site?.longitude;
  String get _targetLabel =>
      _container?.containerName ?? _site?.name ?? 'Container';

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final cnic = AppStateScope.read(context).session?.cnic;
    setState(() {
      _loadingCatalog = true;
      _error = null;
    });
    try {
      await WasteCatalog.ensureLoaded(cnic: cnic, force: true);
      if (!mounted) return;
      final zones = [
        for (final z in WasteCatalog.zones)
          if (z == 'Zone-4' || z == 'Zone-5') z,
      ];
      // Old way: only two sizes — 1.1 m3 | 8 m3.
      final types = WasteCatalog.taggingContainerTypes;
      setState(() {
        _zones = zones.isEmpty ? const ['Zone-4', 'Zone-5'] : zones;
        _types = types.isEmpty ? WasteCatalog.inventoryContainerTypes : types;
        if (_normalizedContainerType(_containerType) == null) {
          _containerType = null;
        }
        _loadingCatalog = false;
      });
    } on SupervisorException catch (e) {
      if (!mounted) return;
      setState(() {
        _types = WasteCatalog.inventoryContainerTypes;
        _loadingCatalog = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _types = WasteCatalog.inventoryContainerTypes;
        _loadingCatalog = false;
        _error = 'Could not load catalog.';
      });
    }
  }

  String? _normalizedContainerType(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase().replaceAll(' ', '');
    if (lower.contains('1.1') || lower == '1.1m3' || lower == '1,1m3') {
      return '1.1 m3';
    }
    if (lower.contains('8m3') || lower == '8' || RegExp(r'(^|[^0-9.])8(\s*)m').hasMatch(lower)) {
      return '8 m3';
    }
    for (final allowed in _types) {
      if (allowed.toLowerCase() == value.toLowerCase()) return allowed;
    }
    for (final allowed in WasteCatalog.inventoryContainerTypes) {
      if (allowed.toLowerCase() == value.toLowerCase()) return allowed;
    }
    return null;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _clear() {
    setState(() {
      _zone = null;
      _containerType = null;
      _site = null;
      _container = null;
      _deviceLat = null;
      _deviceLng = null;
      _photo = null;
      _sites = const [];
      _containers = const [];
      _error = null;
    });
  }

  Future<void> _onZone(String value) async {
    setState(() {
      _zone = value;
      _site = null;
      _container = null;
      _containerType = null;
      _deviceLat = null;
      _deviceLng = null;
      _photo = null;
      _sites = const [];
      _containers = const [];
      _loadingSites = true;
    });
    final session = AppStateScope.read(context).session;
    if (session == null) {
      setState(() => _loadingSites = false);
      _snack('Sign in again.');
      return;
    }
    try {
      final rows = await SupervisorApi().primarySites(
        session.cnic,
        zoneCode: value,
        purpose: 'tagging',
      );
      // Only sites that still have untagged work (IsTagged = 0), or no inventory yet.
      final open = [for (final s in rows) if (s.needsTagging) s];
      if (!mounted) return;
      setState(() {
        _sites = open;
        _loadingSites = false;
      });
      if (open.isEmpty) {
        _snack(rows.isEmpty
            ? 'No primary sites for $value.'
            : 'All containers in $value are already tagged.');
      }
    } on SupervisorException catch (e) {
      if (!mounted) return;
      setState(() => _loadingSites = false);
      _snack(e.message);
    }
  }

  /// Prefer type from a picked container, else first valid type under the site.
  String? _typeFromContainers(List<TaggingContainer> rows, {TaggingContainer? prefer}) {
    final fromPrefer = _normalizedContainerType(prefer?.containerType);
    if (fromPrefer != null) return fromPrefer;
    for (final c in rows) {
      final t = _normalizedContainerType(c.containerType);
      if (t != null) return t;
    }
    return null;
  }

  Future<void> _onSite(String name) async {
    TaggingPrimarySite? matched;
    for (final s in _sites) {
      if (s.name == name) matched = s;
    }
    if (matched == null) return;
    final site = matched;
    setState(() {
      _site = site;
      _container = null;
      _containerType = null;
      _deviceLat = null;
      _deviceLng = null;
      _photo = null;
      _containers = const [];
      _loadingContainers = true;
    });
    final session = AppStateScope.read(context).session;
    if (session == null) {
      setState(() => _loadingContainers = false);
      _snack('Sign in again.');
      return;
    }
    try {
      final api = SupervisorApi();
      final result = await api.containersForPrimarySite(
        session.cnic,
        site.id,
        purpose: 'tagging',
      );
      if (!mounted) return;
      final all = result.items;
      // Tagging picker: only IsTagged = 0 (hide already tagged).
      final items = [for (final c in all) if (!c.isTagged) c];
      if (all.isNotEmpty && items.isEmpty) {
        setState(() {
          _containers = const [];
          _container = null;
          _containerType = null;
          _loadingContainers = false;
          _site = null;
        });
        _snack('All containers at this site are already tagged.');
        return;
      }
      // One inventory row → auto-select it; type comes from Containers.ContainerType.
      var autoContainer = items.length == 1 ? items.first : null;
      var autoType = _typeFromContainers(items, prefer: autoContainer);
      if (autoType == null && autoContainer != null) {
        try {
          final detail = await api.containerDetail(session.cnic, autoContainer.containerId);
          if (detail.isTagged) {
            if (!mounted) return;
            setState(() {
              _containers = const [];
              _container = null;
              _containerType = null;
              _loadingContainers = false;
              _site = null;
            });
            _snack('This container is already tagged.');
            return;
          }
          autoType = _normalizedContainerType(detail.containerType);
          autoContainer = TaggingContainer(
            containerId: detail.containerId,
            containerName: detail.containerName,
            primarySiteId: detail.primarySiteId ?? site.id,
            primarySiteName: detail.primarySiteName ?? site.name,
            zoneCode: detail.zoneCode ?? site.zoneCode,
            containerType: detail.containerType ?? autoContainer.containerType,
            latitude: detail.latitude,
            longitude: detail.longitude,
            siteLatitude: detail.siteLatitude ?? site.latitude,
            siteLongitude: detail.siteLongitude ?? site.longitude,
            tagStatus: detail.tagStatus,
            isTagged: detail.isTagged,
            taggingDate: detail.taggingDate,
          );
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _containers = items;
        _container = autoContainer;
        // Prefer type from Containers under the site; fall back to site list field.
        _containerType =
            autoType ?? _normalizedContainerType(site.containerType);
        _loadingContainers = false;
      });
    } on SupervisorException catch (e) {
      if (!mounted) return;
      setState(() {
        _containerType = null;
        _loadingContainers = false;
      });
      _snack(e.message);
    }
  }

  void _onContainer(String name) {
    TaggingContainer? selected;
    for (final c in _containers) {
      if (c.containerName == name) selected = c;
    }
    setState(() {
      _container = selected;
      // Auto-fetch type from the selected container (same as Activity).
      final fromContainer = _normalizedContainerType(selected?.containerType);
      if (fromContainer != null) _containerType = fromContainer;
      _deviceLat = null;
      _deviceLng = null;
      _photo = null;
    });
  }

  String _stampedName(String? name) {
    final raw = (name ?? 'tagging.jpg').trim();
    final lower = raw.toLowerCase();
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp')) {
      final dot = raw.lastIndexOf('.');
      return '${raw.substring(0, dot)}_gps.png';
    }
    return '${raw}_gps.png';
  }

  Future<void> _onPhoto(LocalPhoto photo) async {
    if (!_gpsDone || photo.bytes == null || photo.bytes!.isEmpty) {
      setState(() => _photo = photo);
      return;
    }
    try {
      final stampedBytes = await stampGpsOnPhoto(
        photo.bytes!,
        latitude: _deviceLat!,
        longitude: _deviceLng!,
        title: _targetLabel,
      );
      if (!mounted) return;
      setState(() {
        _photo = LocalPhoto(
          photo.id,
          bytes: stampedBytes,
          filename: _stampedName(photo.filename),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _photo = photo);
    }
  }

  Future<void> _locate() async {
    if (!_targetReady) {
      _snack(
        _containers.isEmpty
            ? 'Select zone and site first.'
            : 'Select zone, site and container first.',
      );
      return;
    }
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
        _deviceLat = parts.first.trim();
        _deviceLng = parts.length > 1 ? parts[1].trim() : null;
      });
    } on SupervisorException catch (e) {
      if (!mounted) return;
      setState(() => _locating = false);
      _snack(e.message);
    }
  }

  Future<void> _save() async {
    if (!_zoneDone) {
      _snack('Select a zone.');
      return;
    }
    // Container type is compulsory — never submit without 1.1 m3 / 8 m3.
    final taggingType = _normalizedContainerType(_containerType);
    if (!_typeDone || taggingType == null) {
      _snack('Container type is required. Select 1.1 m3 or 8 m3.');
      setState(() => _containerType = null);
      return;
    }
    if (!_siteDone) {
      _snack('Select a primary site.');
      return;
    }
    if (!_siteOnlyMode && !_containerDone) {
      _snack('Select a container.');
      return;
    }
    if (!_gpsDone) {
      _snack('Fetch your current GPS location.');
      return;
    }
    if (_photo == null || _photo!.bytes == null || _photo!.bytes!.isEmpty) {
      _snack('Take one photo of the container.');
      return;
    }
    final session = AppStateScope.read(context).session;
    if (session == null) {
      _snack('Sign in again.');
      return;
    }
    setState(() {
      _saving = true;
      _containerType = taggingType;
    });
    try {
      // Ensure GPS is burned into the image (same idea as attendance stamped photos).
      var upload = _photo!;
      final alreadyStamped = (upload.filename ?? '').toLowerCase().contains('_gps.');
      if (!alreadyStamped && upload.bytes != null && upload.bytes!.isNotEmpty) {
        final stampedBytes = await stampGpsOnPhoto(
          upload.bytes!,
          latitude: _deviceLat!,
          longitude: _deviceLng!,
          title: _targetLabel,
        );
        upload = LocalPhoto(
          upload.id,
          bytes: stampedBytes,
          filename: _stampedName(upload.filename),
        );
        if (mounted) setState(() => _photo = upload);
      }
      final saved = await SupervisorApi().saveFieldRecord(
        cnic: session.cnic,
        kind: 'tagging',
        tagging: WasteCatalog.containerTagging,
        containerType: taggingType,
        primarySiteId: _site!.id,
        // Optional: only send when inventory container rows exist under the site.
        containerId: _container?.containerId,
        containerName: _targetLabel,
        zoneCode: _zone,
        latitude: _deviceLat,
        longitude: _deviceLng,
        bulk: uploadPhotos([upload]),
      );
      if (!mounted) return;
      AppStateScope.read(context).updateWaste((draft) {
        draft.reset();
        draft.kind = WasteKind.tagging;
        draft.zone = _zone;
        draft.containerType = taggingType;
        draft.primarySite = _site!.name;
        draft.primarySiteId = _site!.id;
        draft.containerId = _container?.containerId;
        draft.containerName = _targetLabel;
        draft.latitude = _deviceLat;
        draft.longitude = _deviceLng;
        draft.recordId = saved.id;
        draft.beforePhotos.add(upload);
        draft.savedAt = DateTime.now();
      });
      AppStateScope.read(context).noteWasteSynced();
      if (!mounted) return;
      _snack(saved.message ?? 'Container tagged.');
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
      bottom: PrimaryButton(
        label: 'Save Tag',
        loading: _saving,
        onPressed: _canSubmit ? _save : null,
      ),
      body: _loadingCatalog
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: LoadingSkeletonGroup(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                const _HeroCard(),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  InlineMessage(tone: InlineTone.error, message: _error!),
                ],
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Selection',
                  subtitle:
                      'Zone → site → type auto-fills from that site (1.1 m3 / 8 m3). UC not required.',
                  child: Column(
                    children: [
                      DropdownField(
                        label: 'Zone',
                        hint: 'Select Zone-4 or Zone-5',
                        items: _zones,
                        value: _zone,
                        onChanged: _onZone,
                      ),
                      const SizedBox(height: 14),
                      if (_loadingSites)
                        const _InlineLoader(label: 'Loading primary sites…')
                      else
                        DropdownField(
                          label: 'Site',
                          hint: !_zoneDone
                              ? 'Select zone first'
                              : (_sites.isEmpty ? 'No sites in this zone' : 'Select site'),
                          items: [for (final s in _sites) s.name],
                          value: _site?.name,
                          enabled: _zoneDone && _sites.isNotEmpty && !_saving,
                          onChanged: _onSite,
                        ),
                      const SizedBox(height: 14),
                      if (_loadingContainers)
                        const _InlineLoader(label: 'Loading container type…')
                      else
                        DropdownField(
                          label: 'Container Type *',
                          hint: !_siteDone
                              ? 'Select site first'
                              : (_typeValid
                                  ? 'Auto from site — change if needed'
                                  : 'Required — select 1.1 m3 or 8 m3'),
                          items: _types.isEmpty
                              ? WasteCatalog.inventoryContainerTypes
                              : _types,
                          value: _containerType,
                          enabled: _siteDone && !_saving,
                          errorText: _siteDone && _typeDone && !_typeValid
                              ? 'Select 1.1 m3 or 8 m3'
                              : null,
                          onChanged: (value) => setState(() => _containerType = value),
                        ),
                      const SizedBox(height: 14),
                      if (_loadingContainers)
                        const SizedBox.shrink()
                      else if (_containers.isNotEmpty)
                        DropdownField(
                          label: 'Container',
                          hint: 'Select container',
                          items: [for (final c in _containers) c.containerName],
                          value: _container?.containerName,
                          enabled: _siteDone && !_saving,
                          onChanged: _onContainer,
                        )
                      else if (_siteDone)
                        const InlineMessage(
                          tone: InlineTone.info,
                          message:
                              'No inventory containers under this site — tagging will use the primary site itself. Pick type if it did not auto-fill.',
                        ),
                    ],
                  ),
                ),
                if (_container != null) ...[
                  const SizedBox(height: 14),
                  _ContainerSummaryCard(
                    container: _container!,
                    siteName: _site?.name,
                    pinLat: _pinLat,
                    pinLng: _pinLng,
                  ),
                ] else if (_siteOnlyMode && _site != null) ...[
                  const SizedBox(height: 14),
                  _SiteSummaryCard(
                    site: _site!,
                    pinLat: _pinLat,
                    pinLng: _pinLng,
                  ),
                ],
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Live GPS',
                  subtitle: 'Device location is saved as the tagged position.',
                  child: Opacity(
                    opacity: _targetReady ? 1 : 0.55,
                    child: IgnorePointer(
                      ignoring: !_targetReady,
                      child: LocationCard(
                        latitude: _deviceLat,
                        longitude: _deviceLng,
                        loading: _locating,
                        onGetLocation: _locate,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: 'Container photo',
                  subtitle: 'One clear photo. Camera (front/back) or gallery.',
                  child: Opacity(
                    opacity: _gpsDone ? 1 : 0.55,
                    child: IgnorePointer(
                      ignoring: !_gpsDone,
                      child: PhotoUploader(
                        title: 'Photo',
                        hint: 'Take Photo',
                        caption: _gpsDone
                            ? 'Exactly one picture required.'
                            : 'Fetch GPS first, then add a photo.',
                        maxPhotos: 1,
                        photos: _photo == null ? const [] : [_photo!],
                        onAdd: _onPhoto,
                        onRemove: (_) => setState(() => _photo = null),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const InlineMessage(
                  tone: InlineTone.info,
                  message:
                      'Saving marks this container as tagged on the portal and stores your GPS with the photo.',
                ),
              ],
            ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

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
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tagging of Containers',
                  style: AppType.section.copyWith(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Zone → site → type auto-fills → GPS → one photo.',
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

class _ContainerSummaryCard extends StatelessWidget {
  const _ContainerSummaryCard({
    required this.container,
    required this.siteName,
    required this.pinLat,
    required this.pinLng,
  });

  final TaggingContainer container;
  final String? siteName;
  final double? pinLat;
  final double? pinLng;

  @override
  Widget build(BuildContext context) {
    final tagged = container.isTagged;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FAF7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: const Color(0xFFC7E8D9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  container.containerName,
                  style: AppType.section.copyWith(fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tagged ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tagged ? 'Tagged' : 'Not tagged',
                  style: AppType.caption.copyWith(
                    color: tagged ? AppColors.success : const Color(0xFFC2410C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (siteName != null) ...[
            const SizedBox(height: 6),
            Text(siteName!, style: AppType.caption),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniCoord(
                  label: 'Stored lat',
                  value: pinLat?.toStringAsFixed(6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniCoord(
                  label: 'Stored lng',
                  value: pinLng?.toStringAsFixed(6),
                ),
              ),
            ],
          ),
          if (pinLat != null && pinLng != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 160,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(pinLat!, pinLng!),
                    initialZoom: 16,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'pk.gov.cda.cda_clean_islamabad',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(pinLat!, pinLng!),
                          width: 36,
                          height: 36,
                          alignment: Alignment.bottomCenter,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.emerald,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (container.taggingDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last tagged: ${container.taggingDate}',
              style: AppType.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _SiteSummaryCard extends StatelessWidget {
  const _SiteSummaryCard({
    required this.site,
    this.pinLat,
    this.pinLng,
  });

  final TaggingPrimarySite site;
  final double? pinLat;
  final double? pinLng;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: const Color(0xFFC7E8D9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(site.name, style: AppType.section.copyWith(fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            'Primary site (no child containers)',
            style: AppType.caption,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniCoord(
                  label: 'Stored lat',
                  value: pinLat?.toStringAsFixed(6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniCoord(
                  label: 'Stored lng',
                  value: pinLng?.toStringAsFixed(6),
                ),
              ),
            ],
          ),
          if (pinLat != null && pinLng != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 160,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(pinLat!, pinLng!),
                    initialZoom: 16,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'pk.gov.cda.cda_clean_islamabad',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(pinLat!, pinLng!),
                          width: 36,
                          height: 36,
                          alignment: Alignment.bottomCenter,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.emerald,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniCoord extends StatelessWidget {
  const _MiniCoord({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7EBE2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.caption),
          const SizedBox(height: 4),
          Text(
            value ?? '—',
            style: AppType.body.copyWith(
              fontWeight: FontWeight.w600,
              color: value == null ? AppColors.disabledText : AppColors.textPrimary,
            ),
          ),
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
