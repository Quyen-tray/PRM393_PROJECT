import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/business_labels.dart';

void main() {
  test(
    'Unknown business states remain visible and midnight-crossing dates include both days',
    () {
      expect(statusLabel('NEW_BACKEND_STATE'), 'NEW_BACKEND_STATE');
      expect(dateText('2026-11-04T22:00:00+07:00'), '04/11/2026 · 22:00');
      expect(dateText('2026-11-05T06:00:00+07:00'), '05/11/2026 · 06:00');
    },
  );
}
