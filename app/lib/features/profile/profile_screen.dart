import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_copy.dart';
import '../../constants/app_routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Sign out?',
      message: 'You will return to the login screen.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed || !context.mounted) return;
    AppStateScope.read(context).clearSession();
    context.go(AppRoutes.login);
  }

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
            subtitle: AppCopy.roleLabel,
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
            subtitle: 'Name, father name, CNIC, address, mobile, date of birth',
            leading: const Icon(Icons.badge_outlined, color: AppColors.navy),
            onTap: () => context.push(AppRoutes.profileDetails),
          ),
          const SizedBox(height: 18),
          OutlineButton(label: 'Sign out', onPressed: () => _signOut(context)),
        ],
      ),
    );
  }
}
