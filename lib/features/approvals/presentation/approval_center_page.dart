import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/features/approvals/presentation/approval_queues.dart';

class ApprovalCenterPage extends StatelessWidget {
  const ApprovalCenterPage({super.key});
  @override
  Widget build(BuildContext context) => const PageBody(
        children: [
          SectionTitle('Trung tâm công việc'),
          Text(
            'Các hàng đợi xuất hiện theo quyền thực tế. Mỗi nghiệp vụ có trạng thái và bước phê duyệt riêng.',
          ),
          SizedBox(height: 12),
          ApprovalQueues(),
        ],
      );
}
