package com.hrm.coffeeshop.shared.controller;

import com.hrm.coffeeshop.shared.dto.AuthDto.GoogleLoginRequest;
import com.hrm.coffeeshop.shared.dto.AuthDto.LogoutRequest;
import com.hrm.coffeeshop.shared.dto.AuthDto.PermissionsView;
import com.hrm.coffeeshop.shared.dto.AuthDto.RefreshRequest;
import com.hrm.coffeeshop.shared.dto.AuthDto.TokenResponse;
import com.hrm.coffeeshop.shared.dto.AuthDto.UpdateProfileRequest;
import com.hrm.coffeeshop.shared.dto.AuthDto.UserView;
import com.hrm.coffeeshop.shared.service.AuthService;
import com.hrm.coffeeshop.shared.service.UserService;

import com.hrm.coffeeshop.common.ApiResponse;
import com.hrm.coffeeshop.common.SecurityUtils;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
public class SharedAuthController {
    private final AuthService auth;
    private final UserService users;

    public SharedAuthController(AuthService auth, UserService users) {
        this.auth = auth;
        this.users = users;
    }

    @PostMapping("/auth/google")
    public ApiResponse<TokenResponse> google(@Valid @RequestBody GoogleLoginRequest r) {
        return ApiResponse.ok("Login successful", auth.loginWithGoogle(r.idToken()));
    }

    @PostMapping("/auth/refresh")
    public ApiResponse<TokenResponse> refresh(@Valid @RequestBody RefreshRequest r) {
        return ApiResponse.ok("Token refreshed", auth.refresh(r.refreshToken()));
    }

    @PostMapping("/auth/logout")
    public ApiResponse<Void> logout(@RequestBody(required = false) LogoutRequest r) {
        auth.logout(SecurityUtils.current().userId(), r == null ? null : r.refreshToken());
        return ApiResponse.ok("Logged out", null);
    }

    @GetMapping("/users/me")
    public ApiResponse<UserView> me() { return ApiResponse.ok(users.me()); }

    @PatchMapping("/users/me")
    public ApiResponse<UserView> updateMe(@Valid @RequestBody UpdateProfileRequest r) {
        return ApiResponse.ok("Profile updated", users.updateMe(r));
    }

    @GetMapping("/users/me/permissions")
    public ApiResponse<PermissionsView> permissions() { return ApiResponse.ok(users.permissions()); }
}
