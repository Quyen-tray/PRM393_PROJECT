package com.hrm.coffeeshop.admin.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.Set;

public final class AdminAuthDto {
    private AdminAuthDto() {}

    public record SetRolesRequest(@jakarta.validation.constraints.NotEmpty List<String> roles) {}

    /** Thay toàn bộ quyền gán trực tiếp. permissionSets (vd ["HR"]) được mở rộng thành từng quyền; để trống cả hai = gỡ hết. */
    public record SetPermissionsRequest(List<String> permissions, List<String> permissionSets) {}

    public record SetStatusRequest(@NotBlank String status) {}

}
