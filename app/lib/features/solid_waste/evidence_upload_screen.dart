import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../utils/gps_photo_stamp.dart';

class EvidenceUploadArgs {
  const EvidenceUploadArgs({
    this.code,
    this.activity,
    this.date,
    this.pedSerial,
    this.hitsPed = false,
  });

  final String? code;
  final String? activity;
  final String? date;
  final String? pedSerial;
  final bool hitsPed;
}

class EvidenceUploadScreen extends StatefulWidget {
  const EvidenceUploadScreen({super.key, this.args});

  final EvidenceUploadArgs? args;

  @override
  State<EvidenceUploadScreen> createState() => _EvidenceUploadScreenState();
}

class _EvidenceUploadScreenState extends State<EvidenceUploadScreen> {
  final _photos = <LocalPhoto>[];
  List<EvidenceActivity> _activities = const [];
  String? _code;
  String? _geo;
  bool _loading = true;
  bool _saving = false;
  bool _locating = false;
  String? _error;

  EvidenceActivity? get _selected {
    for (final item in _activities) {
      if (item.code == _code) return item;
    }
    return null;
  }

  String get _date {
    return widget.args?.date ?? supervisorToday();
  }

  @override
  void initState() {
    super.initState();
    _code = widget.args?.code;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prepare();
    });
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _error = null;
      _locating = true;
    });
    try {
      final rows = await SupervisorApi().activities();
      rows.sort((a, b) {
        if (a.hitsPed != b.hitsPed) return a.hitsPed ? -1 : 1;
        return a.activity.compareTo(b.activity);
      });
      if (!mounted) return;
      setState(() {
        _activities = rows;
        _code ??= rows.where((item) => item.hitsPed).firstOrNull?.code ?? rows.firstOrNull?.code;
        _loading = false;
      });
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
    await _locate();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final geo = await currentGeoTag();
      if (!mounted) return;
      setState(() {
        _geo = geo;
        _locating = false;
      });
      if (geo == null) _snack('Enable live location, then try again.');
    } on SupervisorException catch (error) {
      if (!mounted) return;
      setState(() => _locating = false);
      _snack(error.message);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _gpsReady {
    final parts = (_geo ?? '').split(',');
    return parts.length >= 2 &&
        parts[0].trim().isNotEmpty &&
        parts[1].trim().isNotEmpty;
  }

  String? get _lat {
    final parts = (_geo ?? '').split(',');
    if (parts.isEmpty) return null;
    final value = parts.first.trim();
    return value.isEmpty ? null : value;
  }

  String? get _lng {
    final parts = (_geo ?? '').split(',');
    if (parts.length < 2) return null;
    final value = parts[1].trim();
    return value.isEmpty ? null : value;
  }

  String _stampedName(String? name) {
    final raw = (name ?? 'evidence.jpg').trim();
    final lower = raw.toLowerCase();
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp')) {
      final dot = raw.lastIndexOf('.');
      return '${raw.substring(0, dot)}_gps.png';
    }
    return '${raw}_gps.png';
  }

  Future<LocalPhoto> _stampPhoto(LocalPhoto photo) async {
    final lat = _lat;
    final lng = _lng;
    if (lat == null || lng == null || photo.bytes == null || photo.bytes!.isEmpty) return photo;
    final alreadyStamped = (photo.filename ?? '').toLowerCase().contains('_gps.');
    if (alreadyStamped) return photo;
    try {
      final stampedBytes = await stampGpsOnPhoto(
        photo.bytes!,
        latitude: lat,
        longitude: lng,
        title: _selected?.activity ?? 'PED evidence',
      );
      return LocalPhoto(
        photo.id,
        bytes: stampedBytes,
        filename: _stampedName(photo.filename),
      );
    } catch (_) {
      return photo;
    }
  }

  Future<void> _onAddPhoto(LocalPhoto photo) async {
    if (!_gpsReady) {
      _snack('Fetch your current GPS location first.');
      return;
    }
    if (_photos.length >= 10) {
      _snack('The server accepts 10 photos at a time.');
      return;
    }
    final stamped = await _stampPhoto(photo);
    if (!mounted) return;
    setState(() => _photos.add(stamped));
  }

  Future<void> _save() async {
    final selected = _selected;
    if (selected == null) {
      _snack('Select an activity.');
      return;
    }
    if (!_gpsReady) {
      _snack('Fetch your current GPS location.');
      return;
    }
    if (_photos.isEmpty) {
      _snack('Add a photo from the camera or gallery.');
      return;
    }
    if (_photos.length > 10) {
      _snack('The server accepts 10 photos at a time.');
      return;
    }
    final session = AppStateScope.read(context).session;
    if (session == null) {
      _snack('Sign in again.');
      return;
    }
    setState(() => _saving = true);
    try {
      final stamped = <LocalPhoto>[];
      for (final photo in _photos) {
        stamped.add(await _stampPhoto(photo));
      }
      if (!mounted) return;
      setState(() {
        _photos
          ..clear()
          ..addAll(stamped);
      });
      final uploads = uploadPhotos(stamped);
      if (uploads.isEmpty) {
        _snack('Add a photo from the camera or gallery.');
        return;
      }
      final geo = _geo ?? await currentGeoTag();
      final saved = await SupervisorApi().uploadEvidence(
        cnic: session.cnic,
        activityCode: selected.code,
        activity: selected.activity,
        photos: uploads,
        geoTag: geo,
        date: _date,
        verifiedBy: supervisorVerifiedBy(session),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved.message)));
      context.pop(true);
    } on SupervisorException catch (error) {
      if (!mounted) return;
      _snack(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.args?.code != null && widget.args!.code!.isNotEmpty;
    final selected = _selected;
    final parts = (_geo ?? '').split(',');
    final lat = parts.isNotEmpty && parts.first.trim().isNotEmpty ? parts.first.trim() : null;
    final lng = parts.length > 1 && parts[1].trim().isNotEmpty ? parts[1].trim() : null;
    final ped = selected?.pedSerial ?? widget.args?.pedSerial;
    final hitsPed = selected?.hitsPed ?? widget.args?.hitsPed ?? false;

    return AppPage(
      title: 'Daily PED evidence',
      bottom: PrimaryButton(
        label: 'Upload photos',
        loading: _saving,
        onPressed: _saving || _loading ? null : _save,
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: LoadingSkeletonGroup(),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                ModuleHero(
                  icon: Icons.photo_camera_outlined,
                  title: 'Daily PED evidence',
                  subtitle: 'Geo-tagged photos for $_date. Up to 10 images in one upload.',
                  colors: ModulePalette.waste,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  InlineMessage(tone: InlineTone.error, message: _error!),
                ],
                const SizedBox(height: 16),
                ModulePanel(
                  title: 'Activity',
                  child: locked
                      ? InfoCard(
                          label: ped == null ? 'Activity' : 'PED $ped',
                          value: selected?.activity ?? widget.args?.activity ?? 'Activity',
                          icon: Icons.assignment_outlined,
                        )
                      : DropdownField(
                          label: 'Activity',
                          hint: 'Select activity',
                          items: [for (final item in _activities) _label(item)],
                          value: selected == null ? null : _label(selected),
                          onChanged: (value) {
                            for (final item in _activities) {
                              if (_label(item) == value) {
                                setState(() => _code = item.code);
                                return;
                              }
                            }
                          },
                        ),
                ),
                if (hitsPed) ...[
                  const SizedBox(height: 10),
                  const InlineMessage(
                    tone: InlineTone.info,
                    message:
                        'This activity scores the Digital Pictorial Evidence subfactor (15%) after PED is regenerated for this date.',
                  ),
                ],
                const SizedBox(height: 14),
                ModulePanel(
                  title: 'Live location',
                  subtitle: 'Fetch GPS before capturing photos.',
                  child: LocationCard(
                    latitude: lat,
                    longitude: lng,
                    loading: _locating,
                    onGetLocation: _locate,
                  ),
                ),
                const SizedBox(height: 14),
                ModulePanel(
                  title: 'Pictures',
                  subtitle: 'Each photo is stamped with lat/long. Maximum 10.',
                  child: Opacity(
                    opacity: _gpsReady ? 1 : 0.55,
                    child: IgnorePointer(
                      ignoring: !_gpsReady,
                      child: PhotoUploader(
                        title: 'Pictures',
                        hint: 'Capture or upload',
                        caption: _gpsReady
                            ? 'Each photo is stamped with lat/long and place detail. Maximum 10.'
                            : 'Fetch GPS first, then capture. Photos are stamped like tagging.',
                        maxPhotos: 10,
                        photos: _photos,
                        onAdd: _onAddPhoto,
                        onRemove: (id) => setState(() => _photos.removeWhere((photo) => photo.id == id)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _label(EvidenceActivity item) {
    final serial = item.pedSerial;
    if (serial == null || serial.isEmpty) return item.activity;
    return '${item.activity} ($serial)';
  }
}
