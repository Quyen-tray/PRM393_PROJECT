import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/router/module_registry.dart';
import '../../../core/presentation/resource_widgets.dart';
import '../../../shared/resources/presentation/linked_resource_list.dart';
import '../../../shared/resources/presentation/record_action_context.dart';
import '../../auth/data/session_controller.dart';
import 'employees_record_actions.dart';

class EmployeeRelatedPage extends ConsumerWidget {
  const EmployeeRelatedPage(this.employeeId, this.section, {super.key});
  final String employeeId, section;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(employeeId);
    if (id == null) return const PageBody(children: [EmptyPanel()]);
    final widgets = buildEmployeeRecordActions(
        RecordActionContext(
            context: context,
            ref: ref,
            spec: module('employees'),
            row: {'employeeId': id},
            user: ref.watch(sessionProvider).user!),
        linkSections: false);
    final content = widgets.where((widget) {
      if (widget is LinkedResourceList) {
        return (widget.spec.key == 'enrollments'
                ? 'training'
                : widget.spec.key) ==
            section;
      }
      if (widget is ResourceView) {
        return (widget.query.path.endsWith('overview')
                ? 'overview'
                : 'document-catalog') ==
            section;
      }
      return false;
    }).toList();
    return PageBody(
        children: content.isEmpty
            ? [
                const EmptyPanel(
                    message:
                        'Mục này không tồn tại hoặc bạn chưa được cấp quyền truy cập.')
              ]
            : content);
  }
}
