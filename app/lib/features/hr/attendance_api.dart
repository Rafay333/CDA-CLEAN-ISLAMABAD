import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const attendanceApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://localhost:4000',
);

class AttendanceException implements Exception {
  AttendanceException(this.message, {this.retry = false});

  final String message;
  final bool retry;

  @override
  String toString() => message;
}

class AttendanceApi {
  AttendanceApi({Dio? client})
    : dio =
          client ??
          Dio(
            BaseOptions(
              baseUrl: attendanceApiBase,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 90),
              headers: {'Accept': 'application/json'},
            ),
          );

  final Dio dio;

  Future<List<Map<String, dynamic>>> employees() {
    return _list(dio.get('/api/v1/hr/employees'));
  }

  Future<Map<String, dynamic>> employee(int id) {
    return _map(dio.get('/api/v1/hr/employees/$id'));
  }

  Future<Map<String, dynamic>> resetFace(int id) {
    return _map(dio.post('/api/v1/hr/employees/$id/reset-face'));
  }

  Future<Map<String, dynamic>> enroll(int employeeId, List<Uint8List> photos, String shift) {
    return _map(
      dio.post(
        '/api/v1/hr/enroll',
        data: _photos(photos, {'employeeId': employeeId, 'shift': shift}),
      ),
    );
  }

  Future<Map<String, dynamic>> markAttendance({
    required List<Uint8List> photos,
    required Position position,
    required String deviceId,
  }) {
    return _map(
      dio.post(
        '/api/v1/hr/attendance',
        data: _photos(photos, {
          'lat': position.latitude.toString(),
          'lng': position.longitude.toString(),
          'acc': position.accuracy.toString(),
          'mock': position.isMocked.toString(),
          'deviceId': deviceId,
        }),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> log({DateTime? date, String? query}) {
    final day = date == null
        ? null
        : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final text = query?.trim();
    return _list(
      dio.get(
        '/api/v1/hr/attendance',
        queryParameters: {
          'date': ?day,
          'q': text == null || text.isEmpty ? null : text,
        },
      ),
    );
  }

  String photoUrl(int id, String? registeredAt) {
    final stamp = Uri.encodeQueryComponent(registeredAt ?? '');
    return '$attendanceApiBase/api/v1/hr/employees/$id/photo?v=$stamp';
  }

  FormData _photos(List<Uint8List> photos, Map<String, dynamic> fields) {
    return FormData.fromMap({
      ...fields,
      for (var i = 0; i < photos.length; i++)
        'image$i': MultipartFile.fromBytes(photos[i], filename: 'face$i.jpg'),
    });
  }

  Future<Map<String, dynamic>> _map(Future<Response<dynamic>> call) async {
    final data = await _data(call);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> _list(Future<Response<dynamic>> call) async {
    final data = await _data(call);
    return (data as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<dynamic> _data(Future<Response<dynamic>> call) async {
    try {
      final response = await call;
      return response.data;
    } on DioException catch (error) {
      throw AttendanceException(
        _message(error),
        retry: error.response?.statusCode == 409,
      );
    }
  }

  String _message(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map && data['error']['message'] is String) {
      return data['error']['message'] as String;
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach the CDA Clean server.';
    }
    return 'Something went wrong. Try again.';
  }
}

Future<String> attendanceDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('attendanceDeviceId');
  if (saved != null && saved.isNotEmpty) return saved;
  final created = 'app-${DateTime.now().millisecondsSinceEpoch}';
  await prefs.setString('attendanceDeviceId', created);
  return created;
}

Future<Position> attendancePosition() async {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw AttendanceException('Location permission needed.');
  }
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );
  if (position.isMocked) {
    throw AttendanceException(
      'Fake GPS detected. Turn off any fake-location app and try again.',
    );
  }
  if (position.accuracy > 300) {
    throw AttendanceException(
      'GPS signal is too weak (accuracy ${position.accuracy.round()} m). Move to an open area and try again.',
    );
  }
  return position;
}
