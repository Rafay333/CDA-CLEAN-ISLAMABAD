import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/components.dart';
import '../constants/app_routes.dart';
import '../features/authentication/forgot_password_screen.dart';
import '../features/authentication/login_screen.dart';
import '../features/authentication/splash_screen.dart';
import '../features/complaints/after_photo_screen.dart';
import '../features/complaints/complaint_details_screen.dart';
import '../features/complaints/complaint_list_screen.dart';
import '../features/complaints/complaint_map_screen.dart';
import '../features/complaints/complaints_home_screen.dart';
import '../features/complaints/submit_complaint_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/notifications_screen.dart';
import '../features/hr/attendance_log_screen.dart';
import '../features/hr/attendance_screen.dart';
import '../features/hr/hr_home_screen.dart';
import '../features/hr/worker_registration_screen.dart';
import '../features/profile/profile_details_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/solid_waste/activity_screen.dart';
import '../features/solid_waste/bulk_waste_screen.dart';
import '../features/solid_waste/primary_site_form_screen.dart';
import '../features/solid_waste/primary_site_record_screen.dart';
import '../features/solid_waste/record_details_screen.dart';
import '../features/solid_waste/solid_waste_home_screen.dart';
import '../features/solid_waste/tagging_screen.dart';
import '../features/solid_waste/transfer_station_screen.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileDetails,
        builder: (context, state) => const ProfileDetailsScreen(),
      ),
      GoRoute(
        path: AppRoutes.hr,
        builder: (context, state) => const HrHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.workerRegistration,
        builder: (context, state) => const WorkerRegistrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.attendance,
        builder: (context, state) => const AttendanceScreen(),
      ),
      GoRoute(
        path: AppRoutes.attendanceLog,
        builder: (context, state) => const AttendanceLogScreen(),
      ),
      GoRoute(
        path: AppRoutes.waste,
        builder: (context, state) => const SolidWasteHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.primarySite,
        builder: (context, state) => const PrimarySiteFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.primaryRecord,
        builder: (context, state) => const PrimarySiteRecordScreen(),
      ),
      GoRoute(
        path: AppRoutes.transferStation,
        builder: (context, state) => const TransferStationScreen(),
      ),
      GoRoute(
        path: AppRoutes.wasteActivity,
        builder: (context, state) => const ActivityScreen(),
      ),
      GoRoute(
        path: AppRoutes.wasteTagging,
        builder: (context, state) => const TaggingScreen(),
      ),
      GoRoute(
        path: AppRoutes.bulkWaste,
        builder: (context, state) => const BulkWasteScreen(),
      ),
      GoRoute(
        path: AppRoutes.recordDetails,
        builder: (context, state) => const RecordDetailsScreen(),
      ),
      GoRoute(
        path: AppRoutes.complaints,
        builder: (context, state) => const ComplaintsHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.complaintMap,
        builder: (context, state) => const ComplaintMapScreen(),
      ),
      GoRoute(
        path: AppRoutes.complaintList,
        builder: (context, state) => const ComplaintListScreen(),
      ),
      GoRoute(
        path: AppRoutes.openComplaints,
        builder: (context, state) => const ComplaintListScreen(openOnly: true),
      ),
      GoRoute(
        path: AppRoutes.complaintDetails,
        builder: (context, state) => const ComplaintDetailsScreen(),
      ),
      GoRoute(
        path: AppRoutes.submitComplaint,
        builder: (context, state) => const SubmitComplaintScreen(),
      ),
      GoRoute(
        path: AppRoutes.afterPhotos,
        builder: (context, state) => const AfterPhotoScreen(),
      ),
    ],
  );
}

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
