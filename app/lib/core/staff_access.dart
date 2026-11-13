import '../constants/app_routes.dart';
import 'staff_capabilities.dart';
import 'supervisor_api.dart';

export 'staff_capabilities.dart';

extension StaffSession on SupervisorUser {
  bool can(String code) => capabilities.contains(code);

  /// Tagging, bulk, transfer, and the other field-record kinds have no
  /// capability code. They stay available only for the full supervisor set.
  bool get canUseOtherFieldRecords => StaffCapability.all.every(can);

  bool allowsPath(String path) {
    if (path.startsWith(AppRoutes.hr1Register) || path.startsWith(AppRoutes.hrFaceRegister)) {
      return can(StaffCapability.manageHr);
    }
    if (path.startsWith(AppRoutes.hr1Attendance) || path.startsWith(AppRoutes.hrFaceAttendance)) {
      return can(StaffCapability.markAttendance);
    }
    if (path == AppRoutes.hr1 || path == AppRoutes.hrFace) {
      return can(StaffCapability.manageHr) || can(StaffCapability.markAttendance);
    }
    if (path.startsWith(AppRoutes.wasteEvidenceUpload) || path.startsWith(AppRoutes.wasteEvidenceHistory)) {
      return can(StaffCapability.submitEvidence);
    }
    if (path.startsWith(AppRoutes.wasteTagging)) return canUseOtherFieldRecords;
    if (path.startsWith(AppRoutes.wasteActivity) || path.startsWith(AppRoutes.recordDetails)) {
      return can(StaffCapability.serveContainers) || canUseOtherFieldRecords;
    }
    if (path == AppRoutes.waste) {
      return can(StaffCapability.serveContainers) ||
          can(StaffCapability.submitEvidence) ||
          canUseOtherFieldRecords;
    }
    if (path.startsWith(AppRoutes.complaints) || path.startsWith(AppRoutes.notifications)) {
      return can(StaffCapability.resolveIssues);
    }
    return true;
  }
}
