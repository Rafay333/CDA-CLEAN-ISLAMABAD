import 'dart:typed_data';

import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this.base) {
    dio = Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        headers: {'Accept': 'application/json'},
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (access != null) {
            options.headers['Authorization'] = 'Bearer $access';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final path = error.requestOptions.path;
          final canRefresh =
              error.response?.statusCode == 401 &&
              refresh != null &&
              error.requestOptions.extra['retried'] != true &&
              !path.contains('/auth/');
          if (!canRefresh) {
            handler.next(error);
            return;
          }
          try {
            final fresh = Dio(BaseOptions(baseUrl: base));
            final result = await fresh.post<Map<String, dynamic>>(
              '/api/v1/auth/refresh',
              data: {'refreshToken': refresh},
            );
            access = result.data?['accessToken'] as String?;
            refresh = result.data?['refreshToken'] as String?;
            if (access != null && refresh != null) {
              await onTokens?.call(access!, refresh!);
            }
            final request = error.requestOptions;
            request.headers['Authorization'] = 'Bearer $access';
            request.extra['retried'] = true;
            handler.resolve(await dio.fetch(request));
          } catch (_) {
            await onAuthFailure?.call();
            handler.next(error);
          }
        },
      ),
    );
  }

  final String base;
  late final Dio dio;
  String? access;
  String? refresh;
  Future<void> Function(String access, String refresh)? onTokens;
  Future<void> Function()? onAuthFailure;

  void setTokens(String nextAccess, String nextRefresh) {
    access = nextAccess;
    refresh = nextRefresh;
  }

  void clear() {
    access = null;
    refresh = null;
  }

  Future<Map<String, dynamic>> health() async =>
      _map(dio.get('/api/v1/health'));

  Future<void> requestOtp(String phone) async {
    await _data(dio.post('/api/v1/auth/otp/request', data: {'phone': phone}));
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
    String? fullName,
  }) {
    return _map(
      dio.post(
        '/api/v1/auth/otp/verify',
        data: {
          'phone': phone,
          'code': code,
          if (fullName != null && fullName.trim().isNotEmpty)
            'fullName': fullName.trim(),
        },
      ),
    );
  }

  Future<Map<String, dynamic>> staffLogin(String employeeId, String password) {
    return _map(
      dio.post(
        '/api/v1/auth/staff/login',
        data: {'employeeId': employeeId, 'password': password},
      ),
    );
  }

  Future<Map<String, dynamic>> me() => _map(dio.get('/api/v1/me'));

  Future<Map<String, dynamic>> patchMe({
    String? fullName,
    String? sectorId,
    String? language,
  }) {
    return _map(
      dio.patch(
        '/api/v1/me',
        data: {
          'fullName': ?fullName,
          'sectorId': ?sectorId,
          'language': ?language,
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> categories() =>
      _list(dio.get('/api/v1/categories'));

  Future<List<Map<String, dynamic>>> sectors() =>
      _list(dio.get('/api/v1/sectors'));

  Future<List<Map<String, dynamic>>> zones() => _list(dio.get('/api/v1/zones'));

  Future<Map<String, dynamic>?> lookupSector(double lat, double lng) async {
    final data = await _data(
      dio.get(
        '/api/v1/sectors/lookup',
        queryParameters: {'lat': lat, 'lng': lng},
      ),
    );
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> schedule(String? sectorId) {
    return _map(
      dio.get('/api/v1/schedule', queryParameters: {'sectorId': ?sectorId}),
    );
  }

  Future<String> uploadPhoto(Uint8List bytes, String kind) async {
    final form = FormData.fromMap({
      'kind': kind,
      'file': MultipartFile.fromBytes(bytes, filename: 'photo.jpg'),
    });
    final data = await _map(dio.post('/api/v1/media', data: form));
    return '${data['id']}';
  }

  Future<Map<String, dynamic>> createCase(Map<String, dynamic> body) =>
      _map(dio.post('/api/v1/cases', data: body));

  Future<List<Map<String, dynamic>>> myCases() =>
      _list(dio.get('/api/v1/cases'));

  Future<Map<String, dynamic>> caseDetail(String id) =>
      _map(dio.get('/api/v1/cases/$id'));

  Future<List<Map<String, dynamic>>> mapPins(String sectorId) {
    return _list(
      dio.get('/api/v1/cases/map', queryParameters: {'sectorId': sectorId}),
    );
  }

  Future<List<Map<String, dynamic>>> zoneCases({
    String? bucket,
    String? query,
  }) {
    final search = query == null || query.isEmpty ? null : query;
    return _list(
      dio.get(
        '/api/v1/zone/cases',
        queryParameters: {'bucket': ?bucket, 'q': ?search},
      ),
    );
  }

  Future<List<Map<String, dynamic>>> officers() =>
      _list(dio.get('/api/v1/zone/officers'));

  Future<List<Map<String, dynamic>>> jobs() => _list(dio.get('/api/v1/jobs'));

  Future<Map<String, dynamic>> postCase(
    String id,
    String action, [
    Map<String, dynamic>? body,
  ]) {
    return _map(
      dio.post('/api/v1/cases/$id/$action', data: body ?? <String, dynamic>{}),
    );
  }

  Future<List<Map<String, dynamic>>> notifications() =>
      _list(dio.get('/api/v1/notifications'));

  Future<void> markRead(String id) async {
    await _data(dio.post('/api/v1/notifications/$id/read'));
  }

  Future<Map<String, dynamic>> cityDashboard() =>
      _map(dio.get('/api/v1/dashboard/city'));

  Future<List<Map<String, dynamic>>> adminCases() =>
      _list(dio.get('/api/v1/admin/cases'));

  Future<List<Map<String, dynamic>>> staff() =>
      _list(dio.get('/api/v1/admin/staff'));

  Future<void> createStaff(Map<String, dynamic> body) async {
    await _data(dio.post('/api/v1/admin/staff', data: body));
  }

  Future<void> setStaffStatus(String id, String status) async {
    await _data(dio.patch('/api/v1/admin/staff/$id', data: {'status': status}));
  }

  Future<void> logout() async {
    if (refresh == null) return;
    try {
      await dio.post('/api/v1/auth/logout', data: {'refreshToken': refresh});
    } catch (_) {
      // Local sign-out still proceeds when the server is unreachable.
    }
  }

  Future<Map<String, dynamic>> _map(Future<Response<dynamic>> call) async {
    final data = await _data(call);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> _list(
    Future<Response<dynamic>> call,
  ) async {
    final data = await _data(call);
    return (data as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<dynamic> _data(Future<Response<dynamic>> call) async {
    try {
      final response = await call;
      return response.data;
    } on DioException catch (error) {
      throw ApiException(_message(error));
    }
  }

  String _message(DioException error) {
    final data = error.response?.data;
    if (data is Map &&
        data['error'] is Map &&
        data['error']['message'] is String) {
      return data['error']['message'] as String;
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach the CDA Clean server.';
    }
    return 'Something went wrong. Try again.';
  }
}
