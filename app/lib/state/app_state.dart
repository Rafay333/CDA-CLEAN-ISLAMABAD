import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/pending_resolve_store.dart';
import '../core/staff_access.dart';
import '../core/supervisor_api.dart';

enum ComplaintStatus { none, fresh, inProcessing, resolved }

enum WasteKind { none, activity, tagging }

enum ScanPhase { ready, scanning, complete }

enum AttendanceMark { none, checkedIn, checkedOut }

class LocalPhoto {
  LocalPhoto(this.id, {this.bytes, this.filename});

  factory LocalPhoto.unique() {
    return LocalPhoto(DateTime.now().microsecondsSinceEpoch.toString());
  }

  final String id;
  final Uint8List? bytes;
  final String? filename;
}

List<UploadPhoto> uploadPhotos(List<LocalPhoto> photos) {
  return [
    for (final photo in photos)
      if (photo.bytes != null && photo.bytes!.isNotEmpty)
        UploadPhoto(bytes: photo.bytes!, filename: photo.filename),
  ];
}

class UcPhotoGroup {
  UcPhotoGroup({this.uc});

  String? uc;
  final List<LocalPhoto> photos = [];
}

class ProfileDetails {
  const ProfileDetails({
    this.name = '',
    this.fatherName = '',
    this.cnic = '',
    this.mobile = '',
    this.dob,
    this.contractorName = '',
    this.accountType = '',
  });

  final String name;
  final String fatherName;
  final String cnic;
  final String mobile;
  final DateTime? dob;
  final String contractorName;
  final String accountType;

  bool get hasAny =>
      name.trim().isNotEmpty ||
      fatherName.trim().isNotEmpty ||
      cnic.trim().isNotEmpty ||
      mobile.trim().isNotEmpty ||
      dob != null;

  factory ProfileDetails.fromSupervisor(SupervisorProfile row) {
    return ProfileDetails(
      name: row.fullName,
      fatherName: row.fatherName,
      cnic: row.cnic,
      mobile: row.mobile,
      dob: parseSupervisorDate(row.dob) ?? DateTime.tryParse(row.dob ?? ''),
      contractorName: row.contractorName,
      accountType: row.accountType,
    );
  }
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
  int? issueId;
  String sector = '';
  String activity = '';
  String loggedBy = '';
  String? slaLabel;
  final List<String> remoteBefore = [];
  final List<String> remoteAfter = [];
  final List<LocalPhoto> photos = [];
  final List<LocalPhoto> afterPhotos = [];
  final List<TimelineEntry> timeline = [];

  void reset() {
    status = ComplaintStatus.none;
    description = '';
    followUp = '';
    submitted = false;
    submittedAt = null;
    issueId = null;
    sector = '';
    activity = '';
    loggedBy = '';
    slaLabel = null;
    remoteBefore.clear();
    remoteAfter.clear();
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
  int? primarySiteId;
  String? location;
  int? locationId;
  String? vehicleType;
  String vehicleNumber = '';
  String? latitude;
  String? longitude;
  bool locating = false;
  String remarks = '';
  DateTime? savedAt;
  String? activity;
  String? zone;
  String? containerType;
  int? containerId;
  String? containerName;
  int? recordId;
  final List<LocalPhoto> beforePhotos = [];
  final List<LocalPhoto> afterPhotos = [];
  final List<UcPhotoGroup> ucGroups = [];

  void reset() {
    kind = WasteKind.none;
    area = 'Urban';
    uc = null;
    primarySite = null;
    primarySiteId = null;
    location = null;
    locationId = null;
    vehicleType = null;
    vehicleNumber = '';
    latitude = null;
    longitude = null;
    locating = false;
    remarks = '';
    savedAt = null;
    activity = null;
    zone = null;
    containerType = null;
    containerId = null;
    containerName = null;
    recordId = null;
    beforePhotos.clear();
    afterPhotos.clear();
    ucGroups.clear();
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
  AppState() {
    _ready = restore();
  }

  static const _sessionKey = 'supervisorSession';
  static const _lastActivityKey = 'lastActivitySave';

  ProfileDetails profile = const ProfileDetails();
  bool rememberMe = false;
  SupervisorUser? session;
  late final Future<void> _ready;
  final complaint = ComplaintDraft();
  final waste = WasteDraft();
  final attendance = AttendanceUi();
  DateTime? wasteSyncedAt;
  DateTime? complaintSyncedAt;
  int pendingResolveCount = 0;
  List<PendingResolve> pendingResolves = const [];
  int unreadNotices = 0;
  String? _flashNotice;

  /// Last successful Activity save on this phone (used to block a stuck GPS pin).
  String? lastActivityLatitude;
  String? lastActivityLongitude;
  int? lastActivityContainerId;
  String? lastActivityVehicleNumber;
  String? lastActivityRemarks;
  DateTime? lastActivitySavedAt;
  String? _lastActivityCnic;

  Future<void> get ready => _ready;

  bool get wastePendingSync {
    final saved = waste.savedAt;
    if (saved == null) return false;
    final synced = wasteSyncedAt;
    return synced == null || saved.isAfter(synced);
  }

  bool get complaintPendingSync => pendingResolveCount > 0;

  int get pendingSyncCount {
    var count = 0;
    if (wastePendingSync) count++;
    count += pendingResolveCount;
    return count;
  }

  bool get hasPendingSync => pendingSyncCount > 0;

  void markPendingSynced() {
    if (waste.savedAt != null) wasteSyncedAt = waste.savedAt;
    if (complaint.submitted) {
      complaintSyncedAt = complaint.submittedAt ?? DateTime.now();
    }
    notifyListeners();
  }

  void noteWasteSynced() {
    wasteSyncedAt = waste.savedAt ?? DateTime.now();
    notifyListeners();
  }

  /// One-shot banner after a successful save (e.g. Activity → Solid Waste home).
  void setFlashNotice(String message) {
    final text = message.trim();
    if (text.isEmpty) return;
    _flashNotice = text;
  }

  String? takeFlashNotice() {
    final text = _flashNotice;
    _flashNotice = null;
    return text;
  }

  void rememberActivitySave({
    required String? latitude,
    required String? longitude,
    int? containerId,
    String? vehicleNumber,
    String? remarks,
  }) {
    lastActivityLatitude = latitude?.trim();
    lastActivityLongitude = longitude?.trim();
    lastActivityContainerId = containerId;
    lastActivityVehicleNumber = vehicleNumber?.trim();
    lastActivityRemarks = remarks?.trim();
    lastActivitySavedAt = DateTime.now();
    _lastActivityCnic = session?.cnic;
    // Persist so a stuck pin is still blocked after the app is killed/reopened.
    _persistLastActivitySave();
  }

  Future<void> _persistLastActivitySave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cnic = _lastActivityCnic ?? session?.cnic;
      if (cnic == null || cnic.isEmpty) {
        await prefs.remove(_lastActivityKey);
        return;
      }
      await prefs.setString(
        _lastActivityKey,
        jsonEncode({
          'cnic': cnic,
          'latitude': lastActivityLatitude,
          'longitude': lastActivityLongitude,
          'containerId': lastActivityContainerId,
          'vehicleNumber': lastActivityVehicleNumber,
          'remarks': lastActivityRemarks,
          'savedAt': lastActivitySavedAt?.toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  Future<void> _restoreLastActivitySave(String? cnic) async {
    lastActivityLatitude = null;
    lastActivityLongitude = null;
    lastActivityContainerId = null;
    lastActivityVehicleNumber = null;
    lastActivityRemarks = null;
    lastActivitySavedAt = null;
    _lastActivityCnic = null;
    if (cnic == null || cnic.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_lastActivityKey);
      if (raw == null || raw.isEmpty) return;
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (data['cnic']?.toString() != cnic) return;
      lastActivityLatitude = data['latitude']?.toString();
      lastActivityLongitude = data['longitude']?.toString();
      lastActivityContainerId = int.tryParse('${data['containerId'] ?? ''}');
      lastActivityVehicleNumber = data['vehicleNumber']?.toString();
      lastActivityRemarks = data['remarks']?.toString();
      lastActivitySavedAt = DateTime.tryParse('${data['savedAt'] ?? ''}');
      _lastActivityCnic = cnic;
    } catch (_) {}
  }

  void noteComplaintSynced() {
    complaintSyncedAt = complaint.submittedAt ?? DateTime.now();
    notifyListeners();
  }

  Future<void> refreshPendingResolves() async {
    pendingResolves = await PendingResolveStore.list();
    pendingResolveCount = pendingResolves.length;
    if (pendingResolveCount == 0 && complaint.status == ComplaintStatus.resolved) {
      complaintSyncedAt = complaint.submittedAt ?? DateTime.now();
    }
    notifyListeners();
  }

  Future<void> refreshAccount() async {
    final user = session;
    if (user == null) return;
    final api = SupervisorApi();
    StaffAccessUpdate? fromMe;
    StaffAccessUpdate? fromGap;
    await Future.wait([
      () async {
        try {
          fromMe = await api.me(user.cnic);
        } catch (_) {}
      }(),
      () async {
        try {
          fromGap = await api.gapProfile(user.cnic);
        } catch (_) {}
      }(),
    ]);
    if (fromMe != null) _applyStaffAccess(fromMe!);
    if (fromGap != null) _applyStaffAccess(fromGap!);
    final current = session;
    if (current != null && current.can(StaffCapability.resolveIssues)) {
      try {
        final notices = await api.notifications(current.cnic);
        unreadNotices = notices.where((item) => !item.read).length;
      } catch (_) {}
    } else {
      unreadNotices = 0;
    }
    if (rememberMe && session != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_sessionKey, jsonEncode(session!.toJson()));
      } catch (_) {}
    }
    notifyListeners();
  }

  void _applyStaffAccess(StaffAccessUpdate update) {
    final user = session;
    if (user == null || update.isEmpty) return;
    final next = user.copyWith(
      role: update.role,
      roleLabel: update.roleLabel,
      capabilities: update.capabilities,
    );
    session = next;
    final label = next.roleLabel.trim();
    if (label.isEmpty || profile.accountType == label) return;
    profile = ProfileDetails(
      name: profile.name,
      fatherName: profile.fatherName,
      cnic: profile.cnic,
      mobile: profile.mobile,
      dob: profile.dob,
      contractorName: profile.contractorName,
      accountType: label,
    );
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw != null && raw.isNotEmpty) {
        final user = SupervisorUser.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
        session = user;
        rememberMe = true;
        profile = ProfileDetails(
          name: user.fullName,
          cnic: user.cnic,
          mobile: user.phone,
          contractorName: user.contractorName,
          accountType: user.roleLabel,
        );
      }
    } catch (_) {
      session = null;
    }
    await _restoreLastActivitySave(session?.cnic);
    try {
      pendingResolves = await PendingResolveStore.list();
      pendingResolveCount = pendingResolves.length;
    } catch (_) {
      pendingResolves = const [];
      pendingResolveCount = 0;
    }
    notifyListeners();
    await refreshAccount();
  }

  Future<void> signIn(SupervisorUser user, {required bool remember}) async {
    if (!user.can(StaffCapability.login)) {
      throw SupervisorException('This account cannot use the app.');
    }
    session = user;
    rememberMe = remember;
    profile = ProfileDetails(
      name: user.fullName,
      cnic: user.cnic,
      mobile: user.phone,
      contractorName: user.contractorName,
      accountType: user.roleLabel,
    );
    final prefs = await SharedPreferences.getInstance();
    if (remember) {
      await prefs.setString(_sessionKey, jsonEncode(user.toJson()));
    } else {
      await prefs.remove(_sessionKey);
    }
    await _restoreLastActivitySave(user.cnic);
    notifyListeners();
    await refreshAccount();
  }

  void openIssue(SupervisorIssue issue, {bool processing = false}) {
    complaint.reset();
    complaint.submitted = true;
    complaint.issueId = issue.id;
    complaint.description = issue.description;
    complaint.sector = issue.sector;
    complaint.activity = issue.activity;
    complaint.loggedBy = issue.loggedBy;
    complaint.slaLabel = issue.slaLabel;
    complaint.status = issue.resolved
        ? ComplaintStatus.resolved
        : (processing || issue.inProcessing)
            ? ComplaintStatus.inProcessing
            : ComplaintStatus.fresh;
    complaint.submittedAt = DateTime.tryParse(issue.dateLogged);
    complaint.remoteBefore.addAll(issue.beforePictures);
    complaint.remoteAfter.addAll(issue.afterPictures);
    if (issue.timeline.isNotEmpty) {
      for (final event in issue.timeline) {
        complaint.timeline.add(
          TimelineEntry(
            title: event.title,
            at: DateTime.tryParse(event.at ?? '') ?? complaint.submittedAt ?? DateTime.now(),
            color: complaintStatusColor(complaint.status),
          ),
        );
      }
    } else {
      complaint.timeline.add(
        TimelineEntry(
          title: issue.resolved
              ? 'Marked as Completed'
              : (processing || issue.inProcessing)
                  ? 'Marked as In Processing'
                  : 'Marked as New',
          at: complaint.submittedAt ?? DateTime.now(),
          color: complaintStatusColor(complaint.status),
        ),
      );
    }
    notifyListeners();
  }

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

  Future<void> clearSession() async {
    profile = const ProfileDetails();
    rememberMe = false;
    session = null;
    complaint.reset();
    waste.reset();
    attendance.reset();
    wasteSyncedAt = null;
    complaintSyncedAt = null;
    pendingResolves = const [];
    pendingResolveCount = 0;
    unreadNotices = 0;
    _flashNotice = null;
    // Keep last-activity prefs on disk (keyed by CNIC) so a stuck GPS pin is
    // still blocked after logout/login. Only clear the in-memory copy here.
    lastActivityLatitude = null;
    lastActivityLongitude = null;
    lastActivityContainerId = null;
    lastActivityVehicleNumber = null;
    lastActivityRemarks = null;
    lastActivitySavedAt = null;
    _lastActivityCnic = null;
    await PendingResolveStore.clearAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
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
    ComplaintStatus.resolved => 'Completed',
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
    WasteKind.activity => 'Activity',
    WasteKind.tagging => 'Tagging',
  };
}
