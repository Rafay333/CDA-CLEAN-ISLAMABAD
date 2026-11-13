import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/components.dart';
import '../../constants/app_copy.dart';
import '../../constants/app_routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_typography.dart';
import '../../utils/display_format.dart';

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
    final state = AppStateScope.of(context);
    final profile = state.profile;
    final session = state.session;
    final contractor = session?.contractorName ?? profile.contractorName;
    final cnic = displayOr(profile.cnic.isEmpty ? session?.cnic : profile.cnic, AppCopy.notProvided);
    final mobile = displayOr(profile.mobile, AppCopy.notProvided);
    final account = displayOr(
      profile.accountType.isNotEmpty ? profile.accountType : session?.roleLabel,
      AppCopy.roleLabel,
    );

    return AppPage(
      title: 'Profile',
      showBack: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _ProfileHero(
            name: displayOr(profile.name, AppCopy.roleLabel),
            subtitle: displayOr(contractor, AppCopy.roleLabel),
            onTap: () => context.push(AppRoutes.profileDetails),
          ),
          const SizedBox(height: 16),
          ModulePanel(
            title: 'Account overview',
            subtitle: 'Tap below to edit father name, mobile and date of birth.',
            accent: ModulePalette.profileAccent,
            child: ModuleMetaCard(
              accent: ModulePalette.profileAccent,
              rows: [
                (Icons.badge_outlined, 'CNIC', cnic),
                (Icons.call_outlined, 'Mobile', mobile),
                (Icons.business_outlined, 'Contractor', displayOr(contractor, AppCopy.notProvided)),
                (Icons.verified_user_outlined, 'Account', account),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ModuleMenuCard(
            icon: Icons.badge_outlined,
            accent: ModulePalette.profileAccent,
            badge: const Color(0xFFE5F6F4),
            title: 'Profile details',
            subtitle: 'Name, father name, CNIC, mobile, date of birth',
            onTap: () => context.push(AppRoutes.profileDetails),
          ),
          if (state.hasPendingSync) ...[
            const SizedBox(height: 14),
            const InlineMessage(
              tone: InlineTone.warning,
              message: 'A record on this phone is still waiting to sync to the server.',
            ),
          ],
          const SizedBox(height: 22),
          OutlineButton(
            label: 'Sign out',
            icon: Icons.logout_rounded,
            onPressed: () => confirmSignOut(context),
          ),
          const SizedBox(height: 14),
          const Center(child: AppVersionLabel()),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: ModulePalette.profile,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x33123B5D), blurRadius: 18, offset: Offset(0, 8)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 2),
                  ),
                  child: AppAvatar(name: name, size: 78, onTap: onTap),
                ),
                const SizedBox(height: 14),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: AppType.section.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: AppType.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_outlined, color: Colors.white, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'View & edit profile',
                        style: AppType.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
