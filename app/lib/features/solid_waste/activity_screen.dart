import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_routes.dart';
import '../../core/supervisor_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'waste_catalog.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String? _activity;
  String? _zone;
  String? _lat;
  String? _lng;
  bool _locating = false;
  final List<UcPhotoGroup> _groups = [UcPhotoGroup()];
  List<CatalogActivity> _activities = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final session = AppStateScope.read(context).session;
    try {
      await WasteCatalog.ensureLoaded(cnic: session?.cnic);
      var rows = List<CatalogActivity>.from(WasteCatalog.activities);
      if (rows.isEmpty && session != null) {
        final evidence = await SupervisorApi().activities();
        rows = [
          for (final item in evidence)
            CatalogActivity(code: item.code, name: item.activity, unlimitedPictures: false),
        ];
      }
      if (!mounted) return;
      setState(() => _activities = rows);
    } on SupervisorException catch (error) {
      if (!mounted) return;
      _snack(error.message);
    }
    await _locate();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _clear() {
    setState(() {
      _activity = null;
      _zone = null;
      _lat = null;
      _lng = null;
      _groups.clear();
      _groups.add(UcPhotoGroup());
    });
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

  void _addGroup() {
    if (_zone == null) {
      _snack('Select a zone first.');
      return;
    }
    setState(() => _groups.add(UcPhotoGroup()));
  }

  void _addPhoto(UcPhotoGroup group, LocalPhoto photo) {
    final limit = WasteCatalog.pictureLimit(_selectedActivity()?.name ?? _activity);
    if (limit != null && group.photos.length >= limit) {
      _snack('This activity allows $limit picture${limit == 1 ? '' : 's'} per UC.');
      return;
    }
    setState(() => group.photos.add(photo));
  }

  void _removePhoto(UcPhotoGroup group, String id) {
    setState(() => group.photos.removeWhere((photo) => photo.id == id));
  }

  List<String> _ucChoices(int index) {
    final taken = <String>{
      for (var i = 0; i < _groups.length; i++)
        if (i != index && _groups[i].uc != null) _groups[i].uc!,
    };
    return [
      for (final uc in WasteCatalog.ucsFor(_zone))
        if (!taken.contains(uc)) uc,
    ];
  }

  String _label(CatalogActivity item) => item.name;

  CatalogActivity? _selectedActivity() {
    for (final item in _activities) {
      if (item.name == _activity || item.code == _activity) return item;
    }
    return null;
  }

  Future<void> _save() async {
    final selected = _selectedActivity();
    if (selected == null) {
      _snack('Select an activity.');
      return;
    }
    if (_zone == null) {
      _snack('Select a zone.');
      return;
    }
    for (final group in _groups) {
      if (group.photos.isNotEmpty && (group.uc == null || group.uc!.isEmpty)) {
        _snack('Select a union council for each set of pictures.');
        return;
      }
    }
    final filled = [for (final group in _groups) if (group.uc != null && group.photos.isNotEmpty) group];
    if (filled.isEmpty) {
      _snack('Add a photo from the camera or gallery.');
      return;
    }
    final limit = WasteCatalog.pictureLimit(selected.name);
    for (final group in filled) {
      if (limit != null && group.photos.length > limit) {
        _snack('This activity allows $limit picture${limit == 1 ? '' : 's'} per UC.');
        return;
      }
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
        kind: 'activity',
        activity: selected.name,
        activityCode: selected.code,
        zoneCode: _zone,
        latitude: _lat,
        longitude: _lng,
        groups: [
          for (final group in filled)
            (ucCode: group.uc!, photos: uploadPhotos(group.photos)),
        ],
      );
      if (!mounted) return;
      AppStateScope.read(context).updateWaste((draft) {
        draft.reset();
        draft.kind = WasteKind.activity;
        draft.activity = selected.name;
        draft.zone = _zone;
        draft.area = 'Rural';
        draft.latitude = _lat;
        draft.longitude = _lng;
        draft.recordId = saved.id;
        draft.ucGroups.addAll(filled);
        draft.savedAt = DateTime.now();
      });
      AppStateScope.read(context).noteWasteSynced();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved.message ?? 'Record saved.')));
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
    final selected = _selectedActivity();

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
      bottom: PrimaryButton(label: 'Save Record', loading: _saving, onPressed: _saving ? null : _save),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Activity, zone, union council, GPS and pictures are saved as one field record.',
            style: AppType.body.copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Activity card', style: AppType.section.copyWith(fontSize: 16)),
                if (selected != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    selected.unlimitedPictures
                        ? 'Unlimited pictures per UC'
                        : '${selected.pictureLimitPerUc} picture${selected.pictureLimitPerUc == 1 ? '' : 's'} per UC',
                    style: AppType.caption,
                  ),
                ],
                const SizedBox(height: 14),
                DropdownField(
                  label: 'Activity',
                  hint: 'Select activity',
                  items: [for (final item in _activities) _label(item)],
                  value: _activity,
                  onChanged: (value) => setState(() => _activity = value),
                ),
                const SizedBox(height: 14),
                DropdownField(
                  label: 'Zone',
                  hint: 'Select zone',
                  items: WasteCatalog.zones,
                  value: _zone,
                  onChanged: (value) {
                    setState(() {
                      _zone = value;
                      for (final group in _groups) {
                        group.uc = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                LocationCard(
                  latitude: _lat,
                  longitude: _lng,
                  loading: _locating,
                  onGetLocation: _locate,
                ),
                const SizedBox(height: 16),
                Text('Pictures', style: AppType.label),
                const SizedBox(height: 4),
                Text(
                  'Pictures are stored with this field record. PED daily photos stay on the evidence screen.',
                  style: AppType.caption,
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < _groups.length; index++) ...[
                  if (index > 0) const SizedBox(height: 12),
                  _UcBlock(
                    index: index,
                    group: _groups[index],
                    zoneSelected: _zone != null,
                    ucItems: _ucChoices(index),
                    remaining: () {
                      final limit = WasteCatalog.pictureLimit(_selectedActivity()?.name ?? _activity) ?? 99;
                      final left = limit - _groups[index].photos.length;
                      return left < 0 ? 0 : left;
                    }(),
                    canRemove: _groups.length > 1,
                    onUc: (value) => setState(() => _groups[index].uc = value),
                    onAdd: (photo) => _addPhoto(_groups[index], photo),
                    onRemovePhoto: (id) => _removePhoto(_groups[index], id),
                    onRemoveCard: () => setState(() => _groups.removeAt(index)),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _zone == null ? null : _addGroup,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add UC'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.teal,
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: AppColors.teal),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
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

class _UcBlock extends StatelessWidget {
  const _UcBlock({
    required this.index,
    required this.group,
    required this.zoneSelected,
    required this.ucItems,
    required this.remaining,
    required this.canRemove,
    required this.onUc,
    required this.onAdd,
    required this.onRemovePhoto,
    required this.onRemoveCard,
  });

  final int index;
  final UcPhotoGroup group;
  final bool zoneSelected;
  final List<String> ucItems;
  final int remaining;
  final bool canRemove;
  final ValueChanged<String> onUc;
  final ValueChanged<LocalPhoto> onAdd;
  final ValueChanged<String> onRemovePhoto;
  final VoidCallback onRemoveCard;

  @override
  Widget build(BuildContext context) {
    final limit = remaining < 0 ? 0 : remaining;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('UC ${index + 1}', style: AppType.section.copyWith(fontSize: 14)),
              const Spacer(),
              if (canRemove)
                IconButton(
                  tooltip: 'Remove UC',
                  onPressed: onRemoveCard,
                  icon: const Icon(Icons.close_rounded, color: AppColors.error),
                ),
            ],
          ),
          DropdownField(
            label: 'UC',
            hint: zoneSelected ? 'Select UC' : 'Select a zone first',
            items: ucItems,
            value: group.uc,
            enabled: zoneSelected,
            onChanged: onUc,
          ),
          const SizedBox(height: 14),
          PhotoUploader(
            title: 'Pictures',
            hint: 'Upload picture',
            caption: 'Up to $limit photo${limit == 1 ? '' : 's'} for this UC.',
            photos: group.photos,
            maxPhotos: group.photos.length + limit,
            onAdd: onAdd,
            onRemove: onRemovePhoto,
          ),
        ],
      ),
    );
  }
}
