import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/presentation/business_labels.dart';
import '../../../core/presentation/resource_widgets.dart';
import '../data/attendance_controller.dart';
import 'camera_capture_page.dart';

const blockerLabels = {
  'DEVICE_NOT_ACTIVE':
      'Bản cài đặt này chưa có thiết bị được duyệt. Mở Thiết bị của tôi để đăng ký hoặc xem kết quả.',
  'CHECK_IN_TOO_EARLY': 'Chưa đến giờ được phép vào ca.',
  'CHECK_IN_WINDOW_CLOSED': 'Ca đã kết thúc. Hãy gửi giải trình từ lịch làm.',
  'ACCOUNT_NOT_ACTIVE': 'Hồ sơ nhân viên chưa ở trạng thái làm việc.',
  'PAYROLL_PERIOD_LOCKED': 'Kỳ công chứa ca này đã khóa.',
};

class CheckInScreen extends ConsumerWidget {
  const CheckInScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(attendanceControllerProvider, (previous, next) {
      final message = next.asData?.value.message;
      if (message != null && message != previous?.asData?.value.message) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    });
    final state = ref.watch(attendanceControllerProvider);
    final controller = ref.read(attendanceControllerProvider.notifier);
    return state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => PageBody(children: [
              ErrorPanel(e,
                  retry: () => ref.invalidate(attendanceControllerProvider))
            ]),
        data: (s) => PageBody(
                onRefresh: () async {
                  ref.invalidate(attendanceControllerProvider);
                  await ref.read(attendanceControllerProvider.future);
                },
                children: [
                  Text('Chấm công tại cửa hàng',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  if (s.message != null)
                    Card(
                        color: const Color(0xffdef3e6),
                        child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(s.message!))),
                  if (s.pending != null)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                      'Có thao tác chưa xác định được kết quả. Thử lại sẽ dùng nguyên khóa để tránh ghi công hai lần.'),
                                  const SizedBox(height: 10),
                                  FilledButton(
                                      onPressed: s.busy
                                          ? null
                                          : () =>
                                              controller.submit(retry: true),
                                      child: const Text(
                                          'Kiểm tra và gửi lại thao tác trước'))
                                ]))),
                  if (s.shift == null)
                    const EmptyPanel(
                        message:
                            'Chưa có ca có thể chấm công. Kiểm tra lịch làm hoặc liên hệ quản lý.')
                  else ...[
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${s.shift!['shiftName'] ?? 'Ca làm'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 8),
                                  Text(
                                      '${dateText(s.shift!['plannedStartAt'])}\n→ ${dateText(s.shift!['plannedEndAt'])}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  if (s.shift!['attendanceStatus'] != null)
                                    StatusChip(s.shift!['attendanceStatus']),
                                ]))),
                    for (final code in s.shift!['blockers'] as List? ?? [])
                      Card(
                          child: ListTile(
                              leading: const Icon(Icons.info_outline),
                              title: Text(
                                  blockerLabels[code] ?? statusLabel(code)))),
                  ],
                  Wrap(spacing: 10, children: [
                    OutlinedButton.icon(
                        onPressed: () => context.push('/module/my-devices'),
                        icon: const Icon(Icons.phonelink_lock),
                        label: const Text('Thiết bị của tôi')),
                    OutlinedButton.icon(
                        onPressed: () => context.push('/module/my-schedule'),
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Lịch và giải trình'))
                  ]),
                  const SectionTitle('1. Vị trí hiện tại'),
                  Card(
                      child: ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text('${s.store?['name'] ?? 'Cửa hàng'}'),
                          subtitle: Text(
                              '${s.store?['address'] ?? ''}\nBán kính chấm công: ${s.store?['attendanceRadiusMeters'] ?? 'Chưa cấu hình'} m'))),
                  if (s.position != null)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                                'Sai số GPS: ${s.position!.accuracy.toStringAsFixed(1)} m\nKhoảng cách tới quán: ${Geolocator.distanceBetween(s.position!.latitude, s.position!.longitude, (s.store!['latitude'] as num).toDouble(), (s.store!['longitude'] as num).toDouble()).toStringAsFixed(1)} m'))),
                  OutlinedButton.icon(
                      onPressed: s.busy ? null : controller.locate,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Lấy vị trí GPS')),
                  TextButton(
                      onPressed: () => Geolocator.openAppSettings(),
                      child: const Text('Mở cài đặt quyền vị trí')),
                  const SectionTitle('2. Ảnh bằng chứng'),
                  if (s.photo != null)
                    ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.memory(s.photo!,
                            height: 250, fit: BoxFit.contain)),
                  OutlinedButton.icon(
                      onPressed: s.busy
                          ? null
                          : () async {
                              final bytes = await Navigator.of(context,
                                      rootNavigator: true)
                                  .push<Uint8List>(MaterialPageRoute(
                                      builder: (_) =>
                                          const CameraCapturePage()));
                              if (bytes != null) controller.setPhoto(bytes);
                            },
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(s.photo == null
                          ? 'Mở camera và chụp ảnh'
                          : 'Chụp ảnh khác')),
                  if (s.error != null) ErrorPanel(s.error!),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                      onPressed: s.busy ||
                              s.photo == null ||
                              s.pending != null ||
                              !(s.shift?['canCheckIn'] == true ||
                                  s.shift?['canCheckOut'] == true)
                          ? null
                          : () => controller.submit(),
                      icon: s.busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.fingerprint),
                      label: Text(s.busy
                          ? 'Đang gửi…'
                          : s.checkout
                              ? 'Xác nhận check-out'
                              : 'Xác nhận check-in')),
                  const SizedBox(height: 10),
                  const Text(
                      'Giờ chấm công do máy chủ ghi nhận. Ảnh và GPS được gửi để kiểm tra theo chính sách cửa hàng.',
                      style: TextStyle(fontSize: 12)),
                ]));
  }
}
