import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../constants/app_copy.dart';
import '../../state/app_state.dart';
import '../../utils/display_format.dart';

class ProfileDetailsScreen extends StatelessWidget {
  const ProfileDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AppStateScope.of(context).profile;
    return AppPage(
      title: 'Profile Details',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Center(child: AppAvatar(name: profile.name, size: 84)),
          const SizedBox(height: 16),
          InfoCard(
            label: 'Name',
            value: displayOr(profile.name, AppCopy.notProvided),
          ),
          const SizedBox(height: 8),
          InfoCard(
            label: 'Father name',
            value: displayOr(profile.fatherName, AppCopy.notProvided),
          ),
          const SizedBox(height: 8),
          InfoCard(
            label: 'CNIC',
            value: displayOr(profile.cnic, AppCopy.notProvided),
          ),
          const SizedBox(height: 8),
          InfoCard(
            label: 'Address',
            value: displayOr(profile.address, AppCopy.notProvided),
          ),
          const SizedBox(height: 8),
          InfoCard(
            label: 'Mobile number',
            value: displayOr(profile.mobile, AppCopy.notProvided),
          ),
          const SizedBox(height: 8),
          InfoCard(
            label: 'Date of birth',
            value: profile.dob == null
                ? AppCopy.notProvided
                : formatDate(profile.dob!),
          ),
        ],
      ),
    );
  }
}
