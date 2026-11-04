import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../storage/session_store.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';

class AuthenticatedApi {
  AuthenticatedApi({Dio? transport, TokenVault? vault})
      : vault = vault ?? TokenVault(const SecureSessionStore()),
        dio = transport ??
            Dio(BaseOptions(
                baseUrl: ApiEndpoints.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                sendTimeout: const Duration(seconds: 30),
                headers: {'Accept': 'application/json'}));
  final Dio dio;
  final TokenVault vault;
  Future<bool>? _refreshing;
  void Function()? onExpired;

  Future<bool> refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  Future<bool> _doRefresh() async {
    if (vault.refreshToken == null) return false;
    final generation = vault.generation;
    try {
      final response = await dio.post('/api/v1/auth/refresh',
          data: {'refreshToken': vault.refreshToken});
      if (generation != vault.generation) return false;
      await vault.save(Map<String, dynamic>.from(response.data['data']));
      return true;
    } on DioException catch (e) {
      if ([400, 401, 403].contains(e.response?.statusCode)) {
        await vault.clear();
        onExpired?.call();
      }
      throw mapError(e);
    }
  }

  Future<Response<dynamic>> request(String method, String path,
      {Object? data,
      Map<String, dynamic>? queryParameters,
      Map<String, dynamic>? headers,
      String? contentType,
      ResponseType? responseType}) async {
    final authenticated =
        !path.endsWith('/auth/google') && !path.endsWith('/auth/refresh');
    Future<Response<dynamic>> send() => dio.request(path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
            method: method,
            contentType: contentType,
            responseType: responseType,
            headers: {
              if (authenticated && vault.accessToken != null)
                'Authorization': 'Bearer ${vault.accessToken}',
              if (authenticated && vault.deviceCredential != null)
                'X-Device-Credential': vault.deviceCredential,
              ...?headers
            }));
    try {
      return await send();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 &&
          authenticated &&
          vault.refreshToken != null) {
        if (await refresh()) {
          try {
            return await send();
          } on DioException catch (retry) {
            if (retry.response?.statusCode == 401) {
              await vault.clear();
              onExpired?.call();
            }
            throw mapError(retry);
          }
        }
      }
      if (e.response?.statusCode == 401 && authenticated) {
        await vault.clear();
        onExpired?.call();
      }
      throw mapError(e);
    }
  }

  Future<dynamic> data(String method, String path,
      {Object? body,
      Map<String, dynamic>? query,
      Map<String, dynamic>? headers}) async {
    final response = await request(
        method, path.startsWith('/api/') ? path : '/api/v1$path',
        data: body, queryParameters: query, headers: headers);
    if (response.data == null || response.statusCode == 204) return null;
    final envelope = response.data;
    if (envelope is! Map || envelope['success'] != true) {
      throw const ApiException(
          message: 'Máy chủ trả về dữ liệu không hợp lệ.',
          code: 'INVALID_RESPONSE');
    }
    return envelope['data'];
  }

  Future<String> upload(Uint8List bytes, String mime, String purpose,
      {int? employeeId}) async {
    final r = await request('POST', '/api/v1/storage/uploads',
        data: bytes,
        contentType: mime,
        queryParameters: {
          'purpose': purpose,
          if (employeeId != null) 'targetEmployeeId': employeeId
        });
    return r.data['data']['storageKey'] as String;
  }

  ApiException mapError(DioException e) {
    final body = e.response?.data;
    final error =
        body is Map && body['error'] is Map ? body['error'] as Map : const {};
    return ApiException(
        statusCode: e.response?.statusCode,
        code: error['code'] as String?,
        details: error['details'] is Map
            ? Map<String, dynamic>.from(error['details'])
            : const {},
        message: body is Map && body['message'] is String
            ? body['message'] as String
            : e.type == DioExceptionType.connectionTimeout ||
                    e.type == DioExceptionType.receiveTimeout
                ? 'Yêu cầu quá thời gian. Hãy tải lại để kiểm tra kết quả trước khi gửi lại.'
                : 'Không thể kết nối máy chủ. Kiểm tra mạng và thử lại.');
  }
}
