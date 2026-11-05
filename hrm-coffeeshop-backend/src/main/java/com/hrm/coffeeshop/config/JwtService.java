package com.hrm.coffeeshop.config;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.util.Date;

@Component
public class JwtService {
    private final AppProperties props;
    private final Clock clock;
    private SecretKey key;

    public JwtService(AppProperties props, Clock clock) {
        this.props = props;
        this.clock = clock;
    }

    @PostConstruct
    void init() {
        String s = props.jwt().secret();
        if (s == null || s.getBytes(StandardCharsets.UTF_8).length < 32)
            throw new IllegalStateException("app.jwt.secret (env JWT_SECRET) phải có tối thiểu 32 ký tự");
        if (s.startsWith("change-me"))
            throw new IllegalStateException("app.jwt.secret đang dùng giá trị mẫu; hãy đặt JWT_SECRET ngẫu nhiên");
        key = Keys.hmacShaKeyFor(s.getBytes(StandardCharsets.UTF_8));
    }

    public String createAccessToken(Long userId) {
        Instant now = clock.instant();
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .claim("typ", "access")
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusSeconds(props.jwt().accessTtlSeconds())))
                .signWith(key)
                .compact();
    }

    /** @return userId nếu token hợp lệ. */
    public Long parseAccessToken(String token) {
        try {
            Claims c = Jwts.parser().verifyWith(key).clock(() -> Date.from(clock.instant()))
                    .build().parseSignedClaims(token).getPayload();
            if (!"access".equals(c.get("typ", String.class)))
                throw new BusinessException(ErrorCode.INVALID_TOKEN, "Token không hợp lệ");
            return Long.valueOf(c.getSubject());
        } catch (JwtException | IllegalArgumentException e) {
            throw new BusinessException(ErrorCode.INVALID_TOKEN, "Token không hợp lệ hoặc đã hết hạn");
        }
    }

    public long accessTtlSeconds() { return props.jwt().accessTtlSeconds(); }
}
