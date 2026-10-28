import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/pakistan_time.dart';

const supervisorBaseUrl = 'https://cda-swm.asktech.com.pk:5010';

const _authKey = 'CDA-EMP-8fK2mN9qR4vX7wP1sT6yH3bL5cJ0';

class UploadPhoto {
  const UploadPhoto({required this.bytes, this.filename});

  final Uint8List bytes;
  final String? filename;
}

class SupervisorException implements Exception {
  SupervisorException(this.message, {this.retry = false});

  final String message;
  final bool retry;

  @override
  String toString() => message;
}

class SupervisorUser {
  const SupervisorUser({
    required this.userId,
    required this.employeeId,
    required this.fullName,
    required this.cnic,
    required this.phone,
    required this.contractorId,
    required this.contractorCode,
    required this.contractorName,
  });

  final int userId;
  final int employeeId;
  final String fullName;
  final String cnic;
  final String phone;
  final int contractorId;
  final String contractorCode;
  final String contractorName;

  factory SupervisorUser.fromJson(Map<String, dynamic> json) {
    return SupervisorUser(
      userId: _int(json['userId']),
      employeeId: _int(json['employeeId']),
      fullName: _text(json['fullName']),
      cnic: _text(json['cnic']),
      phone: _text(json['phone']),
      contractorId: _int(json['contractorId']),
      contractorCode: _text(json['contractorCode']),
      contractorName: _text(json['contractorName']),
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'employeeId': employeeId,
    'fullName': fullName,
    'cnic': cnic,
    'phone': phone,
    'contractorId': contractorId,
    'contractorCode': contractorCode,
    'contractorName': contractorName,
  };
}

class SupervisorIssue {
  const SupervisorIssue({
    required this.id,
    required this.issueType,
    required this.source,
    required this.activity,
    required this.description,
    required this.status,
    required this.portalStatus,
    required this.dateLogged,
    required this.sector,
    required this.loggedBy,
    required this.beforePictures,
    required this.afterPictures,
    this.landmark,
    this.geoTag,
    this.latitude,
    this.longitude,
    this.slaLabel,
    this.timeline = const [],
  });

  final int id;
  final String issueType;
  final String source;
  final String activity;
  final String description;
  final String status;
  final String portalStatus;
  final String dateLogged;
  final String sector;
  final String loggedBy;
  final List<String> beforePictures;
  final List<String> afterPictures;
  final String? landmark;
  final String? geoTag;
  final double? latitude;
  final double? longitude;
  final String? slaLabel;
  final List<IssueTimelineEntry> timeline;

  bool get resolved {
    final portal = portalStatus.toLowerCase();
    final label = status.toLowerCase();
    return portal == 'resolved' || label == 'resolved' || label == 'closed';
  }

  bool get inProcessing => portalStatus.toLowerCase() == 'in_processing';

  factory SupervisorIssue.fromJson(Map<String, dynamic> json) {
    return SupervisorIssue(
      id: _int(json['issue_id']),
      issueType: _text(json['issue_type']),
      source: _text(json['source']),
      activity: _text(json['activity']),
      description: _text(json['description']),
      status: _text(json['status']),
      portalStatus: _text(json['portal_status']),
      dateLogged: _text(json['date_logged']),
      sector: _text(json['sector']),
      loggedBy: _text(json['logged_by_name']),
      beforePictures: _paths(json['before_pictures']),
      afterPictures: _paths(json['after_pictures']),
      landmark: _optional(json['landmark']),
      geoTag: _optional(json['geo_tag']),
      latitude: _double(json['lat']),
      longitude: _double(json['long']),
      slaLabel: _optional(json['sla_label']),
      timeline: [
        for (final item in json['timeline'] is List ? json['timeline'] as List : const [])
          if (item is Map) IssueTimelineEntry.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

class IssueTimelineEntry {
  const IssueTimelineEntry({required this.title, this.at});

  final String title;
  final String? at;

  factory IssueTimelineEntry.fromJson(Map<String, dynamic> json) {
    return IssueTimelineEntry(
      title: _text(json['title'] ?? json['status'] ?? json['message']),
      at: _optional(json['at'] ?? json['time'] ?? json['created_at']),
    );
  }
}

class EvidenceActivity {
  const EvidenceActivity({
    required this.code,
    required this.activity,
    required this.hitsPed,
    this.pedSerial,
    this.pedTag,
    this.folder,
  });

  final String code;
  final String activity;
  final bool hitsPed;
  final String? pedSerial;
  final String? pedTag;
  final String? folder;

  factory EvidenceActivity.fromJson(Map<String, dynamic> json) {
    return EvidenceActivity(
      code: _text(json['code'] ?? json['activity_code']),
      activity: _text(json['activity']),
      hitsPed: _flag(json['hits_ped']),
      pedSerial: _optional(json['ped_serial']),
      pedTag: _optional(json['ped_tag']),
      folder: _optional(json['folder']),
    );
  }
}

class EvidenceStatusRow {
  const EvidenceStatusRow({
    required this.code,
    required this.activity,
    required this.hitsPed,
    required this.required,
    required this.uploaded,
    required this.photoCount,
    this.pedSerial,
  });

  final String code;
  final String activity;
  final bool hitsPed;
  final bool required;
  final bool uploaded;
  final int photoCount;
  final String? pedSerial;

  factory EvidenceStatusRow.fromJson(Map<String, dynamic> json) {
    return EvidenceStatusRow(
      code: _text(json['code'] ?? json['activity_code']),
      activity: _text(json['activity']),
      hitsPed: _flag(json['hits_ped']),
      required: _flag(json['required']),
      uploaded: _flag(json['uploaded']),
      photoCount: _int(json['photo_count']),
      pedSerial: _optional(json['ped_serial']),
    );
  }
}

class EvidenceStatus {
  const EvidenceStatus({
    required this.date,
    required this.totalPhotos,
    required this.requiredCount,
    required this.uploadedRequired,
    required this.pendingRequired,
    required this.complete,
    required this.activities,
  });

  final String date;
  final int totalPhotos;
  final int requiredCount;
  final int uploadedRequired;
  final int pendingRequired;
  final bool complete;
  final List<EvidenceStatusRow> activities;
}

class EvidenceSummary {
  const EvidenceSummary({
    required this.activityCode,
    required this.activity,
    required this.photoCount,
    this.pedSerial,
    this.hitsPed = false,
  });

  final String activityCode;
  final String activity;
  final int photoCount;
  final String? pedSerial;
  final bool hitsPed;

  factory EvidenceSummary.fromJson(Map<String, dynamic> json) {
    return EvidenceSummary(
      activityCode: _text(json['activity_code'] ?? json['code']),
      activity: _text(json['activity']),
      photoCount: _int(json['photo_count']),
      pedSerial: _optional(json['ped_serial']),
      hitsPed: _flag(json['hits_ped']),
    );
  }
}

class EvidenceItem {
  const EvidenceItem({
    required this.id,
    required this.activity,
    required this.url,
    required this.dateCaptured,
    this.activityCode,
    this.pedSerial,
    this.hitsPed = false,
    this.geoTag,
    this.verifiedBy,
  });

  final int id;
  final String activity;
  final String url;
  final String dateCaptured;
  final String? activityCode;
  final String? pedSerial;
  final bool hitsPed;
  final String? geoTag;
  final String? verifiedBy;

  factory EvidenceItem.fromJson(Map<String, dynamic> json) {
    final path = _text(json['url']).isEmpty ? _text(json['file_path']) : _text(json['url']);
    return EvidenceItem(
      id: _int(json['evidence_id']),
      activity: _text(json['activity']),
      activityCode: _optional(json['activity_code']),
      pedSerial: _optional(json['ped_serial']),
      hitsPed: _flag(json['hits_ped']),
      url: path,
      dateCaptured: _text(json['date_captured']),
      geoTag: _optional(json['geo_tag']),
      verifiedBy: _optional(json['verified_by']),
    );
  }
}

class EvidenceDay {
  const EvidenceDay({
    required this.date,
    required this.count,
    required this.items,
    this.from,
    this.to,
    this.mineOnly = true,
    this.activitiesSummary = const [],
  });

  final String date;
  final String? from;
  final String? to;
  final int count;
  final bool mineOnly;
  final List<EvidenceSummary> activitiesSummary;
  final List<EvidenceItem> items;
}

class SavedEvidence {
  const SavedEvidence({
    required this.message,
    required this.count,
    this.activity,
    this.activityCode,
    this.pedSerial,
    this.hitsPed = false,
  });

  final String message;
  final int count;
  final String? activity;
  final String? activityCode;
  final String? pedSerial;
  final bool hitsPed;
}

class RosterEmployee {
  const RosterEmployee({
    required this.id,
    required this.name,
    required this.role,
    required this.cnic,
    required this.contact,
    required this.isSupervisor,
  });

  final int id;
  final String name;
  final String role;
  final String cnic;
  final String contact;
  final bool isSupervisor;

  factory RosterEmployee.fromJson(Map<String, dynamic> json) {
    return RosterEmployee(
      id: _int(json['employee_id']),
      name: _text(json['name']),
      role: _text(json['role_label']).isEmpty ? _text(json['role']) : _text(json['role_label']),
      cnic: _text(json['cnic']),
      contact: _text(json['contact']),
      isSupervisor: json['is_supervisor'] == true,
    );
  }
}

class RosterRow {
  const RosterRow({
    required this.employeeId,
    required this.name,
    required this.role,
    required this.present,
    this.checkIn,
    this.checkOut,
    this.beat,
  });

  final int employeeId;
  final String name;
  final String role;
  final bool present;
  final String? checkIn;
  final String? checkOut;
  final String? beat;

  factory RosterRow.fromJson(Map<String, dynamic> json) {
    return RosterRow(
      employeeId: _int(json['employee_id']),
      name: _text(json['name']),
      role: _text(json['role_label']).isEmpty ? _text(json['role']) : _text(json['role_label']),
      present: json['present'] == true,
      checkIn: _optional(json['check_in']),
      checkOut: _optional(json['check_out']),
      beat: _optional(json['beat']),
    );
  }
}

class HrSummary {
  const HrSummary({
    required this.date,
    required this.contractorName,
    required this.activeEmployees,
    required this.presentToday,
    required this.absentToday,
    required this.attendancePercent,
    required this.meetsThreshold,
  });

  final String date;
  final String contractorName;
  final int activeEmployees;
  final int presentToday;
  final int absentToday;
  final num attendancePercent;
  final bool meetsThreshold;

  factory HrSummary.fromJson(Map<String, dynamic> json) {
    final percent = json['attendance_percent'];
    return HrSummary(
      date: _text(json['date']),
      contractorName: _text(json['contractor_name']),
      activeEmployees: _int(json['active_employees']),
      presentToday: _int(json['present_today']),
      absentToday: _int(json['absent_today']),
      attendancePercent: percent is num ? percent : 0,
      meetsThreshold: json['meets_threshold'] == true,
    );
  }
}

class CatalogZone {
  const CatalogZone({required this.code, required this.name});

  final String code;
  final String name;

  factory CatalogZone.fromJson(Map<String, dynamic> json) {
    return CatalogZone(code: _text(json['code']), name: _text(json['name']).isEmpty ? _text(json['code']) : _text(json['name']));
  }
}

class CatalogUc {
  const CatalogUc({required this.code, required this.name, required this.zoneCode});

  final String code;
  final String name;
  final String zoneCode;

  factory CatalogUc.fromJson(Map<String, dynamic> json) {
    return CatalogUc(
      code: _text(json['code']),
      name: _text(json['name']).isEmpty ? _text(json['code']) : _text(json['name']),
      zoneCode: _text(json['zone_code']),
    );
  }
}

class CatalogActivity {
  const CatalogActivity({
    required this.code,
    required this.name,
    required this.unlimitedPictures,
    this.pictureLimitPerUc = 2,
  });

  final String code;
  final String name;
  final bool unlimitedPictures;
  final int pictureLimitPerUc;

  factory CatalogActivity.fromJson(Map<String, dynamic> json) {
    return CatalogActivity(
      code: _text(json['code']),
      name: _text(json['name'] ?? json['activity']),
      unlimitedPictures: _flag(json['unlimited_pictures']),
      pictureLimitPerUc: _int(json['picture_limit_per_uc']) == 0 ? 2 : _int(json['picture_limit_per_uc']),
    );
  }
}

class CatalogSite {
  const CatalogSite({
    required this.id,
    required this.name,
    this.ucCode,
    this.zoneCode,
    this.latitude,
    this.longitude,
  });

  final int id;
  final String name;
  final String? ucCode;
  final String? zoneCode;
  final double? latitude;
  final double? longitude;

  factory CatalogSite.fromJson(Map<String, dynamic> json) {
    return CatalogSite(
      id: _int(json['id']),
      name: _text(json['name']),
      ucCode: _optional(json['uc_code']),
      zoneCode: _optional(json['zone_code']),
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
    );
  }
}

/// Primary site row from `GET /api/supervisor/primary-sites`.
class TaggingPrimarySite {
  const TaggingPrimarySite({
    required this.id,
    required this.name,
    this.zoneCode,
    this.latitude,
    this.longitude,
    this.containerCount = 0,
    this.taggedCount = 0,
  });

  final int id;
  final String name;
  final String? zoneCode;
  final double? latitude;
  final double? longitude;
  final int containerCount;
  final int taggedCount;

  factory TaggingPrimarySite.fromJson(Map<String, dynamic> json) {
    return TaggingPrimarySite(
      id: _int(json['id']),
      name: _text(json['name']),
      zoneCode: _optional(json['zone_code']),
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
      containerCount: _int(json['container_count']),
      taggedCount: _int(json['tagged_count']),
    );
  }
}

/// Container under a primary site for tagging.
class TaggingContainer {
  const TaggingContainer({
    required this.containerId,
    required this.containerName,
    this.primarySiteId,
    this.primarySiteName,
    this.zoneCode,
    this.containerType,
    this.latitude,
    this.longitude,
    this.siteLatitude,
    this.siteLongitude,
    this.tagStatus = 'No',
    this.isTagged = false,
    this.taggingDate,
  });

  final int containerId;
  final String containerName;
  final int? primarySiteId;
  final String? primarySiteName;
  final String? zoneCode;
  final String? containerType;
  final double? latitude;
  final double? longitude;
  final double? siteLatitude;
  final double? siteLongitude;
  final String tagStatus;
  final bool isTagged;
  final String? taggingDate;

  double? get displayLat => latitude ?? siteLatitude;
  double? get displayLng => longitude ?? siteLongitude;

  factory TaggingContainer.fromJson(Map<String, dynamic> json) {
    return TaggingContainer(
      containerId: _int(json['container_id'] ?? json['id']),
      containerName: _text(json['container_name'] ?? json['name'] ?? json['container_code']),
      primarySiteId: _int(json['primary_site_id']) == 0 ? null : _int(json['primary_site_id']),
      primarySiteName: _optional(json['primary_site_name']),
      zoneCode: _optional(json['zone_code']),
      containerType: _optional(json['container_type'] ?? json['type'] ?? json['container_type_name']),
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
      siteLatitude: _double(json['site_latitude']),
      siteLongitude: _double(json['site_longitude']),
      tagStatus: _optional(json['tag_status']) ?? (_flag(json['is_tagged']) ? 'Yes' : 'No'),
      isTagged: _flag(json['is_tagged']) ||
          (_optional(json['tag_status'])?.toLowerCase() == 'yes'),
      taggingDate: _optional(json['tagging_date']),
    );
  }
}

class CatalogLocation {
  const CatalogLocation({required this.id, required this.name, this.ucCode});

  final int id;
  final String name;
  final String? ucCode;

  factory CatalogLocation.fromJson(Map<String, dynamic> json) {
    return CatalogLocation(
      id: _int(json['id']),
      name: _text(json['name']),
      ucCode: _optional(json['uc_code']),
    );
  }
}

class CatalogVehicle {
  const CatalogVehicle({
    required this.number,
    this.id,
    this.vehicleType,
    this.zoneCode,
  });

  final int? id;
  final String number;
  final String? vehicleType;
  final String? zoneCode;

  factory CatalogVehicle.fromJson(Map<String, dynamic> json) {
    return CatalogVehicle(
      id: _int(json['id'] ?? json['vehicle_id']) == 0 ? null : _int(json['id'] ?? json['vehicle_id']),
      number: _text(
        json['vehicle_number'] ?? json['number'] ?? json['plate'] ?? json['registration'] ?? json['name'],
      ),
      vehicleType: _optional(json['vehicle_type'] ?? json['type'] ?? json['vehicle_type_name']),
      zoneCode: _optional(json['zone_code']),
    );
  }
}

class SupervisorCatalog {
  const SupervisorCatalog({
    this.zones = const [],
    this.ucs = const [],
    this.activities = const [],
    this.containerTypes = const [],
    this.vehicleTypes = const [],
    this.vehicles = const [],
    this.primarySites = const [],
    this.locations = const [],
  });

  final List<CatalogZone> zones;
  final List<CatalogUc> ucs;
  final List<CatalogActivity> activities;
  final List<String> containerTypes;
  final List<String> vehicleTypes;
  final List<CatalogVehicle> vehicles;
  final List<CatalogSite> primarySites;
  final List<CatalogLocation> locations;

  factory SupervisorCatalog.fromJson(Map<String, dynamic> json) {
    List<T> rows<T>(Object? value, T Function(Map<String, dynamic>) map) {
      if (value is! List) return const [];
      return [
        for (final item in value)
          if (item is Map) map(Map<String, dynamic>.from(item)),
      ];
    }

    List<String> names(Object? value) {
      if (value is! List) return const [];
      return [for (final item in value) item.toString()].where((item) => item.trim().isNotEmpty).toList();
    }

    return SupervisorCatalog(
      zones: rows(json['zones'], CatalogZone.fromJson),
      ucs: rows(json['ucs'], CatalogUc.fromJson),
      activities: rows(json['activities'], CatalogActivity.fromJson),
      containerTypes: names(json['container_types']),
      vehicleTypes: names(json['vehicle_types']),
      vehicles: rows(json['vehicles'], CatalogVehicle.fromJson),
      primarySites: rows(json['primary_sites'], CatalogSite.fromJson),
      locations: rows(json['locations'], CatalogLocation.fromJson),
    );
  }
}

class SavedFieldRecord {
  const SavedFieldRecord({required this.id, required this.kind, required this.status, required this.date, this.message});

  final int id;
  final String kind;
  final String status;
  final String date;
  final String? message;
}

class FieldRecordDay {
  const FieldRecordDay({required this.date, required this.count, this.items = const []});

  final String date;
  final int count;
  final List<FieldRecordSummary> items;

  factory FieldRecordDay.fromJson(Map<String, dynamic> json) {
    final rows = json['items'];
    return FieldRecordDay(
      date: _text(json['date']),
      count: _int(json['count']),
      items: [
        if (rows is List)
          for (final item in rows)
            if (item is Map) FieldRecordSummary.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

class FieldRecordSummary {
  const FieldRecordSummary({
    required this.id,
    required this.kind,
    this.status = '',
    this.date = '',
    this.remarks,
    this.beforePictures = const [],
    this.afterPictures = const [],
  });

  final int id;
  final String kind;
  final String status;
  final String date;
  final String? remarks;
  final List<String> beforePictures;
  final List<String> afterPictures;

  factory FieldRecordSummary.fromJson(Map<String, dynamic> json) {
    return FieldRecordSummary(
      id: _int(json['id'] ?? json['record_id']),
      kind: _text(json['kind']),
      status: _text(json['status']),
      date: _text(json['date']),
      remarks: _optional(json['remarks']),
      beforePictures: _paths(json['before_pictures'] ?? json['before']),
      afterPictures: _paths(json['after_pictures'] ?? json['after']),
    );
  }
}

class SupervisorProfile {
  const SupervisorProfile({
    this.fullName = '',
    this.fatherName = '',
    this.cnic = '',
    this.mobile = '',
    this.dob,
    this.contractorName = '',
    this.accountType = '',
  });

  final String fullName;
  final String fatherName;
  final String cnic;
  final String mobile;
  final String? dob;
  final String contractorName;
  final String accountType;

  factory SupervisorProfile.fromJson(Map<String, dynamic> json) {
    return SupervisorProfile(
      fullName: _text(json['full_name'] ?? json['fullName']),
      fatherName: _text(json['father_name']),
      cnic: _text(json['cnic']),
      mobile: _text(json['mobile'] ?? json['phone']),
      dob: _optional(json['dob']),
      contractorName: _text(json['contractor_name']),
      accountType: _text(json['account_type']),
    );
  }
}

class SupervisorNotice {
  const SupervisorNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    this.at,
    this.issueId,
  });

  final int id;
  final String title;
  final String body;
  final bool read;
  final String? at;
  final int? issueId;

  factory SupervisorNotice.fromJson(Map<String, dynamic> json) {
    return SupervisorNotice(
      id: _int(json['id']),
      title: _text(json['title']),
      body: _text(json['body']),
      read: _flag(json['read']),
      at: _optional(json['at']),
      issueId: _int(json['issue_id']) == 0 ? null : _int(json['issue_id']),
    );
  }
}

class UcBoundary {
  const UcBoundary({required this.name, required this.ucCode, required this.points, this.margin});

  final String name;
  final String ucCode;
  final double? margin;
  final List<UcPoint> points;

  factory UcBoundary.fromJson(Map<String, dynamic> json) {
    final rows = json['points'];
    return UcBoundary(
      name: _text(json['name']),
      ucCode: _text(json['uc_code']),
      margin: _double(json['margin']),
      points: [
        if (rows is List)
          for (final item in rows)
            if (item is Map)
              UcPoint(
                lat: _double(item['lat']) ?? 0,
                lng: _double(item['lng'] ?? item['lon']) ?? 0,
              ),
      ],
    );
  }
}

class UcPoint {
  const UcPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

class SupervisorApi {
  SupervisorApi({Dio? client}) : dio = client ?? _shared;

  static final Dio _shared = Dio(
    BaseOptions(
      baseUrl: supervisorBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
      headers: {'Accept': 'application/json', 'authkey': _authKey},
    ),
  );

  final Dio dio;

  Future<SupervisorUser> login({required String cnic, required String password}) async {
    final data = _map(
      await _send(
        dio.post('/api/supervisor/login', data: {'cnic': cnic, 'password': password}),
      ),
    );
    if (data['success'] == false) {
      throw SupervisorException(_text(data['message']).isEmpty ? 'Login failed.' : _text(data['message']));
    }
    return SupervisorUser.fromJson(data);
  }

  Future<List<SupervisorIssue>> issues(String cnic, {String status = 'all', String? query}) {
    return _issues('/api/supervisor/issues', {
      'supervisor_cnic': cnic,
      'status': status,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    });
  }

  Future<List<SupervisorIssue>> openIssues(String cnic, {String? query}) {
    return _issues('/api/supervisor/issues/open', {
      'supervisor_cnic': cnic,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    });
  }

  Future<SupervisorIssue> issue(String cnic, int id) async {
    final data = _map(
      await _send(dio.get('/api/supervisor/issues/$id', queryParameters: {'supervisor_cnic': cnic})),
    );
    return SupervisorIssue.fromJson(data);
  }

  Future<String> resolveIssue({
    required String cnic,
    required int id,
    required List<UploadPhoto> photos,
    String? notes,
    String? resolvedByName,
    DateTime? resolvedAt,
    String? resolvedAtIso,
  }) async {
    final files = _files(photos, 'after');
    if (files.isEmpty) {
      throw SupervisorException('Add at least one after photo.');
    }
    final form = FormData();
    form.fields.add(MapEntry('supervisor_cnic', cnic));
    if (notes != null && notes.trim().isNotEmpty) {
      form.fields.add(MapEntry('notes', notes.trim()));
    }
    if (resolvedByName != null && resolvedByName.trim().isNotEmpty) {
      form.fields.add(MapEntry('resolved_by_name', resolvedByName.trim()));
    }
    final atIso = (resolvedAtIso != null && resolvedAtIso.trim().isNotEmpty)
        ? resolvedAtIso.trim()
        : (resolvedAt != null ? toPakistanIso(resolvedAt) : null);
    if (atIso != null) {
      form.fields.add(MapEntry('resolved_at', atIso));
    }
    form.files.addAll(files);
    final data = await _send(dio.post('/api/supervisor/issues/$id/resolve', data: form));
    if (data is Map && data['message'] is String && (data['message'] as String).isNotEmpty) {
      return data['message'] as String;
    }
    return 'Complaint resolved.';
  }

  Future<List<EvidenceActivity>> activities() async {
    final data = await _send(dio.get('/api/supervisor/evidence/activities'));
    final rows = _list(data, const ['activities', 'items', 'data']);
    return [
      for (final item in rows)
        if (item is Map) EvidenceActivity.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<EvidenceStatus> evidenceStatus(String cnic, {String? date}) async {
    final data = _map(
      await _send(
        dio.get(
          '/api/supervisor/evidence/status',
          queryParameters: {'supervisor_cnic': cnic, 'date': ?date},
        ),
      ),
    );
    final rows = data['activities'];
    return EvidenceStatus(
      date: _text(data['date']),
      totalPhotos: _int(data['total_photos']),
      requiredCount: _int(data['required_count']),
      uploadedRequired: _int(data['uploaded_required']),
      pendingRequired: _int(data['pending_required']),
      complete: _flag(data['complete']),
      activities: [
        if (rows is List)
          for (final item in rows)
            if (item is Map) EvidenceStatusRow.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  Future<EvidenceDay> evidence(
    String cnic, {
    String? date,
    String? from,
    String? to,
    bool? mineOnly,
    String? activityCode,
  }) async {
    final data = _map(
      await _send(
        dio.get(
          '/api/supervisor/evidence',
          queryParameters: {
            'supervisor_cnic': cnic,
            'date': ?date,
            'from': ?from,
            'to': ?to,
            if (mineOnly != null) 'mine_only': mineOnly ? 'true' : 'false',
            'activity_code': ?activityCode,
          },
        ),
      ),
    );
    final items = data['items'];
    final summary = data['activities_summary'];
    return EvidenceDay(
      date: _text(data['date']),
      from: _optional(data['from']),
      to: _optional(data['to']),
      count: _int(data['count']),
      mineOnly: data['mine_only'] != false,
      activitiesSummary: [
        if (summary is List)
          for (final item in summary)
            if (item is Map) EvidenceSummary.fromJson(Map<String, dynamic>.from(item)),
      ],
      items: [
        if (items is List)
          for (final item in items)
            if (item is Map) EvidenceItem.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  Future<SavedEvidence> uploadEvidence({
    required String cnic,
    required String activityCode,
    required List<UploadPhoto> photos,
    String? geoTag,
    String? date,
    String? verifiedBy,
    String? activity,
  }) async {
    final files = _files(photos, 'photo');
    if (files.isEmpty) throw SupervisorException('Add at least one photo.');
    if (files.length > 10) throw SupervisorException('The server accepts up to 10 photos at a time.');
    final form = FormData();
    form.fields.add(MapEntry('supervisor_cnic', cnic));
    form.fields.add(MapEntry('activity_code', activityCode));
    if (activity != null && activity.trim().isNotEmpty) {
      form.fields.add(MapEntry('activity', activity.trim()));
    }
    form.fields.add(MapEntry('date', (date == null || date.isEmpty) ? supervisorToday() : date));
    if (geoTag != null && geoTag.isNotEmpty) form.fields.add(MapEntry('geo_tag', geoTag));
    if (verifiedBy != null && verifiedBy.trim().isNotEmpty) {
      form.fields.add(MapEntry('verified_by', verifiedBy.trim()));
    }
    form.files.addAll(files);
    final data = _map(await _send(dio.post('/api/supervisor/evidence', data: form)));
    if (data['success'] == false) {
      throw SupervisorException(_text(data['message']).isEmpty ? 'The photo was not saved.' : _text(data['message']));
    }
    final saved = data['items'];
    return SavedEvidence(
      message: _text(data['message']).isEmpty ? 'Photos saved.' : _text(data['message']),
      count: saved is List ? saved.length : files.length,
      activity: _optional(data['activity']),
      activityCode: _optional(data['activity_code']),
      pedSerial: _optional(data['ped_serial']),
      hitsPed: _flag(data['hits_ped']),
    );
  }

  Future<List<RosterEmployee>> employees(String cnic) async {
    final data = await _send(dio.get('/api/supervisor/employees', queryParameters: {'supervisor_cnic': cnic}));
    if (data is! List) throw SupervisorException('The server sent an unexpected response.');
    return [
      for (final item in data)
        if (item is Map) RosterEmployee.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<List<RosterRow>> attendance(String cnic, {String? date}) async {
    final data = _map(
      await _send(
        dio.get(
          '/api/supervisor/attendance',
          queryParameters: {'supervisor_cnic': cnic, 'date': ?date},
        ),
      ),
    );
    final rows = data['rows'];
    if (rows is! List) return const [];
    return [
      for (final item in rows)
        if (item is Map) RosterRow.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<String> saveAttendance({
    required String cnic,
    String? date,
    required List<({int employeeId, String? checkIn, String? checkOut, String? beat})> marks,
  }) async {
    final data = _map(
      await _send(
        dio.post(
          '/api/supervisor/attendance',
          data: {
            'supervisor_cnic': cnic,
            'date': ?date,
            'marks': [
              for (final mark in marks)
                {
                  'employee_id': mark.employeeId,
                  'present': true,
                  'check_in': ?mark.checkIn,
                  'check_out': ?mark.checkOut,
                  'beat': ?mark.beat,
                  'source': 'SupervisorApp',
                },
            ],
          },
        ),
      ),
    );
    if (data['success'] == false) {
      throw SupervisorException(_text(data['message']).isEmpty ? 'Attendance was not saved.' : _text(data['message']));
    }
    return _text(data['message']).isEmpty ? 'Attendance saved.' : _text(data['message']);
  }

  Future<List<Map<String, dynamic>>> faceEmployees(String cnic) async {
    final data = await _send(
      dio.get('/api/supervisor/employees', queryParameters: {'supervisor_cnic': cnic}),
    );
    if (data is! List) throw SupervisorException('The server sent an unexpected response.');
    return [
      for (final item in data)
        if (item is Map) _facePerson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<Map<String, dynamic>> employee(String cnic, int id) async {
    final data = await _send(
      dio.get('/api/supervisor/employees/$id', queryParameters: {'supervisor_cnic': cnic}),
    );
    return _unwrapEmployee(data);
  }

  Future<Map<String, dynamic>> enrollFace({
    required String cnic,
    required int employeeId,
    required String shift,
    required List<Uint8List> photos,
    bool confirmDifferent = false,
  }) async {
    final data = _map(
      await _send(
        dio.post(
          '/api/supervisor/employees/$employeeId/enroll',
          data: _faceForm(photos, {
            'supervisor_cnic': cnic,
            'shift': shift,
            if (confirmDifferent) 'confirm_different': 'true',
          }),
        ),
      ),
    );
    if (data['success'] == false) {
      throw SupervisorException(_text(data['message']).isEmpty ? 'Face was not registered.' : _text(data['message']));
    }
    return {
      'success': true,
      'message': _text(data['message']).isEmpty ? 'Face registered.' : _text(data['message']),
      'employee': _unwrapEmployee(data),
    };
  }

  Future<Map<String, dynamic>> resetFace({required String cnic, required int employeeId}) async {
    final data = await _send(
      dio.post(
        '/api/supervisor/employees/$employeeId/reset-face',
        data: {'supervisor_cnic': cnic},
      ),
    );
    return _unwrapEmployee(data);
  }

  Future<Map<String, dynamic>> markFace({
    required String cnic,
    required List<Uint8List> photos,
    required double lat,
    required double lng,
    required double accuracy,
    required bool mock,
    required String deviceId,
    bool confirm = true,
    int? expectedEmployeeId,
  }) async {
    final data = _map(
      await _send(
        dio.post(
          '/api/supervisor/attendance/face',
          data: _faceForm(photos, {
            'supervisor_cnic': cnic,
            'lat': lat.toString(),
            'lng': lng.toString(),
            'acc': accuracy.toString(),
            'mock': mock.toString(),
            'deviceId': deviceId,
            'confirm': confirm.toString(),
            if (expectedEmployeeId != null) 'expected_employee_id': expectedEmployeeId.toString(),
          }),
        ),
      ),
    );
    if (data['success'] == false) {
      throw SupervisorException(_text(data['message']).isEmpty ? 'Attendance was not recorded.' : _text(data['message']));
    }
    final match = data['matchPercent'];
    final attendance = data['attendance'];
    final requiresConfirm = data['requiresConfirm'] == true || data['confirmed'] == false;
    return {
      'action': _optional(data['action']),
      'message': _text(data['message']).isEmpty ? 'Attendance recorded.' : _text(data['message']),
      'matchPercent': match is num ? match.round() : int.tryParse('${match ?? ''}'),
      'shift': _shiftName(data['shift']),
      'requiresConfirm': requiresConfirm,
      'employee': data['employee'] is Map
          ? _facePerson(Map<String, dynamic>.from(data['employee'] as Map))
          : _facePerson(data),
      'attendance': attendance is Map ? _faceAttendance(Map<String, dynamic>.from(attendance)) : null,
    };
  }

  Future<List<Map<String, dynamic>>> faceLog(String cnic, {String? date, String? query}) async {
    final text = query?.trim();
    final data = await _send(
      dio.get(
        '/api/supervisor/attendance/log',
        queryParameters: {
          'supervisor_cnic': cnic,
          'date': ?date,
          'q': text == null || text.isEmpty ? null : text,
        },
      ),
    );
    if (data is! List) return const [];
    return [
      for (final item in data)
        if (item is Map) _faceLogRow(Map<String, dynamic>.from(item)),
    ];
  }

  String facePhotoUrl(int employeeId, String cnic, String? registeredAt) {
    final stamp = Uri.encodeQueryComponent(registeredAt ?? '');
    final who = Uri.encodeQueryComponent(cnic);
    return '$supervisorBaseUrl/api/supervisor/employees/$employeeId/photo?supervisor_cnic=$who&v=$stamp';
  }

  Map<String, String> get facePhotoHeaders => const {'authkey': _authKey};

  FormData _faceForm(List<Uint8List> photos, Map<String, String> fields) {
    if (photos.length < 3) {
      throw SupervisorException('The camera could not take all the pictures. Please try again.');
    }
    final form = FormData();
    for (final field in fields.entries) {
      form.fields.add(MapEntry(field.key, field.value));
    }
    for (var i = 0; i < 3; i++) {
      form.files.add(
        MapEntry('image$i', MultipartFile.fromBytes(photos[i], filename: 'face$i.jpg')),
      );
    }
    return form;
  }

  Future<SupervisorCatalog> catalog(String cnic) async {
    final data = _map(
      await _send(dio.get('/api/supervisor/catalog', queryParameters: {'supervisor_cnic': cnic})),
    );
    return SupervisorCatalog.fromJson(data);
  }

  /// Vehicles for the contractor (number + type). Empty list is valid.
  Future<List<CatalogVehicle>> vehicles(String cnic, {String? zoneCode}) async {
    final data = await _send(
      dio.get(
        '/api/supervisor/vehicles',
        queryParameters: {
          'supervisor_cnic': cnic,
          if (zoneCode != null && zoneCode.isNotEmpty) 'zone_code': zoneCode,
        },
      ),
    );
    final rows = data is List
        ? data
        : (data is Map ? (data['items'] ?? data['vehicles'] ?? const []) : const []);
    if (rows is! List) return const [];
    return [
      for (final item in rows)
        if (item is Map) CatalogVehicle.fromJson(Map<String, dynamic>.from(item)),
    ].where((item) => item.number.isNotEmpty).toList();
  }

  /// Containers for a zone (includes container_type for Activity auto-fill).
  Future<List<TaggingContainer>> containers(String cnic, {String? zoneCode}) async {
    final data = await _send(
      dio.get(
        '/api/supervisor/containers',
        queryParameters: {
          'supervisor_cnic': cnic,
          if (zoneCode != null && zoneCode.isNotEmpty) 'zone_code': zoneCode,
        },
      ),
    );
    final rows = data is List
        ? data
        : (data is Map ? (data['items'] ?? data['containers'] ?? const []) : const []);
    if (rows is! List) return const [];
    return [
      for (final item in rows)
        if (item is Map) TaggingContainer.fromJson(Map<String, dynamic>.from(item)),
    ].where((item) => item.containerName.isNotEmpty).toList();
  }

  /// Preferred tagging picker: sites for Zone-4 / Zone-5 (omit zone for all).
  Future<List<TaggingPrimarySite>> primarySites(String cnic, {String? zoneCode}) async {
    final data = _map(
      await _send(
        dio.get(
          '/api/supervisor/primary-sites',
          queryParameters: {
            'supervisor_cnic': cnic,
            if (zoneCode != null && zoneCode.isNotEmpty) 'zone_code': zoneCode,
          },
        ),
      ),
    );
    final items = data['items'];
    return [
      if (items is List)
        for (final item in items)
          if (item is Map) TaggingPrimarySite.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<({
    int primarySiteId,
    String? primarySiteName,
    String? zoneCode,
    double? siteLatitude,
    double? siteLongitude,
    List<TaggingContainer> items,
  })> containersForPrimarySite(String cnic, int primarySiteId) async {
    final data = _map(
      await _send(
        dio.get(
          '/api/supervisor/primary-sites/$primarySiteId/containers',
          queryParameters: {'supervisor_cnic': cnic},
        ),
      ),
    );
    final items = data['items'];
    return (
      primarySiteId: _int(data['primary_site_id']) == 0 ? primarySiteId : _int(data['primary_site_id']),
      primarySiteName: _optional(data['primary_site_name']),
      zoneCode: _optional(data['zone_code']),
      siteLatitude: _double(data['site_latitude']),
      siteLongitude: _double(data['site_longitude']),
      items: [
        if (items is List)
          for (final item in items)
            if (item is Map) TaggingContainer.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  Future<TaggingContainer> containerDetail(String cnic, int containerId) async {
    final data = _map(
      await _send(
        dio.get(
          '/api/supervisor/containers/$containerId',
          queryParameters: {'supervisor_cnic': cnic},
        ),
      ),
    );
    return TaggingContainer.fromJson(data);
  }

  Future<List<UcBoundary>> zoneBoundary(String cnic, String zoneCode) async {
    final data = _map(
      await _send(
        dio.get(
          '/api/supervisor/zones/$zoneCode/boundary',
          queryParameters: {'supervisor_cnic': cnic},
        ),
      ),
    );
    final areas = data['areas'];
    return [
      if (areas is List)
        for (final item in areas)
          if (item is Map) UcBoundary.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<SavedFieldRecord> saveFieldRecord({
    required String cnic,
    required String kind,
    String? area,
    String? date,
    String? latitude,
    String? longitude,
    String? remarks,
    String? ucCode,
    int? primarySiteId,
    int? locationId,
    String? vehicleType,
    String? vehicleNumber,
    String? containerActivity,
    String? activity,
    String? activityCode,
    String? zoneCode,
    String? tagging,
    String? containerType,
    String? containerName,
    int? containerId,
    int? vehicleId,
    String? geoTag,
    String? verifiedBy,
    List<UploadPhoto> before = const [],
    List<UploadPhoto> after = const [],
    List<UploadPhoto> bulk = const [],
    List<({String ucCode, List<UploadPhoto> photos})> groups = const [],
  }) async {
    final form = FormData();
    form.fields.add(MapEntry('supervisor_cnic', cnic));
    form.fields.add(MapEntry('kind', kind));
    if (area != null && area.isNotEmpty) form.fields.add(MapEntry('area', area));
    form.fields.add(MapEntry('date', (date == null || date.isEmpty) ? supervisorToday() : date));
    if (latitude != null && latitude.isNotEmpty) form.fields.add(MapEntry('latitude', latitude));
    if (longitude != null && longitude.isNotEmpty) form.fields.add(MapEntry('longitude', longitude));
    if (geoTag != null && geoTag.isNotEmpty) form.fields.add(MapEntry('geo_tag', geoTag));
    if (remarks != null && remarks.trim().isNotEmpty) form.fields.add(MapEntry('remarks', remarks.trim()));
    if (verifiedBy != null && verifiedBy.trim().isNotEmpty) {
      form.fields.add(MapEntry('verified_by', verifiedBy.trim()));
    }
    if (ucCode != null && ucCode.isNotEmpty) form.fields.add(MapEntry('uc_code', ucCode));
    if (primarySiteId != null) form.fields.add(MapEntry('primary_site_id', '$primarySiteId'));
    if (containerId != null) form.fields.add(MapEntry('container_id', '$containerId'));
    if (containerName != null && containerName.isNotEmpty) {
      form.fields.add(MapEntry('container_name', containerName));
    }
    if (locationId != null) form.fields.add(MapEntry('location_id', '$locationId'));
    if (vehicleId != null) form.fields.add(MapEntry('vehicle_id', '$vehicleId'));
    if (vehicleType != null && vehicleType.isNotEmpty) form.fields.add(MapEntry('vehicle_type', vehicleType));
    if (vehicleNumber != null && vehicleNumber.isNotEmpty) form.fields.add(MapEntry('vehicle_number', vehicleNumber));
    if (containerActivity != null && containerActivity.isNotEmpty) {
      form.fields.add(MapEntry('container_activity', containerActivity));
    }
    if (activity != null && activity.isNotEmpty) form.fields.add(MapEntry('activity', activity));
    if (activityCode != null && activityCode.isNotEmpty) form.fields.add(MapEntry('activity_code', activityCode));
    if (zoneCode != null && zoneCode.isNotEmpty) form.fields.add(MapEntry('zone_code', zoneCode));
    if (tagging != null && tagging.isNotEmpty) form.fields.add(MapEntry('tagging', tagging));
    if (containerType != null && containerType.isNotEmpty) form.fields.add(MapEntry('container_type', containerType));
    form.files.addAll(_files(before, 'before'));
    form.files.addAll(_files(after, 'after'));
    form.files.addAll(_files(bulk, 'photo'));
    if (groups.isNotEmpty) {
      final payload = <Map<String, dynamic>>[];
      for (var g = 0; g < groups.length; g++) {
        final keys = <String>[];
        for (var p = 0; p < groups[g].photos.length; p++) {
          final key = 'g${g}p$p';
          keys.add(key);
          final photo = groups[g].photos[p];
          form.files.add(MapEntry(key, MultipartFile.fromBytes(photo.bytes, filename: _fileName(photo.filename, p))));
        }
        payload.add({'uc_code': groups[g].ucCode, 'photo_keys': keys});
      }
      form.fields.add(MapEntry('groups', jsonEncode(payload)));
    }
    final data = _map(await _send(dio.post('/api/supervisor/field-records', data: form)));
    if (data['success'] == false) {
      throw SupervisorException(_text(data['message']).isEmpty ? 'The record was not saved.' : _text(data['message']));
    }
    return SavedFieldRecord(
      id: _int(data['record_id'] ?? data['id']),
      kind: _text(data['kind']).isEmpty ? kind : _text(data['kind']),
      status: _text(data['status']).isEmpty ? 'pending' : _text(data['status']),
      date: _text(data['date']),
      message: _optional(data['message']) ?? 'Record saved.',
    );
  }

  Future<SavedFieldRecord> patchFieldRecord({
    required String cnic,
    required int id,
    List<UploadPhoto> after = const [],
    String? remarks,
  }) async {
    final form = FormData();
    form.fields.add(MapEntry('supervisor_cnic', cnic));
    if (remarks != null) form.fields.add(MapEntry('remarks', remarks.trim()));
    form.files.addAll(_files(after, 'after'));
    if (form.files.isEmpty && (remarks == null || remarks.trim().isEmpty)) {
      throw SupervisorException('Add an after photo or remarks.');
    }
    final data = _map(await _send(dio.patch('/api/supervisor/field-records/$id', data: form)));
    if (data['success'] == false) {
      throw SupervisorException(_text(data['message']).isEmpty ? 'The record was not updated.' : _text(data['message']));
    }
    return SavedFieldRecord(
      id: _int(data['record_id'] ?? id),
      kind: _text(data['kind']),
      status: _text(data['status']),
      date: _text(data['date']),
      message: _optional(data['message']) ?? 'Record updated.',
    );
  }

  Future<FieldRecordDay> fieldRecords(String cnic, {String? date, String? kind}) async {
    final data = _map(
      await _send(
        dio.get(
          '/api/supervisor/field-records',
          queryParameters: {
            'supervisor_cnic': cnic,
            'date': ?date,
            'kind': ?kind,
          },
        ),
      ),
    );
    return FieldRecordDay.fromJson(data);
  }

  Future<FieldRecordSummary> fieldRecord(String cnic, int id) async {
    final data = _map(
      await _send(
        dio.get('/api/supervisor/field-records/$id', queryParameters: {'supervisor_cnic': cnic}),
      ),
    );
    return FieldRecordSummary.fromJson(data);
  }

  Future<String> createComplaint({
    required String cnic,
    required String description,
    String? sector,
    String? landmark,
    String? activity,
    String? latitude,
    String? longitude,
    List<UploadPhoto> photos = const [],
  }) async {
    if (description.trim().isEmpty) throw SupervisorException('Enter a description.');
    final form = FormData();
    form.fields.add(MapEntry('supervisor_cnic', cnic));
    form.fields.add(MapEntry('description', description.trim()));
    if (sector != null && sector.trim().isNotEmpty) form.fields.add(MapEntry('sector', sector.trim()));
    if (landmark != null && landmark.trim().isNotEmpty) form.fields.add(MapEntry('landmark', landmark.trim()));
    if (activity != null && activity.trim().isNotEmpty) form.fields.add(MapEntry('activity', activity.trim()));
    if (latitude != null && latitude.isNotEmpty) form.fields.add(MapEntry('lat', latitude));
    if (longitude != null && longitude.isNotEmpty) form.fields.add(MapEntry('long', longitude));
    form.files.addAll(_files(photos, 'before'));
    final data = _map(await _send(dio.post('/api/supervisor/complaints', data: form)));
    if (data['success'] == false) {
      throw SupervisorException(_text(data['message']).isEmpty ? 'The complaint was not submitted.' : _text(data['message']));
    }
    return _text(data['message']).isEmpty ? 'Complaint submitted.' : _text(data['message']);
  }

  Future<String> setIssueStatus({required String cnic, required int id, required String portalStatus}) async {
    final data = _map(
      await _send(
        dio.post(
          '/api/supervisor/issues/$id/status',
          data: {'supervisor_cnic': cnic, 'portal_status': portalStatus},
        ),
      ),
    );
    if (data['success'] == false) {
      throw SupervisorException(_text(data['message']).isEmpty ? 'Status was not updated.' : _text(data['message']));
    }
    return _text(data['message']).isEmpty ? 'Status updated.' : _text(data['message']);
  }

  Future<SupervisorProfile> updateProfile(String cnic, {String? fatherName, String? mobile, String? dob}) async {
    final body = <String, dynamic>{'supervisor_cnic': cnic};
    if (fatherName != null && fatherName.trim().isNotEmpty) body['father_name'] = fatherName.trim();
    if (mobile != null && mobile.trim().isNotEmpty) body['mobile'] = mobile.trim();
    if (dob != null && dob.trim().isNotEmpty) body['dob'] = dob.trim();
    final data = _map(await _send(dio.patch('/api/supervisor/profile', data: body)));
    if (data['success'] == false) {
      throw SupervisorException(_text(data['message']).isEmpty ? 'Profile was not saved.' : _text(data['message']));
    }
    return SupervisorProfile.fromJson(data);
  }

  Future<String> forgotPassword(String cnic) async {
    final data = _map(await _send(dio.post('/api/supervisor/password/forgot', data: {'cnic': cnic})));
    return _text(data['message']).isEmpty ? 'If this CNIC has an account, reset instructions were sent.' : _text(data['message']);
  }

  Future<List<SupervisorNotice>> notifications(String cnic) async {
    final data = _map(
      await _send(dio.get('/api/supervisor/notifications', queryParameters: {'supervisor_cnic': cnic})),
    );
    final items = data['items'];
    return [
      if (items is List)
        for (final item in items)
          if (item is Map) SupervisorNotice.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<void> markNotificationRead(String cnic, int id) async {
    await _send(
      dio.post('/api/supervisor/notifications/$id/read', data: {'supervisor_cnic': cnic}),
    );
  }

  Future<HrSummary> hrSummary(String cnic, {String? date}) async {
    final data = _map(
      await _send(
        dio.get(
          '/api/supervisor/hr-summary',
          queryParameters: {'supervisor_cnic': cnic, 'date': ?date},
        ),
      ),
    );
    return HrSummary.fromJson(data);
  }

  Future<List<SupervisorIssue>> _issues(String path, Map<String, dynamic> query) async {
    final data = await _send(dio.get(path, queryParameters: query));
    if (data is! List) throw SupervisorException('The server sent an unexpected response.');
    return [
      for (final item in data)
        if (item is Map) SupervisorIssue.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  List<MapEntry<String, MultipartFile>> _files(List<UploadPhoto> photos, String field) {
    final files = <MapEntry<String, MultipartFile>>[];
    for (var i = 0; i < photos.length; i++) {
      final bytes = photos[i].bytes;
      if (bytes.isEmpty) continue;
      files.add(MapEntry(field, MultipartFile.fromBytes(bytes, filename: _fileName(photos[i].filename, i))));
    }
    return files;
  }

  Future<dynamic> _send(Future<Response<dynamic>> call) async {
    try {
      final response = await call;
      return response.data;
    } on DioException catch (error) {
      throw SupervisorException(_message(error), retry: _isRetryable(error));
    }
  }
}

bool _isRetryable(DioException error) {
  if (error.response?.statusCode == 409) return true;
  return error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.unknown;
}

String supervisorMediaUrl(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  final suffix = path.startsWith('/') ? path : '/$path';
  return '$supervisorBaseUrl$suffix';
}

String? geoTagFrom(String? latitude, String? longitude) {
  final lat = latitude?.trim();
  final lng = longitude?.trim();
  if (lat == null || lat.isEmpty || lng == null || lng.isEmpty) return null;
  return '$lat,$lng';
}

/// Opens the system **Location** screen when live location is off.
/// Throws [SupervisorException] with a short on-screen message.
Future<void> ensureLiveLocationEnabled() async {
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (!enabled) {
    await Geolocator.openLocationSettings();
    throw SupervisorException('Enable live location, then try again.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    await Geolocator.openAppSettings();
    throw SupervisorException('Allow location for this app, then try again.');
  }
  if (permission == LocationPermission.denied) {
    throw SupervisorException('Enable live location permission, then try again.');
  }
}

Future<String?> currentGeoTag() async {
  try {
    await ensureLiveLocationEnabled();
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return '${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}';
  } on SupervisorException {
    rethrow;
  } catch (_) {
    return null;
  }
}

Future<String> supervisorDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('attendanceDeviceId');
  if (saved != null && saved.isNotEmpty) return saved;
  final created = 'app-${DateTime.now().millisecondsSinceEpoch}';
  await prefs.setString('attendanceDeviceId', created);
  return created;
}

Future<Position> supervisorFacePosition() async {
  await ensureLiveLocationEnabled();
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );
  if (position.isMocked) {
    throw SupervisorException('Fake GPS detected. Turn off any fake-location app and try again.');
  }
  if (position.accuracy > 300) {
    throw SupervisorException(
      'GPS signal is too weak (accuracy ${position.accuracy.round()} m). Move to an open area and try again.',
    );
  }
  return position;
}

String supervisorToday() => supervisorDate(pakistanNow());

String supervisorDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

DateTime? parseSupervisorDate(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  final parts = text.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

String supervisorVerifiedBy(SupervisorUser user) {
  final name = user.fullName.trim();
  if (name.isEmpty) return user.cnic;
  return '$name (${user.cnic})';
}

String supervisorClock(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _fileName(String? name, int index) {
  final trimmed = name?.trim() ?? '';
  final lower = trimmed.toLowerCase();
  const allowed = ['.jpg', '.jpeg', '.png', '.webp'];
  if (allowed.any(lower.endsWith)) return trimmed;
  return 'photo$index.jpg';
}

String _message(DioException error) {
  final fromBody = _serverMessage(error.response?.data);
  if (fromBody != null) return _friendlyServerMessage(fromBody);
  final code = error.response?.statusCode;
  final path = error.requestOptions.path;
  if (code == 404 &&
      (path.contains('/enroll') ||
          path.contains('/reset-face') ||
          path.contains('/photo') ||
          path.contains('/attendance/face') ||
          path.contains('/attendance/log'))) {
    return 'Face attendance is not available on the supervisor server yet.';
  }
  if (code == 404) return 'The supervisor server could not find this record.';
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout) {
    return 'Cannot reach the supervisor server.';
  }
  if (code != null) return 'The supervisor server returned an error ($code).';
  return 'Something went wrong. Try again.';
}

String _friendlyServerMessage(String message) {
  if (RegExp(r"Invalid column name\s+'?Address'?", caseSensitive: false).hasMatch(message)) {
    return 'Supervisor profile is not ready on the server. The Address column is missing from SmartSWM.';
  }
  if (RegExp(r'Invalid column name|Invalid object name', caseSensitive: false).hasMatch(message)) {
    return 'The supervisor server database is missing a table or column for this request.';
  }
  return message.replaceFirst(RegExp(r'^API error:\s*', caseSensitive: false), '');
}

String? _serverMessage(dynamic data) {
  if (data is Map) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();
  }
  if (data is List) {
    for (final item in data) {
      final message = _serverMessage(item);
      if (message != null) return message;
    }
  }
  if (data is String) {
    final text = data.trim();
    if (text.isNotEmpty && !text.startsWith('<')) return text;
  }
  return null;
}

Map<String, dynamic> _map(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  throw SupervisorException('The server sent an unexpected response.');
}

List<dynamic> _list(dynamic data, List<String> keys) {
  if (data is List) return data;
  if (data is Map) {
    for (final key in keys) {
      final value = data[key];
      if (value is List) return value;
    }
  }
  throw SupervisorException('The server sent an unexpected response.');
}

bool _flag(Object? value) {
  if (value == true || value == 1) return true;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes';
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _double(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String _text(Object? value) => value?.toString() ?? '';

bool _faceEnrolled(Map<String, dynamic> json) {
  final explicit = json['enrolled'];
  if (explicit == false || explicit == 0) return false;
  if (explicit == true || explicit == 1) return true;
  final at = json['faceRegisteredAt'] ?? json['face_registered_at'];
  final stamp = at?.toString().trim() ?? '';
  return stamp.isNotEmpty && stamp != 'null';
}

Map<String, dynamic> _facePerson(Map<String, dynamic> json) {
  final roleLabel = _optional(json['role_label']);
  return {
    'employeeId': _int(json['employeeId'] ?? json['employee_id']),
    'name': _text(json['name']),
    'cnic': _text(json['cnic']),
    'role': roleLabel ?? _text(json['role']),
    'contact': _optional(json['contact']),
    'enrolled': _faceEnrolled(json),
    'shift': _shiftName(json['shift']),
    'faceRegisteredAt': _optional(json['faceRegisteredAt'] ?? json['face_registered_at']),
    'salary': json['salary'],
    'status': json['status'],
    'statusId': json['statusId'] ?? json['status_id'],
    'statusName': json['statusName'] ?? json['status_name'],
    'contractorId': json['contractorId'] ?? json['contractor_id'],
    'contractorName': json['contractorName'] ?? json['contractor_name'],
    'contractorCode': json['contractorCode'] ?? json['contractor_code'],
    'createdBy': json['createdBy'] ?? json['created_by'],
    'createdAt': json['createdAt'] ?? json['created_at'],
    'modifiedBy': json['modifiedBy'] ?? json['modified_by'],
    'modifiedAt': json['modifiedAt'] ?? json['modified_at'],
  };
}

Map<String, dynamic> _faceAttendance(Map<String, dynamic> json) {
  return {
    'employeeId': _int(json['employeeId'] ?? json['employee_id']),
    'checkIn': _optional(json['checkIn'] ?? json['check_in']),
    'checkOut': _optional(json['checkOut'] ?? json['check_out']),
    'geoTag': _optional(json['geoTag'] ?? json['geo_tag']),
    'date': _optional(json['date']),
  };
}

Map<String, dynamic> _faceLogRow(Map<String, dynamic> json) {
  final similarity = json['similarity'];
  return {
    ..._facePerson(json),
    ..._faceAttendance(json),
    'similarity': similarity is num ? similarity.toDouble() : double.tryParse('${similarity ?? ''}'),
  };
}

Map<String, dynamic> _unwrapEmployee(dynamic data) {
  final map = _map(data);
  final nested = map['employee'];
  if (nested is Map) return _facePerson(Map<String, dynamic>.from(nested));
  return _facePerson(map);
}

String? _shiftName(Object? value) {
  final text = _optional(value);
  if (text == null) return null;
  final lower = text.toLowerCase();
  if (lower == 'day') return 'Day';
  if (lower == 'evening') return 'Evening';
  if (lower == 'night') return 'Night';
  return text;
}

String? _optional(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text == 'null') return null;
  return text;
}

List<String> _paths(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) item.toString()].where((item) => item.isNotEmpty).toList();
}
