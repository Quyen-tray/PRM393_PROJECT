package com.hrm.coffeeshop.shared.controller;

import com.hrm.coffeeshop.shared.dto.DocumentDto.DocumentView;
import com.hrm.coffeeshop.shared.service.DocumentService;

import com.hrm.coffeeshop.common.*;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
public class SharedDocumentController {
    private final DocumentService svc;

    public SharedDocumentController(DocumentService svc) {
        this.svc = svc;
    }

    @GetMapping("/employees/{employeeId}/documents")
    public ApiResponse<List<DocumentView>> list(@PathVariable Long employeeId) { return ApiResponse.ok(svc.list(employeeId)); }

    @GetMapping("/documents/{documentId}")
    public ApiResponse<DocumentView> get(@PathVariable Long documentId) { return ApiResponse.ok(svc.get(documentId)); }
}
