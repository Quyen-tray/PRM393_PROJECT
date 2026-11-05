package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.EmployeeDto.CreateRequest;
import com.hrm.coffeeshop.shared.dto.EmployeeDto.EmployeeView;
import com.hrm.coffeeshop.shared.dto.EmployeeDto.OverviewView;
import com.hrm.coffeeshop.shared.dto.EmployeeDto.StatusRequest;
import com.hrm.coffeeshop.shared.dto.EmployeeDto.UpdateRequest;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.AppUser;
import com.hrm.coffeeshop.domain.Employee;
import com.hrm.coffeeshop.domain.JobPosition;
import com.hrm.coffeeshop.repository.*;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.util.Map;

@Service
public class EmployeeService {
    private final EmployeeRepository employees;
    private final JobPositionRepository positions;
    private final AppUserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final StoreService storeService;
    private final DocumentService documents;
    private final TrainingService training;
    private final AttendanceStatsService stats;
    private final AuditService audit;
    private final Clock clock;

    public EmployeeService(EmployeeRepository employees, JobPositionRepository positions, AppUserRepository users,
                           RefreshTokenRepository refreshTokens,
                           StoreService storeService, DocumentService documents, TrainingService training,
                           AttendanceStatsService stats, AuditService audit, Clock clock) {
        this.employees = employees;
        this.positions = positions;
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.storeService = storeService;
        this.documents = documents;
        this.training = training;
        this.stats = stats;
        this.audit = audit;
        this.clock = clock;
    }

    private static String mask(String s) { return s == null ? null : s.length() <= 3 ? "***" : "***" + s.substring(s.length() - 3); }

    @Transactional(readOnly = true)
    EmployeeView view(Employee e) {
        AppUser u = users.findById(e.getUserId()).orElseThrow();
        AuthUser cu = SecurityUtils.current();
        boolean revealPii = e.getEmployeeId().equals(cu.employeeId()) || cu.hasPermission(Permissions.EMPLOYEE_PII_VIEW);
        return new EmployeeView(e.getEmployeeId(), e.getUserId(), e.getEmployeeCode(), u.getDisplayName(), u.getEmail(), u.getPhoneNumber(),
                e.getJobTitle(), e.getPositionId(), e.getEmploymentType(), e.getEmploymentStatus(), e.getHireDate(), e.getDateOfBirth(),
                revealPii ? e.getIdentityNumber() : mask(e.getIdentityNumber()), e.getAddress(), e.getEmergencyContact(),
                documents.profile(e).profileStatus(), training.eligibility(e).eligible() ? "ELIGIBLE" : "RESTRICTED");
    }

    @Transactional
    public EmployeeView create(CreateRequest r) {
        SecurityUtils.requirePermission(Permissions.EMPLOYEE_MANAGE);
        users.findById(r.userId()).orElseThrow(() -> BusinessException.notFound("tài khoản"));
        if (employees.findByUserId(r.userId()).isPresent()) throw new BusinessException(ErrorCode.CONFLICT, "Tài khoản đã gắn với một hồ sơ nhân viên");
        if (employees.findByEmployeeCode(r.employeeCode()).isPresent()) throw new BusinessException(ErrorCode.CONFLICT, "Mã nhân viên đã tồn tại");
        if (r.hireDate().isAfter(TimeUtils.today(clock).plusYears(1))) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Ngày vào làm không hợp lệ");
        Employee e = new Employee();
        e.setUserId(r.userId());
        e.setEmployeeCode(r.employeeCode().trim());
        e.setStoreId(storeService.current().getStoreId());
        JobPosition pos = activePosition(r.positionId());
        e.setPositionId(pos.getPositionId());
        e.setJobTitle(pos.getPositionName());
        if (r.employmentType() != null) e.setEmploymentType(r.employmentType());
        e.setHireDate(r.hireDate());
        e.setDateOfBirth(r.dateOfBirth());
        e.setIdentityNumber(r.identityNumber());
        e.setAddress(r.address());
        e.setEmergencyContact(r.emergencyContact());
        employees.save(e);
        documents.syncProfileStatus(e);
        audit.log("EMPLOYEE_CREATE", "Employee", e.getEmployeeId(), null,
                Map.of("employeeCode", e.getEmployeeCode(), "jobTitle", e.getJobTitle()));
        return view(e);
    }

    @Transactional(readOnly = true)
    public PageResponse<EmployeeView> list(String q, String status, String jobTitle, Pageable p) {
        return PageResponse.of(employees.search(q == null ? "" : q.trim(), status == null ? "" : status,
                jobTitle == null ? "" : jobTitle.trim(), p), this::view);
    }

    @Transactional(readOnly = true)
    public EmployeeView get(Long id) {
        Employee e = find(id);
        assertCanView(e);
        return view(e);
    }

    @Transactional(readOnly = true)
    public EmployeeView me() { return view(find(SecurityUtils.requireEmployeeId())); }

    @Transactional
    public EmployeeView update(Long id, UpdateRequest r) {
        SecurityUtils.requirePermission(Permissions.EMPLOYEE_MANAGE);
        Employee e = find(id);
        AppUser u = users.findById(e.getUserId()).orElseThrow();
        Map<String, Object> before = Map.of("jobTitle", e.getJobTitle(), "type", e.getEmploymentType(), "fullName", u.getDisplayName());
        if (r.fullName() != null && !r.fullName().isBlank()) u.setDisplayName(r.fullName().trim());
        if (r.phone() != null) u.setPhoneNumber(r.phone().isBlank() ? null : r.phone().trim());
        if (r.positionId() != null) {
            JobPosition pos = activePosition(r.positionId());
            e.setPositionId(pos.getPositionId());
            e.setJobTitle(pos.getPositionName());
        }
        if (r.employmentType() != null) e.setEmploymentType(r.employmentType());
        if (r.dateOfBirth() != null) e.setDateOfBirth(r.dateOfBirth());
        if (r.identityNumber() != null) e.setIdentityNumber(r.identityNumber().isBlank() ? null : r.identityNumber());
        if (r.address() != null) e.setAddress(r.address());
        if (r.emergencyContact() != null) e.setEmergencyContact(r.emergencyContact());
        documents.syncProfileStatus(e);    // đổi chức vụ → yêu cầu hồ sơ thay đổi
        audit.log("EMPLOYEE_UPDATE", "Employee", id, before,
                Map.of("jobTitle", e.getJobTitle(), "type", e.getEmploymentType(), "fullName", u.getDisplayName()));
        return view(e);
    }

    @Transactional
    public EmployeeView setStatus(Long id, StatusRequest r) {
        SecurityUtils.requirePermission(Permissions.EMPLOYEE_MANAGE);
        Employee e = find(id);
        String old = e.getEmploymentStatus();
        if ("RESIGNED".equals(old) && !"RESIGNED".equals(r.status()))
            throw BusinessException.invalidState("Nhân viên đã nghỉ việc không thể kích hoạt lại ở đây");
        if (e.getUserId().equals(SecurityUtils.current().userId()))
            throw BusinessException.forbidden("Không thể tự đổi trạng thái làm việc của chính mình");
        e.setEmploymentStatus(r.status());
        if ("RESIGNED".equals(r.status())) {      // thu hồi quyền truy cập khi nghỉ việc
            users.findById(e.getUserId()).ifPresent(u -> u.setUserStatus("INACTIVE"));
            refreshTokens.revokeAll(e.getUserId(), clock.instant());
        }
        audit.log("EMPLOYEE_STATUS_CHANGE", "Employee", id, Map.of("status", old),
                Map.of("status", r.status(), "reason", String.valueOf(r.reason())));
        return view(e);
    }

    @Transactional(readOnly = true)
    public OverviewView overview(Long id) {
        Employee e = find(id);
        assertCanView(e);
        LocalDate first = TimeUtils.today(clock).withDayOfMonth(1);
        return new OverviewView(view(e), documents.profile(e), training.progress(id),
                stats.stats(first, first.plusMonths(1).minusDays(1), null, id));
    }

    /** GET /employees/{id}/training — danh sách khóa học của nhân viên (bản thân hoặc người có EMPLOYEE_VIEW). */
    @Transactional(readOnly = true)
    public java.util.List<com.hrm.coffeeshop.shared.dto.TrainingDto.MyTrainingView> trainings(Long id) {
        assertCanView(find(id));
        return training.mine(id);
    }

    /** GET /employees/{id}/attendance-summary — mặc định tháng hiện tại; tối đa 366 ngày. */
    @Transactional(readOnly = true)
    public com.hrm.coffeeshop.shared.dto.AttendanceDto.StatsView attendanceSummary(Long id, LocalDate from, LocalDate to) {
        assertCanView(find(id));
        LocalDate f = from != null ? from : TimeUtils.today(clock).withDayOfMonth(1);
        LocalDate t = to != null ? to : (from != null ? from.plusMonths(1).minusDays(1) : f.plusMonths(1).minusDays(1));
        if (t.isBefore(f)) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Ngày kết thúc phải sau ngày bắt đầu");
        if (f.plusDays(366).isBefore(t)) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Khoảng thời gian tối đa 366 ngày");
        return stats.stats(f, t, null, id);
    }

    private JobPosition activePosition(Integer positionId) {
        return positions.findById(positionId).filter(p -> Boolean.TRUE.equals(p.getIsActive()))
                .orElseThrow(() -> new BusinessException(ErrorCode.VALIDATION_ERROR, "Chức vụ không tồn tại hoặc đã ngưng"));
    }

    private Employee find(Long id) { return employees.findById(id).orElseThrow(() -> BusinessException.notFound("nhân viên")); }

    private void assertCanView(Employee e) {
        AuthUser u = SecurityUtils.current();
        if (!e.getEmployeeId().equals(u.employeeId()) && !u.hasPermission(Permissions.EMPLOYEE_VIEW))
            throw BusinessException.forbidden("Bạn không có quyền xem hồ sơ nhân viên này");
    }
}
