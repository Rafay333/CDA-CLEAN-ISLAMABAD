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
  final List<UcPhotoGroup> _groups = [UcPhotoGroup()];
  List<EvidenceActivity> _activities = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
      final rows = await SupervisorApi().activities();
      if (!mounted) return;
      setState(() => _activities = rows);
    } on SupervisorException catch (error) {
      if (!mounted) return;
      _snack(error.message);
    }
  }

  int get _photoCount => _groups.fold<int>(0, (sum, group) => sum + group.photos.length);

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _clear() {
    setState(() {
      _activity = null;
      _zone = null;
      _groups.clear();
      _groups.add(UcPhotoGroup());
    });
  }

  void _addGroup() {
    if (_zone == null) {
      _snack('Select a zone first.');
      return;
    }
    setState(() => _groups.add(UcPhotoGroup()));
  }

  void _addPhoto(UcPhotoGroup group, LocalPhoto photo) {
    if (_photoCount >= 10) {
      _snack('The server accepts 10 photos at a time.');
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

  Future<void> _save() async {
    final selected = _activities.cast<EvidenceActivity?>().where((item) => item!.activity == _activity).firstOrNull;
    if (selected == null) {
      _snack('Select an activity.');
      return;
    }
    final photos = [for (final group in _groups) ...group.photos];
    final uploads = uploadPhotos(photos);
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
      final geo = await currentGeoTag();
      final saved = await SupervisorApi().uploadEvidence(
        cnic: session.cnic,
        activityCode: selected.code,
        photos: uploads,
        geoTag: geo,
      );
      if (!mounted) return;
      AppStateScope.read(context).updateWaste((draft) {
        draft.reset();
        draft.kind = WasteKind.activity;
        draft.activity = selected.activity;
        draft.zone = _zone;
        draft.area = 'Rural';
        draft.ucGroups.addAll(_groups);
        draft.savedAt = DateTime.now();
      });
      AppStateScope.read(context).noteWasteSynced();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved.message)));
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
    const rule = 'Up to 10 photos. They are saved on the server for this activity.';

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
          DropdownField(
            label: 'Activity',
            hint: 'Select activity',
            items: [for (final item in _activities) item.activity],
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
          const SizedBox(height: 18),
          const SectionHeader(title: 'Pictures'),
          const SizedBox(height: 6),
          Text(rule, style: AppType.caption),
          const SizedBox(height: 12),
          for (var index = 0; index < _groups.length; index++) ...[
            _UcPictureCard(
              index: index,
              group: _groups[index],
              zoneSelected: _zone != null,
              ucItems: _ucChoices(index),
              limit: 10,
              canRemove: _groups.length > 1,
              onUc: (value) => setState(() => _groups[index].uc = value),
              onAdd: (photo) => _addPhoto(_groups[index], photo),
              onRemovePhoto: (id) => _removePhoto(_groups[index], id),
              onRemoveCard: () => setState(() => _groups.removeAt(index)),
            ),
            const SizedBox(height: 12),
          ],
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
    );
  }
}

class _UcPictureCard extends StatelessWidget {
  const _UcPictureCard({
    required this.index,
    required this.group,
    required this.zoneSelected,
    required this.ucItems,
    required this.limit,
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
  final int? limit;
  final bool canRemove;
  final ValueChanged<String> onUc;
  final ValueChanged<LocalPhoto> onAdd;
  final ValueChanged<String> onRemovePhoto;
  final VoidCallback onRemoveCard;

  @override
  Widget build(BuildContext context) {
    final over = limit != null && group.photos.length > limit!;
    final caption = over
        ? 'Remove the extra pictures. This activity allows $limit for this UC.'
        : limit == null
        ? 'Unlimited pictures'
        : '$limit pictures for this UC';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: over ? AppColors.error : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'UC ${index + 1}',
                style: AppType.section.copyWith(fontSize: 15),
              ),
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
            caption: caption,
            captionColor: over ? AppColors.error : null,
            photos: group.photos,
            maxPhotos: over ? group.photos.length : limit,
            onAdd: onAdd,
            onRemove: onRemovePhoto,
          ),
        ],
      ),
    );
  }
}
