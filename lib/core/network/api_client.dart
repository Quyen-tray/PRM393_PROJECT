import 'package:dio/dio.dart';

import 'api_endpoints.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient()
      : dio = Dio(
    BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  final Dio dio;

  Future<Response<dynamic>> get(
      String path, {
        Map<String, dynamic>? queryParameters,
      }) async {
    try {
      return await dio.get(
        path,
        queryParameters: queryParameters,
      );
    } on DioException catch (error) {
      throw _mapException(error);
    }
  }

  Future<Response<dynamic>> post(
      String path, {
        Object? data,
      }) async {
    try {
      return await dio.post(path, data: data);
    } on DioException catch (error) {
      throw _mapException(error);
    }
  }

  ApiException _mapException(DioException error) {
    final statusCode = error.response?.statusCode;

    final responseData = error.response?.data;
    var message = 'Không thể kết nối đến máy chủ.';

    if (responseData is Map<String, dynamic>) {
      final serverMessage = responseData['message'];
      if (serverMessage is String && serverMessage.isNotEmpty) {
        message = serverMessage;
      }
    }

    if (statusCode == 401) {
      message = 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.';
    } else if (statusCode == 403) {
      message = 'Bạn không có quyền thực hiện thao tác này.';
    }

    return ApiException(
      message: message,
      statusCode: statusCode,
    );
  }
}