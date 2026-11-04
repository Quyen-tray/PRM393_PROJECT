package com.hrm.coffeeshop.admin.controller;

import com.hrm.coffeeshop.admin.dto.AdminAuthDto.SetPermissionsRequest;
import com.hrm.coffeeshop.admin.dto.AdminAuthDto.SetRolesRequest;
import com.hrm.coffeeshop.admin.dto.AdminAuthDto.SetStatusRequest;
import com.hrm.coffeeshop.shared.dto.AuthDto.CreateUserRequest;
import com.hrm.coffeeshop.shared.dto.AuthDto.PermissionCatalogView;
import com.hrm.coffeeshop.shared.dto.AuthDto.UserPermissionsView;
import com.hrm.coffeeshop.shared.dto.AuthDto.UserView;
import com.hrm.coffeeshop.shared.service.UserService;

import com.hrm.coffeeshop.common.ApiResponse;
import com.hrm.coffeeshop.common.PageResponse;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/admin/users")
@PreAuthorize("hasRole('SYSTEM_ADMIN')")
public class AdminUserController {
    private final UserService users;

    public AdminUserController(UserService users) { this.users = users; }

    @GetMapping
    public ApiResponse<PageResponse<UserView>> list(@PageableDefault(size = 20, sort = "userId") Pageable p) {
        return ApiResponse.ok(users.list(p));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<UserView> create(@Valid @RequestBody CreateUserRequest r) {
        return ApiResponse.ok("User created", users.create(r));
    }

    @PutMapping("/{userId}/roles")
    public ApiResponse<UserView> roles(@PathVariable Long userId, @Valid @RequestBody SetRolesRequest r) {
        return ApiResponse.ok("Roles updated", users.setRoles(userId, r.roles()));
    }

    /** Danh mục quyền + tập quyền dựng sẵn (vd HR) để chọn khi gán. */
    @GetMapping("/permission-catalog")
    public ApiResponse<PermissionCatalogView> permissionCatalog() {
        return ApiResponse.ok(users.permissionCatalog());
    }

    @GetMapping("/{userId}/permissions")
    public ApiResponse<UserPermissionsView> permissions(@PathVariable Long userId) {
        return ApiResponse.ok(users.userPermissions(userId));
    }

    /** Cấp/gỡ quyền gán trực tiếp, vd {"permissionSets":["HR"]} để cấp tập quyền HR. */
    @PutMapping("/{userId}/permissions")
    public ApiResponse<UserPermissionsView> setPermissions(@PathVariable Long userId, @Valid @RequestBody SetPermissionsRequest r) {
        return ApiResponse.ok("Permissions updated", users.setUserPermissions(userId, r.permissions(), r.permissionSets()));
    }

    @PatchMapping("/{userId}/status")
    public ApiResponse<UserView> status(@PathVariable Long userId, @Valid @RequestBody SetStatusRequest r) {
        return ApiResponse.ok("Status updated", users.setStatus(userId, r.status()));
    }
}
