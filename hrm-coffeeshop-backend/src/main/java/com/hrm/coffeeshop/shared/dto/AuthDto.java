package com.hrm.coffeeshop.shared.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.Map;
import java.util.Set;

public final class AuthDto {
    private AuthDto() {}

    public record GoogleLoginRequest(@NotBlank String idToken) {}

    public record RefreshRequest(@NotBlank String refreshToken) {}

    public record LogoutRequest(String refreshToken) {}

    public record UserView(Long userId, String email, String displayName, String avatarUrl, String phoneNumber,
                           List<String> roles, Long employeeId, String status) {}

    public record TokenResponse(String accessToken, String refreshToken, String tokenType, long expiresIn, UserView user) {}

    public record UpdateProfileRequest(@Size(max = 150) String displayName, @Size(max = 20) String phoneNumber) {}

    public record PermissionsView(List<String> roles, Set<String> permissions) {}

    public record PermissionItem(String code, String name) {}

    /** Danh mục quyền và các tập quyền dựng sẵn (vd HR) để Admin chọn khi gán. */
    public record PermissionCatalogView(List<PermissionItem> permissions, Map<String, List<String>> permissionSets) {}

    /** direct = quyền gán trực tiếp (vd tập quyền HR); effective = direct ∪ quyền của các role đang có. */
    public record UserPermissionsView(Long userId, List<String> roles, List<String> direct, List<String> effective) {}

    public record CreateUserRequest(@NotBlank @Email @Size(max = 255) String email,
                                    @NotBlank @Size(max = 150) String displayName,
                                    @Size(max = 20) String phoneNumber, List<String> roles) {}
}
