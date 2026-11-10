class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
  static const reports = '/reports';
  static const profile = '/profile';
  static const profileDetails = '/profile/details';
  static const notifications = '/notifications';
  /// Manual HR (GPS stamp photo — working path).
  static const hr1 = '/hr1';
  static const hr1Register = '/hr1/register';
  static const hr1Attendance = '/hr1/attendance';
  static const hr1AttendanceLog = '/hr1/attendance/log';
  /// Face-recognition HR (server verify).
  static const hrFace = '/hr-face';
  static const hrFaceRegister = '/hr-face/register';
  static const hrFaceAttendance = '/hr-face/attendance';
  static const hrFaceAttendanceLog = '/hr-face/attendance/log';
  static const waste = '/waste';
  static const wasteEvidenceUpload = '/waste/evidence/upload';
  static const wasteEvidenceHistory = '/waste/evidence/history';
  static const wasteActivity = '/waste/activity';
  static const wasteTagging = '/waste/tagging';
  static const recordDetails = '/waste/record';
  static const complaints = '/complaints';
  static const complaintMap = '/complaints/map';
  static const complaintList = '/complaints/list';
  static const openComplaints = '/complaints/open';
  static const complaintDetails = '/complaints/details';
  static const submitComplaint = '/complaints/submit';
  static const afterPhotos = '/complaints/after-photos';
}
