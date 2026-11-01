package com.hrm.coffeeshop.shared.dto;

import com.hrm.coffeeshop.shared.dto.AttendanceDto.StatsView;
import com.hrm.coffeeshop.shared.dto.DocumentDto.ProfileStatusView;
import com.hrm.coffeeshop.shared.dto.TrainingDto.ProgressView;

import jakarta.validation.constraints.*;
import java.time.LocalDate;
import java.util.List;

public final class EmployeeDto {
    private EmployeeDto() {}

    public record CreateRequest(@NotNull Long userId, @NotBlank @Size(max = 30) String employeeCode,
                                @NotNull Integer positionId,
                                @Pattern(regexp = "FULL_TIME|PART_TIME|TEMPORARY|PROBATION") String employmentType,
                                @NotNull LocalDate hireDate, LocalDate dateOfBirth, @Size(max = 50) String identityNumber,
                                @Size(max = 300) String address, @Size(max = 150) String emergencyContact) {}

    public record UpdateRequest(@Size(max = 150) String fullName, @Size(max = 20) String phone, Integer positionId,
                                @Pattern(regexp = "FULL_TIME|PART_TIME|TEMPORARY|PROBATION") String employmentType,
                                LocalDate dateOfBirth, @Size(max = 50) String identityNumber, @Size(max = 300) String address,
                                @Size(max = 150) String emergencyContact) {}

    public record StatusRequest(@NotBlank @Pattern(regexp = "ACTIVE|ON_LEAVE|SUSPENDED|RESIGNED") String status,
                                @Size(max = 500) String reason) {}

    public record EmployeeView(Long employeeId, Long userId, String employeeCode, String fullName, String email, String phone,
                               String jobTitle, Integer positionId, String employmentType, String employmentStatus, LocalDate hireDate,
                               LocalDate dateOfBirth, String identityNumber, String address, String emergencyContact,
                               String profileStatus, String shiftEligibility) {}

    public record OverviewView(EmployeeView employee, ProfileStatusView documents,
                               ProgressView training, StatsView attendanceThisMonth) {}
}
