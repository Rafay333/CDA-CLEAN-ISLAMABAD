import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../constants/app_copy.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/display_format.dart';

class RecordDetailsScreen extends StatelessWidget {
  const RecordDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final waste = state.waste;
    final onServer = waste.savedAt != null && !state.wastePendingSync;
    return AppPage(
      title: 'Record Details',
      bottom: null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              StatusBadge(
                label: onServer ? 'Saved' : 'Pending',
                color: onServer ? AppColors.success : AppColors.warning,
              ),
              const Spacer(),
              if (waste.savedAt != null)
                Text(
                  formatDateTime(waste.savedAt!),
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 16),
          InfoCard(label: _kindLabel(waste), value: _headline(waste)),
          if (waste.kind == WasteKind.activity) ...[
            const SizedBox(height: 8),
            InfoCard(
              label: 'Zone',
              value: displayOr(waste.zone, AppCopy.notSelected),
            ),
            if ((waste.uc ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              InfoCard(
                label: 'UC',
                value: displayOr(waste.uc, AppCopy.notSelected),
              ),
            ],
            if ((waste.containerName ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              InfoCard(
                label: 'Container',
                value: displayOr(waste.containerName, AppCopy.notSelected),
              ),
            ],
            if ((waste.containerType ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              InfoCard(
                label: 'Container Type',
                value: displayOr(waste.containerType, AppCopy.notSelected),
              ),
            ],
            const SizedBox(height: 12),
            _PhotoStrip(
              title: 'Before',
              photos: waste.beforePhotos,
              emptyLabel: 'No before picture',
            ),
            const SizedBox(height: 12),
            _PhotoStrip(
              title: 'After',
              photos: waste.afterPhotos,
              emptyLabel: 'No after picture',
            ),
          ],
          if (waste.kind == WasteKind.tagging) ...[
            const SizedBox(height: 8),
            InfoCard(
              label: 'Zone',
              value: displayOr(waste.zone, AppCopy.notSelected),
            ),
            const SizedBox(height: 8),
            InfoCard(
              label: 'Container Type',
              value: displayOr(waste.containerType, AppCopy.notSelected),
            ),
            const SizedBox(height: 8),
            InfoCard(
              label: 'Site',
              value: displayOr(waste.primarySite, AppCopy.notSelected),
            ),
            const SizedBox(height: 8),
            InfoCard(
              label: 'Container',
              value: displayOr(
                waste.containerName ??
                    (waste.containerId == null ? null : '#${waste.containerId}'),
                AppCopy.notSelected,
              ),
            ),
            const SizedBox(height: 8),
            InfoCard(
              label: 'GPS',
              value: displayOr(
                [
                  if ((waste.latitude ?? '').isNotEmpty) 'Lat ${waste.latitude}',
                  if ((waste.longitude ?? '').isNotEmpty) 'Lng ${waste.longitude}',
                ].join(' · '),
                AppCopy.notSelected,
              ),
            ),
            const SizedBox(height: 18),
            _PhotoStrip(
              title: 'Tagging photo',
              photos: waste.beforePhotos,
              emptyLabel: 'No picture',
            ),
          ],
          if (waste.remarks.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            InfoCard(label: 'Remarks', value: waste.remarks),
          ],
        ],
      ),
    );
  }

  String _kindLabel(WasteDraft waste) {
    if (waste.kind == WasteKind.none) return 'Record';
    return wasteKindLabel(waste.kind);
  }

  String _headline(WasteDraft waste) {
    if (waste.kind == WasteKind.activity) {
      return displayOr(waste.activity, AppCopy.notSelected);
    }
    if (waste.kind == WasteKind.tagging) return 'Tagging of Containers';
    return displayOr(waste.location ?? waste.uc, AppCopy.notSelected);
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.title,
    required this.photos,
    required this.emptyLabel,
  });

  final String title;
  final List<LocalPhoto> photos;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: 8),
        if (photos.isEmpty)
          PhotoCard(index: 0, emptyLabel: emptyLabel)
        else
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) => PhotoCard(index: index),
            ),
          ),
      ],
    );
  }
}
