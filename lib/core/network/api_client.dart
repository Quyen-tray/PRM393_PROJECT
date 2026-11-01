import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_endpoints.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    Dio? dio,
    FlutterSecureStorage? storage,
  })  : dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiEndpoints.baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 20),
              headers: const {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
            )),
        storage = storage ?? const FlutterSecureStorage() {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final path = options.path;
          if (!_isPublic(path)) {
            final token = await this.storage.read(key: _accessTokenKey);
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          if (error.response?.statusCode != 401 ||
              request.extra['retried'] == true ||
              _isPublic(request.path)) {
            handler.next(error);
            return;
          }

          try {
            final newAccessToken = await _refreshAccessToken();
            if (newAccessToken == null) {
              handler.next(error);
              return;
            }
            request
              ..extra['retried'] = true
              ..headers['Authorization'] = 'Bearer $newAccessToken';
            final response = await this.dio.fetch<dynamic>(request);
            handler.resolve(response);
          } catch (_) {
            await clearTokens();
            handler.next(error);
          }
        },
      ),
    );
  }

  static const _accessTokenKey = 'hrm_access_token';
  static const _refreshTokenKey = 'hrm_refresh_token';

  final Dio dio;
  final FlutterSecureStorage storage;
  Completer<String?>? _refreshCompleter;

  bool _isPublic(String path) =>
      path.contains('/auth/google') || path.contains('/auth/refresh');

  Future<String?> _refreshAccessToken() async {
    if (_refreshCompleter != null) return _refreshCompleter!.future;

    final completer = Completer<String?>();
    _refreshCompleter = completer;
    try {
      final refreshToken = await storage.read(key: _refreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) {
        await clearTokens();
        completer.complete(null);
      } else {
        final refreshDio = Dio(BaseOptions(
          baseUrl: ApiEndpoints.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: const {'Accept': 'application/json'},
        ));
        final response = await refreshDio.post(
          '/api/v1/auth/refresh',
          data: {'refreshToken': refreshToken},
        );
        final payload = response.data;
        final data = payload is Map ? payload['data'] : null;
        if (payload is! Map ||
            payload['success'] != true ||
            data is! Map ||
            data['accessToken'] is! String ||
            data['refreshToken'] is! String) {
          throw const FormatException('Phản hồi refresh token không hợp lệ.');
        }
        final access = data['accessToken'] as String;
        await saveTokens(
          accessToken: access,
          refreshToken: data['refreshToken'] as String,
        );
        completer.complete(access);
      }
    } catch (error) {
      if (!completer.isCompleted) completer.completeError(error);
    } finally {
      _refreshCompleter = null;
    }
    return completer.future;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await storage.write(key: _accessTokenKey, value: accessToken);
    await storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> readAccessToken() => storage.read(key: _accessTokenKey);
  Future<String?> readRefreshToken() => storage.read(key: _refreshTokenKey);

  Future<void> clearTokens() async {
    await storage.delete(key: _accessTokenKey);
    await storage.delete(key: _refreshTokenKey);
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await dio.get(path, queryParameters: queryParameters);
    } on DioException catch (error) {
      throw _mapException(error);
    }
  }

  Future<Response<dynamic>> post(String path, {Object? data}) async {
    try {
      return await dio.post(path, data: data);
    } on DioException catch (error) {
      throw _mapException(error);
    }
  }

  Future<Response<dynamic>> put(String path, {Object? data}) async {
    try {
      return await dio.put(path, data: data);
    } on DioException catch (error) {
      throw _mapException(error);
    }
  }

  Future<Response<dynamic>> patch(String path, {Object? data}) async {
    try {
      return await dio.patch(path, data: data);
    } on DioException catch (error) {
      throw _mapException(error);
    }
  }

  Future<Response<dynamic>> delete(String path, {Object? data}) async {
    try {
      return await dio.delete(path, data: data);
    } on DioException catch (error) {
      throw _mapException(error);
    }
  }

  Future<Response<dynamic>> uploadBytes(
    String path, {
    required List<int> bytes,
    required String contentType,
  }) async {
    try {
      return await dio.post(
        path,
        data: bytes,
        options: Options(headers: {'Content-Type': contentType}),
      );
    } on DioException catch (error) {
      throw _mapException(error);
    }
  }

  ApiException _mapException(DioException error) {
    final statusCode = error.response?.statusCode;
    final body = error.response?.data;
    var message = 'Không thể kết nối đến máy chủ.';

    if (body is Map) {
      if (body['message'] is String) {
        message = body['message'] as String;
      } else if (body['error'] is Map && body['error']['message'] is String) {
        message = body['error']['message'] as String;
      }
    }

    if (statusCode == 401) {
      message = 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.';
    } else if (statusCode == 403) {
      message = 'Bạn không có quyền thực hiện thao tác này.';
    } else if (statusCode == 404) {
      message = 'Không tìm thấy dữ liệu hoặc API.';
    } else if (statusCode == 405) {
      message = 'Phương thức gọi API không được hỗ trợ.';
    }

    Map<String, dynamic>? details;
    if (body is Map && body['error'] is Map && (body['error'] as Map)['details'] is Map) {
      details = Map<String, dynamic>.from((body['error'] as Map)['details'] as Map);
    }

    return ApiException(message: message, statusCode: statusCode, details: details);
  }
}
