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

  bool get resolved {
    final portal = portalStatus.toLowerCase();
    final label = status.toLowerCase();
    return portal == 'resolved' || label == 'resolved' || label == 'closed';
  }

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
    );
  }
}

class EvidenceActivity {
  const EvidenceActivity({
    required this.code,
    required this.activity,
    required this.hitsPed,
  });

  final String code;
  final String activity;
  final bool hitsPed;

  factory EvidenceActivity.fromJson(Map<String, dynamic> json) {
    return EvidenceActivity(
      code: _text(json['code']),
      activity: _text(json['activity']),
      hitsPed: json['hits_ped'] == true,
    );
  }
}

class EvidenceItem {
  const EvidenceItem({
    required this.id,
    required this.activity,
    required this.url,
    required this.dateCaptured,
    this.geoTag,
  });

  final int id;
  final String activity;
  final String url;
  final String dateCaptured;
  final String? geoTag;

  factory EvidenceItem.fromJson(Map<String, dynamic> json) {
    final path = _text(json['url']).isEmpty ? _text(json['file_path']) : _text(json['url']);
    return EvidenceItem(
      id: _int(json['evidence_id']),
      activity: _text(json['activity']),
      url: path,
      dateCaptured: _text(json['date_captured']),
      geoTag: _optional(json['geo_tag']),
    );
  }
}

class EvidenceDay {
  const EvidenceDay({required this.date, required this.count, required this.items});

  final String date;
  final int count;
  final List<EvidenceItem> items;
}

class SavedEvidence {
  const SavedEvidence({required this.message, required this.count});

  final String message;
  final int count;
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

  Future<List<SupervisorIssue>> openIssues(String cnic) {
    return _issues('/api/supervisor/issues/open', {'supervisor_cnic': cnic});
  }

  Future<List<SupervisorIssue>> issues(String cnic, {String status = 'all'}) {
    return _issues('/api/supervisor/issues', {'supervisor_cnic': cnic, 'status': status});
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
    if (data is! List) throw SupervisorException('The server sent an unexpected response.');
    return [
      for (final item in data)
        if (item is Map) EvidenceActivity.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<EvidenceDay> evidence(String cnic, {String? date}) async {
    final data = _map(
      await _send(
        dio.get(
          '/api/supervisor/evidence',
          queryParameters: {'supervisor_cnic': cnic, 'date': ?date},
        ),
      ),
    );
    final items = data['items'];
    return EvidenceDay(
      date: _text(data['date']),
      count: _int(data['count']),
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
  }) async {
    final files = _files(photos, 'photo');
    if (files.isEmpty) throw SupervisorException('Add at least one photo.');
    if (files.length > 10) throw SupervisorException('The server accepts up to 10 photos at a time.');
    final form = FormData();
    form.fields.add(MapEntry('supervisor_cnic', cnic));
    form.fields.add(MapEntry('activity_code', activityCode));
    if (date != null && date.isNotEmpty) form.fields.add(MapEntry('date', date));
    if (geoTag != null && geoTag.isNotEmpty) form.fields.add(MapEntry('geo_tag', geoTag));
    form.files.addAll(files);
    final data = _map(await _send(dio.post('/api/supervisor/evidence', data: form)));
    if (data['success'] == false) {
      throw SupervisorException(_text(data['message']).isEmpty ? 'The photo was not saved.' : _text(data['message']));
    }
    final saved = data['items'];
    return SavedEvidence(
      message: _text(data['message']).isEmpty ? 'Photos saved.' : _text(data['message']),
      count: saved is List ? saved.length : files.length,
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

  Future<Map<String, dynamic>> enrollFace({
    required String cnic,
    required int employeeId,
    required String shift,
    required List<Uint8List> photos,
  }) async {
    final data = _map(
      await _send(
        dio.post(
          '/api/supervisor/employees/$employeeId/enroll',
          data: _faceForm(photos, {'supervisor_cnic': cnic, 'shift': shift}),
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

Future<String?> currentGeoTag() async {
  try {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return '${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}';
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
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    throw SupervisorException('Location permission needed.');
  }
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

String supervisorToday() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
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
  if (fromBody != null) return fromBody;
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

Map<String, dynamic> _facePerson(Map<String, dynamic> json) {
  final roleLabel = _optional(json['role_label']);
  return {
    'employeeId': _int(json['employeeId'] ?? json['employee_id']),
    'name': _text(json['name']),
    'cnic': _text(json['cnic']),
    'role': roleLabel ?? _text(json['role']),
    'contact': _optional(json['contact']),
    'enrolled': json['enrolled'] == true || json['enrolled'] == 1,
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
