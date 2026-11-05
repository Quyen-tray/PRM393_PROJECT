package com.hrm.coffeeshop.common;

import java.time.*;

/** Mọi thời điểm lưu UTC; hiển thị theo Asia/Ho_Chi_Minh với offset rõ ràng. */
public final class TimeUtils {
    public static final ZoneId ZONE = ZoneId.of("Asia/Ho_Chi_Minh");
    private TimeUtils() {}

    public static OffsetDateTime nowVn() { return OffsetDateTime.now(ZONE); }
    public static OffsetDateTime vn(Instant i) { return i == null ? null : i.atZone(ZONE).toOffsetDateTime(); }
    public static Instant instant(OffsetDateTime o) { return o == null ? null : o.toInstant(); }
    public static Instant at(LocalDate d, LocalTime t) { return d.atTime(t).atZone(ZONE).toInstant(); }
    public static LocalDate today(Clock c) { return LocalDate.now(c.withZone(ZONE)); }
    public static LocalDate dateOf(Instant i) { return i.atZone(ZONE).toLocalDate(); }
    public static Instant startOfDay(LocalDate d) { return d.atStartOfDay(ZONE).toInstant(); }
    public static long minutes(Instant a, Instant b) { return Duration.between(a, b).toMinutes(); }
    /** Làm tròn lên theo phút. */
    public static int ceilMinutes(Instant from, Instant to) {
        long s = Duration.between(from, to).getSeconds();
        return s <= 0 ? 0 : (int) ((s + 59) / 60);
    }
}
