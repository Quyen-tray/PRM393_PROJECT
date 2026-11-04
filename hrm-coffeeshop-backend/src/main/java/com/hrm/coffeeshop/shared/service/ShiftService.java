package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentPatch;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentRequest;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentView;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.EligibilityView;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.ShiftRequest;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.ShiftView;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.*;
import com.hrm.coffeeshop.repository.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class ShiftService {
    private final WorkShiftRepository shifts;
    private final ShiftAssignmentRepository schedules;
    private final EmployeeRepository employees;
    private final AppUserRepository users;
    private final AttendanceRepository attendance;
    private final StoreService storeService;
    private final TrainingService training;
    private final NotificationService notifications;
    private final AuditService audit;
    private final PayrollLockGuard lockGuard;
    private final Clock clock;

    public ShiftService(WorkShiftRepository shifts, ShiftAssignmentRepository schedules,
                        EmployeeRepository employees, AppUserRepository users, AttendanceRepository attendance,
                        StoreService storeService, TrainingService training,
                        NotificationService notifications, AuditService audit, PayrollLockGuard lockGuard, Clock clock) {
        this.shifts = shifts;
        this.schedules = schedules;
        this.employees = employees;
        this.users = users;
        this.attendance = attendance;
        this.storeService = storeService;
        this.training = training;
        this.notifications = notifications;
        this.audit = audit;
        this.lockGuard = lockGuard;
        this.clock = clock;
    }

    public static ShiftView view(WorkShift s) {
        return new ShiftView(s.getWorkShiftId(), s.getShiftCode(), s.getShiftName(), s.getStartTime(), s.getEndTime(),
                (int) s.getBreakMinutes(), (int) s.getEarlyCheckInMinutes(), (int) s.getGraceMinutes(), s.getIsActive());
    }

    // ---------- Mẫu ca ----------
    @Transactional(readOnly = true)
    public List<ShiftView> listShifts(boolean onlyActive) {
        Integer storeId = storeService.current().getStoreId();
        return (onlyActive ? shifts.findByStoreIdAndIsActiveTrue(storeId) : shifts.findByStoreId(storeId))
                .stream().map(ShiftService::view).toList();
    }

    @Transactional
    public ShiftView createShift(ShiftRequest r) {
        Store store = storeService.current();
        if (shifts.findByStoreIdAndShiftCode(store.getStoreId(), r.shiftCode()).isPresent())
            throw new BusinessException(ErrorCode.CONFLICT, "Mã ca đã tồn tại");
        WorkShift s = new WorkShift();
        s.setStoreId(store.getStoreId());
        apply(s, r, true);
        shifts.save(s);
        audit.log("SHIFT_TEMPLATE_CREATE", "WorkShift", s.getWorkShiftId(), null, view(s));
        return view(s);
    }

    /** Sửa mẫu ca chỉ ảnh hưởng ca phân MỚI; lịch đã tạo giữ nguyên PlannedStartAt/EndAt. */
    @Transactional
    public ShiftView updateShift(Integer id, ShiftRequest r) {
        WorkShift s = shifts.findById(id).orElseThrow(() -> BusinessException.notFound("mẫu ca"));
        shifts.findByStoreIdAndShiftCode(s.getStoreId(), r.shiftCode()).filter(x -> !x.getWorkShiftId().equals(id))
                .ifPresent(x -> { throw new BusinessException(ErrorCode.CONFLICT, "Mã ca đã tồn tại"); });
        ShiftView before = view(s);
        apply(s, r, false);
        audit.log("SHIFT_TEMPLATE_UPDATE", "WorkShift", id, before, view(s));
        return view(s);
    }

    private void apply(WorkShift s, ShiftRequest r, boolean isNew) {
        if (r.startTime().equals(r.endTime())) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Giờ bắt đầu và kết thúc không được trùng nhau");
        requireBreakWithinShift(r.startTime(), r.endTime(), r.breakMinutes());
        int early = r.earlyCheckInMinutes() != null ? r.earlyCheckInMinutes() : storeService.current().getCheckInEarlyMinutes();
        int grace = r.graceMinutes() != null ? r.graceMinutes() : storeService.current().getGraceMinutes();
        if (early < 15 || early > 30) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Check-in sớm phải trong 15–30 phút");
        if (grace < 3 || grace > 5) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Ân hạn phải trong 3–5 phút");
        s.setShiftCode(r.shiftCode().trim());
        s.setShiftName(r.shiftName().trim());
        s.setStartTime(r.startTime());
        s.setEndTime(r.endTime());
        s.setBreakMinutes((short) (r.breakMinutes() == null ? 0 : r.breakMinutes()));
        s.setEarlyCheckInMinutes((short) early);
        s.setGraceMinutes((short) grace);
        if (r.isActive() != null) s.setIsActive(r.isActive());
    }

    /** Thời lượng ca (phút). Ca qua nửa đêm (kết thúc nhỏ hơn hoặc bằng bắt đầu) được cộng 24 giờ. */
    public static int shiftMinutes(LocalTime start, LocalTime end) {
        long m = java.time.Duration.between(start, end).toMinutes();
        return (int) (m <= 0 ? m + 24 * 60 : m);
    }

    /** P2-05: thời gian nghỉ giữa ca không âm và phải nhỏ hơn thời lượng ca (không chỉ trần 240 phút). */
    public static void requireBreakWithinShift(LocalTime start, LocalTime end, Integer breakMinutes) {
        int brk = breakMinutes == null ? 0 : breakMinutes;
        if (brk < 0) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Thời gian nghỉ không được âm");
        int dur = shiftMinutes(start, end);
        if (brk >= dur)
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                    "Thời gian nghỉ (" + brk + " phút) phải nhỏ hơn thời lượng ca (" + dur + " phút)");
    }

    // ---------- Phân ca ----------
    static Instant plannedStart(LocalDate d, WorkShift s) { return TimeUtils.at(d, s.getStartTime()); }

    static Instant plannedEnd(LocalDate d, WorkShift s) {
        return s.getEndTime().isAfter(s.getStartTime()) ? TimeUtils.at(d, s.getEndTime()) : TimeUtils.at(d.plusDays(1), s.getEndTime());
    }

    @Transactional(readOnly = true)
    public EligibilityView eligibility(Long assignmentId) {
        ShiftAssignment sc = schedules.findById(assignmentId).orElseThrow(() -> BusinessException.notFound("phân ca"));
        assertCanSee(sc.getEmployeeId());
        TrainingService.Eligibility el = training.eligibility(employees.findById(sc.getEmployeeId()).orElseThrow());
        return new EligibilityView(el.eligible(), el.restrictions());
    }

    @Transactional
    public AssignmentView create(AssignmentRequest r) {
        lockGuard.assertWorkDateOpen(r.workDate());   // ngày được phân phải nằm ngoài kỳ đã chốt
        Employee e = employees.findByIdForUpdate(r.employeeId()).orElseThrow(() -> BusinessException.notFound("nhân viên"));
        if (!"ACTIVE".equals(e.getEmploymentStatus()))
            throw BusinessException.rule("Chỉ phân ca cho nhân viên đang làm việc (ACTIVE)");
        WorkShift sh = shifts.findById(r.workShiftId()).filter(x -> Boolean.TRUE.equals(x.getIsActive()))
                .orElseThrow(() -> new BusinessException(ErrorCode.VALIDATION_ERROR, "Mẫu ca không tồn tại hoặc đã ngưng"));
        requireEligible(e);
        Instant start = plannedStart(r.workDate(), sh), end = plannedEnd(r.workDate(), sh);
        requireNoOverlap(e.getEmployeeId(), start, end, -1L);
        ShiftAssignment sc = new ShiftAssignment();
        sc.setEmployeeId(e.getEmployeeId());
        sc.setWorkShiftId(sh.getWorkShiftId());
        sc.setWorkDate(r.workDate());
        sc.setPlannedStartAt(start);
        sc.setPlannedEndAt(end);
        sc.setScheduleStatus("PUBLISHED");
        sc.setCreatedBy(SecurityUtils.current().userId());
        sc.setNote(r.note());
        schedules.save(sc);
        audit.log("SCHEDULE_CREATE", "ShiftAssignment", sc.getShiftAssignmentId(), null,
                Map.of("employeeId", e.getEmployeeId(), "shiftId", sh.getWorkShiftId(), "workDate", r.workDate().toString()));
        notifications.notify(e.getUserId(), "SCHEDULE_ASSIGNED", "Bạn có ca làm mới",
                "Ca " + sh.getShiftName() + " ngày " + r.workDate(), "ShiftAssignment", sc.getShiftAssignmentId(), null);
        return toView(sc, sh);
    }

    @Transactional
    public AssignmentView patch(Long id, AssignmentPatch p) {
        ShiftAssignment sc = schedules.findById(id).orElseThrow(() -> BusinessException.notFound("phân ca"));
        lockGuard.assertWorkDateOpen(sc.getWorkDate());          // ngày cũ
        if (p.workDate() != null) lockGuard.assertWorkDateOpen(p.workDate());   // ngày mới
        if (!List.of("DRAFT", "PUBLISHED").contains(sc.getScheduleStatus()))
            throw BusinessException.invalidState("Không thể sửa phân ca ở trạng thái " + sc.getScheduleStatus());
        if (attendance.findByShiftAssignmentId(id).isPresent())
            throw BusinessException.invalidState("Ca đã phát sinh chấm công, không thể điều chỉnh");
        WorkShift sh = shifts.findById(p.workShiftId() != null ? p.workShiftId() : sc.getWorkShiftId())
                .filter(x -> Boolean.TRUE.equals(x.getIsActive()))
                .orElseThrow(() -> new BusinessException(ErrorCode.VALIDATION_ERROR, "Mẫu ca không tồn tại hoặc đã ngưng"));
        LocalDate date = p.workDate() != null ? p.workDate() : sc.getWorkDate();
        Employee e = employees.findByIdForUpdate(sc.getEmployeeId()).orElseThrow();
        requireEligible(e);
        Instant start = plannedStart(date, sh), end = plannedEnd(date, sh);
        requireNoOverlap(sc.getEmployeeId(), start, end, id);
        Map<String, Object> before = Map.of("shiftId", sc.getWorkShiftId(), "workDate", sc.getWorkDate().toString());
        sc.setWorkShiftId(sh.getWorkShiftId());
        sc.setWorkDate(date);
        sc.setPlannedStartAt(start);
        sc.setPlannedEndAt(end);
        if (p.note() != null) sc.setNote(p.note());
        audit.log("SCHEDULE_UPDATE", "ShiftAssignment", id, before,
                Map.of("shiftId", sh.getWorkShiftId(), "workDate", date.toString()));
        notifications.notify(e.getUserId(), "SCHEDULE_CHANGED", "Ca làm đã thay đổi", "Ca ngày " + date + " được cập nhật.",
                "ShiftAssignment", id, null);
        return toView(sc, sh);
    }

    @Transactional
    public AssignmentView cancel(Long id, String reason) {
        ShiftAssignment sc = schedules.findById(id).orElseThrow(() -> BusinessException.notFound("phân ca"));
        lockGuard.assertWorkDateOpen(sc.getWorkDate());
        if (attendance.findByShiftAssignmentId(id).isPresent())
            throw BusinessException.invalidState("Ca đã phát sinh chấm công, không thể hủy");
        if ("CANCELLED".equals(sc.getScheduleStatus())) throw BusinessException.invalidState("Ca đã bị hủy");
        sc.setScheduleStatus("CANCELLED");
        if (reason != null && !reason.isBlank()) sc.setNote(reason);
        audit.log("SCHEDULE_CANCEL", "ShiftAssignment", id, null, Map.of("reason", String.valueOf(reason)));
        employees.findById(sc.getEmployeeId()).ifPresent(e -> notifications.notify(e.getUserId(), "SCHEDULE_CANCELLED",
                "Ca làm đã bị hủy", "Ca ngày " + sc.getWorkDate() + " đã bị hủy.", "ShiftAssignment", id, null));
        return toView(sc, shifts.findById(sc.getWorkShiftId()).orElse(null));
    }

    @Transactional(readOnly = true)
    public AssignmentView get(Long id) {
        ShiftAssignment sc = schedules.findById(id).orElseThrow(() -> BusinessException.notFound("phân ca"));
        assertCanSee(sc.getEmployeeId());
        return toView(sc, shifts.findById(sc.getWorkShiftId()).orElse(null));
    }

    @Transactional(readOnly = true)
    public List<AssignmentView> mine(LocalDate from, LocalDate to) {
        Long empId = SecurityUtils.requireEmployeeId();
        LocalDate f = from != null ? from : TimeUtils.today(clock), t = to != null ? to : f.plusDays(14);
        return toViews(schedules.findByEmployeeIdAndWorkDateBetweenOrderByPlannedStartAtAsc(empId, f, t));
    }

    @Transactional(readOnly = true)
    public PageResponse<AssignmentView> search(LocalDate from, LocalDate to, Long employeeId, Pageable p) {
        LocalDate f = from != null ? from : TimeUtils.today(clock), t = to != null ? to : f.plusDays(7);
        Page<ShiftAssignment> page = schedules.search(f, t, employeeId == null ? 0L : employeeId, p);
        return new PageResponse<>(toViews(page.getContent()), page.getNumber(), page.getSize(),
                page.getTotalElements(), page.getTotalPages());
    }

    /** Dựng nhiều phân ca với số truy vấn cố định (thay cho N+1: mỗi dòng trước đây gọi 4 truy vấn). */
    private List<AssignmentView> toViews(List<ShiftAssignment> list) {
        if (list.isEmpty()) return List.of();
        Map<Integer, WorkShift> shiftById = new HashMap<>();
        shifts.findAllById(list.stream().map(ShiftAssignment::getWorkShiftId).distinct().toList())
                .forEach(s -> shiftById.put(s.getWorkShiftId(), s));
        Map<Long, Employee> empById = new HashMap<>();
        employees.findAllById(list.stream().map(ShiftAssignment::getEmployeeId).distinct().toList())
                .forEach(e -> empById.put(e.getEmployeeId(), e));
        Map<Long, AppUser> userById = new HashMap<>();
        users.findAllById(empById.values().stream().map(Employee::getUserId).distinct().toList())
                .forEach(u -> userById.put(u.getUserId(), u));
        Map<Long, Long> attIdByShift = new HashMap<>();
        attendance.findByShiftAssignmentIdIn(list.stream().map(ShiftAssignment::getShiftAssignmentId).toList())
                .forEach(a -> attIdByShift.put(a.getShiftAssignmentId(), a.getAttendanceId()));
        return list.stream().map(sc -> {
            Employee e = empById.get(sc.getEmployeeId());
            AppUser u = e == null ? null : userById.get(e.getUserId());
            WorkShift sh = shiftById.get(sc.getWorkShiftId());
            return new AssignmentView(sc.getShiftAssignmentId(), sc.getEmployeeId(), u == null ? null : u.getDisplayName(),
                    sh == null ? null : view(sh), sc.getWorkDate(), TimeUtils.vn(sc.getPlannedStartAt()),
                    TimeUtils.vn(sc.getPlannedEndAt()), sc.getScheduleStatus(), sc.getNote(),
                    attIdByShift.get(sc.getShiftAssignmentId()));
        }).toList();
    }

    // ---------- helpers ----------
    private void requireEligible(Employee e) {
        TrainingService.Eligibility el = training.eligibility(e);
        if (!el.eligible())
            throw new BusinessException(ErrorCode.EMPLOYEE_NOT_ELIGIBLE_FOR_SHIFT, "Nhân viên chưa hoàn thành đào tạo bắt buộc",
                    BusinessException.details("restrictions", el.restrictions()));
    }

    private void requireNoOverlap(Long employeeId, Instant start, Instant end, Long excludeId) {
        if (!schedules.findOverlapping(employeeId, start, end, excludeId).isEmpty())
            throw new BusinessException(ErrorCode.CONFLICT, "Nhân viên đã có ca trùng thời gian");
    }

    private void assertCanSee(Long employeeId) {
        AuthUser u = SecurityUtils.current();
        if (!employeeId.equals(u.employeeId()) && !u.isStaffReviewer())
            throw BusinessException.forbidden("Bạn không có quyền xem phân ca này");
    }

    private AssignmentView toView(ShiftAssignment sc, WorkShift sh) {
        String name = employees.findById(sc.getEmployeeId()).flatMap(e -> users.findById(e.getUserId()))
                .map(AppUser::getDisplayName).orElse(null);
        Long attId = attendance.findByShiftAssignmentId(sc.getShiftAssignmentId()).map(Attendance::getAttendanceId).orElse(null);
        return new AssignmentView(sc.getShiftAssignmentId(), sc.getEmployeeId(), name, sh == null ? null : view(sh), sc.getWorkDate(),
                TimeUtils.vn(sc.getPlannedStartAt()), TimeUtils.vn(sc.getPlannedEndAt()), sc.getScheduleStatus(), sc.getNote(), attId);
    }
}
