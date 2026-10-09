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
    final waste = AppStateScope.of(context).waste;
    final siteValue = waste.primarySite;
    return AppPage(
      title: 'Record Details',
      bottom: OutlineButton(
        label: 'Upload After Photo',
        onPressed: () => context.push(AppRoutes.primaryRecord),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              const StatusBadge(label: 'Pending', color: AppColors.warning),
              const Spacer(),
              if (waste.savedAt != null)
                Text(
                  formatDateTime(waste.savedAt!),
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 16),
          InfoCard(
            label: wasteKindLabel(
              waste.kind == WasteKind.none ? WasteKind.primary : waste.kind,
            ),
            value: displayOr(siteValue, AppCopy.notSelected),
          ),
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
          const SizedBox(height: 18),
          const SectionHeader(title: 'Before Photo'),
          const SizedBox(height: 8),
          if (waste.beforePhotos.isEmpty)
            const PhotoCard(index: 0, emptyLabel: 'No before photo')
          else
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: waste.beforePhotos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) => PhotoCard(index: index),
              ),
            ),
          const SizedBox(height: 16),
          const SectionHeader(title: 'After Photo'),
          const SizedBox(height: 8),
          if (waste.afterPhotos.isEmpty)
            const PhotoCard(index: 0, emptyLabel: 'No after photo')
          else
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: waste.afterPhotos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) => PhotoCard(index: index),
              ),
            ),
          if (waste.remarks.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            InfoCard(label: 'Remarks', value: waste.remarks),
          ],
        ],
      ),
    );
  }
}
