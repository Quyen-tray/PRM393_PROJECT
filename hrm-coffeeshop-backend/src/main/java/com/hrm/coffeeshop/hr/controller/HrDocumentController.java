package com.hrm.coffeeshop.hr.controller;

import com.hrm.coffeeshop.shared.dto.DocumentDto.DocumentView;
import com.hrm.coffeeshop.shared.dto.DocumentDto.SubmitRequest;
import com.hrm.coffeeshop.shared.dto.MiscDto.ReasonRequest;
import com.hrm.coffeeshop.shared.service.DocumentService;

import com.hrm.coffeeshop.common.*;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
public class HrDocumentController {
    private final DocumentService svc;

    public HrDocumentController(DocumentService svc) {
        this.svc = svc;
    }

    @PostMapping("/employees/{employeeId}/documents")
    @PreAuthorize("hasAuthority('DOCUMENT_REVIEW')")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<DocumentView> submitFor(@PathVariable Long employeeId, @Valid @RequestBody SubmitRequest r) {
        return ApiResponse.ok("Document submitted", svc.submit(employeeId, r));
    }

    /** Hàng đợi hồ sơ chờ duyệt (Quản lý/HR). Đặt trước /documents/{documentId}. */
    @GetMapping("/documents/pending")
    @PreAuthorize("hasAuthority('DOCUMENT_REVIEW')")
    public ApiResponse<List<DocumentView>> pending() { return ApiResponse.ok(svc.listPending()); }

    @PostMapping("/documents/{documentId}/approve")
    @PreAuthorize("hasAuthority('DOCUMENT_REVIEW')")
    public ApiResponse<DocumentView> approve(@PathVariable Long documentId) {
        return ApiResponse.ok("Document approved", svc.approve(documentId));
    }

    @PostMapping("/documents/{documentId}/reject")
    @PreAuthorize("hasAuthority('DOCUMENT_REVIEW')")
    public ApiResponse<DocumentView> reject(@PathVariable Long documentId, @Valid @RequestBody ReasonRequest r) {
        return ApiResponse.ok("Document rejected", svc.reject(documentId, r.reason()));
    }
}
