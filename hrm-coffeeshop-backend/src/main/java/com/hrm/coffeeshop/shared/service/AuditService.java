package com.hrm.coffeeshop.shared.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hrm.coffeeshop.common.AuthUser;
import com.hrm.coffeeshop.common.SecurityUtils;
import com.hrm.coffeeshop.domain.AuditLog;
import com.hrm.coffeeshop.repository.AuditLogRepository;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/** Audit append-only: chỉ có thao tác ghi. Không lưu token/bí mật. */
@Service
public class AuditService {
    /** Chỉ controller đặt thuộc tính này sau khi xác minh HMAC của signed URL thành công. */
    public static final String SIGNED_URL_ACTOR_ATTRIBUTE = AuditService.class.getName() + ".signedUrlActor";

    private final AuditLogRepository repo;
    private final ObjectMapper mapper;

    public AuditService(AuditLogRepository repo, ObjectMapper mapper) {
        this.repo = repo;
        this.mapper = mapper;
    }

    @Transactional
    public void log(String action, String entityType, Object entityId, Object before, Object after) {
        AuditLog a = new AuditLog();
        AuthUser u = SecurityUtils.currentOrNull();
        Long actorId = u == null ? null : u.userId();
        a.setActionCode(action);
        a.setEntityType(entityType);
        a.setEntityId(entityId == null ? null : String.valueOf(entityId));
        a.setBeforeJson(json(before));
        a.setAfterJson(json(after));
        if (RequestContextHolder.getRequestAttributes() instanceof ServletRequestAttributes sra) {
            HttpServletRequest r = sra.getRequest();
            if (actorId == null && r.getAttribute(SIGNED_URL_ACTOR_ATTRIBUTE) instanceof Long signedActorId)
                actorId = signedActorId;
            a.setIpAddress(r.getRemoteAddr());
            Object correlationId = r.getAttribute(com.hrm.coffeeshop.config.CorrelationIdFilter.ATTRIBUTE);
            if (correlationId instanceof String id) a.setCorrelationId(id);
            String ua = r.getHeader("User-Agent");
            a.setUserAgent(ua == null ? null : ua.substring(0, Math.min(ua.length(), 500)));
        }
        a.setActorUserId(actorId);
        repo.save(a);
    }

    private String json(Object o) {
        if (o == null) return null;
        try {
            return mapper.writeValueAsString(o);
        } catch (Exception e) {
            return "\"<unserializable>\"";
        }
    }
}
