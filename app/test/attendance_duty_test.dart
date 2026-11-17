import 'package:cda_clean_islamabad/core/attendance_duty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final office = AttendancePoint.fromJson({
    'attendance_point_id': 5,
    'uc_zone_id': 18,
    'name': 'UC office gate',
    'latitude': 33.6844,
    'longitude': 73.0479,
    'radius_metres': 100,
    'duty_start_from': '07:00',
    'duty_start_time': '09:00',
    'duty_end_from': '17:00',
    'duty_end_time': '19:00',
  });

  final legacy = AttendancePoint.fromJson({
    'attendance_point_id': 1,
    'name': 'UC_Islamabad_Expressway',
    'duty_start_from': null,
    'duty_start_time': '04:00',
    'duty_end_from': null,
    'duty_end_time': '07:00',
  });

  DateTime at(int hour, int minute, [int second = 0]) => DateTime(2026, 11, 13, hour, minute, second);

  test('check-in window 07:00–09:00 allows the open minute and refuses the close minute', () {
    expect(canCheckIn(office, at(6, 59)), isFalse);
    expect(canCheckIn(office, at(7, 0)), isTrue);
    expect(canCheckIn(office, at(8, 59, 59)), isTrue);
    expect(canCheckIn(office, at(9, 0)), isFalse);
    expect(canCheckIn(office, at(17, 0)), isFalse);
  });

  test('check-out window 17:00–19:00 requires a check-in today', () {
    expect(canCheckOut(office, at(16, 59), true), isFalse);
    expect(canCheckOut(office, at(17, 0), true), isTrue);
    expect(canCheckOut(office, at(18, 59), true), isTrue);
    expect(canCheckOut(office, at(19, 0), true), isFalse);
    expect(canCheckOut(office, at(17, 0), false), isFalse);
  });

  test('a null open time still closes at the stored close time', () {
    expect(canCheckIn(legacy, at(3, 59)), isTrue);
    expect(canCheckIn(legacy, at(4, 0)), isFalse);
    expect(canCheckOut(legacy, at(6, 59), true), isTrue);
    expect(canCheckOut(legacy, at(7, 0), true), isFalse);
  });

  test('missing duty keys are treated as null and do not block that edge', () {
    final open = AttendancePoint.fromJson({
      'attendance_point_id': 9,
      'name': 'Gate',
    });
    expect(open.dutyStartFrom, isNull);
    expect(open.dutyStartTime, isNull);
    expect(open.dutyEndFrom, isNull);
    expect(open.dutyEndTime, isNull);
    expect(canCheckIn(open, at(23, 30)), isTrue);
    expect(canCheckOut(open, at(1, 0), true), isTrue);
  });

  test('a missed check-in does not become a check-out later in the day', () {
    final gate = AttendanceMarkGate.evaluate(point: office, hasCheckIn: false, nowPak: at(17, 30));
    expect(gate.checkOut, isFalse);
    expect(gate.allowed, isFalse);
    expect(gate.reason, contains('closed after 09:00'));
  });

  test('live payloads omit open times and use uc_name plus zone', () {
    final point = AttendancePoint.fromJson({
      'attendance_point_id': 1,
      'uc_zone_id': 78,
      'name': 'UC_Islamabad_Expressway',
      'latitude': 33.68742,
      'longitude': 73.21686,
      'radius_metres': null,
      'duty_start_time': '04:00',
      'duty_end_time': '07:00',
    });
    expect(point.dutyStartFrom, isNull);
    expect(point.dutyEndFrom, isNull);
    expect(point.radiusMetres, isNull);
    expect(point.windowSummary, 'Check-in before 04:00 · Check-out before 07:00');
    expect(canCheckIn(point, at(3, 59, 59)), isTrue);
    expect(canCheckIn(point, at(4, 0)), isFalse);

    final uc = SupervisorUc.fromJson({
      'uc_zone_id': 78,
      'uc_code': null,
      'uc_name': 'Islamabad_Expressway',
      'operational_zone_name': 'Zone-IV',
    });
    expect(uc.id, 78);
    expect(uc.label, 'Islamabad_Expressway · Zone-IV');

    final bulk = SupervisorUc.fromJson({
      'uc_zone_id': 73,
      'uc_name': 'Bulk Waste',
      'operational_zone_name': 'Zone-V',
    });
    expect(bulk.label, 'Bulk Waste · Zone-V');
  });

  test('geofence uses 100 m when radius is missing and skips when coordinates are missing', () {
    final noCoords = AttendancePoint.fromJson({'attendance_point_id': 3, 'name': 'Desk'});
    expect(geofenceRefusal(noCoords, 33.68, 73.04), isNull);

    final here = AttendancePoint.fromJson({
      'attendance_point_id': 4,
      'name': 'Gate',
      'latitude': 33.6844,
      'longitude': 73.0479,
    });
    expect(geofenceRefusal(here, 33.6844, 73.0479), isNull);
    expect(geofenceRefusal(here, 33.70, 73.10), contains('Move within 100 m'));
  });
}
