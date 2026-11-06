package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.ChecklistDto.AddEvidenceRequest;
import com.hrm.coffeeshop.shared.dto.ChecklistDto.CompleteItemRequest;
import com.hrm.coffeeshop.shared.dto.ChecklistDto.GenerateRequest;
import com.hrm.coffeeshop.shared.dto.ChecklistDto.ItemRequest;
import com.hrm.coffeeshop.shared.dto.ChecklistDto.ItemView;
import com.hrm.coffeeshop.shared.dto.ChecklistDto.RunItemView;
import com.hrm.coffeeshop.shared.dto.ChecklistDto.RunView;
import com.hrm.coffeeshop.shared.dto.ChecklistDto.TemplateRequest;
import com.hrm.coffeeshop.shared.dto.ChecklistDto.TemplateView;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.*;
import com.hrm.coffeeshop.repository.*;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

/**
 * Checklist vận hành. Schema hiện lưu theo cấp "run" (một lần thực hiện của mẫu); "taskId" của API = ChecklistTaskId.
 * Duyệt ở cấp run (Template.IsManagerApprovalRequired). Versioning (BR-CHK-01): mỗi version là một dòng
 * ChecklistTemplate cùng mã; sửa mẫu đã có lượt thực hiện sẽ tạo version mới, lượt cũ giữ nguyên version của mình.
 */
@Service
public class ChecklistService {
    private static final List<String> OPEN_STATES = List.of("PENDING", "IN_PROGRESS", "OVERDUE", "REJECTED");

    private final ChecklistTemplateRepository templates;
    private final ChecklistTemplateItemRepository items;
    private final ChecklistTaskRepository runs;
    private final ChecklistTaskItemRepository runItems;
    private final ChecklistInstanceRepository instances;
    private final ChecklistEvidenceRepository evidences;
    private final ChecklistReviewRepository reviews;
    private final ShiftAssignmentRepository schedules;
    private final EmployeeRepository employees;
    private final StoreService storeService;
    private final PersonLookup people;
    private final NotificationService notifications;
    private final AuditService audit;
    private final Clock clock;
    private final StorageGateway storage;

    public ChecklistService(ChecklistTemplateRepository templates, ChecklistTemplateItemRepository items,
                            ChecklistTaskRepository runs, ChecklistTaskItemRepository runItems,
                            ShiftAssignmentRepository schedules, EmployeeRepository employees,
                            StoreService storeService, PersonLookup people, NotificationService notifications,
                            AuditService audit, Clock clock, ChecklistInstanceRepository instances,
                            ChecklistEvidenceRepository evidences, ChecklistReviewRepository reviews,
                            StorageGateway storage) {
        this.storage = storage;
        this.instances = instances;
        this.evidences = evidences;
        this.reviews = reviews;
        this.templates = templates;
        this.items = items;
        this.runs = runs;
        this.runItems = runItems;
        this.schedules = schedules;
        this.employees = employees;
        this.storeService = storeService;
        this.people = people;
        this.notifications = notifications;
        this.audit = audit;
        this.clock = clock;
    }

    // ================= Mẫu (Admin) =================
    TemplateView view(ChecklistTemplate t) {
        List<ItemView> iv = items.findByChecklistTemplateIdOrderBySortOrderAsc(t.getChecklistTemplateId()).stream()
                .map(i -> new ItemView(i.getChecklistTemplateItemId(), i.getItemName(), i.getInstructions(), i.getIsMandatory(),
                        i.getRequiresEvidence(), i.getSortOrder(), i.getRequiresManagerApproval())).toList();
        return new TemplateView(t.getChecklistTemplateId(), t.getChecklistCode(), t.getChecklistName(), t.getChecklistType(),
                t.getIsManagerApprovalRequired(), t.getIsActive(), iv, t.getVersion());
    }

    @Transactional(readOnly = true)
    public List<TemplateView> listTemplates(boolean onlyActive) {
        Integer storeId = storeService.current().getStoreId();
        return (onlyActive ? templates.findByStoreIdAndIsActiveTrue(storeId) : templates.findByStoreId(storeId))
                .stream().map(this::view).toList();
    }

    @Transactional
    public TemplateView createTemplate(TemplateRequest r) {
        Integer storeId = storeService.current().getStoreId();
        if (!templates.findByStoreIdAndChecklistCode(storeId, r.checklistCode()).isEmpty())
            throw new BusinessException(ErrorCode.CONFLICT, "Mã checklist đã tồn tại");
        ChecklistTemplate t = new ChecklistTemplate();
        t.setStoreId(storeId);
        t.setVersion(1);
        applyHeader(t, r);
        templates.save(t);
        saveItems(t.getChecklistTemplateId(), r.items());
        audit.log("CHECKLIST_TEMPLATE_CREATE", "ChecklistTemplate", t.getChecklistTemplateId(), null, view(t));
        return view(t);
    }

    /**
     * Sửa mẫu (BR-CHK-01). Mẫu chưa có lượt thực hiện: sửa tại chỗ.
     * Mẫu đã có lượt: tạo VERSION mới (dòng mới cùng mã), version cũ giữ nguyên cho các lượt đã phát sinh;
     * version mới chưa hoạt động cho tới khi được kích hoạt.
     */
    @Transactional
    public TemplateView updateTemplate(Integer id, TemplateRequest r) {
        ChecklistTemplate t = templates.findById(id).orElseThrow(() -> BusinessException.notFound("mẫu checklist"));
        String code = r.checklistCode().trim();
        boolean used = runs.existsByChecklistTemplateId(id);
        if (!code.equals(t.getChecklistCode())) {
            if (used) throw BusinessException.invalidState("Không đổi mã mẫu đã có lượt thực hiện");
            if (!templates.findByStoreIdAndChecklistCode(t.getStoreId(), code).isEmpty())
                throw new BusinessException(ErrorCode.CONFLICT, "Mã checklist đã tồn tại");
        }
        TemplateView before = view(t);
        if (used) {
            int next = templates.findFirstByStoreIdAndChecklistCodeOrderByVersionDesc(t.getStoreId(), t.getChecklistCode())
                    .map(x -> x.getVersion() + 1).orElse(t.getVersion() + 1);
            ChecklistTemplate v = new ChecklistTemplate();
            v.setStoreId(t.getStoreId());
            v.setVersion(next);
            applyHeader(v, r);
            v.setIsActive(false);
            templates.save(v);
            saveItems(v.getChecklistTemplateId(), r.items());
            audit.log("CHECKLIST_TEMPLATE_NEW_VERSION", "ChecklistTemplate", v.getChecklistTemplateId(), before, view(v));
            return view(v);
        }
        applyHeader(t, r);
        for (ChecklistTemplateItem old : items.findByChecklistTemplateIdOrderBySortOrderAsc(id)) items.delete(old);
        items.flush();
        saveItems(id, r.items());
        audit.log("CHECKLIST_TEMPLATE_UPDATE", "ChecklistTemplate", id, before, view(t));
        return view(t);
    }

    /** Kích hoạt một version: các version khác cùng mã bị ngưng (chỉ một version hoạt động). */
    @Transactional
    public TemplateView activateTemplate(Integer id) {
        ChecklistTemplate t = templates.findById(id).orElseThrow(() -> BusinessException.notFound("mẫu checklist"));
        TemplateView before = view(t);
        for (ChecklistTemplate other : templates.findByStoreIdAndChecklistCode(t.getStoreId(), t.getChecklistCode())) {
            if (!other.getChecklistTemplateId().equals(id)) other.setIsActive(false);
        }
        t.setIsActive(true);
        audit.log("CHECKLIST_TEMPLATE_ACTIVATE", "ChecklistTemplate", id, before, view(t));
        return view(t);
    }

    private void applyHeader(ChecklistTemplate t, TemplateRequest r) {
        t.setChecklistCode(r.checklistCode().trim());
        t.setChecklistName(r.checklistName().trim());
        t.setChecklistType(r.checklistType());
        if (r.managerApprovalRequired() != null) t.setIsManagerApprovalRequired(r.managerApprovalRequired());
        if (r.isActive() != null) t.setIsActive(r.isActive());
    }

    private void saveItems(Integer templateId, List<ItemRequest> reqs) {
        int order = 1;
        for (ItemRequest ir : reqs) {
            ChecklistTemplateItem i = new ChecklistTemplateItem();
            i.setChecklistTemplateId(templateId);
            i.setItemName(ir.itemName().trim());
            i.setInstructions(ir.instructions());
            if (ir.isRequired() != null) i.setIsMandatory(ir.isRequired());
            if (ir.requiresEvidence() != null) i.setRequiresEvidence(ir.requiresEvidence());
            if (ir.requiresManagerApproval() != null) i.setRequiresManagerApproval(ir.requiresManagerApproval());
            i.setSortOrder(ir.sortOrder() != null ? ir.sortOrder() : order);
            items.save(i);
            order++;
        }
    }

    // ================= Sinh & giao việc =================
    @Transactional
    public RunView generate(GenerateRequest r) {
        ChecklistTemplate t = templates.findById(r.templateId()).filter(x -> Boolean.TRUE.equals(x.getIsActive()))
                .orElseThrow(() -> new BusinessException(ErrorCode.VALIDATION_ERROR, "Mẫu checklist không tồn tại hoặc đã ngưng"));
        Long scheduleId = r.scheduleId(), employeeId = r.employeeId();
        ShiftAssignment sc = null;
        if (scheduleId != null) {
            sc = schedules.findById(scheduleId).orElseThrow(() -> BusinessException.notFound("phân ca"));
            if (!"PUBLISHED".equals(sc.getScheduleStatus())) throw BusinessException.rule("Ca đã hủy hoặc đã kết thúc nghiệp vụ");
            if (employeeId != null && !employeeId.equals(sc.getEmployeeId()))
                throw BusinessException.rule("Nhân viên được giao phải trùng với nhân viên của ca đã chọn");
            if (r.workDate() != null && !r.workDate().equals(sc.getWorkDate()))
                throw BusinessException.rule("Ngày thực hiện phải trùng với ngày của ca đã chọn");
            if (employeeId == null) employeeId = sc.getEmployeeId();
        }
        if (employeeId == null) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Cần scheduleId hoặc employeeId");
        Employee e = employees.findById(employeeId).orElseThrow(() -> BusinessException.notFound("nhân viên"));
        if (!"ACTIVE".equals(e.getEmploymentStatus())) throw BusinessException.rule("Nhân viên không ở trạng thái đang làm việc");
        if (scheduleId != null && runs.existsByChecklistTemplateIdAndShiftAssignmentId(t.getChecklistTemplateId(), scheduleId))
            throw new BusinessException(ErrorCode.CONFLICT, "Ca này đã có checklist cùng mẫu");
        Instant due;
        if (sc != null) due = "OPENING".equals(t.getChecklistType()) ? sc.getPlannedStartAt().plusSeconds(30 * 60) : sc.getPlannedEndAt();
        else {
            LocalDate d = r.workDate() != null ? r.workDate() : TimeUtils.today(clock);
            due = TimeUtils.startOfDay(d.plusDays(1)).minusSeconds(60);
        }
        LocalDate workDay = sc != null ? sc.getWorkDate() : (r.workDate() != null ? r.workDate() : TimeUtils.today(clock));
        Integer workShiftId = sc != null ? sc.getWorkShiftId() : null;
        ChecklistInstance inst = instances.findByChecklistTemplateIdAndWorkDate(t.getChecklistTemplateId(), workDay).stream()
                .filter(i -> Objects.equals(i.getWorkShiftId(), workShiftId)).findFirst().orElseGet(() -> {
                    ChecklistInstance n = new ChecklistInstance();
                    n.setChecklistTemplateId(t.getChecklistTemplateId());
                    n.setWorkDate(workDay);
                    n.setWorkShiftId(workShiftId);
                    return instances.save(n);
                });
        ChecklistTask run = new ChecklistTask();
        run.setChecklistTemplateId(t.getChecklistTemplateId());
        run.setShiftAssignmentId(scheduleId);
        run.setChecklistInstanceId(inst.getChecklistInstanceId());
        run.setEmployeeId(employeeId);
        run.setDueAt(due);
        // ManagerStatus chỉ chuyển sang PENDING khi nộp (submit); lúc tạo giữ NOT_REQUIRED để không lọt vào hàng chờ duyệt.
        run.setManagerStatus("NOT_REQUIRED");
        runs.save(run);
        for (ChecklistTemplateItem it : items.findByChecklistTemplateIdOrderBySortOrderAsc(t.getChecklistTemplateId())) {
            ChecklistTaskItem ri = new ChecklistTaskItem();
            ri.setChecklistTaskId(run.getChecklistTaskId());
            ri.setChecklistTemplateItemId(it.getChecklistTemplateItemId());
            runItems.save(ri);
        }
        audit.log("CHECKLIST_RUN_CREATE", "ChecklistTask", run.getChecklistTaskId(), null,
                Map.of("templateId", t.getChecklistTemplateId(), "employeeId", employeeId));
        notifications.notify(e.getUserId(), "CHECKLIST_ASSIGNED", "Bạn có checklist mới", t.getChecklistName(),
                "ChecklistTask", run.getChecklistTaskId(), null);
        return runView(run, true);
    }

    @Transactional
    public RunView reassign(Long taskId, Long newEmployeeId) {
        ChecklistTask run = findRun(taskId);
        if (!OPEN_STATES.contains(run.getRunStatus())) throw BusinessException.invalidState("Chỉ giao lại checklist chưa nộp");
        Employee e = employees.findById(newEmployeeId).orElseThrow(() -> BusinessException.notFound("nhân viên"));
        if (!"ACTIVE".equals(e.getEmploymentStatus())) throw BusinessException.rule("Nhân viên không ở trạng thái đang làm việc");
        Long old = run.getEmployeeId();
        run.setEmployeeId(newEmployeeId);
        audit.log("CHECKLIST_REASSIGN", "ChecklistTask", taskId, Map.of("employeeId", old), Map.of("employeeId", newEmployeeId));
        notifications.notify(e.getUserId(), "CHECKLIST_ASSIGNED", "Bạn được giao checklist", "Checklist #" + taskId,
                "ChecklistTask", taskId, null);
        return runView(run, true);
    }

    // ================= Thực hiện =================
    @Transactional(readOnly = true)
    public List<RunView> myTasks(String status) {
        Long empId = SecurityUtils.requireEmployeeId();
        List<ChecklistTask> list = status == null
                ? runs.findMine(empId, OPEN_STATES)
                : status.isBlank()
                    ? runs.findByEmployeeIdOrderByDueAtDescChecklistTaskIdDesc(empId)
                    : runs.findByEmployeeIdAndRunStatusOrderByDueAtDescChecklistTaskIdDesc(empId, status);
        return list.stream().map(r -> runView(r, false)).toList();
    }

    @Transactional(readOnly = true)
    public RunView get(Long taskId) {
        ChecklistTask run = findRun(taskId);
        assertCanSee(run);
        return runView(run, true);
    }

    @Transactional(readOnly = true)
    public PageResponse<RunView> list(String status, Pageable p) {
        Sort sort = p.getSort().isSorted() ? p.getSort() : Sort.by(Sort.Direction.DESC, "dueAt");
        Sort.Order dueOrder = sort.getOrderFor("dueAt");
        Sort.Direction direction = dueOrder == null ? Sort.Direction.DESC : dueOrder.getDirection();
        if (sort.getOrderFor("checklistTaskId") == null)
            sort = sort.and(Sort.by(direction, "checklistTaskId"));
        Pageable ordered = PageRequest.of(p.getPageNumber(), p.getPageSize(), sort);
        return PageResponse.of(runs.searchByStatus(status == null ? "" : status, ordered), r -> runView(r, false));
    }

    @Transactional
    public RunView start(Long taskId) {
        ChecklistTask run = ownRun(taskId);
        if (!List.of("PENDING", "REJECTED", "OVERDUE").contains(run.getRunStatus()))
            throw BusinessException.invalidState("Không thể bắt đầu checklist ở trạng thái " + run.getRunStatus());
        run.setRunStatus("IN_PROGRESS");
        if (run.getStartedAt() == null) run.setStartedAt(clock.instant());
        run.setManagerStatus("NOT_REQUIRED");
        return runView(run, true);
    }

    @Transactional
    public RunView completeItem(Long taskId, Long runItemId, CompleteItemRequest r) {
        ChecklistTask run = ownRun(taskId);
        if (!"IN_PROGRESS".equals(run.getRunStatus()) && !"OVERDUE".equals(run.getRunStatus()))
            throw BusinessException.invalidState("Hãy bắt đầu checklist trước khi hoàn thành mục");
        ChecklistTaskItem ri = runItems.findById(runItemId).filter(x -> x.getChecklistTaskId().equals(taskId))
                .orElseThrow(() -> BusinessException.notFound("mục checklist"));
        ChecklistTemplateItem it = items.findById(ri.getChecklistTemplateItemId()).orElseThrow();
        String key = r == null ? null : r.evidenceStorageKey();
        if (key != null && !key.isBlank()) {
            if (!key.startsWith("checklist-evidence/") || key.contains(".."))
                throw new BusinessException(ErrorCode.VALIDATION_ERROR, "evidenceStorageKey phải nằm trong checklist-evidence/");
            saveEvidence(run, ri, key);
        }
        if (Boolean.TRUE.equals(it.getRequiresEvidence()) && currentEvidence(run).stream()
                .noneMatch(e -> e.getChecklistTaskItemId().equals(ri.getChecklistTaskItemId())))
            throw new BusinessException(ErrorCode.CHECKLIST_EVIDENCE_REQUIRED, "Mục này bắt buộc có minh chứng",
                    BusinessException.details("runItemId", runItemId));
        ri.setIsCompleted(true);
        ri.setCompletedAt(clock.instant());
        ri.setCompletedBy(SecurityUtils.current().userId());
        if (r != null && r.note() != null) ri.setNote(r.note());
        return runView(run, true);
    }

    /** Thêm minh chứng cho một mục mà chưa đánh dấu hoàn thành (SRS: POST /checklists/tasks/{taskId}/evidence). */
    @Transactional
    public RunView addEvidence(Long taskId, AddEvidenceRequest r) {
        ChecklistTask run = ownRun(taskId);
        if (!"IN_PROGRESS".equals(run.getRunStatus()) && !"OVERDUE".equals(run.getRunStatus()))
            throw BusinessException.invalidState("Hãy bắt đầu checklist trước khi thêm minh chứng");
        ChecklistTaskItem ri = runItems.findById(r.runItemId()).filter(x -> x.getChecklistTaskId().equals(taskId))
                .orElseThrow(() -> BusinessException.notFound("mục checklist"));
        String key = r.evidenceStorageKey().trim();
        saveEvidence(run, ri, key);
        return runView(run, true);
    }

    @Transactional
    public RunView submit(Long taskId) {
        ChecklistTask run = ownRun(taskId);
        if (!"IN_PROGRESS".equals(run.getRunStatus()) && !"OVERDUE".equals(run.getRunStatus()))
            throw BusinessException.invalidState("Checklist không ở trạng thái đang thực hiện");
        ChecklistTemplate t = templates.findById(run.getChecklistTemplateId()).orElseThrow();
        Map<Integer, ChecklistTemplateItem> tmpl = new HashMap<>();
        items.findByChecklistTemplateIdOrderBySortOrderAsc(t.getChecklistTemplateId()).forEach(i -> tmpl.put(i.getChecklistTemplateItemId(), i));
        Set<Long> withEvidence = new HashSet<>();
        currentEvidence(run).forEach(e -> withEvidence.add(e.getChecklistTaskItemId()));
        List<Long> missing = new ArrayList<>(), noEvidence = new ArrayList<>();
        for (ChecklistTaskItem ri : runItems.findByChecklistTaskIdOrderByChecklistTaskItemIdAsc(taskId)) {
            ChecklistTemplateItem it = tmpl.get(ri.getChecklistTemplateItemId());
            if (it == null) continue;
            if (Boolean.TRUE.equals(it.getIsMandatory()) && !Boolean.TRUE.equals(ri.getIsCompleted())) missing.add(ri.getChecklistTaskItemId());
            if (Boolean.TRUE.equals(it.getRequiresEvidence()) && Boolean.TRUE.equals(ri.getIsCompleted()) && !withEvidence.contains(ri.getChecklistTaskItemId()))
                noEvidence.add(ri.getChecklistTaskItemId());
        }
        if (!noEvidence.isEmpty())
            throw new BusinessException(ErrorCode.CHECKLIST_EVIDENCE_REQUIRED, "Còn mục thiếu minh chứng",
                    BusinessException.details("runItemIds", noEvidence));
        if (!missing.isEmpty())
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Còn mục bắt buộc chưa hoàn thành",
                    BusinessException.details("runItemIds", missing));
        run.setSubmittedAt(clock.instant());
        if (requiresManagerApproval(t)) {
            run.setRunStatus("SUBMITTED");
            run.setManagerStatus("PENDING");
            notifications.notifyRole(Roles.STORE_MANAGER, "CHECKLIST_PENDING_REVIEW", "Checklist chờ duyệt",
                    t.getChecklistName() + " - " + people.nameOf(run.getEmployeeId()), "ChecklistTask", taskId);
        } else {
            run.setRunStatus("APPROVED");
            run.setManagerStatus("NOT_REQUIRED");
        }
        audit.log("CHECKLIST_SUBMIT", "ChecklistTask", taskId, null, Map.of("status", run.getRunStatus()));
        return runView(run, true);
    }

    // ================= Duyệt =================
    @Transactional
    public RunView approve(Long taskId, String note) {
        ChecklistTask run = reviewable(taskId);
        run.setRunStatus("APPROVED");
        run.setManagerStatus("APPROVED");
        finish(run, "APPROVED", note);
        audit.log("CHECKLIST_APPROVE", "ChecklistTask", taskId, Map.of("status", "SUBMITTED"), Map.of("status", "APPROVED"));
        notifications.notify(people.userIdOf(run.getEmployeeId()), "CHECKLIST_REVIEWED", "Checklist đã được duyệt",
                "Checklist #" + taskId, "ChecklistTask", taskId, null);
        return runView(run, true);
    }

    @Transactional
    public RunView reject(Long taskId, String reason) {
        if (reason == null || reason.isBlank()) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Phải nhập lý do từ chối");
        ChecklistTask run = reviewable(taskId);
        run.setRunStatus("REJECTED");
        run.setManagerStatus("REJECTED");
        for (ChecklistTaskItem item : runItems.findByChecklistTaskIdOrderByChecklistTaskItemIdAsc(taskId)) {
            item.setIsCompleted(false);
            item.setCompletedAt(null);
            item.setCompletedBy(null);
        }
        finish(run, "REJECTED", reason.trim());
        audit.log("CHECKLIST_REJECT", "ChecklistTask", taskId, Map.of("status", "SUBMITTED"), Map.of("status", "REJECTED", "reason", reason));
        notifications.notify(people.userIdOf(run.getEmployeeId()), "CHECKLIST_REVIEWED", "Checklist bị từ chối - cần làm lại",
                reason, "ChecklistTask", taskId, null);
        return runView(run, true);
    }

    private ChecklistTask reviewable(Long taskId) {
        SecurityUtils.requireAny(Roles.STORE_MANAGER);
        ChecklistTask run = findRun(taskId);
        if (!"SUBMITTED".equals(run.getRunStatus()) || !"PENDING".equals(run.getManagerStatus()))
            throw new BusinessException(ErrorCode.CHECKLIST_REQUIRES_REVIEW, "Checklist không ở trạng thái chờ duyệt");
        if (people.userIdOf(run.getEmployeeId()).equals(SecurityUtils.current().userId()))
            throw BusinessException.forbidden("Không thể tự duyệt checklist của chính mình");
        return run;
    }

    /** Ghi lịch sử duyệt (SRS 7.4 ChecklistReview): mỗi lần duyệt/từ chối một dòng. */
    private void finish(ChecklistTask run, String decision, String note) {
        ChecklistReview rv = new ChecklistReview();
        rv.setChecklistTaskId(run.getChecklistTaskId());
        rv.setReviewerId(SecurityUtils.current().userId());
        rv.setDecision(decision);
        rv.setReason(note);
        rv.setReviewedAt(clock.instant());
        reviews.save(rv);
    }

    /** Minh chứng: mỗi ảnh/tệp một dòng ChecklistEvidence (SRS 7.4). */
    private void saveEvidence(ChecklistTask run, ChecklistTaskItem ri, String key) {
        EvidenceKeys.requireOwnedChecklistEvidence(key, SecurityUtils.requireEmployeeId());
        if (!storage.exists(key))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Minh chứng chưa được tải lên hoặc đã bị xóa");
        Instant rejectedAt = reviews.findFirstByChecklistTaskIdOrderByReviewedAtDesc(run.getChecklistTaskId())
                .filter(r -> "REJECTED".equals(r.getDecision())).map(ChecklistReview::getReviewedAt).orElse(null);
        if (rejectedAt != null && evidences.findByChecklistTaskId(run.getChecklistTaskId()).stream()
                .anyMatch(e -> key.equals(e.getStorageKey()) && !e.getUploadedAt().isAfter(rejectedAt)))
            throw new BusinessException(ErrorCode.CHECKLIST_EVIDENCE_REQUIRED, "Cần tải ảnh mới sau khi quản lý yêu cầu làm lại");
        ChecklistEvidence ev = new ChecklistEvidence();
        ev.setChecklistTaskId(run.getChecklistTaskId());
        ev.setChecklistTaskItemId(ri.getChecklistTaskItemId());
        ev.setStorageKey(key);
        ev.setUploadedBy(SecurityUtils.current().userId());
        ev.setUploadedAt(clock.instant());
        evidences.save(ev);
    }

    private List<ChecklistEvidence> currentEvidence(ChecklistTask run) {
        Instant rejectedAt = reviews.findFirstByChecklistTaskIdOrderByReviewedAtDesc(run.getChecklistTaskId())
                .filter(r -> "REJECTED".equals(r.getDecision())).map(ChecklistReview::getReviewedAt).orElse(null);
        return evidences.findByChecklistTaskId(run.getChecklistTaskId()).stream()
                .filter(e -> rejectedAt == null || e.getUploadedAt().isAfter(rejectedAt)).toList();
    }

    private String latestReviewReason(ChecklistTask run) {
        return reviews.findFirstByChecklistTaskIdOrderByReviewedAtDesc(run.getChecklistTaskId())
                .map(ChecklistReview::getReason).orElse(null);
    }

    @Transactional(readOnly = true)
    public List<Map<String, Object>> evidence(Long taskId) {
        ChecklistTask task = findRun(taskId);
        assertCanSee(task);
        AuthUser user = SecurityUtils.current();
        if (!Objects.equals(task.getEmployeeId(), user.employeeId()) && !user.hasAnyPermission(Permissions.CHECKLIST_REVIEW, Permissions.EVIDENCE_VIEW))
            throw BusinessException.forbidden("Bạn không có quyền xem minh chứng checklist");
        return evidences.findByChecklistTaskId(taskId).stream().map(e -> Map.<String, Object>of(
            "runItemId", e.getChecklistTaskItemId(), "evidenceViewUrl", storage.createViewUrl(e.getStorageKey(), java.time.Duration.ofMinutes(5), user.userId()))).toList();
    }

    // ================= helpers =================
    private ChecklistTask findRun(Long id) { return runs.findById(id).orElseThrow(() -> BusinessException.notFound("checklist")); }

    private ChecklistTask ownRun(Long id) {
        ChecklistTask run = findRun(id);
        if (!run.getEmployeeId().equals(SecurityUtils.requireEmployeeId()))
            throw BusinessException.forbidden("Checklist này không được giao cho bạn");
        return run;
    }

    private void assertCanSee(ChecklistTask run) {
        AuthUser u = SecurityUtils.current();
        if (!run.getEmployeeId().equals(u.employeeId()) && !u.isStaffReviewer()) throw BusinessException.forbidden("Bạn không có quyền xem checklist này");
    }

    RunView runView(ChecklistTask run, boolean withItems) {
        ChecklistTemplate t = templates.findById(run.getChecklistTemplateId()).orElseThrow();
        List<RunItemView> iv = List.of();
        if (withItems) {
            Map<Integer, ChecklistTemplateItem> tm = new HashMap<>();
            items.findByChecklistTemplateIdOrderBySortOrderAsc(t.getChecklistTemplateId()).forEach(i -> tm.put(i.getChecklistTemplateItemId(), i));
            Set<Long> hasEvidence = new HashSet<>();
            currentEvidence(run).forEach(e -> hasEvidence.add(e.getChecklistTaskItemId()));
            iv = runItems.findByChecklistTaskIdOrderByChecklistTaskItemIdAsc(run.getChecklistTaskId()).stream().map(ri -> {
                ChecklistTemplateItem it = tm.get(ri.getChecklistTemplateItemId());
                return new RunItemView(ri.getChecklistTaskItemId(), ri.getChecklistTemplateItemId(), it == null ? null : it.getItemName(),
                        it == null ? null : it.getInstructions(), it == null ? null : it.getIsMandatory(),
                        it == null ? null : it.getRequiresEvidence(), ri.getIsCompleted(), TimeUtils.vn(ri.getCompletedAt()),
                        hasEvidence.contains(ri.getChecklistTaskItemId()), ri.getNote());
            }).toList();
        }
        return new RunView(run.getChecklistTaskId(), t.getChecklistTemplateId(), t.getChecklistName(), t.getChecklistType(), run.getShiftAssignmentId(),
                run.getEmployeeId(), people.nameOf(run.getEmployeeId()), TimeUtils.vn(run.getDueAt()), TimeUtils.vn(run.getStartedAt()),
                TimeUtils.vn(run.getSubmittedAt()), run.getRunStatus(), run.getManagerStatus(), latestReviewReason(run), iv);
    }

    /** Cần Manager duyệt nếu mẫu bật cờ, hoặc có mục nào của mẫu đặt RequiresManagerApproval (SRS 7.4). */
    private boolean requiresManagerApproval(ChecklistTemplate t) {
        return Boolean.TRUE.equals(t.getIsManagerApprovalRequired())
                || items.findByChecklistTemplateIdOrderBySortOrderAsc(t.getChecklistTemplateId()).stream()
                        .anyMatch(i -> Boolean.TRUE.equals(i.getRequiresManagerApproval()));
    }
}
