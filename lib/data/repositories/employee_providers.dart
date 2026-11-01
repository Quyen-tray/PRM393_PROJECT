import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_providers.dart';
import 'employee_repository.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository(ref.watch(apiClientProvider));
});
