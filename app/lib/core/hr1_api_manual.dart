import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'supervisor_api.dart';

const _authKey = 'CDA-EMP-8fK2mN9qR4vX7wP1sT6yH3bL5cJ0';

/// Manual HR photo registration and GPS attendance.
/// Does not call the face-recognition endpoints.
class Hr1ApiManual {
  Hr1ApiManual({Dio? client}) : dio = client ?? _shared;

  static final Dio _shared = Dio(
    BaseOptions(
      baseUrl: supervisorBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
      headers: {'Accept': 'application/json', 'authkey': _authKey},
    ),
  );

  final Dio dio;

  Map<String, String> get photoHeaders => const {'authkey': _authKey};

  String absolute(String? path, String cnic) {
    final raw = path?.trim() ?? '';
    if (raw.isEmpty) return '';
    final base = raw.startsWith('http://') || raw.startsWith('https://') ? raw : '$supervisorBaseUrl$raw';
    final uri = Uri.parse(base);
    final query = Map<String, String>.from(uri.queryParameters);
    query['supervisor_cnic'] = cnic;
    return uri.replace(queryParameters: query).toString();
  }

  Future<Map<String, dynamic>> registration(String cnic, int employeeId) async {
    final data = _map(
      await _send(
        dio.get(
          '/api/supervisor/hr-photo-manual/register/$employeeId',
          queryParameters: {'supervisor_cnic': cnic},
        ),
      ),
    );
    if (data['success'] == false) {
      throw SupervisorException(_text(data['message']).isEmpty ? 'Photo status was not loaded.' : _text(data['message']));
    }
    return data;
  }

  Future<Map<String, dynamic>> registerPhoto({
    required String cnic,
    required int employeeId,
    required String shift,
    required String camera,
    required Uint8List photo,
  }) async {
    final data = _map(
      await _send(
        dio.post(
          '/api/supervisor/hr-photo-manual/register',
          data: FormData.fromMap({
            'supervisor_cnic': cnic,
            'employee_id': employeeId,
            'shift': shift,
            'camera': camera,
            'image': MultipartFile.fromBytes(photo, filename: 'photo.jpg'),
          }),
        ),
      ),
    );
    if (data['success'] == false) {
      throw SupervisorException(_text(data['message']).isEmpty ? 'Photo was not registered.' : _text(data['message']));
    }
    return data;
  }

  Future<Map<String, dynamic>> markAttendance({
    required String cnic,
    required int employeeId,
    required String type,
    required Uint8List photo,
    required double latitude,
    required double longitude,
    required double accuracy,
    required bool mock,
    int? attendancePointId,
    String? note,
  }) async {
    final data = _map(
      await _send(
        dio.post(
          '/api/supervisor/hr-photo-manual/attendance',
          data: FormData.fromMap({
            'supervisor_cnic': cnic,
            'employee_id': employeeId,
            'type': type,
            'lat': latitude.toString(),
            'lng': longitude.toString(),
            'accuracy': accuracy.toString(),
            'mock': mock.toString(),
            if (attendancePointId != null) 'attendance_point_id': '$attendancePointId',
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
            'image': MultipartFile.fromBytes(photo, filename: 'selfie.jpg'),
          }),
        ),
      ),
    );
    if (data['success'] == false) {
      throw SupervisorException(_text(data['message']).isEmpty ? 'Attendance was not saved.' : _text(data['message']));
    }
    final attendance = data['attendance'];
    return {
      'message': _text(data['message']).isEmpty ? 'Attendance saved.' : _text(data['message']),
      'attendance': attendance is Map ? Map<String, dynamic>.from(attendance) : <String, dynamic>{},
    };
  }

  Future<List<Map<String, dynamic>>> attendanceLog(
    String cnic, {
    String? date,
    int? employeeId,
  }) async {
    final data = await _send(
      dio.get(
        '/api/supervisor/hr-photo-manual/attendance',
        queryParameters: {
          'supervisor_cnic': cnic,
          if (date != null && date.isNotEmpty) 'date': date,
          'employee_id': ?employeeId,
        },
      ),
    );
    if (data is Map && data['success'] == false) {
      throw SupervisorException(_text(data['message']).isEmpty ? 'Attendance log was not loaded.' : _text(data['message']));
    }
    if (data is! List) throw SupervisorException('The server sent an unexpected response.');
    return [
      for (final item in data)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Future<dynamic> _send(Future<Response<dynamic>> call) async {
    try {
      final response = await call;
      return response.data;
    } on DioException catch (error) {
      throw SupervisorException(_message(error), retry: _retry(error));
    }
  }
}

bool _retry(DioException error) {
  return error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.unknown;
}

String _message(DioException error) {
  final fromBody = _serverMessage(error.response?.data);
  if (fromBody != null) {
    if (RegExp(r'Invalid object name|Invalid column name', caseSensitive: false).hasMatch(fromBody)) {
      return 'Attendance could not be saved. Publish the updated API and restart it.';
    }
    return fromBody.replaceFirst(RegExp(r'^API error:\s*', caseSensitive: false), '');
  }
  final code = error.response?.statusCode;
  if (code == 404) return 'Manual HR is not available on the supervisor server yet.';
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return 'No internet. Check the connection and try again.';
  }
  if (code != null) return 'The supervisor server returned an error ($code).';
  return 'Something went wrong. Try again.';
}

String? _serverMessage(dynamic data) {
  if (data is Map) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();
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

String _text(Object? value) => value?.toString() ?? '';
