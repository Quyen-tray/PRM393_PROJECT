package com.hrm.coffeeshop.config;

import com.hrm.coffeeshop.common.AuthUser;
import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.domain.AppUser;
import com.hrm.coffeeshop.repository.AppUserRepository;
import com.hrm.coffeeshop.repository.EmployeeRepository;
import com.hrm.coffeeshop.repository.PermissionRepository;
import com.hrm.coffeeshop.repository.RoleRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/** Mỗi request: xác thực JWT rồi nạp lại trạng thái tài khoản/quyền/hồ sơ từ DB (backend quyết định quyền). */
public class JwtAuthFilter extends OncePerRequestFilter {
    private final JwtService jwt;
    private final AppUserRepository users;
    private final RoleRepository roles;
    private final PermissionRepository permissions;
    private final EmployeeRepository employees;

    public JwtAuthFilter(JwtService jwt, AppUserRepository users, RoleRepository roles,
                         PermissionRepository permissions, EmployeeRepository employees) {
        this.jwt = jwt;
        this.users = users;
        this.roles = roles;
        this.permissions = permissions;
        this.employees = employees;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String h = req.getHeader("Authorization");
        if (h != null && h.startsWith("Bearer ")) {
            try {
                Long userId = jwt.parseAccessToken(h.substring(7));
                AppUser u = users.findById(userId).orElse(null);
                if (u != null && "ACTIVE".equals(u.getUserStatus())) {
                    Set<String> codes = Set.copyOf(roles.findActiveCodesByUserId(userId));
                    Long empId = employees.findByUserId(userId).map(e -> e.getEmployeeId()).orElse(null);
                    Set<String> perms = Set.copyOf(permissions.findEffectiveCodesByUserId(userId));
                    AuthUser principal = new AuthUser(userId, u.getEmail(), codes, perms, empId);
                    // ROLE_xxx cho hasRole(...); mã quyền nguyên dạng cho hasAuthority(...)
                    List<SimpleGrantedAuthority> auth = Stream.concat(
                                    codes.stream().map(c -> "ROLE_" + c), perms.stream())
                            .map(SimpleGrantedAuthority::new).collect(Collectors.toList());
                    SecurityContextHolder.getContext()
                            .setAuthentication(new UsernamePasswordAuthenticationToken(principal, null, auth));
                }
            } catch (BusinessException ignored) {
                // token sai/hết hạn: để entry point trả 401
            }
        }
        chain.doFilter(req, res);
    }
}
