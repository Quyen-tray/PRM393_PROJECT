package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.DocumentDto.DocumentView;
import com.hrm.coffeeshop.shared.dto.DocumentDto.DocumentCatalogItem;
import com.hrm.coffeeshop.shared.dto.DocumentDto.DocumentCatalogView;
import com.hrm.coffeeshop.shared.dto.DocumentDto.ProfileStatusView;
import com.hrm.coffeeshop.shared.dto.DocumentDto.RequirementStatus;
import com.hrm.coffeeshop.shared.dto.DocumentDto.SubmitRequest;
import com.hrm.coffeeshop.shared.dto.DocumentDto.TypeRequest;
import com.hrm.coffeeshop.shared.dto.DocumentDto.TypeView;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.*;
import com.hrm.coffeeshop.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.time.LocalDate;
import java.util.*;
import java.util.regex.Pattern;

@Service
public class DocumentService {
    private static final Pattern KEY = Pattern.compile("^private-documents/[A-Za-z0-9._\\-/]{1,850}$");

    private final DocumentTypeRepository types;
    private final PositionDocumentRequirementRepository requirements;
    private final EmployeeDocumentRepository docs;
    private final EmployeeRepository employees;
    private final AppUserRepository users;
    private final StorageGateway storage;
    private final NotificationService notifications;
    private final AuditService audit;
    private final Clock clock;

    public DocumentService(DocumentTypeRepository types, PositionDocumentRequirementRepository requirements,
                           EmployeeDocumentRepository docs,
                           EmployeeRepository employees, AppUserRepository users, StorageGateway storage,
                           NotificationService notifications, AuditService audit, Clock clock) {
        this.types = types;
        this.requirements = requirements;
        this.docs = docs;
        this.employees = employees;
        this.users = users;
        this.storage = storage;
        this.notifications = notifications;
        this.audit = audit;
        this.clock = clock;
    }

    static TypeView view(DocumentType t) {
        return new TypeView(t.getDocumentTypeId(), t.getDocumentCode(), t.getDocumentName(), t.getIsActive());
    }

    // ---------- Danh mục loại hồ sơ (Admin) ----------
    @Transactional(readOnly = true)
    public List<TypeView> listTypes() { return types.findAll().stream().map(DocumentService::view).toList(); }

    @Transactional
    public TypeView createType(TypeRequest r) {
        if (types.findByDocumentCode(r.documentCode()).isPresent())
            throw new BusinessException(ErrorCode.CONFLICT, "Mã loại hồ sơ đã tồn tại");
        DocumentType t = new DocumentType();
        applyType(t, r);
        types.save(t);
        audit.log("DOCUMENT_TYPE_CREATE", "DocumentType", t.getDocumentTypeId(), null, view(t));
        return view(t);
    }

    @Transactional
    public TypeView updateType(Integer id, TypeRequest r) {
        DocumentType t = types.findById(id).orElseThrow(() -> BusinessException.notFound("loại hồ sơ"));
        types.findByDocumentCode(r.documentCode()).filter(x -> !x.getDocumentTypeId().equals(id)).ifPresent(x -> {
            throw new BusinessException(ErrorCode.CONFLICT, "Mã loại hồ sơ đã tồn tại");
        });
        TypeView before = view(t);
        applyType(t, r);
        audit.log("DOCUMENT_TYPE_UPDATE", "DocumentType", id, before, view(t));
        return view(t);
    }

    private void applyType(DocumentType t, TypeRequest r) {
        t.setDocumentCode(r.documentCode().trim());
        t.setDocumentName(r.documentName().trim());
        if (r.isActive() != null) t.setIsActive(r.isActive());
    }

    // ---------- Trạng thái đủ/thiếu hồ sơ: luôn TÍNH từ dữ liệu chi tiết ----------
    @Transactional(readOnly = true)
    public ProfileStatusView profile(Employee e) {
        LocalDate today = TimeUtils.today(clock);
        // Bộ hồ sơ bắt buộc = yêu cầu theo chức vụ đang hiệu lực (SRS 7.4), không còn cờ trên loại hồ sơ
        Map<Integer, DocumentType> tm = new HashMap<>();
        types.findAll().forEach(t -> tm.put(t.getDocumentTypeId(), t));
        List<DocumentType> required = e.getPositionId() == null ? List.of()
                : requirements.findEffective(e.getPositionId(), today).stream()
                .filter(r -> Boolean.TRUE.equals(r.getIsMandatory()))
                .map(r -> tm.get(r.getDocumentTypeId()))
                .filter(t -> t != null && Boolean.TRUE.equals(t.getIsActive()))
                .distinct().toList();
        List<EmployeeDocument> mine = docs.findByEmployeeId(e.getEmployeeId());
        boolean allValid = true, anyPending = false, anyExpired = false;
        List<RequirementStatus> reqs = new ArrayList<>();
        for (DocumentType t : required) {
            List<EmployeeDocument> ds = mine.stream().filter(d -> d.getDocumentTypeId().equals(t.getDocumentTypeId())).toList();
            boolean valid = ds.stream().anyMatch(d -> "APPROVED".equals(d.getReviewStatus())
                    && (d.getExpiresAt() == null || !d.getExpiresAt().isBefore(today)));
            String st;
            if (valid) st = "COMPLETE";
            else {
                allValid = false;
                if (ds.stream().anyMatch(d -> "PENDING".equals(d.getReviewStatus()))) { anyPending = true; st = "UNDER_REVIEW"; }
                else if (ds.stream().anyMatch(d -> "EXPIRED".equals(d.getReviewStatus())
                        || ("APPROVED".equals(d.getReviewStatus()) && d.getExpiresAt() != null && d.getExpiresAt().isBefore(today)))) {
                    anyExpired = true; st = "EXPIRED";
                } else st = "MISSING";
            }
            reqs.add(new RequirementStatus(view(t), st));
        }
        String overall = allValid ? "COMPLETE" : anyPending ? "UNDER_REVIEW" : anyExpired ? "EXPIRED" : "INCOMPLETE";
        return new ProfileStatusView(overall, reqs);
    }

    /** Catalog hồ sơ của nhân viên; employeeId phải đến từ SecurityUtils tại controller self-service. */
    @Transactional(readOnly = true)
    public DocumentCatalogView catalog(Long employeeId) {
        Employee e = employees.findById(employeeId)
                .orElseThrow(() -> BusinessException.notFound("nhân viên"));
        LocalDate today = TimeUtils.today(clock);
        Set<Integer> requiredTypes = e.getPositionId() == null ? Set.of()
                : requirements.findEffective(e.getPositionId(), today).stream()
                .filter(r -> Boolean.TRUE.equals(r.getIsMandatory()))
                .map(PositionDocumentRequirement::getDocumentTypeId)
                .collect(java.util.stream.Collectors.toSet());

        List<EmployeeDocument> history = docs.findByEmployeeIdOrderByUploadedAtDesc(employeeId);
        Map<Integer, List<EmployeeDocument>> documentsByType = new HashMap<>();
        history.forEach(d -> documentsByType.computeIfAbsent(d.getDocumentTypeId(), ignored -> new ArrayList<>()).add(d));

        List<DocumentCatalogItem> items = types.findByIsActiveTrue().stream()
                .sorted(Comparator.comparing(DocumentType::getDocumentName, String.CASE_INSENSITIVE_ORDER))
                .map(type -> {
                    List<EmployeeDocument> ownDocuments = documentsByType.getOrDefault(type.getDocumentTypeId(), List.of());
                    EmployeeDocument latest = ownDocuments.stream().max(Comparator
                            .comparing(EmployeeDocument::getUploadedAt, Comparator.nullsFirst(Comparator.naturalOrder()))
                            .thenComparing(EmployeeDocument::getEmployeeDocumentId,
                                    Comparator.nullsFirst(Comparator.naturalOrder())))
                            .orElse(null);
                    String blockReason = submissionBlockReason(ownDocuments, today);
                    return new DocumentCatalogItem(type.getDocumentTypeId(), type.getDocumentCode(),
                            type.getDocumentName(), type.getIsActive(), requiredTypes.contains(type.getDocumentTypeId()),
                            latest == null ? null : latest.getReviewStatus(), blockReason == null, blockReason);
                }).toList();
        return new DocumentCatalogView(e.getPositionId(), today, items);
    }

    /** Eligibility shared by the catalog and submission; the database index is the concurrent-write guard. */
    @Transactional(readOnly = true)
    public boolean canSubmit(Long employeeId, Integer documentTypeId, LocalDate today) {
        List<EmployeeDocument> matching = docs.findByEmployeeId(employeeId).stream()
                .filter(d -> d.getDocumentTypeId().equals(documentTypeId)).toList();
        return submissionBlockReason(matching, today) == null;
    }

    private String submissionBlockReason(List<EmployeeDocument> documents, LocalDate today) {
        if (documents.stream().anyMatch(d -> "PENDING".equals(d.getReviewStatus())))
            return "Đã có hồ sơ cùng loại đang chờ duyệt.";
        if (documents.stream().anyMatch(d -> "APPROVED".equals(d.getReviewStatus())
                && (d.getExpiresAt() == null || !d.getExpiresAt().isBefore(today))))
            return "Hồ sơ cùng loại đã được duyệt và còn hiệu lực.";
        return null;
    }

    /** Đồng bộ cột cache Employee.ProfileStatus (không phải nguồn sự thật). */
    @Transactional
    public void syncProfileStatus(Employee e) {
        String s = profile(e).profileStatus();
        e.setProfileStatus("EXPIRED".equals(s) ? "INCOMPLETE" : s);
    }

    // ---------- Nộp / xem / duyệt ----------
    @Transactional
    public DocumentView submit(Long employeeId, SubmitRequest r) {
        Employee e = employees.findById(employeeId).orElseThrow(() -> BusinessException.notFound("nhân viên"));
        DocumentType t = types.findById(r.documentTypeId()).filter(x -> Boolean.TRUE.equals(x.getIsActive()))
                .orElseThrow(() -> new BusinessException(ErrorCode.VALIDATION_ERROR, "Loại hồ sơ không tồn tại hoặc đã ngưng"));
        String key = r.storageKey();
        if (!KEY.matcher(key).matches() || key.contains("..") || !key.startsWith("private-documents/employee-" + employeeId + "/"))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                    "storageKey phải nằm trong private-documents/employee-" + employeeId + "/");
        if (!storage.exists(key))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Tệp hồ sơ chưa được tải lên hoặc đã bị xóa");
        if (r.expiresAt() != null && r.expiresAt().isBefore(TimeUtils.today(clock)))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Tài liệu đã hết hạn");
        String blockReason = submissionBlockReason(docs.findByEmployeeId(employeeId).stream()
                .filter(d -> d.getDocumentTypeId().equals(t.getDocumentTypeId())).toList(), TimeUtils.today(clock));
        if (blockReason != null) throw new BusinessException(ErrorCode.CONFLICT, blockReason);
        EmployeeDocument d = new EmployeeDocument();
        d.setEmployeeId(employeeId);
        d.setDocumentTypeId(t.getDocumentTypeId());
        d.setStorageKey(key);
        String fn = key.substring(key.lastIndexOf('/') + 1);
        d.setFileName(fn.substring(0, Math.min(fn.length(), 255)));
        d.setExpiresAt(r.expiresAt());
        if (r.issuedAt() != null && r.issuedAt().isAfter(TimeUtils.today(clock)))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Ngày cấp không được sau hôm nay");
        d.setIssuedAt(r.issuedAt());
        docs.save(d);
        syncProfileStatus(e);
        audit.log("DOCUMENT_SUBMIT", "EmployeeDocument", d.getEmployeeDocumentId(), null,
                Map.of("employeeId", employeeId, "documentTypeId", t.getDocumentTypeId()));
        return toView(d, t, null);
    }

    @Transactional(readOnly = true)
    public List<DocumentView> list(Long employeeId) {
        assertCanAccess(employeeId);
        Map<Integer, DocumentType> tm = new HashMap<>();
        types.findAll().forEach(t -> tm.put(t.getDocumentTypeId(), t));
        return docs.findByEmployeeIdOrderByUploadedAtDesc(employeeId).stream()
                .map(d -> toView(d, tm.get(d.getDocumentTypeId()), null)).toList();
    }

    /** Hàng đợi duyệt hồ sơ cho Quản lý/HR (cũ nhất trước, tối đa 100). */
    @Transactional(readOnly = true)
    public List<DocumentView> listPending() {
        SecurityUtils.requirePermission(Permissions.DOCUMENT_REVIEW);
        Map<Integer, DocumentType> tm = new HashMap<>();
        types.findAll().forEach(t -> tm.put(t.getDocumentTypeId(), t));
        Map<Long, String> names = new HashMap<>();
        List<DocumentView> out = new ArrayList<>();
        for (EmployeeDocument d : docs.findTop100ByReviewStatusOrderByUploadedAtAsc("PENDING")) {
            DocumentView v = toView(d, tm.get(d.getDocumentTypeId()), null);
            String name = names.computeIfAbsent(d.getEmployeeId(), id -> {
                Employee e = employees.findById(id).orElse(null);
                return e == null ? "" : users.findById(e.getUserId()).map(AppUser::getDisplayName).orElse("");
            });
            out.add(new DocumentView(v.documentId(), v.employeeId(), v.documentType(), v.fileName(), v.reviewStatus(),
                    v.expiresAt(), v.uploadedAt(), v.reviewedAt(), v.rejectionReason(), null, name));
        }
        return out;
    }

    /** Metadata + URL xem có hạn; mọi lần truy cập tài liệu nhạy cảm được audit. */
    @Transactional
    public DocumentView get(Long documentId) {
        EmployeeDocument d = docs.findById(documentId).orElseThrow(() -> BusinessException.notFound("hồ sơ"));
        assertCanAccess(d.getEmployeeId());
        audit.log("DOCUMENT_VIEW", "EmployeeDocument", documentId, null, Map.of("employeeId", d.getEmployeeId()));
        String url = storage.createViewUrl(d.getStorageKey(), Duration.ofSeconds(120), SecurityUtils.current().userId());
        return toView(d, types.findById(d.getDocumentTypeId()).orElse(null), url);
    }

    @Transactional
    public DocumentView approve(Long documentId) {
        EmployeeDocument d = reviewable(documentId);
        d.setReviewStatus("APPROVED");
        finishReview(d, null);
        return toView(d, types.findById(d.getDocumentTypeId()).orElse(null), null);
    }

    @Transactional
    public DocumentView reject(Long documentId, String reason) {
        if (reason == null || reason.isBlank()) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Phải nhập lý do từ chối");
        EmployeeDocument d = reviewable(documentId);
        d.setReviewStatus("REJECTED");
        finishReview(d, reason.trim());
        return toView(d, types.findById(d.getDocumentTypeId()).orElse(null), null);
    }

    private EmployeeDocument reviewable(Long id) {
        AuthUser u = SecurityUtils.current();
        if (!u.hasPermission(Permissions.DOCUMENT_REVIEW))
            throw BusinessException.forbidden("Bạn không có quyền duyệt hồ sơ");
        EmployeeDocument d = docs.findById(id).orElseThrow(() -> BusinessException.notFound("hồ sơ"));
        Employee e = employees.findById(d.getEmployeeId()).orElseThrow();
        if (e.getUserId().equals(u.userId())) throw BusinessException.forbidden("Không thể tự duyệt hồ sơ của chính mình");
        if (!"PENDING".equals(d.getReviewStatus()))
            throw BusinessException.invalidState("Hồ sơ không ở trạng thái chờ duyệt");
        return d;
    }

    private void finishReview(EmployeeDocument d, String reason) {
        AuthUser u = SecurityUtils.current();
        d.setReviewedBy(u.userId());
        d.setReviewedAt(clock.instant());
        d.setRejectionReason(reason);
        Employee e = employees.findById(d.getEmployeeId()).orElseThrow();
        syncProfileStatus(e);
        audit.log("DOCUMENT_" + d.getReviewStatus(), "EmployeeDocument", d.getEmployeeDocumentId(), null,
                Map.of("status", d.getReviewStatus(), "reason", String.valueOf(reason)));
        notifications.notify(e.getUserId(), "DOCUMENT_REVIEWED", "Kết quả duyệt hồ sơ",
                "APPROVED".equals(d.getReviewStatus()) ? "Hồ sơ của bạn đã được duyệt." : "Hồ sơ bị từ chối: " + reason,
                "EmployeeDocument", d.getEmployeeDocumentId(), null);
    }

    private void assertCanAccess(Long employeeId) {
        AuthUser u = SecurityUtils.current();
        if (employeeId.equals(u.employeeId()) || u.hasPermission(Permissions.DOCUMENT_REVIEW)) return;
        throw BusinessException.forbidden("Bạn không có quyền xem hồ sơ này");
    }

    private DocumentView toView(EmployeeDocument d, DocumentType t, String url) {
        return new DocumentView(d.getEmployeeDocumentId(), d.getEmployeeId(), t == null ? null : view(t), d.getFileName(),
                d.getReviewStatus(), d.getExpiresAt(), TimeUtils.vn(d.getUploadedAt()), TimeUtils.vn(d.getReviewedAt()),
                "REJECTED".equals(d.getReviewStatus()) ? d.getRejectionReason() : null, url, null);
    }

    @Transactional
    public int expireOutdated() { return docs.markExpired(TimeUtils.today(clock)); }
}
