import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/core/network/authenticated_api.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';

class AuditRepository {
  const AuditRepository(this.api);
  final AuthenticatedApi api;
  Future<String> exportAudit(Json query) async {
    final response = await api.request(
      'GET',
      '/api/v1/admin/audit-logs/export',
      queryParameters: query,
      responseType: ResponseType.plain,
    );
    return response.data as String;
  }
}

final auditRepositoryProvider =
    Provider((ref) => AuditRepository(ref.watch(authenticatedApiProvider)));
