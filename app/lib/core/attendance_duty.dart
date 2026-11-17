import 'dart:math' as math;

/// Active attendance point from `GET /api/supervisor/attendance-points`.
///
/// Missing duty keys are the same as `null`: that edge of the window is not set.
class AttendancePoint {
  const AttendancePoint({
    required this.id,
    required this.ucZoneId,
    required this.name,
    this.latitude,
    this.longitude,
    this.radiusMetres,
    this.dutyStartFrom,
    this.dutyStartTime,
    this.dutyEndFrom,
    this.dutyEndTime,
  });

  final int id;
  final int ucZoneId;
  final String name;
  final double? latitude;
  final double? longitude;
  final double? radiusMetres;

  /// Check-in opens. Null means there is no earliest time.
  final String? dutyStartFrom;

  /// Check-in closes. At this time, and after it, check-in is refused.
  final String? dutyStartTime;

  /// Check-out opens. Null means there is no earliest time.
  final String? dutyEndFrom;

  /// Check-out closes. At this time, and after it, check-out is refused.
  final String? dutyEndTime;

  /// App default when the point has coordinates but no radius.
  static const double defaultRadiusMetres = 100;

  factory AttendancePoint.fromJson(Map<String, dynamic> json) {
    return AttendancePoint(
      id: _int(json['attendance_point_id'] ?? json['id']),
      ucZoneId: _int(json['uc_zone_id']),
      name: _text(json['name']).isEmpty ? 'Attendance point' : _text(json['name']),
      latitude: _nullableDouble(json['latitude']),
      longitude: _nullableDouble(json['longitude']),
      radiusMetres: _nullableDouble(json['radius_metres']),
      dutyStartFrom: _clock(json, 'duty_start_from'),
      dutyStartTime: _clock(json, 'duty_start_time'),
      dutyEndFrom: _clock(json, 'duty_end_from'),
      dutyEndTime: _clock(json, 'duty_end_time'),
    );
  }

  String get windowSummary =>
      '${_span('Check-in', dutyStartFrom, dutyStartTime)} · ${_span('Check-out', dutyEndFrom, dutyEndTime)}';
}

class SupervisorUc {
  const SupervisorUc({required this.id, required this.name, this.zone});

  final int id;
  final String name;
  final String? zone;

  /// Name plus zone, so duplicate names such as "Bulk Waste" stay distinct.
  String get label {
    final zoneName = zone?.trim() ?? '';
    if (zoneName.isEmpty) return name;
    return '$name · $zoneName';
  }

  factory SupervisorUc.fromJson(Map<String, dynamic> json) {
    final name = _firstText(json, const ['uc_name', 'name', 'uc_code', 'code']);
    final zone = _firstText(json, const ['operational_zone_name', 'zone_name']);
    final id = _int(json['uc_zone_id'] ?? json['ucZoneId'] ?? json['id'] ?? json['zone_id']);
    return SupervisorUc(
      id: id,
      name: name.isEmpty ? 'UC $id' : name,
      zone: zone.isEmpty ? null : zone,
    );
  }
}

/// What the mark button should do for this worker right now.
class AttendanceMarkGate {
  const AttendanceMarkGate({required this.checkOut, required this.allowed, this.reason});

  /// True when today's row already has a check-in, so the next punch is check-out.
  final bool checkOut;
  final bool allowed;
  final String? reason;

  factory AttendanceMarkGate.evaluate({
    required AttendancePoint? point,
    required bool hasCheckIn,
    required DateTime nowPak,
  }) {
    if (point == null) {
      return const AttendanceMarkGate(
        checkOut: false,
        allowed: false,
        reason: 'Select an attendance point before marking.',
      );
    }
    if (!hasCheckIn) {
      return AttendanceMarkGate(
        checkOut: false,
        allowed: canCheckIn(point, nowPak),
        reason: checkInRefusal(point, nowPak),
      );
    }
    return AttendanceMarkGate(
      checkOut: true,
      allowed: canCheckOut(point, nowPak, true),
      reason: checkOutRefusal(point, nowPak, true),
    );
  }
}

bool attendanceHasCheckIn(Iterable<Map<String, dynamic>> rows) {
  for (final row in rows) {
    final type = '${row['type'] ?? ''}'.trim().toLowerCase();
    if (type == 'check_in' || type == 'check-in' || type == 'p1' || type == 'in') return true;
  }
  return false;
}

/// Check-in is allowed when now is at or after the open time and strictly before the close time.
bool canCheckIn(AttendancePoint point, DateTime nowPak) {
  final now = _minutes(nowPak);
  final open = hmMinutes(point.dutyStartFrom);
  final close = hmMinutes(point.dutyStartTime);
  if (open != null && now < open) return false;
  if (close != null && now >= close) return false;
  return true;
}

/// Check-out is allowed only after a check-in today, inside the evening window.
bool canCheckOut(AttendancePoint point, DateTime nowPak, bool hasCheckInToday) {
  if (!hasCheckInToday) return false;
  final now = _minutes(nowPak);
  final open = hmMinutes(point.dutyEndFrom);
  final close = hmMinutes(point.dutyEndTime);
  if (open != null && now < open) return false;
  if (close != null && now >= close) return false;
  return true;
}

String? checkInRefusal(AttendancePoint point, DateTime nowPak) {
  if (canCheckIn(point, nowPak)) return null;
  final now = _minutes(nowPak);
  final open = hmMinutes(point.dutyStartFrom);
  if (open != null && now < open) {
    return 'Morning attendance at ${point.name} opens at ${point.dutyStartFrom} (Pakistan time).';
  }
  return 'Morning attendance at ${point.name} closed after ${point.dutyStartTime} (Pakistan time).';
}

String? checkOutRefusal(AttendancePoint point, DateTime nowPak, bool hasCheckInToday) {
  if (!hasCheckInToday) return 'Check-out is available only after a check-in today.';
  if (canCheckOut(point, nowPak, true)) return null;
  final now = _minutes(nowPak);
  final open = hmMinutes(point.dutyEndFrom);
  if (open != null && now < open) {
    return 'Evening attendance at ${point.name} opens at ${point.dutyEndFrom} (Pakistan time).';
  }
  return 'Evening attendance at ${point.name} closed after ${point.dutyEndTime} (Pakistan time).';
}

/// Null when the phone is inside the point, or the point has no coordinates.
String? geofenceRefusal(AttendancePoint point, double latitude, double longitude) {
  if (point.latitude == null || point.longitude == null) return null;
  final radius = point.radiusMetres ?? AttendancePoint.defaultRadiusMetres;
  final metres = distanceMetres(latitude, longitude, point.latitude!, point.longitude!);
  if (metres <= radius) return null;
  final limit = radius == radius.roundToDouble() ? radius.round().toString() : radius.toStringAsFixed(0);
  return 'Outside ${point.name}. Move within $limit m of the attendance point.';
}

int? hmMinutes(String? hhmm) {
  if (hhmm == null) return null;
  final parts = hhmm.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

double distanceMetres(double lat1, double lon1, double lat2, double lon2) {
  const earth = 6371000.0;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

String _span(String label, String? from, String? to) {
  if (from == null && to == null) return '$label any time';
  if (from == null) return '$label before $to';
  if (to == null) return '$label from $from';
  return '$label $from–$to';
}

int _minutes(DateTime now) => now.hour * 60 + now.minute;

String? _clock(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key) || json[key] == null) return null;
  final raw = json[key].toString().trim();
  if (raw.isEmpty || raw.toLowerCase() == 'null') return null;
  final minutes = hmMinutes(raw);
  if (minutes == null) return null;
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

double? _nullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return double.tryParse(text);
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _text(Object? value) => value?.toString().trim() ?? '';

String _firstText(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final text = _text(json[key]);
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return '';
}
