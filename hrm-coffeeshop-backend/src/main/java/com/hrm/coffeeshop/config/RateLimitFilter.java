package com.hrm.coffeeshop.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hrm.coffeeshop.common.ApiResponse;
import com.hrm.coffeeshop.common.AuthUser;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.SecurityUtils;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Clock;
import java.util.concurrent.ConcurrentHashMap;

/** Rate limit cửa sổ cố định 1 phút cho API nhạy cảm (đơn node; nhiều node → dùng Redis/gateway). */
public class RateLimitFilter extends OncePerRequestFilter {
    private record Window(long minute, int[] count) {}

    private final ConcurrentHashMap<String, Window> windows = new ConcurrentHashMap<>();
    private final AppProperties props;
    private final ObjectMapper mapper;
    private final Clock clock;

    public RateLimitFilter(AppProperties props, ObjectMapper mapper, Clock clock) {
        this.props = props;
        this.mapper = mapper;
        this.clock = clock;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String path = req.getRequestURI();
        int limit = 0;
        String key = null;
        if (path.startsWith("/api/v1/auth/")) {
            limit = props.rateLimit().authPerMinute();
            key = "auth:" + req.getRemoteAddr();
        } else if (path.equals("/api/v1/attendance/check-in") || path.equals("/api/v1/attendance/check-out")
                || path.startsWith("/api/v1/attendance/spot-checks/") && path.endsWith("/respond")
                || path.startsWith("/api/v1/attendance/") && path.endsWith("/spot-check")) {
            limit = props.rateLimit().attendancePerMinute();
            AuthUser u = SecurityUtils.currentOrNull();
            key = "att:" + (u != null ? u.userId() : req.getRemoteAddr());
        }
        if (key != null && !allow(key, limit)) {
            res.setStatus(429);
            res.setContentType("application/json;charset=UTF-8");
            res.setHeader("Retry-After", "60");
            mapper.writeValue(res.getWriter(),
                    ApiResponse.error("Quá nhiều yêu cầu, vui lòng thử lại sau", ErrorCode.TOO_MANY_REQUESTS.name(), null));
            return;
        }
        chain.doFilter(req, res);
    }

    private boolean allow(String key, int limit) {
        long minute = clock.millis() / 60_000;
        if (windows.size() > 10_000) windows.entrySet().removeIf(e -> e.getValue().minute() < minute);
        Window w = windows.compute(key, (k, old) -> old == null || old.minute() != minute ? new Window(minute, new int[]{0}) : old);
        synchronized (w) {
            return ++w.count()[0] <= limit;
        }
    }
}
