import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/components.dart';
import '../constants/app_routes.dart';
import '../core/staff_access.dart';
import '../state/app_state.dart';
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
import '../features/hr1/gps_attendance_log_screen_manual.dart';
import '../features/hr1/gps_attendance_screen_manual.dart';
import '../features/hr1/hr1_home_screen_manual.dart';
import '../features/hr1/photo_registration_screen_manual.dart';
import '../features/hr_face/gps_attendance_log_screen_face.dart';
import '../features/hr_face/gps_attendance_screen_face.dart';
import '../features/hr_face/hr_face_home_screen.dart';
import '../features/hr_face/photo_registration_screen_face.dart';
import '../features/profile/profile_details_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/solid_waste/activity_screen.dart';
import '../features/solid_waste/evidence_history_screen.dart';
import '../features/solid_waste/evidence_upload_screen.dart';
import '../features/solid_waste/record_details_screen.dart';
import '../features/solid_waste/solid_waste_home_screen.dart';
import '../features/solid_waste/tagging_screen.dart';

GoRouter createAppRouter(AppState appState) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: appState,
    redirect: (context, state) {
      final path = state.uri.path;
      if (path == AppRoutes.splash || path == AppRoutes.login || path == AppRoutes.forgotPassword) {
        return null;
      }
      final session = appState.session;
      if (session == null) return null;
      if (!session.can(StaffCapability.login)) return AppRoutes.login;
      if (!session.allowsPath(path) && path != AppRoutes.home) return AppRoutes.home;
      return null;
    },
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
        path: AppRoutes.hr1,
        builder: (context, state) => const Hr1HomeScreenManual(),
      ),
      GoRoute(
        path: AppRoutes.hr1Register,
        builder: (context, state) => const PhotoRegistrationScreenManual(),
      ),
      GoRoute(
        path: AppRoutes.hr1Attendance,
        builder: (context, state) => const GpsAttendanceScreenManual(),
      ),
      GoRoute(
        path: AppRoutes.hr1AttendanceLog,
        builder: (context, state) => const GpsAttendanceLogScreenManual(),
      ),
      GoRoute(
        path: AppRoutes.hrFace,
        builder: (context, state) => const HrFaceHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.hrFaceRegister,
        builder: (context, state) => const PhotoRegistrationScreenFace(),
      ),
      GoRoute(
        path: AppRoutes.hrFaceAttendance,
        builder: (context, state) => const GpsAttendanceScreenFace(),
      ),
      GoRoute(
        path: AppRoutes.hrFaceAttendanceLog,
        builder: (context, state) => const GpsAttendanceLogScreenFace(),
      ),
      GoRoute(
        path: AppRoutes.waste,
        builder: (context, state) => const SolidWasteHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.wasteEvidenceUpload,
        builder: (context, state) {
          final extra = state.extra;
          return EvidenceUploadScreen(args: extra is EvidenceUploadArgs ? extra : null);
        },
      ),
      GoRoute(
        path: AppRoutes.wasteEvidenceHistory,
        builder: (context, state) {
          final extra = state.extra;
          return EvidenceHistoryScreen(date: extra is String ? extra : null);
        },
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
