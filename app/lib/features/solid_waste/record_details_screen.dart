import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_copy.dart';
import '../../constants/app_routes.dart';
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
    final standard = _isStandard(waste);
    return AppPage(
      title: 'Record Details',
      bottom: standard
          ? OutlineButton(
              label: 'Upload After Photo',
              onPressed: () => context.push(AppRoutes.primaryRecord),
            )
          : null,
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
            for (final group in waste.ucGroups) ...[
              const SizedBox(height: 8),
              InfoCard(
                label: 'UC',
                value: displayOr(group.uc, AppCopy.notSelected),
              ),
              const SizedBox(height: 12),
              _PhotoStrip(
                title: 'Pictures',
                photos: group.photos,
                emptyLabel: 'No picture',
              ),
            ],
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
              label: 'Primary Site',
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
          if (waste.kind == WasteKind.bulk) ...[
            const SizedBox(height: 18),
            _PhotoStrip(
              title: 'Pictorial Evidence',
              photos: waste.beforePhotos,
              emptyLabel: 'No picture',
            ),
          ],
          if (standard) ..._standardCards(waste),
          if (waste.kind == WasteKind.primary &&
              (waste.containerType ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            InfoCard(label: 'Activity', value: waste.containerType!),
          ],
          if (standard || waste.zeroWaste) ...[
            const SizedBox(height: 18),
            _PhotoStrip(
              title: 'Before Photo',
              photos: waste.beforePhotos,
              emptyLabel: 'No before photo',
            ),
            const SizedBox(height: 16),
            _PhotoStrip(
              title: 'After Photo',
              photos: waste.afterPhotos,
              emptyLabel: 'No after photo',
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

  bool _isStandard(WasteDraft waste) {
    if (waste.kind == WasteKind.activity ||
        waste.kind == WasteKind.tagging ||
        waste.kind == WasteKind.bulk) {
      return false;
    }
    return !waste.zeroWaste;
  }

  String _kindLabel(WasteDraft waste) {
    if (waste.zeroWaste) return 'Zero Waste';
    final kind = waste.kind == WasteKind.none ? WasteKind.primary : waste.kind;
    return wasteKindLabel(kind);
  }

  String _headline(WasteDraft waste) {
    if (waste.kind == WasteKind.activity) {
      return displayOr(waste.activity, AppCopy.notSelected);
    }
    if (waste.kind == WasteKind.tagging) return 'Tagging of Containers';
    if (waste.kind == WasteKind.bulk) return 'General pictorial evidence';
    if (waste.zeroWaste) return displayOr(waste.tcpName, AppCopy.notSelected);
    return displayOr(waste.primarySite, AppCopy.notSelected);
  }

  List<Widget> _standardCards(WasteDraft waste) {
    return [
      const SizedBox(height: 8),
      InfoCard(
        label: 'Area',
        value: displayOr(waste.area, AppCopy.notSelected),
      ),
      const SizedBox(height: 8),
      InfoCard(label: 'UC', value: displayOr(waste.uc, AppCopy.notSelected)),
      const SizedBox(height: 8),
      InfoCard(
        label: 'Location',
        value: displayOr(waste.location, AppCopy.locationNotSelected),
      ),
      const SizedBox(height: 8),
      InfoCard(
        label: 'Vehicle Type',
        value: displayOr(waste.vehicleType, AppCopy.notSelected),
      ),
      const SizedBox(height: 8),
      InfoCard(
        label: 'Vehicle Number',
        value: displayOr(waste.vehicleNumber, AppCopy.notProvided),
      ),
      const SizedBox(height: 8),
      InfoCard(
        label: 'Date & Time',
        value: waste.savedAt == null
            ? AppCopy.notAvailable
            : formatDateTime(waste.savedAt!),
      ),
      const SizedBox(height: 8),
      InfoCard(
        label: 'Coordinates',
        value: waste.latitude == null
            ? AppCopy.locationNotSelected
            : '${waste.latitude}, ${waste.longitude}',
      ),
    ];
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
