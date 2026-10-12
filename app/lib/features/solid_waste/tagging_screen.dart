import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'waste_catalog.dart';

class TaggingScreen extends StatefulWidget {
  const TaggingScreen({super.key});

  @override
  State<TaggingScreen> createState() => _TaggingScreenState();
}

class _TaggingScreenState extends State<TaggingScreen> {
  String? _tagging = WasteCatalog.containerTagging;
  String? _containerType;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _clear() {
    setState(() {
      _tagging = WasteCatalog.containerTagging;
      _containerType = null;
    });
  }

  void _save() {
    if (_tagging == null) {
      _snack('Select tagging of containers.');
      return;
    }
    if (_containerType == null) {
      _snack('Select the container type.');
      return;
    }
    _snack('Tagging is not accepted by the supervisor server, so this record was not saved.');
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
      bottom: PrimaryButton(label: 'Save Record', onPressed: _save),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Tagging of containers is selected once for this record.',
            style: AppType.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          DropdownField(
            label: 'Tagging',
            hint: 'Select tagging',
            items: const [WasteCatalog.containerTagging],
            value: _tagging,
            onChanged: (value) => setState(() => _tagging = value),
          ),
          const SizedBox(height: 14),
          DropdownField(
            label: 'Container Type',
            hint: 'Select container type',
            items: WasteCatalog.containerTypes,
            value: _containerType,
            onChanged: (value) => setState(() => _containerType = value),
          ),
        ],
      ),
    );
  }
}
