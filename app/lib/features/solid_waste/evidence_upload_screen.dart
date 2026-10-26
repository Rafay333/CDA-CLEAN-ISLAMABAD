import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

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

  Future<void> _save() async {
    final selected = _selected;
    if (selected == null) {
      _snack('Select an activity.');
      return;
    }
    final uploads = uploadPhotos(_photos);
    if (uploads.isEmpty) {
      _snack('Add a photo from the camera or gallery.');
      return;
    }
    if (uploads.length > 10) {
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
                if (_error != null) ...[
                  InlineMessage(tone: InlineTone.error, message: _error!),
                  const SizedBox(height: 14),
                ],
                Text(
                  'Geo-tagged photos for $_date. Up to 10 images in one upload.',
                  style: AppType.body.copyWith(color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                if (locked)
                  InfoCard(
                    label: ped == null ? 'Activity' : 'PED $ped',
                    value: selected?.activity ?? widget.args?.activity ?? 'Activity',
                    icon: Icons.assignment_outlined,
                  )
                else
                  DropdownField(
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
                if (hitsPed) ...[
                  const SizedBox(height: 10),
                  const InlineMessage(
                    tone: InlineTone.info,
                    message: 'This activity scores the Digital Pictorial Evidence subfactor (15%) after PED is regenerated for this date.',
                  ),
                ],
                const SizedBox(height: 16),
                LocationCard(
                  latitude: lat,
                  longitude: lng,
                  loading: _locating,
                  onGetLocation: _locate,
                ),
                const SizedBox(height: 16),
                PhotoUploader(
                  title: 'Pictures',
                  hint: 'Capture or upload',
                  caption: 'jpg, jpeg, png or webp. Maximum 10.',
                  maxPhotos: 10,
                  photos: _photos,
                  onAdd: (photo) => setState(() => _photos.add(photo)),
                  onRemove: (id) => setState(() => _photos.removeWhere((photo) => photo.id == id)),
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
