import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/features/training/presentation/quiz_question_editor.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import '../../support/test_support.dart';

class QuestionRepository extends ResourceRepository {
  QuestionRepository(super.api);
  final rows = <Json>[];
  final writes = <Json>[];
  @override
  Future<dynamic> read(String path, [Json query = const {}]) async => rows;
  @override
  Future<dynamic> write(String method, String path, [Object? body]) async {
    writes.add({'method': method, 'path': path, 'body': body});
    if (method == 'DELETE') {
      rows.clear();
      return null;
    }
    rows.clear();
    rows.add({...json(body), 'questionId': writes.length});
    return rows.last;
  }
}

void main() {
  testWidgets(
      'Question page creates, edits and deletes one question without a batch form',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late QuestionRepository repository;
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(() => FixedSession(const SessionState(
          user: CurrentUser(
              id: 2,
              name: 'Admin',
              email: 'a@test',
              roles: {'SYSTEM_ADMIN'},
              permissions: {}),
          workspace: Workspace.admin))),
      resourceRepositoryProvider.overrideWith((ref) =>
          repository = QuestionRepository(ref.read(authenticatedApiProvider))),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: QuizQuestionEditor('9'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm câu hỏi'));
    await tester.pumpAndSettle();
    for (var index = 0; index < 5; index++) {
      await tester.enterText(find.byType(TextFormField).at(index),
          index == 0 ? 'Câu hỏi mới' : 'Đáp án $index');
    }
    final choice = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(choice);
    await tester.tap(choice);
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').last);
    await tester.pumpAndSettle();
    final save = find.text('Lưu và hoàn tất');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.writes.single['method'], 'POST');
    expect(repository.writes.single['path'],
        '/admin/training/courses/9/questions');
    await tester.ensureVisible(find.text('Sửa'));
    await tester.tap(find.text('Sửa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Câu hỏi đã sửa');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repository.writes.last['method'], 'PUT');
    expect(repository.writes.last['path'],
        '/admin/training/courses/9/questions/1');
    await tester.ensureVisible(find.text('Xóa'));
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa câu hỏi'));
    await tester.pumpAndSettle();
    expect(repository.writes.last['method'], 'DELETE');
    expect(repository.writes.last['path'],
        '/admin/training/courses/9/questions/2');
    expect(tester.takeException(), isNull);
  });
}
