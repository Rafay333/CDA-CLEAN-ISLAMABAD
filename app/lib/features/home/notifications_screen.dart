import 'package:flutter/material.dart';

import '../../components/components.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPage(
      title: 'Notifications',
      body: Center(
        child: EmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'No notifications',
          message: 'Alerts will appear here once they are connected.',
        ),
      ),
    );
  }
}
