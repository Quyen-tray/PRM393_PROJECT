package com.hrm.coffeeshop.admin.controller;

import com.hrm.coffeeshop.shared.dto.StoreDto.ReminderRuleRequest;
import com.hrm.coffeeshop.shared.dto.StoreDto.ReminderRuleView;
import com.hrm.coffeeshop.shared.dto.StoreDto.SettingsRequest;
import com.hrm.coffeeshop.shared.dto.StoreDto.SettingsView;
import com.hrm.coffeeshop.shared.service.StoreService;

import com.hrm.coffeeshop.common.ApiResponse;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
public class AdminStoreController {
    private final StoreService store;

    public AdminStoreController(StoreService store) {
        this.store = store;
    }

    @GetMapping("/admin/store-settings")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<SettingsView> settings() { return ApiResponse.ok(store.settingsView()); }

    @PatchMapping("/admin/store-settings")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<SettingsView> update(@RequestBody SettingsRequest r) {
        return ApiResponse.ok("Settings updated", store.update(r));
    }

    @GetMapping("/admin/attendance-policies")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<SettingsView> policies() { return ApiResponse.ok(store.settingsView()); }

    @PutMapping("/admin/attendance-policies")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<SettingsView> putPolicies(@RequestBody SettingsRequest r) {
        return ApiResponse.ok("Policies updated", store.update(r));
    }

    @GetMapping("/admin/reminder-rules")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<List<ReminderRuleView>> rules() { return ApiResponse.ok(store.reminderRules()); }

    @PutMapping("/admin/reminder-rules/{ruleId}")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<ReminderRuleView> updateRule(@PathVariable String ruleId, @RequestBody ReminderRuleRequest r) {
        return ApiResponse.ok("Rule updated", store.updateReminderRule(ruleId, r));
    }
}
