import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';

void main() {
  test('Pagination retains total count and page boundaries', () {
    final page = ResourcePage.parse({
      'items': [
        {'employeeId': 17},
      ],
      'page': 2,
      'totalPages': 4,
      'totalElements': 61,
    });
    expect(page.page, 2);
    expect(page.total, 61);
    expect(page.items.single['employeeId'], 17);
  });
}
