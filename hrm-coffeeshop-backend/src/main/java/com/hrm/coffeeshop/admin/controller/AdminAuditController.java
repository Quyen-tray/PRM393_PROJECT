package com.hrm.coffeeshop.admin.controller;

import com.hrm.coffeeshop.admin.dto.AdminMiscDto.AuditView;
import com.hrm.coffeeshop.shared.service.AuditService;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.AuditLog;
import com.hrm.coffeeshop.repository.AuditLogRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

/** Chỉ đọc/xuất. Không có endpoint sửa hoặc xóa audit log. */
@RestController
@RequestMapping("/admin/audit-logs")
@PreAuthorize("hasRole('SYSTEM_ADMIN')")
public class AdminAuditController {
    private final AuditLogRepository repo;
    private final AuditService audit;

    public AdminAuditController(AuditLogRepository repo, AuditService audit) {
        this.repo = repo;
        this.audit = audit;
    }

    static AuditView view(AuditLog a) {
        return new AuditView(a.getAuditLogId(), a.getActorUserId(), a.getActionCode(), a.getEntityType(), a.getEntityId(),
                a.getBeforeJson(), a.getAfterJson(), a.getIpAddress(), a.getCorrelationId(), TimeUtils.vn(a.getCreatedAt()));
    }

    private static Instant[] range(LocalDate from, LocalDate to) {
        Instant f = from == null ? Instant.EPOCH : TimeUtils.startOfDay(from);
        Instant t = to == null ? Instant.parse("9999-01-01T00:00:00Z") : TimeUtils.startOfDay(to.plusDays(1));
        return new Instant[]{f, t};
    }

    @GetMapping
    public ApiResponse<PageResponse<AuditView>> list(@RequestParam(defaultValue = "") String entityType,
                                                     @RequestParam(defaultValue = "") String actionCode,
                                                     @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                                     @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                                                     @PageableDefault(size = 50) Pageable p) {
        Instant[] r = range(from, to);
        Page<AuditLog> page = repo.search(entityType, actionCode, r[0], r[1],
                PageRequest.of(p.getPageNumber(), Math.min(p.getPageSize(), 200), Sort.by("createdAt").descending()));
        return ApiResponse.ok(PageResponse.of(page, AdminAuditController::view));
    }

    @GetMapping("/{logId}")
    public ApiResponse<AuditView> get(@PathVariable Long logId) {
        return ApiResponse.ok(view(repo.findById(logId).orElseThrow(() -> BusinessException.notFound("audit log"))));
    }

    @GetMapping(value = "/export", produces = MediaType.TEXT_PLAIN_VALUE)
    public String export(@RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                         @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        Instant[] r = range(from, to);
        List<AuditLog> rows = repo.search("", "", r[0], r[1], PageRequest.of(0, 5000, Sort.by("createdAt").descending())).getContent();
        audit.log("AUDIT_EXPORT", "AuditLog", null, null, java.util.Map.of("rows", rows.size()));
        StringBuilder sb = new StringBuilder("auditLogId,createdAt,actorUserId,actionCode,entityType,entityId,ipAddress,correlationId\n");
        for (AuditLog a : rows)
            sb.append(a.getAuditLogId()).append(',').append(TimeUtils.vn(a.getCreatedAt())).append(',')
                    .append(a.getActorUserId()).append(',').append(csv(a.getActionCode())).append(',')
                    .append(csv(a.getEntityType())).append(',').append(csv(a.getEntityId())).append(',')
                    .append(csv(a.getIpAddress())).append(',').append(csv(a.getCorrelationId())).append('\n');
        return sb.toString();
    }

    /** Chống CSV injection. */
    private static String csv(String s) {
        if (s == null) return "";
        String v = s.replace("\"", "\"\"");
        if (!v.isEmpty() && "=+-@".indexOf(v.charAt(0)) >= 0) v = "'" + v;
        return "\"" + v + "\"";
    }
}
