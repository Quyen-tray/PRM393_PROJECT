package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.StoreDto.ReminderRuleRequest;
import com.hrm.coffeeshop.shared.dto.StoreDto.ReminderRuleView;
import com.hrm.coffeeshop.shared.dto.StoreDto.SettingsRequest;
import com.hrm.coffeeshop.shared.dto.StoreDto.SettingsView;
import com.hrm.coffeeshop.shared.dto.StoreDto.StoreView;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.domain.ReminderRule;
import com.hrm.coffeeshop.domain.Store;
import com.hrm.coffeeshop.repository.ReminderRuleRepository;
import com.hrm.coffeeshop.repository.StoreRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;

/**
 * Cửa hàng duy nhất (SRS 1.2, 7.4 Store). Cấu hình chấm công nằm ở các cột của Store;
 * nhắc việc nằm ở ReminderRule (SRS 7.4). Chỉ khóa GPS (không có trong SRS) còn trong AppSetting.
 */
@Service
public class StoreService {

    private final StoreRepository stores;
    private final ReminderRuleRepository reminders;
    private final AuditService audit;

    public StoreService(StoreRepository stores, ReminderRuleRepository reminders, AuditService audit) {
        this.stores = stores;
        this.reminders = reminders;
        this.audit = audit;
    }

    @Transactional(readOnly = true)
    /**
     * Khóa dòng cửa hàng hiện tại. Gọi trong transaction của người dùng; khóa giữ đến khi commit.
     * Hai lần tạo kỳ công đồng thời xếp hàng tại đây, nên lần sau đọc được kỳ vừa commit khi kiểm tra trùng.
     */
    public Store lockCurrentForUpdate() {
        Integer id = current().getStoreId();
        return stores.findByIdForUpdate(id).orElseThrow(() -> BusinessException.notFound("cửa hàng đang hoạt động"));
    }

    public Store current() {
        return stores.findFirstByIsActiveTrueOrderByStoreIdAsc()
                .orElseThrow(() -> BusinessException.notFound("cửa hàng đang hoạt động"));
    }

    public StoreView view(Store s) {
        return new StoreView(s.getStoreId(), s.getStoreCode(), s.getName(), s.getAddressLine(),
                s.getLatitude(), s.getLongitude(), s.getAttendanceRadiusMeters(),
                Boolean.TRUE.equals(s.getIsActive()) ? "ACTIVE" : "INACTIVE");
    }

    private ReminderRule rule(String code) {
        return reminders.findByRuleCode(code).orElseThrow(() -> BusinessException.notFound("rule nhắc nhở " + code));
    }

    private int ruleInt(String code, Function<ReminderRule, Integer> field, int fallback) {
        Integer v = reminders.findByRuleCode(code).map(field).orElse(null);
        return v != null ? v : fallback;
    }

    @Transactional(readOnly = true)
    public SettingsView settingsView() {
        Store s = current();
        return new SettingsView(view(s), s.getAttendanceRadiusMeters(),
                s.getCheckInEarlyMinutes(), s.getGraceMinutes(), s.getMonthlyGraceLimit(), s.getPhotoRetentionMonths(),
                ruleInt("CHECKLIST_OVERDUE", ReminderRule::getIntervalMinutes, 5),
                ruleInt("CHECKLIST_OVERDUE", ReminderRule::getMaxAttempts, 3),
                ruleInt("SHIFT_REMINDER", ReminderRule::getLeadMinutes, 15),
                ruleInt("CHECKLIST_DUE_SOON", ReminderRule::getLeadMinutes, 15),
                s.getGpsMaxAccuracyMeters());
    }

    /** Thay đổi cấu hình chỉ áp dụng cho ca TẠO MỚI (ca đã tạo giữ giá trị của mẫu ca). */
    @Transactional
    public SettingsView update(SettingsRequest r) {
        Store s = current();
        Map<String, Object> before = new LinkedHashMap<>(snapshot());
        range(r.attendanceRadiusMeters(), 15, 50, "Bán kính GPS phải trong 15–50 m");
        range(r.checkInEarlyMinutes(), 15, 30, "Check-in sớm phải trong 15–30 phút");
        range(r.graceMinutes(), 3, 5, "Ân hạn phải trong 3–5 phút");
        range(r.monthlyGraceLimit(), 3, 5, "Hạn mức ân hạn phải trong 3–5 lần/tháng");
        range(r.photoRetentionMonths(), 6, 12, "Thời hạn lưu ảnh phải trong 6–12 tháng (xem D-04)");
        range(r.lateReminderIntervalMinutes(), 1, 60, "Chu kỳ nhắc quá hạn phải trong 1–60 phút");
        range(r.maxLateReminders(), 1, 10, "Số lần nhắc tối đa phải trong 1–10");
        range(r.shiftReminderMinutes(), 5, 120, "Nhắc trước ca phải trong 5–120 phút");
        range(r.checklistDueSoonMinutes(), 5, 120, "Nhắc checklist trước hạn phải trong 5–120 phút");
        range(r.gpsMaxAccuracyMeters(), 5, 200, "Sai số GPS tối đa phải trong 5–200 m");

        if (r.name() != null && !r.name().isBlank()) s.setName(r.name().trim());
        if (r.address() != null && !r.address().isBlank()) s.setAddressLine(r.address().trim());
        if (r.latitude() != null) {
            if (r.latitude().abs().doubleValue() > 90) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Vĩ độ không hợp lệ");
            s.setLatitude(r.latitude());
        }
        if (r.longitude() != null) {
            if (r.longitude().abs().doubleValue() > 180) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Kinh độ không hợp lệ");
            s.setLongitude(r.longitude());
        }
        if (r.attendanceRadiusMeters() != null) s.setAttendanceRadiusMeters(r.attendanceRadiusMeters());
        if (r.checkInEarlyMinutes() != null) s.setCheckInEarlyMinutes(r.checkInEarlyMinutes());
        if (r.graceMinutes() != null) s.setGraceMinutes(r.graceMinutes());
        if (r.monthlyGraceLimit() != null) s.setMonthlyGraceLimit(r.monthlyGraceLimit());
        if (r.photoRetentionMonths() != null) s.setPhotoRetentionMonths(r.photoRetentionMonths());
        if (r.lateReminderIntervalMinutes() != null) {
            ReminderRule x = rule("CHECKLIST_OVERDUE");
            x.setIntervalMinutes(r.lateReminderIntervalMinutes());
        }
        if (r.maxLateReminders() != null) rule("CHECKLIST_OVERDUE").setMaxAttempts(r.maxLateReminders());
        if (r.shiftReminderMinutes() != null) rule("SHIFT_REMINDER").setLeadMinutes(r.shiftReminderMinutes());
        if (r.checklistDueSoonMinutes() != null) rule("CHECKLIST_DUE_SOON").setLeadMinutes(r.checklistDueSoonMinutes());
        if (r.gpsMaxAccuracyMeters() != null) s.setGpsMaxAccuracyMeters(r.gpsMaxAccuracyMeters());
        stores.save(s);
        SettingsView after = settingsView();
        audit.log("STORE_SETTINGS_UPDATE", "Store", s.getStoreId(), before, after);
        return after;
    }

    private Map<String, Object> snapshot() {
        SettingsView v = settingsView();
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("radius", v.attendanceRadiusMeters());
        m.put("early", v.checkInEarlyMinutes());
        m.put("grace", v.graceMinutes());
        m.put("graceMax", v.monthlyGraceLimit());
        m.put("retention", v.photoRetentionMonths());
        m.put("lateInterval", v.lateReminderIntervalMinutes());
        m.put("lateMax", v.maxLateReminders());
        m.put("shiftReminder", v.shiftReminderMinutes());
        m.put("gpsAccuracy", v.gpsMaxAccuracyMeters());
        return m;
    }

    private static void range(Integer v, int min, int max, String msg) {
        if (v != null && (v < min || v > max)) throw new BusinessException(ErrorCode.VALIDATION_ERROR, msg);
    }

    // ---------- Nhắc việc (ReminderRule) ----------
    @Transactional(readOnly = true)
    public List<ReminderRuleView> reminderRules() {
        return List.of(
                new ReminderRuleView("SHIFT_REMINDER", "Nhắc nhân viên trước giờ vào ca",
                        ruleInt("SHIFT_REMINDER", ReminderRule::getLeadMinutes, 15), null, null, rule("SHIFT_REMINDER").getIsActive()),
                new ReminderRuleView("CHECKLIST_DUE_SOON", "Nhắc checklist sắp đến hạn",
                        ruleInt("CHECKLIST_DUE_SOON", ReminderRule::getLeadMinutes, 15), null, null, rule("CHECKLIST_DUE_SOON").getIsActive()),
                new ReminderRuleView("CHECKLIST_OVERDUE", "Nhắc checklist quá hạn", null,
                        ruleInt("CHECKLIST_OVERDUE", ReminderRule::getIntervalMinutes, 5),
                        ruleInt("CHECKLIST_OVERDUE", ReminderRule::getMaxAttempts, 3), rule("CHECKLIST_OVERDUE").getIsActive()));
    }

    @Transactional
    public ReminderRuleView updateReminderRule(String ruleId, ReminderRuleRequest r) {
        ReminderRule x = rule(ruleId);
        ReminderRuleView before = reminderRules().stream().filter(v -> v.ruleId().equals(ruleId)).findFirst().orElseThrow();
        switch (ruleId) {
            case "SHIFT_REMINDER", "CHECKLIST_DUE_SOON" -> {
                need(r.leadMinutes(), 5, 120, "leadMinutes phải trong 5–120");
                x.setLeadMinutes(r.leadMinutes());
            }
            case "CHECKLIST_OVERDUE" -> {
                need(r.intervalMinutes(), 1, 60, "intervalMinutes phải trong 1–60");
                need(r.maxAttempts(), 1, 10, "maxAttempts phải trong 1–10");
                x.setIntervalMinutes(r.intervalMinutes());
                x.setMaxAttempts(r.maxAttempts());
            }
            default -> throw BusinessException.notFound("rule nhắc nhở");
        }
        if(r.isActive()!=null) x.setIsActive(r.isActive());
        ReminderRuleView after = reminderRules().stream().filter(v -> v.ruleId().equals(ruleId)).findFirst().orElseThrow();
        audit.log("REMINDER_RULE_UPDATE", "ReminderRule", ruleId, before, after);
        return after;
    }

    private static void need(Integer v, int min, int max, String msg) {
        if (v == null || v < min || v > max) throw new BusinessException(ErrorCode.VALIDATION_ERROR, msg);
    }
}
