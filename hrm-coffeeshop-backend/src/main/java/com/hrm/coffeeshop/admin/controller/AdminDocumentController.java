package com.hrm.coffeeshop.admin.controller;

import com.hrm.coffeeshop.shared.dto.DocumentDto.TypeRequest;
import com.hrm.coffeeshop.shared.dto.DocumentDto.TypeView;
import com.hrm.coffeeshop.shared.service.DocumentService;

import com.hrm.coffeeshop.common.*;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
public class AdminDocumentController {
    private final DocumentService svc;

    public AdminDocumentController(DocumentService svc) {
        this.svc = svc;
    }

    @GetMapping("/admin/document-types")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<List<TypeView>> types() { return ApiResponse.ok(svc.listTypes()); }

    @PostMapping("/admin/document-types")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<TypeView> createType(@Valid @RequestBody TypeRequest r) {
        return ApiResponse.ok("Document type created", svc.createType(r));
    }

    /** Cập nhật thông tin loại hồ sơ. Bộ hồ sơ bắt buộc theo chức vụ: PUT /admin/job-positions/{id}/document-requirements. */
    @PutMapping("/admin/document-types/{typeId}")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<TypeView> updateType(@PathVariable Integer typeId, @Valid @RequestBody TypeRequest r) {
        return ApiResponse.ok("Document type updated", svc.updateType(typeId, r));
    }
}
