package com.hrm.coffeeshop.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hrm.coffeeshop.common.ApiResponse;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.repository.AppUserRepository;
import com.hrm.coffeeshop.repository.EmployeeRepository;
import com.hrm.coffeeshop.repository.PermissionRepository;
import com.hrm.coffeeshop.repository.RoleRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.method.HandlerTypePredicate;
import org.springframework.web.servlet.config.annotation.PathMatchConfigurer;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.time.Clock;

@Configuration
@EnableMethodSecurity
public class SecurityConfig implements WebMvcConfigurer {

    /** Mọi controller nằm dưới /api/v1 (SRS 8.1). */
    @Override
    public void configurePathMatch(PathMatchConfigurer c) {
        c.addPathPrefix("/api/v1", HandlerTypePredicate.forBasePackage("com.hrm.coffeeshop.admin.controller", "com.hrm.coffeeshop.manager.controller", "com.hrm.coffeeshop.hr.controller", "com.hrm.coffeeshop.employee.controller", "com.hrm.coffeeshop.shared.controller"));
    }

    @Bean
    org.springframework.web.cors.CorsConfigurationSource corsConfigurationSource(
            @org.springframework.beans.factory.annotation.Value("${app.cors.allowed-origins}") String origins) {
        var config = new org.springframework.web.cors.CorsConfiguration();
        config.setAllowedOrigins(java.util.Arrays.stream(origins.split(",")).map(String::trim).filter(s -> !s.isEmpty()).toList());
        config.setAllowedMethods(java.util.List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(java.util.List.of("Authorization", "Content-Type", "Idempotency-Key", "X-Device-Credential", "X-Correlation-Id"));
        config.setExposedHeaders(java.util.List.of("X-Correlation-Id"));
        var source = new org.springframework.web.cors.UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }

    @Bean
    SecurityFilterChain chain(HttpSecurity http, JwtService jwt, AppUserRepository users, RoleRepository roles,
                              PermissionRepository permissions, EmployeeRepository employees, AppProperties props, ObjectMapper mapper,
                              Clock clock) throws Exception {
        JwtAuthFilter jwtFilter = new JwtAuthFilter(jwt, users, roles, permissions, employees);
        RateLimitFilter rateLimit = new RateLimitFilter(props, mapper, clock);
        http.cors(org.springframework.security.config.Customizer.withDefaults()).csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(a -> a
                        // Chỉ những đường dẫn dưới đây là công khai. Mọi endpoint khác mặc định yêu cầu đăng nhập
                        // (fail-closed): controller mới quên khai báo vẫn không bị truy cập ẩn danh.
                        .requestMatchers("/api/v1/auth/google", "/api/v1/auth/refresh").permitAll()
                        // URL xem file đã ký HMAC + có hạn (Image.network không gửi được Bearer)
                        .requestMatchers(HttpMethod.GET, "/api/v1/storage/view").permitAll()
                        .requestMatchers("/swagger-ui/**", "/swagger-ui.html", "/v3/api-docs/**").permitAll()
                        .requestMatchers("/error").permitAll()
                        .anyRequest().authenticated())
                .exceptionHandling(e -> e
                        // Chưa có token hoặc token sai/hết hạn: 401 để client refresh token hoặc đăng nhập lại.
                        .authenticationEntryPoint((req, res, ex) -> {
                            res.setStatus(401);
                            res.setContentType("application/json;charset=UTF-8");
                            mapper.writeValue(res.getWriter(), ApiResponse.error("Chưa xác thực hoặc token hết hạn",
                                    ErrorCode.UNAUTHENTICATED.name(), null));
                        })
                        // Token hợp lệ nhưng thiếu quyền: 403
                        .accessDeniedHandler((req, res, ex) -> {
                            res.setStatus(403);
                            res.setContentType("application/json;charset=UTF-8");
                            mapper.writeValue(res.getWriter(), ApiResponse.error("Bạn không đủ quyền truy cập",
                                    ErrorCode.PERMISSION_DENIED.name(), null));
                        }))
                .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
                .addFilterBefore(new CorrelationIdFilter(), JwtAuthFilter.class)
                .addFilterAfter(rateLimit, JwtAuthFilter.class);
        return http.build();
    }
}
