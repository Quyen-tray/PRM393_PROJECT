import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:hrm_coffee_shop_flutter/core/storage/session_store.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';

class MemoryStore implements SessionStore {
  MemoryStore([Map<String, String> initial = const {}]) : values = {...initial};
  final Map<String, String> values;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class TestAdapter implements HttpClientAdapter {
  TestAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      handler(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody response(Object? data,
        {int status = 200,
        String message = 'OK',
        String? code,
        Map<String, dynamic>? details}) =>
    ResponseBody.fromString(
        jsonEncode({
          'success': status < 400,
          'message': message,
          'data': data,
          'error': code == null ? null : {'code': code, 'details': details}
        }),
        status,
        headers: {
          'content-type': ['application/json']
        });

class FixedSession extends SessionController {
  FixedSession(this.initial);
  final SessionState initial;
  @override
  SessionState build() => initial;
  void replace(SessionState next) => state = next;
}

const employeeUser = CurrentUser(
    id: 1,
    name: 'Nhân viên kiểm thử',
    email: 'employee@example.test',
    roles: {'EMPLOYEE'},
    permissions: {},
    employeeId: 12);
