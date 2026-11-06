package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.DeviceDto.DeviceView;
import com.hrm.coffeeshop.shared.dto.DeviceDto.RegisterRequest;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.AppUser;
import com.hrm.coffeeshop.domain.AttendanceDevice;
import com.hrm.coffeeshop.domain.Employee;
import com.hrm.coffeeshop.repository.AppUserRepository;
import com.hrm.coffeeshop.repository.AttendanceDeviceRepository;
import com.hrm.coffeeshop.repository.EmployeeRepository;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.util.List;
import java.util.Map;

/**
 * Thiết bị chấm công (SRS 7.4 AttendanceDevice, 8.5, BR-DEV-01/02).
 * Trạng thái một cột Status: PENDING, ACTIVE, LOCKED, REJECTED, REVOKED.
 * Mỗi nhân viên có tối đa một thiết bị ACTIVE (unique index UX_AttendanceDevice_OneActive).
 */
@Service
public class DeviceService {
    private final AttendanceDeviceRepository devices;
    private final EmployeeRepository employees;
    private final AppUserRepository users;
    private final NotificationService notifications;
    private final AuditService audit;
    private final Clock clock;

    public DeviceService(AttendanceDeviceRepository devices, EmployeeRepository employees, AppUserRepository users,
                         NotificationService notifications, AuditService audit, Clock clock) {
        this.devices = devices;
        this.employees = employees;
        this.users = users;
        this.notifications = notifications;
        this.audit = audit;
        this.clock = clock;
    }

    static String status(AttendanceDevice d) {
        return d.getStatus();
    }

    private DeviceView view(AttendanceDevice d, String name) {
        return new DeviceView(d.getDeviceId(), d.getEmployeeId(), name, d.getDeviceName(), d.getPlatform(), status(d),
                TimeUtils.vn(d.getRequestedAt()), TimeUtils.vn(d.getApprovedAt()), d.getLockReason());
    }

    private String nameOf(Long employeeId) {
        return employees.findById(employeeId).flatMap(e -> users.findById(e.getUserId())).map(AppUser::getDisplayName).orElse(null);
    }

    @Transactional
    public DeviceView register(RegisterRequest r) {
        Long empId = SecurityUtils.requireEmployeeId();
        employees.findByIdForUpdate(empId).orElseThrow(() -> BusinessException.notFound("nhân viên"));
        String hash = Hashing.sha256Hex(r.deviceFingerprint());   // không lưu fingerprint thô
        var active = devices.findActiveByFingerprint(hash).stream().findFirst();
        if (active.isPresent()) {
            // Cài lại app trên cùng máy: trả lại thiết bị ĐÃ DUYỆT (ACTIVE) của chính nhân viên, không tạo yêu cầu mới.
            if (active.get().getEmployeeId().equals(empId)) return view(active.get(), nameOf(empId));
            throw new BusinessException(ErrorCode.CONFLICT, "Thiết bị này đang được dùng bởi tài khoản khác");
        }
        var pending = devices.findByEmployeeIdOrderByRequestedAtDesc(empId).stream()
                .filter(d -> "PENDING".equals(d.getStatus())).findFirst();
        if (pending.isPresent() && pending.get().getDeviceFingerprint().equals(hash))
            return view(pending.get(), nameOf(empId));
        if (pending.isPresent()) {
            // A reinstalled app cannot recover the old installation credential. Replace only its pending request;
            // an existing ACTIVE device remains active until a reviewer approves this new installation.
            AttendanceDevice old = pending.get();
            old.setStatus("REVOKED");
            old.setRevokedAt(clock.instant());
            old.setLockReason("Thay bằng yêu cầu đăng ký từ bản cài đặt hiện tại");
            audit.log("DEVICE_PENDING_REPLACED", "AttendanceDevice", old.getDeviceId(),
                    Map.of("status", "PENDING"), Map.of("status", "REVOKED"));
        }
        AttendanceDevice d = new AttendanceDevice();
        d.setEmployeeId(empId);
        d.setDeviceFingerprint(hash);
        d.setDeviceName(r.deviceLabel());
        d.setPlatform(r.platform());
        d.setStatus("PENDING");
        devices.save(d);
        audit.log("DEVICE_REGISTER", "AttendanceDevice", d.getDeviceId(), null, Map.of("employeeId", empId, "platform", r.platform()));
        notifications.notifyReviewers(java.util.Set.of(), java.util.Set.of(Permissions.DEVICE_APPROVE),
                "DEVICE_PENDING", "Thiết bị chờ duyệt", nameOf(empId) + " đăng ký thiết bị chấm công", "AttendanceDevice", d.getDeviceId());
        return view(d, nameOf(empId));
    }

    @Transactional(readOnly = true)
    public List<DeviceView> mine() {
        Long empId = SecurityUtils.requireEmployeeId();
        return devices.findByEmployeeIdOrderByRequestedAtDesc(empId).stream().map(d -> view(d, null)).toList();
    }

    @Transactional(readOnly = true)
    public PageResponse<DeviceView> pending(Pageable p) {
        SecurityUtils.requirePermission(Permissions.DEVICE_APPROVE);
        return PageResponse.of(devices.findByStatusOrderByRequestedAtAsc("PENDING", p), d -> view(d, nameOf(d.getEmployeeId())));
    }

    @Transactional(readOnly = true)
    public PageResponse<DeviceView> list(String status, Long employeeId, String q, Pageable p) {
        SecurityUtils.requirePermission(Permissions.DEVICE_APPROVE);
        String filter = status == null ? "" : status.trim();
        if (!filter.isEmpty() && !List.of("PENDING", "ACTIVE", "LOCKED", "REJECTED", "REVOKED").contains(filter))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Trạng thái thiết bị không hợp lệ");
        if (employeeId != null && employeeId <= 0)
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Nhân viên không hợp lệ");
        return PageResponse.of(devices.search(filter, employeeId == null ? 0L : employeeId,
                q == null ? "" : q.trim(), p), d -> view(d, nameOf(d.getEmployeeId())));
    }

    /** Chuyển thiết bị nguyên tử: khóa (LOCKED) thiết bị ACTIVE cũ → kích hoạt thiết bị mới, trong cùng transaction. */
    @Transactional
    public DeviceView approve(Long deviceId) {
        AttendanceDevice d = reviewable(deviceId);
        devices.findActiveByEmployeeId(d.getEmployeeId()).ifPresent(old -> {
            old.setStatus("LOCKED");
            old.setLockedAt(clock.instant());
            old.setLockReason("Replaced by newly approved device");
            devices.saveAndFlush(old);     // phải giải phóng unique index trước khi kích hoạt máy mới
        });
        d.setStatus("ACTIVE");
        d.setApprovedBy(SecurityUtils.current().userId());
        d.setApprovedAt(clock.instant());
        d.setLockReason(null);
        devices.saveAndFlush(d);
        audit.log("DEVICE_APPROVE", "AttendanceDevice", deviceId, Map.of("status", "PENDING"), Map.of("status", "ACTIVE"));
        notifyOwner(d, "Thiết bị chấm công đã được duyệt", "Bạn có thể chấm công bằng thiết bị mới.");
        return view(d, null);
    }

    @Transactional
    public DeviceView reject(Long deviceId, String reason) {
        if (reason == null || reason.isBlank()) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Phải nhập lý do từ chối");
        AttendanceDevice d = reviewable(deviceId);
        d.setStatus("REJECTED");
        d.setLockReason(cut(reason.trim(), 300));
        d.setApprovedBy(SecurityUtils.current().userId());
        d.setApprovedAt(clock.instant());
        audit.log("DEVICE_REJECT", "AttendanceDevice", deviceId, Map.of("status", "PENDING"), Map.of("status", "REJECTED", "reason", reason));
        notifyOwner(d, "Thiết bị bị từ chối", reason);
        return view(d, null);
    }

    @Transactional
    public DeviceView revoke(Long deviceId, String reason) {
        SecurityUtils.requirePermission(Permissions.DEVICE_APPROVE);
        if (reason == null || reason.isBlank()) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Phải nhập lý do thu hồi");
        Long employeeId = devices.employeeIdOfDevice(deviceId).orElseThrow(() -> BusinessException.notFound("thiết bị"));
        employees.findByIdForUpdate(employeeId).orElseThrow(() -> BusinessException.notFound("nhân viên"));
        AttendanceDevice d = devices.findById(deviceId).orElseThrow(() -> BusinessException.notFound("thiết bị"));
        if (!"ACTIVE".equals(d.getStatus())) throw BusinessException.invalidState("Chỉ thu hồi được thiết bị đang ACTIVE");
        d.setStatus("REVOKED");
        d.setRevokedAt(clock.instant());
        d.setLockedAt(clock.instant());
        d.setLockReason(cut(reason.trim(), 300));
        audit.log("DEVICE_REVOKE", "AttendanceDevice", deviceId, Map.of("status", "ACTIVE"), Map.of("status", "REVOKED", "reason", reason));
        notifyOwner(d, "Thiết bị đã bị thu hồi", reason);
        return view(d, null);
    }

    /** Dùng khi chấm công: thiết bị phải thuộc nhân viên và đang ACTIVE. */
    @Transactional(readOnly = true)
    public AttendanceDevice requireActive(Long employeeId, Long deviceId) {
        AttendanceDevice d = deviceId == null ? null : devices.findById(deviceId).orElse(null);
        if (d == null || !d.getEmployeeId().equals(employeeId) || !"ACTIVE".equals(d.getStatus()))
            throw new BusinessException(ErrorCode.DEVICE_NOT_ACTIVE, "Thiết bị chưa được duyệt hoặc không hoạt động");
        return d;
    }

    @Transactional(readOnly = true)
    public boolean hasActive(Long employeeId) { return devices.findActiveByEmployeeId(employeeId).isPresent(); }

    /** Credential ngẫu nhiên của bản cài đặt, được client lưu trong secure storage. Không trả hash ra API. */
    @Transactional(readOnly = true)
    public DeviceView current(String credential) {
        Long employeeId = SecurityUtils.requireEmployeeId();
        if (credential == null || credential.isBlank()) return null;
        String hash = Hashing.sha256Hex(credential);
        return devices.findByEmployeeIdOrderByRequestedAtDesc(employeeId).stream()
                .filter(d -> java.security.MessageDigest.isEqual(hash.getBytes(java.nio.charset.StandardCharsets.UTF_8),
                        d.getDeviceFingerprint().getBytes(java.nio.charset.StandardCharsets.UTF_8)))
                .findFirst().map(d -> view(d, nameOf(employeeId))).orElse(null);
    }

    @Transactional(readOnly = true)
    public void requireInstallation(Long deviceId, String credential) {
        AttendanceDevice d = requireActive(SecurityUtils.requireEmployeeId(), deviceId);
        if (credential == null || credential.isBlank() || !java.security.MessageDigest.isEqual(
                Hashing.sha256Hex(credential).getBytes(java.nio.charset.StandardCharsets.UTF_8),
                d.getDeviceFingerprint().getBytes(java.nio.charset.StandardCharsets.UTF_8)))
            throw new BusinessException(ErrorCode.DEVICE_NOT_ACTIVE, "Bản cài đặt này chưa được duyệt. Hãy đăng ký thiết bị trên máy đang dùng.");
    }

    @Transactional(readOnly = true)
    public DeviceView get(Long id) {
        AttendanceDevice d = devices.findById(id).orElseThrow(() -> BusinessException.notFound("thiết bị"));
        if (!d.getEmployeeId().equals(SecurityUtils.current().employeeId()))
            SecurityUtils.requirePermission(Permissions.DEVICE_APPROVE);
        return view(d, nameOf(d.getEmployeeId()));
    }

    @Transactional(readOnly = true)
    public List<DeviceView> forEmployee(Long id) {
        SecurityUtils.requirePermission(Permissions.DEVICE_APPROVE);
        return devices.findByEmployeeIdOrderByRequestedAtDesc(id).stream().map(d -> view(d, nameOf(id))).toList();
    }

    private static String cut(String s, int max) { return s.length() <= max ? s : s.substring(0, max); }

    private AttendanceDevice reviewable(Long deviceId) {
        AuthUser u = SecurityUtils.current();
        SecurityUtils.requirePermission(Permissions.DEVICE_APPROVE);
        Long employeeId = devices.employeeIdOfDevice(deviceId).orElseThrow(() -> BusinessException.notFound("thiết bị"));
        Employee owner = employees.findByIdForUpdate(employeeId).orElseThrow();
        AttendanceDevice d = devices.findById(deviceId).orElseThrow(() -> BusinessException.notFound("thiết bị"));
        if (owner.getUserId().equals(u.userId())) throw BusinessException.forbidden("Không thể tự duyệt thiết bị của chính mình");
        if (!"PENDING".equals(d.getStatus())) throw BusinessException.invalidState("Thiết bị không ở trạng thái chờ duyệt");
        return d;
    }

    private void notifyOwner(AttendanceDevice d, String title, String msg) {
        employees.findById(d.getEmployeeId()).ifPresent(e ->
                notifications.notify(e.getUserId(), "DEVICE_STATUS", title, msg, "AttendanceDevice", d.getDeviceId(), null));
    }
}
