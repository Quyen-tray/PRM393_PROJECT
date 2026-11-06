package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.AuthUser;
import com.hrm.coffeeshop.common.Permissions;
import com.hrm.coffeeshop.common.SecurityUtils;
import com.hrm.coffeeshop.common.TimeUtils;
import com.hrm.coffeeshop.domain.Attendance;
import com.hrm.coffeeshop.domain.AttendanceSpotCheck;
import com.hrm.coffeeshop.domain.Employee;
import com.hrm.coffeeshop.domain.ShiftAssignment;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.SpotCheckResponseRequest;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.SpotCheckView;
import com.hrm.coffeeshop.repository.AttendanceRepository;
import com.hrm.coffeeshop.repository.AttendanceSpotCheckRepository;
import com.hrm.coffeeshop.repository.ShiftAssignmentRepository;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Clock;
import java.time.Instant;
import java.time.format.DateTimeFormatter;
import java.util.Map;

@Service
public class AttendanceSpotCheckService {
    private static final DateTimeFormatter DEADLINE = DateTimeFormatter.ofPattern("dd/MM HH:mm");

    private final AttendanceSpotCheckRepository checks;
    private final AttendanceRepository attendances;
    private final ShiftAssignmentRepository schedules;
    private final AttendanceService attendanceService;
    private final DeviceService devices;
    private final ViolationService violations;
    private final AuditService audit;
    private final NotificationService notifications;
    private final PersonLookup people;
    private final Clock clock;
    private final int responseMinutes;

    public AttendanceSpotCheckService(AttendanceSpotCheckRepository checks, AttendanceRepository attendances,
                                      ShiftAssignmentRepository schedules,
                                      AttendanceService attendanceService, DeviceService devices,
                                      ViolationService violations, AuditService audit,
                                      NotificationService notifications, PersonLookup people, Clock clock,
                                      @Value("${app.attendance.spot-check-response-minutes:5}") int responseMinutes) {
        this.checks = checks;
        this.attendances = attendances;
        this.schedules = schedules;
        this.attendanceService = attendanceService;
        this.devices = devices;
        this.violations = violations;
        this.audit = audit;
        this.notifications = notifications;
        this.people = people;
        this.clock = clock;
        this.responseMinutes = responseMinutes;
    }

    @Transactional
    public SpotCheckView requestNow(Long attendanceId) {
        SecurityUtils.requirePermission(Permissions.ATTENDANCE_REVIEW);
        AuthUser actor = SecurityUtils.current();
        if (actor.employeeId() == null)
            throw BusinessException.forbidden("Chỉ quản lý cửa hàng mới có thể yêu cầu kiểm tra giữa ca");
        Employee manager = people.employee(actor.employeeId())
                .orElseThrow(() -> BusinessException.forbidden("Tài khoản quản lý chưa có hồ sơ nhân viên"));

        // Giữ cùng thứ tự khóa với check-out, trả lời spot-check và job hết hạn.
        Attendance attendance = attendances.findByIdForUpdate(attendanceId)
                .orElseThrow(() -> BusinessException.notFound("bản ghi chấm công"));
        if (attendance.getCheckInAt() == null || attendance.getCheckOutAt() != null)
            throw BusinessException.invalidState("Chỉ có thể yêu cầu kiểm tra nhân viên đang trong ca");
        if ("LOCKED".equals(attendance.getPayrollStatus()))
            throw BusinessException.invalidState("Kỳ công đã khóa, không thể yêu cầu kiểm tra giữa ca");

        Employee employee = people.employee(attendance.getEmployeeId())
                .orElseThrow(() -> BusinessException.notFound("nhân viên"));
        if (manager.getStoreId() == null || !manager.getStoreId().equals(employee.getStoreId()))
            throw BusinessException.forbidden("Bạn chỉ có thể kiểm tra nhân viên trong cửa hàng của mình");
        ShiftAssignment assignment = schedules.findById(attendance.getShiftAssignmentId())
                .filter(s -> s.getEmployeeId().equals(attendance.getEmployeeId()))
                .orElseThrow(() -> BusinessException.invalidState("Ca làm không khớp với bản ghi chấm công"));

        AttendanceSpotCheck check = checks.findByAttendanceIdForUpdate(attendanceId).orElseGet(() -> {
            AttendanceSpotCheck created = new AttendanceSpotCheck();
            created.setAttendanceId(attendanceId);
            created.setEmployeeId(attendance.getEmployeeId());
            created.setShiftAssignmentId(assignment.getShiftAssignmentId());
            created.setSelected(false);
            created.setStatus("NOT_SELECTED");
            return created;
        });
        if (!attendance.getEmployeeId().equals(check.getEmployeeId())
                || !assignment.getShiftAssignmentId().equals(check.getShiftAssignmentId()))
            throw BusinessException.invalidState("Dữ liệu kiểm tra giữa ca không khớp với bản ghi chấm công");
        if ("REQUESTED".equals(check.getStatus())) return view(check);
        if (!"NOT_SELECTED".equals(check.getStatus()) && !"SCHEDULED".equals(check.getStatus()))
            throw BusinessException.invalidState("Ca này đã có lượt kiểm tra giữa ca và không thể gửi lượt khác");

        Instant now = clock.instant();
        Instant deadline = now.plus(Duration.ofMinutes(responseMinutes));
        if (assignment.getPlannedEndAt() == null || !assignment.getPlannedEndAt().isAfter(deadline))
            throw BusinessException.invalidState("Không đủ thời gian trong ca để nhân viên phản hồi yêu cầu kiểm tra");

        check.setSelected(true);
        check.setStatus("REQUESTED");
        check.setScheduledAt(null);
        check.setRequestedAt(now);
        check.setResponseDeadlineAt(deadline);
        checks.save(check);

        String localDeadline = TimeUtils.vn(deadline).format(DEADLINE);
        notifications.notify(people.userIdOf(employee.getEmployeeId()), "ATTENDANCE_SPOT_CHECK",
                "Yêu cầu kiểm tra giữa ca",
                "Quản lý yêu cầu xác nhận bạn đang làm việc. Hãy chụp ảnh và lấy vị trí GPS trước "
                        + localDeadline + ".",
                "ShiftAssignment", assignment.getShiftAssignmentId(),
                "ATTENDANCE_SPOT_CHECK:" + check.getSpotCheckId());
        audit.log("ATTENDANCE_SPOT_CHECK_REQUESTED", "Attendance", attendanceId, null,
                Map.of("spotCheckId", check.getSpotCheckId(), "triggerSource", "MANAGER"));
        return view(check);
    }

    @Transactional
    public SpotCheckView respond(Long spotCheckId, SpotCheckResponseRequest request) {
        Long employeeId = SecurityUtils.requireEmployeeId();
        AttendanceSpotCheck observed = checks.findById(spotCheckId)
                .filter(c -> c.getEmployeeId().equals(employeeId))
                .orElseThrow(() -> BusinessException.notFound("yêu cầu kiểm tra hiện diện"));

        // Keep the same lock order as check-out: attendance first, then its spot-check row.
        Attendance attendance = attendances.findByIdForUpdate(observed.getAttendanceId())
                .filter(a -> a.getEmployeeId().equals(employeeId))
                .orElseThrow(() -> BusinessException.notFound("bản ghi chấm công"));
        AttendanceSpotCheck check = checks.findByIdForUpdate(spotCheckId)
                .orElseThrow(() -> BusinessException.notFound("yêu cầu kiểm tra hiện diện"));
        if (!check.getAttendanceId().equals(attendance.getAttendanceId()))
            throw BusinessException.notFound("yêu cầu kiểm tra hiện diện");

        if ("VERIFIED".equals(check.getStatus())) {
            if (request.idempotencyKey() == null
                    || request.idempotencyKey().equals(check.getResponseIdempotencyKey())) return view(check);
            throw BusinessException.invalidState("Lượt kiểm tra hiện diện này đã được xác nhận");
        }
        if (!"REQUESTED".equals(check.getStatus()))
            throw BusinessException.invalidState("Yêu cầu kiểm tra hiện diện không còn hiệu lực");

        Instant now = clock.instant();
        if (check.getResponseDeadlineAt() == null || !check.getResponseDeadlineAt().isAfter(now)) {
            markMissed(check);
            return view(check);
        }
        if (attendance.getCheckOutAt() != null) {
            check.setStatus("CANCELLED");
            return view(check);
        }

        devices.requireActive(employeeId, request.deviceId());
        AttendanceService.Geo geo = attendanceService.gpsOrRecord(request.location(), now,
                check.getShiftAssignmentId(), employeeId, "SPOT_CHECK", request.deviceId());
        String photoKey = attendanceService.requirePhoto(request.photoEvidence(), true);
        attendanceService.saveSpotCheckVerifications(attendance, request.deviceId(), photoKey, geo, now);

        check.setStatus("VERIFIED");
        check.setRespondedAt(now);
        check.setResponseIdempotencyKey(request.idempotencyKey());
        audit.log("ATTENDANCE_SPOT_CHECK_VERIFIED", "Attendance", attendance.getAttendanceId(), null,
                Map.of("spotCheckId", check.getSpotCheckId(), "distanceM", Math.round(geo.distance())));
        return view(check);
    }

    private void markMissed(AttendanceSpotCheck check) {
        check.setStatus("MISSED");
        violations.recordAttendanceSpotCheckMissed(check.getEmployeeId(), check.getAttendanceId());
    }

    static SpotCheckView view(AttendanceSpotCheck check) {
        return new SpotCheckView(check.getSpotCheckId(), check.getStatus(),
                TimeUtils.vn(check.getRequestedAt()), TimeUtils.vn(check.getResponseDeadlineAt()));
    }
}
