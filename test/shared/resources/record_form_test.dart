import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_exception.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_form.dart';
import '../../support/resource_fixtures.dart';

void main() {
  testWidgets(
    'Backend validation preserves form input and prevents duplicate submit',
    (tester) async {
      final pending = Completer<void>();
      int calls = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RecordForm(
              title: 'Cập nhật',
              fields: const [FieldSpec('name', 'Tên', required: true)],
              onSubmit: (value) async {
                calls++;
                await pending.future;
                throw const ApiException(
                  message: 'Tên đã tồn tại',
                  statusCode: 409,
                );
              },
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'Tên đã nhập');
      await tester.tap(find.text('Lưu và hoàn tất'));
      await tester.pump();
      expect(calls, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Tên đã nhập'), findsOneWidget);
      expect(find.byType(ErrorPanel), findsOneWidget);
      expect(find.text('Tên đã tồn tại'), findsOneWidget);
    },
  );

  testWidgets(
    'A form can finish after its originating resource widget reloads',
    (tester) async {
      late VoidCallback removeOrigin;
      bool showOrigin = true;
      late RecordingRepository repository;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resourceRepositoryProvider.overrideWith(
              (ref) => repository = RecordingRepository(
                ref.read(authenticatedApiProvider),
              ),
            ),
          ],
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                removeOrigin = () => setState(() => showOrigin = false);
                return Scaffold(
                  body: showOrigin
                      ? Consumer(
                          builder: (context, ref, _) => TextButton(
                            onPressed: () => editRecord(
                              context,
                              ref,
                              title: 'Gửi yêu cầu',
                              fields: const [
                                FieldSpec(
                                  'reason',
                                  'Nội dung',
                                  kind: FieldKind.multiline,
                                  required: true,
                                ),
                              ],
                              path: '/requests',
                            ),
                            child: const Text('Mở form'),
                          ),
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở form'));
      await tester.pumpAndSettle();
      removeOrigin();
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.multiline);
      await tester.enterText(
        find.byType(TextFormField),
        'Nội dung đã nhập\nDòng tiếp theo',
      );
      await tester.tap(find.text('Lưu và hoàn tất'));
      await tester.pumpAndSettle();
      expect(repository.writes.single['path'], '/requests');
      expect(repository.writes.single['body'], {
        'reason': 'Nội dung đã nhập\nDòng tiếp theo',
      });
      expect(tester.takeException(), isNull);
    },
  );
}
