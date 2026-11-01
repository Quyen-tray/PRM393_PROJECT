package com.hrm.coffeeshop.shared.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

public final class AttendanceDto {
    private AttendanceDto() {}

    public record LocationDto(Double latitude, Double longitude, Double accuracyMeters, OffsetDateTime capturedAt) {}

    /** cameraPermissionGranted=false: client báo chưa cấp quyền camera (BR-CAM-01). */
    public record PhotoEvidence(@Size(max = 500) String storageKey, Boolean cameraPermissionGranted) {}

    public record FaceVerification(@Size(max = 200) String sessionId) {}

    public record CheckInRequest(@NotNull Long shiftAssignmentId, @NotNull Long deviceId, @Valid LocationDto location,
                                 @Valid PhotoEvidence photoEvidence, @Valid FaceVerification faceVerification,
                                 @Size(max = 100) String idempotencyKey) {}

    public record CheckOutRequest(@NotNull Long attendanceId, @NotNull Long deviceId, @Valid LocationDto location,
                                  @Valid PhotoEvidence photoEvidence, @Valid FaceVerification faceVerification,
                                  @Size(max = 100) String idempotencyKey) {}

    public record CheckInResponse(Long attendanceId, Long shiftAssignmentId, OffsetDateTime checkInAt,
                                  String attendanceStatus, String verificationStatus, int lateMinutes, boolean graceApplied) {}

    public record CheckOutResponse(Long attendanceId, OffsetDateTime checkOutAt, String attendanceStatus,
                                   int totalWorkedMinutes, long presenceMinutes, long overtimeMinutes,
                                   int approvedOvertimeMinutes, int earlyLeaveMinutes) {}

    public record AttendanceView(Long attendanceId, Long shiftAssignmentId, Long employeeId, String employeeName,
                                 LocalDate workDate, OffsetDateTime checkInAt, OffsetDateTime checkOutAt,
                                 String attendanceStatus, String recordStatus, int lateMinutes, int earlyLeaveMinutes,
                                 Integer workedMinutes, int approvedOvertimeMinutes, String checkInMethod,
                                 String checkOutMethod, String payrollStatus, String note) {}

    public record CurrentShiftView(Long shiftAssignmentId, String shiftName, OffsetDateTime plannedStartAt,
                                   OffsetDateTime plannedEndAt, OffsetDateTime checkInOpensAt, Long attendanceId,
                                   String attendanceStatus, boolean canCheckIn, boolean canCheckOut,
                                   boolean deviceActive, boolean trainingEligible, List<String> blockers) {}

    public record VerificationView(String verificationType, String verificationStatus, Double latitude, Double longitude,
                                   Double accuracyMeters, Double distanceMeters, String evidenceViewUrl,
                                   boolean downloadAllowed, String failureReason, OffsetDateTime verifiedAt) {}

    public record ExplanationRequest(@NotBlank @Size(max = 40) String reasonCode, @NotBlank @Size(max = 1000) String reason,
                                     @Size(max = 500) String evidenceStorageKey, String requestedAction,
                                     OffsetDateTime requestedCheckInAt, OffsetDateTime requestedCheckOutAt, Long scheduleId) {}

    public record ExceptionView(Long requestId, Long employeeId, Long scheduleId, Long attendanceId, String requestType,
                                String reason, String status, OffsetDateTime requestedCheckInAt,
                                OffsetDateTime requestedCheckOutAt, OffsetDateTime submittedAt,
                                OffsetDateTime reviewedAt, String reviewNote) {}

    public record OvertimeRequestDto(@NotNull OffsetDateTime requestedStartAt, @NotNull OffsetDateTime requestedEndAt,
                                     @NotBlank @Size(max = 500) String reason) {}

    public record OvertimeView(Long requestId, Long scheduleId, Long employeeId, OffsetDateTime requestedStartAt,
                               OffsetDateTime requestedEndAt, String reason, String status, OffsetDateTime reviewedAt,
                               String reviewNote) {}

    public record AdjustmentRequest(@NotNull Long attendanceId, @NotBlank @Size(max = 40) String reasonCode,
                                    @NotBlank @Size(max = 900) String reason, OffsetDateTime requestedCheckInAt,
                                    OffsetDateTime requestedCheckOutAt, @Size(max = 500) String evidenceStorageKey) {}

    public record AdjustmentView(Long requestId, Long attendanceId, String fieldName, String oldValue, String newValue,
                                 String reason, String status, String managerStatus, String hrStatus,
                                 OffsetDateTime createdAt) {}

    public record StatsView(LocalDate from, LocalDate to, long scheduledShifts, long checkedInOnTime, long late,
                            long absent, long missingCheckOuts, long verificationPending, long lateMinutesTotal) {}
}
