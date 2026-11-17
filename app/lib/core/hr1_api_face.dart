import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'supervisor_api.dart';

const _authKey = 'CDA-EMP-8fK2mN9qR4vX7wP1sT6yH3bL5cJ0';

/// Face-recognition HR module (`/api/supervisor/hr-photo-face`).
/// Parallel to [Hr1ApiManual] — does not replace the manual GPS-stamp path.
class Hr1ApiFace {
  Hr1ApiFace({Dio? client}) : dio = client ?? _shared;

  static final Dio _shared = Dio(
    BaseOptions(
      baseUrl: supervisorBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 120),
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
          '/api/supervisor/hr-photo-face/register/$employeeId',
          queryParameters: {'supervisor_cnic': cnic},
        ),
      ),
    );
    if (data['success'] == false) {
      throw SupervisorException(
        _text(data['message']).isEmpty ? 'Face status was not loaded.' : _text(data['message']),
      );
    }
    return data;
  }

  /// Exactly 3 photos: `image0`, `image1`, `image2`.
  Future<Map<String, dynamic>> registerFace({
    required String cnic,
    required int employeeId,
    required String shift,
    required List<Uint8List> photos,
    String? camera,
  }) async {
    if (photos.length != 3) {
      throw SupervisorException('Exactly 3 photos required (image0, image1, image2).');
    }
    final form = <String, dynamic>{
      'supervisor_cnic': cnic,
      'employee_id': employeeId,
      'shift': shift,
      if (camera != null && camera.isNotEmpty) 'camera': camera,
      'image0': MultipartFile.fromBytes(photos[0], filename: 'image0.jpg'),
      'image1': MultipartFile.fromBytes(photos[1], filename: 'image1.jpg'),
      'image2': MultipartFile.fromBytes(photos[2], filename: 'image2.jpg'),
    };
    final data = _map(
      await _send(dio.post('/api/supervisor/hr-photo-face/register', data: FormData.fromMap(form))),
    );
    if (data['success'] == false) {
      throw SupervisorException(
        _text(data['message']).isEmpty ? 'Face was not registered.' : _text(data['message']),
      );
    }
    return data;
  }

  /// Attendance burst: exactly 3 live frames as `image0` / `image1` / `image2` (liveness + 1:1 verify).
  Future<Map<String, dynamic>> markAttendance({
    required String cnic,
    required int employeeId,
    required String type,
    required List<Uint8List> photos,
    required double latitude,
    required double longitude,
    required double accuracy,
    required bool mock,
    int? attendancePointId,
    String? note,
  }) async {
    if (photos.length != 3) {
      throw SupervisorException(
        'Exactly 3 photos required (image0, image1, image2) taken within about 5 seconds.',
      );
    }
    final data = _map(
      await _send(
        dio.post(
          '/api/supervisor/hr-photo-face/attendance',
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
            'image0': MultipartFile.fromBytes(photos[0], filename: 'image0.jpg'),
            'image1': MultipartFile.fromBytes(photos[1], filename: 'image1.jpg'),
            'image2': MultipartFile.fromBytes(photos[2], filename: 'image2.jpg'),
          }),
        ),
      ),
    );
    if (data['success'] == false) {
      throw SupervisorException(
        _text(data['message']).isEmpty ? 'Attendance was not saved.' : _text(data['message']),
      );
    }
    final attendance = data['attendance'];
    return {
      'message': _text(data['message']).isEmpty ? 'Attendance saved.' : _text(data['message']),
      'match_percent': data['match_percent'],
      'employee_id': data['employee_id'],
      'employee_name': data['employee_name'],
      'latitude': data['latitude'],
      'longitude': data['longitude'],
      'accuracy_metres': data['accuracy_metres'],
      'address': data['address'],
      'motion': data['motion'],
      'blink': data['blink'],
      'yaw_change': data['yaw_change'],
      'spoof_score': data['spoof_score'],
      'liveness_ok': data['liveness_ok'],
      'suspicious': data['suspicious'] == true,
      'suspicious_reason': _text(data['suspicious_reason']),
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
        '/api/supervisor/hr-photo-face/attendance',
        queryParameters: {
          'supervisor_cnic': cnic,
          if (date != null && date.isNotEmpty) 'date': date,
          'employee_id': ?employeeId,
        },
      ),
    );
    if (data is Map && data['success'] == false) {
      throw SupervisorException(
        _text(data['message']).isEmpty ? 'Attendance log was not loaded.' : _text(data['message']),
      );
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
    return fromBody.replaceFirst(RegExp(r'^API error:\s*', caseSensitive: false), '');
  }
  final code = error.response?.statusCode;
  if (code == 404) return 'Face HR is not available on the supervisor server yet.';
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
