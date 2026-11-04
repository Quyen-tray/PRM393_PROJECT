package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.AuthDto.CreateUserRequest;
import com.hrm.coffeeshop.shared.dto.AuthDto.PermissionCatalogView;
import com.hrm.coffeeshop.shared.dto.AuthDto.PermissionItem;
import com.hrm.coffeeshop.shared.dto.AuthDto.PermissionsView;
import com.hrm.coffeeshop.shared.dto.AuthDto.UserPermissionsView;
import com.hrm.coffeeshop.shared.dto.AuthDto.UpdateProfileRequest;
import com.hrm.coffeeshop.shared.dto.AuthDto.UserView;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.AppUser;
import com.hrm.coffeeshop.domain.Permission;
import com.hrm.coffeeshop.domain.Role;
import com.hrm.coffeeshop.domain.UserPermission;
import com.hrm.coffeeshop.domain.UserRole;
import com.hrm.coffeeshop.repository.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.util.*;

@Service
public class UserService {
    private final AppUserRepository users;
    private final RoleRepository roleRepo;
    private final UserRoleRepository userRoles;
    private final PermissionRepository permissionRepo;
    private final UserPermissionRepository userPermissions;
    private final RefreshTokenRepository refreshTokens;
    private final AuthService auth;
    private final AuditService audit;
    private final Clock clock;

    public UserService(AppUserRepository users, RoleRepository roleRepo, UserRoleRepository userRoles,
                       PermissionRepository permissionRepo, UserPermissionRepository userPermissions,
                       RefreshTokenRepository refreshTokens, AuthService auth, AuditService audit, Clock clock) {
        this.users = users;
        this.roleRepo = roleRepo;
        this.userRoles = userRoles;
        this.permissionRepo = permissionRepo;
        this.userPermissions = userPermissions;
        this.refreshTokens = refreshTokens;
        this.auth = auth;
        this.audit = audit;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public UserView me() {
        AuthUser cu = SecurityUtils.current();
        AppUser u = users.findById(cu.userId()).orElseThrow(() -> BusinessException.notFound("tài khoản"));
        return auth.view(u, roleRepo.findActiveCodesByUserId(u.getUserId()));
    }

    @Transactional
    public UserView updateMe(UpdateProfileRequest r) {
        AppUser u = users.findById(SecurityUtils.current().userId()).orElseThrow(() -> BusinessException.notFound("tài khoản"));
        Map<String, Object> before = Map.of("displayName", u.getDisplayName(), "phoneNumber", String.valueOf(u.getPhoneNumber()));
        if (r.displayName() != null) {
            if (r.displayName().isBlank()) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Tên hiển thị không được để trống");
            u.setDisplayName(r.displayName().trim());
        }
        if (r.phoneNumber() != null) u.setPhoneNumber(r.phoneNumber().isBlank() ? null : r.phoneNumber().trim());
        audit.log("USER_PROFILE_UPDATE", "AppUser", u.getUserId(), before,
                Map.of("displayName", u.getDisplayName(), "phoneNumber", String.valueOf(u.getPhoneNumber())));
        return auth.view(u, roleRepo.findActiveCodesByUserId(u.getUserId()));
    }

    /** Quyền hiệu lực của người đang đăng nhập (đã nạp từ DB ở JwtAuthFilter: quyền của role ∪ quyền gán trực tiếp). */
    public PermissionsView permissions() {
        AuthUser u = SecurityUtils.current();
        return new PermissionsView(new ArrayList<>(u.roles()), new TreeSet<>(u.permissions()));
    }

    // ---------- Admin ----------
    @Transactional(readOnly = true)
    public PageResponse<UserView> list(Pageable p) {
        return list("", "", "", p);
    }

    @Transactional(readOnly = true)
    public PageResponse<UserView> list(String q, String status, String role, Pageable p) {
        Page<AppUser> page = users.search(q == null ? "" : q.trim(), status == null ? "" : status, role == null ? "" : role, p);
        return PageResponse.of(page, u -> auth.view(u, roleRepo.findActiveCodesByUserId(u.getUserId())));
    }

    @Transactional(readOnly = true)
    public PermissionCatalogView permissionCatalog() {
        List<PermissionItem> items = permissionRepo.findAll().stream()
                .sorted(Comparator.comparing(Permission::getPermissionCode))
                .map(p -> new PermissionItem(p.getPermissionCode(), p.getPermissionName())).toList();
        return new PermissionCatalogView(items, new TreeMap<>(PermissionSets.ALL));
    }

    @Transactional(readOnly = true)
    public UserPermissionsView userPermissions(Long userId) {
        users.findById(userId).orElseThrow(() -> BusinessException.notFound("tài khoản"));
        return permissionsOf(userId);
    }

    /**
     * Thay toàn bộ quyền gán trực tiếp của một người dùng (đây là cách cấp tập quyền HR cho Quản lý/Nhân viên).
     * Có hiệu lực ngay ở request kế tiếp vì quyền được nạp lại từ DB mỗi request. Mọi thay đổi đều audit.
     */
    @Transactional
    public UserPermissionsView setUserPermissions(Long userId, List<String> codes, List<String> sets) {
        AuthUser cu = SecurityUtils.current();
        users.findById(userId).orElseThrow(() -> BusinessException.notFound("tài khoản"));

        Set<String> wanted = new TreeSet<>();
        if (codes != null) wanted.addAll(codes);
        if (sets != null) for (String name : sets) {
            List<String> members = PermissionSets.ALL.get(name);
            if (members == null) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Tập quyền không tồn tại: " + name);
            wanted.addAll(members);
        }
        List<Permission> found = permissionRepo.findByPermissionCodeIn(wanted);
        if (found.size() != wanted.size()) {
            Set<String> known = new HashSet<>();
            found.forEach(p -> known.add(p.getPermissionCode()));
            wanted.removeAll(known);
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Quyền không tồn tại: " + String.join(", ", wanted));
        }

        List<String> before = permissionRepo.findDirectCodesByUserId(userId);
        userPermissions.deleteByUserId(userId);
        userPermissions.flush();
        for (Permission p : found) {
            UserPermission up = new UserPermission();
            up.setUserId(userId);
            up.setPermissionId(p.getPermissionId());
            up.setGrantedBy(cu.userId());
            userPermissions.save(up);
        }
        List<String> after = found.stream().map(Permission::getPermissionCode).sorted().toList();
        List<String> setNames = sets == null ? List.<String>of() : sets;
        audit.log("USER_PERMISSIONS_CHANGE", "AppUser", userId,
                Map.<String, Object>of("permissions", new TreeSet<String>(before)),
                Map.<String, Object>of("permissions", after, "permissionSets", setNames));
        return permissionsOf(userId);
    }

    private UserPermissionsView permissionsOf(Long userId) {
        return new UserPermissionsView(userId, roleRepo.findActiveCodesByUserId(userId),
                permissionRepo.findDirectCodesByUserId(userId).stream().sorted().toList(),
                permissionRepo.findEffectiveCodesByUserId(userId).stream().sorted().toList());
    }

    @Transactional
    public UserView create(CreateUserRequest r) {
        String email = r.email().trim().toLowerCase();
        if (users.findByEmail(email).isPresent())
            throw new BusinessException(ErrorCode.CONFLICT, "Email đã tồn tại");
        AppUser u = new AppUser();
        u.setEmail(email);
        u.setDisplayName(r.displayName().trim());
        u.setPhoneNumber(r.phoneNumber());
        u.setUserStatus("ACTIVE");
        users.save(u);
        List<String> codes = r.roles() == null || r.roles().isEmpty() ? List.of(Roles.EMPLOYEE) : r.roles();
        assignRoles(u.getUserId(), codes);
        audit.log("USER_CREATE", "AppUser", u.getUserId(), null, Map.of("email", email, "roles", codes));
        return auth.view(u, roleRepo.findActiveCodesByUserId(u.getUserId()));
    }

    @Transactional
    public UserView setRoles(Long userId, List<String> codes) {
        AuthUser cu = SecurityUtils.current();
        AppUser u = users.findById(userId).orElseThrow(() -> BusinessException.notFound("tài khoản"));
        List<String> before = roleRepo.findActiveCodesByUserId(userId);
        if (cu.userId().equals(userId) && !codes.contains(Roles.SYSTEM_ADMIN))
            throw BusinessException.rule("Không thể tự gỡ quyền quản trị của chính mình");
        if (!codes.contains(Roles.SYSTEM_ADMIN)) assertNotLastActiveAdmin(userId);
        userRoles.deleteByUserId(userId);
        userRoles.flush();
        assignRoles(userId, codes);
        audit.log("USER_ROLES_CHANGE", "AppUser", userId, Map.of("roles", before), Map.of("roles", codes));
        return auth.view(u, roleRepo.findActiveCodesByUserId(userId));
    }

    @Transactional
    public UserView setStatus(Long userId, String status) {
        AuthUser cu = SecurityUtils.current();
        if (!List.of("ACTIVE", "LOCKED", "INACTIVE").contains(status))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Trạng thái phải là ACTIVE, LOCKED hoặc INACTIVE");
        if (cu.userId().equals(userId)) throw BusinessException.rule("Không thể tự đổi trạng thái tài khoản của mình");
        AppUser u = users.findById(userId).orElseThrow(() -> BusinessException.notFound("tài khoản"));
        if (!"ACTIVE".equals(status)) assertNotLastActiveAdmin(userId);
        String old = u.getUserStatus();
        u.setUserStatus(status);
        if (!"ACTIVE".equals(status)) refreshTokens.revokeAll(userId, clock.instant());
        audit.log("USER_STATUS_CHANGE", "AppUser", userId, Map.of("status", old), Map.of("status", status));
        return auth.view(u, roleRepo.findActiveCodesByUserId(userId));
    }

    /** Luôn còn ít nhất một System Admin đang hoạt động (không khóa hoặc gỡ quyền admin cuối cùng). */
    private void assertNotLastActiveAdmin(Long userId) {
        if (!roleRepo.findActiveCodesByUserId(userId).contains(Roles.SYSTEM_ADMIN)) return;
        boolean anotherAdmin = users.findActiveUserIdsByRoleCode(Roles.SYSTEM_ADMIN).stream()
                .anyMatch(id -> !id.equals(userId));
        if (!anotherAdmin) throw BusinessException.rule("Phải còn ít nhất một System Admin đang hoạt động");
    }

    private void assignRoles(Long userId, List<String> codes) {
        for (String code : new LinkedHashSet<>(codes)) {
            if ("HR".equals(code))
                throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                        "HR là tập quyền, không phải vai trò. Hãy gán qua PUT /admin/users/{id}/permissions với permissionSets=[\"HR\"]");
            Role role = roleRepo.findByRoleCode(code)
                    .filter(rr -> Boolean.TRUE.equals(rr.getIsActive()))
                    .orElseThrow(() -> new BusinessException(ErrorCode.VALIDATION_ERROR, "Vai trò không tồn tại: " + code));
            UserRole ur = new UserRole();
            ur.setUserId(userId);
            ur.setRoleId(role.getRoleId());
            userRoles.save(ur);
        }
    }
}
