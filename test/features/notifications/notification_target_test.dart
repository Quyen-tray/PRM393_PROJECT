import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/features/notifications/presentation/notification_target.dart';
import '../../support/test_support.dart';

void main() {
  test(
    'Notification targets preserve their entity identity and permission-specific destination',
    () {
      expect(
        notificationRoute({
          'relatedEntityType': 'EmployeeRewardPenalty',
          'relatedEntityId': 42,
        }, employeeUser),
        '/record/my-rewards/42',
      );
      expect(
        notificationRoute({
          'relatedEntityType': 'EmployeeTraining',
          'relatedEntityId': 9,
        }, employeeUser),
        '/record/enrollments/9',
      );
      expect(
        notificationRoute({
          'relatedEntityType': 'UNKNOWN',
          'relatedEntityId': 9,
        }, employeeUser),
        null,
      );
    },
  );
}
