import 'package:flutter/material.dart';

enum ComplaintStatus { none, fresh, inProcessing, resolved }

enum WasteKind { none, primary, transfer }

enum ScanPhase { ready, scanning, complete }

enum AttendanceMark { none, checkedIn, checkedOut }

class LocalPhoto {
  LocalPhoto(this.id);

  final String id;
}

class ProfileDetails {
  const ProfileDetails({
    this.name = '',
    this.fatherName = '',
    this.cnic = '',
    this.address = '',
    this.mobile = '',
    this.dob,
  });

  final String name;
  final String fatherName;
  final String cnic;
  final String address;
  final String mobile;
  final DateTime? dob;

  bool get hasAny =>
      name.trim().isNotEmpty ||
      fatherName.trim().isNotEmpty ||
      cnic.trim().isNotEmpty ||
      address.trim().isNotEmpty ||
      mobile.trim().isNotEmpty ||
      dob != null;
}

class TimelineEntry {
  TimelineEntry({required this.title, required this.at, required this.color});

  final String title;
  final DateTime at;
  final Color color;
}

class ComplaintDraft {
  ComplaintStatus status = ComplaintStatus.none;
  String description = '';
  String followUp = '';
  bool submitted = false;
  DateTime? submittedAt;
  final List<LocalPhoto> photos = [];
  final List<LocalPhoto> afterPhotos = [];
  final List<TimelineEntry> timeline = [];

  void reset() {
    status = ComplaintStatus.none;
    description = '';
    followUp = '';
    submitted = false;
    submittedAt = null;
    photos.clear();
    afterPhotos.clear();
    timeline.clear();
  }
}

class WasteDraft {
  WasteKind kind = WasteKind.none;
  String area = 'Urban';
  String? uc;
  String? primarySite;
  String? location;
  String? vehicleType;
  String vehicleNumber = '';
  String? latitude;
  String? longitude;
  bool locating = false;
  String remarks = '';
  DateTime? savedAt;
  final List<LocalPhoto> beforePhotos = [];
  final List<LocalPhoto> afterPhotos = [];

  void reset() {
    kind = WasteKind.none;
    area = 'Urban';
    uc = null;
    primarySite = null;
    location = null;
    vehicleType = null;
    vehicleNumber = '';
    latitude = null;
    longitude = null;
    locating = false;
    remarks = '';
    savedAt = null;
    beforePhotos.clear();
    afterPhotos.clear();
  }
}

class AttendanceUi {
  ScanPhase phase = ScanPhase.ready;
  AttendanceMark mark = AttendanceMark.none;
  DateTime? markedAt;

  void reset() {
    phase = ScanPhase.ready;
    mark = AttendanceMark.none;
    markedAt = null;
  }
}

class AppState extends ChangeNotifier {
  ProfileDetails profile = const ProfileDetails();
  bool rememberMe = false;
  final complaint = ComplaintDraft();
  final waste = WasteDraft();
  final attendance = AttendanceUi();

  void saveProfile(ProfileDetails details) {
    profile = details;
    notifyListeners();
  }

  void setRememberMe(bool value) {
    rememberMe = value;
    notifyListeners();
  }

  void updateComplaint(void Function(ComplaintDraft draft) change) {
    change(complaint);
    notifyListeners();
  }

  void updateWaste(void Function(WasteDraft draft) change) {
    change(waste);
    notifyListeners();
  }

  void updateAttendance(void Function(AttendanceUi ui) change) {
    change(attendance);
    notifyListeners();
  }

  void clearSession() {
    profile = const ProfileDetails();
    rememberMe = false;
    complaint.reset();
    waste.reset();
    attendance.reset();
    notifyListeners();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    required AppState notifier,
    required super.child,
    super.key,
  }) : super(notifier: notifier);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope is missing');
    return scope!.notifier!;
  }

  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope is missing');
    return scope!.notifier!;
  }
}

String complaintStatusLabel(ComplaintStatus status) {
  return switch (status) {
    ComplaintStatus.none => 'No status',
    ComplaintStatus.fresh => 'New',
    ComplaintStatus.inProcessing => 'In Processing',
    ComplaintStatus.resolved => 'Resolved',
  };
}

Color complaintStatusColor(ComplaintStatus status) {
  return switch (status) {
    ComplaintStatus.none => const Color(0xFF64748B),
    ComplaintStatus.fresh => const Color(0xFF0284C7),
    ComplaintStatus.inProcessing => const Color(0xFFF59E0B),
    ComplaintStatus.resolved => const Color(0xFF16A34A),
  };
}

String wasteKindLabel(WasteKind kind) {
  return switch (kind) {
    WasteKind.none => 'Record',
    WasteKind.primary => 'Primary Site',
    WasteKind.transfer => 'Transfer Station',
  };
}
