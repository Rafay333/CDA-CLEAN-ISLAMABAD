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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          ModuleHero(
            icon: waste.kind == WasteKind.tagging
                ? Icons.sell_outlined
                : Icons.assignment_outlined,
            title: _headline(waste),
            subtitle: onServer
                ? 'Saved on the server${waste.savedAt == null ? '' : ' · ${formatDateTime(waste.savedAt!)}'}'
                : 'Pending sync to the server',
            colors: ModulePalette.waste,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: ModuleStatusChip(
              label: onServer ? 'Saved' : 'Pending',
              color: onServer ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(height: 14),
          ModulePanel(
            title: _kindLabel(waste),
            child: ModuleMetaCard(
              rows: [
                if (waste.kind == WasteKind.activity) ...[
                  (Icons.assignment_outlined, 'Activity', displayOr(waste.activity, AppCopy.notSelected)),
                  (Icons.map_outlined, 'Zone', displayOr(waste.zone, AppCopy.notSelected)),
                  if ((waste.uc ?? '').isNotEmpty)
                    (Icons.location_city_outlined, 'UC', displayOr(waste.uc, AppCopy.notSelected)),
                  if ((waste.containerName ?? '').isNotEmpty)
                    (Icons.delete_outline, 'Container', displayOr(waste.containerName, AppCopy.notSelected)),
                  if ((waste.containerType ?? '').isNotEmpty)
                    (Icons.category_outlined, 'Type', displayOr(waste.containerType, AppCopy.notSelected)),
                ],
                if (waste.kind == WasteKind.tagging) ...[
                  (Icons.map_outlined, 'Zone', displayOr(waste.zone, AppCopy.notSelected)),
                  (Icons.category_outlined, 'Type', displayOr(waste.containerType, AppCopy.notSelected)),
                  (Icons.place_outlined, 'Site', displayOr(waste.primarySite, AppCopy.notSelected)),
                  (
                    Icons.delete_outline,
                    'Container',
                    displayOr(
                      waste.containerName ??
                          (waste.containerId == null ? null : '#${waste.containerId}'),
                      AppCopy.notSelected,
                    )
                  ),
                  (
                    Icons.my_location_outlined,
                    'GPS',
                    displayOr(
                      [
                        if ((waste.latitude ?? '').isNotEmpty) 'Lat ${waste.latitude}',
                        if ((waste.longitude ?? '').isNotEmpty) 'Lng ${waste.longitude}',
                      ].join(' · '),
                      AppCopy.notSelected,
                    )
                  ),
                ],
              ],
            ),
          ),
          if (waste.kind == WasteKind.activity) ...[
            const SizedBox(height: 14),
            if (waste.afterPhotos.isEmpty)
              ModulePanel(
                title: 'Pictures',
                child: _PhotoStrip(photos: waste.beforePhotos, emptyLabel: 'No picture'),
              )
            else ...[
              ModulePanel(
                title: 'Before',
                child: _PhotoStrip(photos: waste.beforePhotos, emptyLabel: 'No before picture'),
              ),
              const SizedBox(height: 14),
              ModulePanel(
                title: 'After',
                child: _PhotoStrip(photos: waste.afterPhotos, emptyLabel: 'No after picture'),
              ),
            ],
          ],
          if (waste.kind == WasteKind.tagging) ...[
            const SizedBox(height: 14),
            ModulePanel(
              title: 'Tagging photo',
              child: _PhotoStrip(photos: waste.beforePhotos, emptyLabel: 'No picture'),
            ),
          ],
          if (waste.remarks.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            ModulePanel(
              title: 'Remarks',
              child: Text(waste.remarks),
            ),
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
    required this.photos,
    required this.emptyLabel,
  });

  final List<LocalPhoto> photos;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return PhotoCard(index: 0, emptyLabel: emptyLabel);
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => PhotoCard(index: index),
      ),
    );
  }
}
