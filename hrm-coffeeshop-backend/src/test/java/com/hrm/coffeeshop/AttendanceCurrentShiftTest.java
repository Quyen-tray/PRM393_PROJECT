package com.hrm.coffeeshop;

import com.hrm.coffeeshop.common.AuthUser;
import com.hrm.coffeeshop.common.TimeUtils;
import com.hrm.coffeeshop.config.AppProperties;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.*;
import java.math.BigDecimal;
import com.hrm.coffeeshop.domain.*;
import com.hrm.coffeeshop.repository.*;
import com.hrm.coffeeshop.shared.service.*;
import org.junit.jupiter.api.*;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class AttendanceCurrentShiftTest {
    private static final Instant NOW = Instant.parse("2026-11-04T03:00:00Z");
    private final AttendanceRepository attendance = mock(AttendanceRepository.class);
    private final ShiftAssignmentRepository schedules = mock(ShiftAssignmentRepository.class);
    private final WorkShiftRepository shifts = mock(WorkShiftRepository.class);
    private final EmployeeRepository employees = mock(EmployeeRepository.class);
    private final DeviceService devices = mock(DeviceService.class);
    private final TrainingService training = mock(TrainingService.class);
    private AttendanceService service;

    @BeforeEach void setup() {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new AuthUser(1L, "employee@example.test", Set.of("EMPLOYEE"), Set.of(), 1L), null));
        Employee employee = new Employee();
        employee.setEmploymentStatus("ACTIVE");
        when(employees.findById(1L)).thenReturn(Optional.of(employee));
        when(training.eligibility(employee)).thenReturn(new TrainingService.Eligibility(true, 0, 0, List.of()));
        when(devices.hasActive(1L)).thenReturn(true);
        WorkShift shift = new WorkShift();
        shift.setShiftName("Ca làm");
        shift.setEarlyCheckInMinutes((short) 10);
        when(shifts.findById(1)).thenReturn(Optional.of(shift));
        service = new AttendanceService(attendance, null, schedules, shifts, employees, null,
                devices, training, null, null, null, null, null, null, null, null, null, null,
                Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @AfterEach void cleanup() { SecurityContextHolder.clearContext(); }

    private ShiftAssignment shift(long id, Instant start, Instant end) {
        ShiftAssignment s = new ShiftAssignment();
        s.setShiftAssignmentId(id);
        s.setEmployeeId(1L);
        s.setWorkShiftId(1);
        s.setWorkDate(TimeUtils.dateOf(start));
        s.setPlannedStartAt(start);
        s.setPlannedEndAt(end);
        s.setScheduleStatus("PUBLISHED");
        return s;
    }

    private void available(ShiftAssignment... items) {
        when(schedules.findByEmployeeIdAndWorkDateBetweenOrderByPlannedStartAtAsc(eq(1L), any(), any()))
                .thenReturn(List.of(items));
    }

    private void checkedIn(ShiftAssignment s) {
        Attendance a = new Attendance();
        a.setAttendanceId(99L);
        a.setCheckInAt(s.getPlannedStartAt());
        when(attendance.findByShiftAssignmentId(s.getShiftAssignmentId())).thenReturn(Optional.of(a));
    }

    @Test void overdueCheckoutDoesNotHideTodaysAvailableShift() {
        var yesterday = shift(1, NOW.minusSeconds(86400), NOW.minusSeconds(60000));
        var today = shift(2, NOW.minusSeconds(3600), NOW.plusSeconds(3600));
        checkedIn(yesterday);
        available(yesterday, today);
        var result = service.current();
        assertEquals(2L, result.shiftAssignmentId());
        assertTrue(result.canCheckIn());
        assertFalse(result.canCheckOut());
    }

    @Test void ongoingOvernightShiftKeepsCheckoutPriority() {
        var overnight = shift(1, NOW.minusSeconds(43200), NOW.plusSeconds(300));
        var next = shift(2, NOW.plusSeconds(300), NOW.plusSeconds(20000));
        checkedIn(overnight);
        available(overnight, next);
        assertEquals(1L, service.current().shiftAssignmentId());
        assertTrue(service.current().canCheckOut());
    }

    @Test void upcomingShiftExplainsWhenCheckInOpens() {
        available(shift(1, NOW.plusSeconds(3600), NOW.plusSeconds(7200)));
        var result = service.current();
        assertFalse(result.canCheckIn());
        assertTrue(result.blockers().contains("CHECK_IN_TOO_EARLY"));
        assertEquals(NOW.plusSeconds(3000), result.checkInOpensAt().toInstant());
    }

    @Test void checkInOpensAtExactEarlyWindowBoundary() {
        available(shift(1, NOW.plusSeconds(600), NOW.plusSeconds(7200)));
        assertTrue(service.current().canCheckIn());
    }

    @Test void deviceApprovalIsStillRequired() {
        available(shift(1, NOW.minusSeconds(600), NOW.plusSeconds(7200)));
        when(devices.hasActive(1L)).thenReturn(false);
        assertFalse(service.current().canCheckIn());
        assertTrue(service.current().blockers().contains("DEVICE_NOT_ACTIVE"));
    }

    @Test void cancelledShiftCannotBeSelected() {
        var cancelled = shift(1, NOW.minusSeconds(600), NOW.plusSeconds(7200));
        cancelled.setScheduleStatus("CANCELLED");
        available(cancelled);
        assertNull(service.current());
    }

    @Test void availableShiftAcceptsCheckInWithApprovedDeviceGpsAndUploadedPhoto() {
        var today = shift(2, NOW.minusSeconds(600), NOW.plusSeconds(7200));
        available(today);
        when(schedules.findById(2L)).thenReturn(Optional.of(today));
        var storeService = mock(StoreService.class);
        Store store = new Store();
        store.setLatitude(BigDecimal.valueOf(10.7769));
        store.setLongitude(BigDecimal.valueOf(106.7009));
        when(storeService.current()).thenReturn(store);
        var storage = mock(StorageGateway.class);
        String photo = "attendance-evidence/1/20261104/00000000-0000-0000-0000-000000000001.jpg";
        when(storage.exists(photo)).thenReturn(true);
        var face = mock(FaceVerificationClient.class);
        when(face.verify(null, photo, 1L)).thenReturn(new FaceVerificationClient.Result("EXEMPTED", "EXEMPTED", "test"));
        var evidence = mock(AttendanceVerificationRepository.class);
        when(attendance.saveAndFlush(any())).thenAnswer(invocation -> {
            Attendance a = invocation.getArgument(0);
            a.setAttendanceId(100L);
            return a;
        });
        var props = new AppProperties(null, null, null, null, new AppProperties.Attendance(50, 120), null);
        service = new AttendanceService(attendance, evidence, schedules, shifts, employees, null,
                devices, training, storeService, mock(AttendanceMetricsService.class), face, storage,
                mock(ViolationService.class), null, mock(AuditService.class), props,
                mock(PayrollLockGuard.class), mock(VerificationAttemptRecorder.class), Clock.fixed(NOW, ZoneOffset.UTC));
        assertTrue(service.current().canCheckIn());
        var result = service.checkIn(new CheckInRequest(2L, 52L,
                new LocationDto(10.7769, 106.7009, 10.0, NOW.atOffset(ZoneOffset.UTC)),
                new PhotoEvidence(photo, true), null, "checkin-test-2"));
        assertEquals("CHECKED_IN", result.attendanceStatus());
        assertEquals(100L, result.attendanceId());
        verify(devices).requireActive(1L, 52L);
        verify(evidence, times(4)).save(any());
    }
}
