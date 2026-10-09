import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../state/app_state.dart';

class AfterPhotoScreen extends StatefulWidget {
  const AfterPhotoScreen({super.key});

  @override
  State<AfterPhotoScreen> createState() => _AfterPhotoScreenState();
}

class _AfterPhotoScreenState extends State<AfterPhotoScreen> {
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(
      text: AppStateScope.read(context).complaint.followUp,
    );
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  void _add() {
    AppStateScope.read(context).updateComplaint((draft) {
      draft.afterPhotos.add(
        LocalPhoto(DateTime.now().microsecondsSinceEpoch.toString()),
      );
    });
  }

  void _remove(String id) {
    AppStateScope.read(context).updateComplaint((draft) {
      draft.afterPhotos.removeWhere((photo) => photo.id == id);
    });
  }

  void _submit() {
    AppStateScope.read(context).updateComplaint((draft) {
      draft.followUp = _description.text.trim();
    });
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final complaint = AppStateScope.of(context).complaint;
    return AppPage(
      title: 'After Photos',
      bottom: PrimaryButton(label: 'Submit', onPressed: _submit),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const SectionHeader(title: 'Before Photos'),
          const SizedBox(height: 8),
          if (complaint.photos.isEmpty)
            const PhotoCard(index: 0, emptyLabel: 'No before photos')
          else
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: complaint.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) => PhotoCard(index: index),
              ),
            ),
          const SizedBox(height: 16),
          PhotoUploader(
            title: 'After Photos',
            hint: 'Add More Photos',
            photos: complaint.afterPhotos,
            onAdd: _add,
            onRemove: _remove,
          ),
          const SizedBox(height: 16),
          TextInput(
            label: 'Description',
            controller: _description,
            hint: 'Enter description',
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}
