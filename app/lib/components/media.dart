import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'bottom_sheet.dart';

class PhotoUploader extends StatelessWidget {
  const PhotoUploader({
    super.key,
    required this.title,
    required this.hint,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    this.maxPhotos,
    this.caption,
    this.captionColor,
  });

  final String title;
  final String hint;
  final List<LocalPhoto> photos;
  final ValueChanged<LocalPhoto> onAdd;
  final ValueChanged<String> onRemove;
  final int? maxPhotos;
  final String? caption;
  final Color? captionColor;

  bool get _canAdd => maxPhotos == null || photos.length < maxPhotos!;

  @override
  Widget build(BuildContext context) {
    final canAdd = _canAdd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppType.label),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(
            caption!,
            style: captionColor == null
                ? AppType.caption
                : AppType.caption.copyWith(color: captionColor),
          ),
        ],
        const SizedBox(height: 8),
        if (photos.isEmpty)
          Material(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: canAdd ? () => _ask(context) : null,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 120),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_a_photo_outlined,
                      color: AppColors.teal,
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hint,
                      style: AppType.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Camera or gallery',
                      style: AppType.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length + (canAdd ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (canAdd && index == photos.length) {
                  return _AddTile(onTap: () => _ask(context));
                }
                return PhotoCard(
                  index: index,
                  photo: photos[index],
                  onRemove: () => onRemove(photos[index].id),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _ask(BuildContext context) async {
    if (!_canAdd) return;
    final source = await showAppSheet<ImageSource>(
      context,
      builder: (context) {
        return SheetScaffold(
          title: title,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(ImageSource.camera),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text('Camera', style: AppType.button.copyWith(color: AppColors.white)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source is! ImageSource || !context.mounted) return;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (file == null || !context.mounted) return;
      final bytes = await file.readAsBytes();
      if (!context.mounted) return;
      onAdd(
        LocalPhoto(
          DateTime.now().microsecondsSinceEpoch.toString(),
          bytes: bytes,
          filename: file.name,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The photo could not be opened.')),
      );
    }
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          width: 104,
          height: 112,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, color: AppColors.teal),
              const SizedBox(height: 4),
              Text(
                'Add',
                style: AppType.caption.copyWith(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PhotoCard extends StatelessWidget {
  const PhotoCard({
    super.key,
    required this.index,
    this.photo,
    this.onRemove,
    this.emptyLabel,
  });

  final int index;
  final LocalPhoto? photo;
  final VoidCallback? onRemove;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (emptyLabel != null) {
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 96),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(emptyLabel!, style: AppType.caption),
      );
    }
    return SizedBox(
      width: 104,
      height: 112,
      child: Stack(
        children: [
          Container(
            width: 104,
            height: 112,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF3F6),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: photo?.bytes == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.image_outlined, color: AppColors.navy, size: 26),
                      const SizedBox(height: 6),
                      Text(
                        'Photo ${index + 1}',
                        style: AppType.caption.copyWith(color: AppColors.navy),
                      ),
                    ],
                  )
                : Image.memory(photo!.bytes!, fit: BoxFit.cover, width: 104, height: 112),
          ),
          if (onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: AppColors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LocationCard extends StatelessWidget {
  const LocationCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.loading,
    required this.onGetLocation,
  });

  final String? latitude;
  final String? longitude;
  final bool loading;
  final VoidCallback onGetLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Location', style: AppType.label),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: loading ? null : onGetLocation,
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded, size: 18),
            label: Text(loading ? 'Getting location' : 'Get Live Location'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.info,
              side: const BorderSide(color: AppColors.sky),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Coord(label: 'Latitude', value: latitude),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Coord(label: 'Longitude', value: longitude),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Coord extends StatelessWidget {
  const _Coord({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final missing = value == null || value!.trim().isEmpty;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.caption),
          const SizedBox(height: 4),
          Text(
            missing ? '—' : value!,
            style: AppType.body.copyWith(
              fontWeight: FontWeight.w600,
              color: missing ? AppColors.disabledText : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
