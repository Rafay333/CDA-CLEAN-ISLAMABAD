import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/pending_resolve_store.dart';
import '../core/supervisor_api.dart';

enum ComplaintStatus { none, fresh, inProcessing, resolved }

enum WasteKind { none, primary, transfer, activity, tagging, bulk }

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
  String? location;
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
  String? tcpName;
  bool zeroWaste = false;
  final List<LocalPhoto> beforePhotos = [];
  final List<LocalPhoto> afterPhotos = [];
  final List<UcPhotoGroup> ucGroups = [];

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
    activity = null;
    zone = null;
    containerType = null;
    tcpName = null;
    zeroWaste = false;
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

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionKey);
      if (raw != null && raw.isNotEmpty) {
        final user = SupervisorUser.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
        session = user;
        rememberMe = true;
        profile = ProfileDetails(name: user.fullName, cnic: user.cnic, mobile: user.phone);
      }
    } catch (_) {
      session = null;
    }
    try {
      pendingResolves = await PendingResolveStore.list();
      pendingResolveCount = pendingResolves.length;
    } catch (_) {
      pendingResolves = const [];
      pendingResolveCount = 0;
    }
    notifyListeners();
  }

  Future<void> signIn(SupervisorUser user, {required bool remember}) async {
    session = user;
    rememberMe = remember;
    profile = ProfileDetails(name: user.fullName, cnic: user.cnic, mobile: user.phone);
    final prefs = await SharedPreferences.getInstance();
    if (remember) {
      await prefs.setString(_sessionKey, jsonEncode(user.toJson()));
    } else {
      await prefs.remove(_sessionKey);
    }
    notifyListeners();
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
        : processing
            ? ComplaintStatus.inProcessing
            : ComplaintStatus.fresh;
    complaint.submittedAt = DateTime.tryParse(issue.dateLogged);
    complaint.remoteBefore.addAll(issue.beforePictures);
    complaint.remoteAfter.addAll(issue.afterPictures);
    complaint.timeline.add(
      TimelineEntry(
        title: issue.resolved
            ? 'Marked as Completed'
            : processing
                ? 'Marked as In Processing'
                : 'Marked as New',
        at: complaint.submittedAt ?? DateTime.now(),
        color: complaintStatusColor(complaint.status),
      ),
    );
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
    WasteKind.primary => 'Primary Site',
    WasteKind.transfer => 'Transfer Station',
    WasteKind.activity => 'Activity',
    WasteKind.tagging => 'Tagging',
    WasteKind.bulk => 'Bulk Waste',
  };
}
