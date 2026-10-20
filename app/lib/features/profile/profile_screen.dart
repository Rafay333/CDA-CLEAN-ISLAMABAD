import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_copy.dart';
import '../../constants/app_routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

Future<void> confirmSignOut(BuildContext context) async {
  final state = AppStateScope.read(context);
  final pending = state.hasPendingSync;
  final confirmed = await ConfirmationDialog.show(
    context,
    title: 'Sign out?',
    message: pending
        ? 'A record on this phone was not saved to the server. Sign out drops it.'
        : 'You will return to the login screen.',
    confirmLabel: 'Sign out',
  );
  if (!confirmed || !context.mounted) return;
  await AppStateScope.read(context).clearSession();
  if (!context.mounted) return;
  context.go(AppRoutes.login);
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AppStateScope.of(context).profile;
    return AppPage(
      title: 'Profile',
      showBack: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          ProfileCard(
            name: profile.name,
            subtitle: AppStateScope.of(context).session?.contractorName ?? AppCopy.roleLabel,
            onAvatarTap: () => context.push(AppRoutes.profileDetails),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the photo to view profile details.',
            style: AppType.caption,
          ),
          const SizedBox(height: 16),
          ListItem(
            title: 'Profile details',
            subtitle: 'Name, father name, CNIC, mobile, date of birth',
            leading: const Icon(Icons.badge_outlined, color: AppColors.navy),
            onTap: () => context.push(AppRoutes.profileDetails),
          ),
          const SizedBox(height: 18),
          OutlineButton(label: 'Sign out', onPressed: () => confirmSignOut(context)),
          const SizedBox(height: 10),
          const AppVersionLabel(),
        ],
      ),
    );
  }
}
