package com.hrm.coffeeshop.employee.controller;

import com.hrm.coffeeshop.shared.dto.DocumentDto.DocumentView;
import com.hrm.coffeeshop.shared.dto.DocumentDto.SubmitRequest;
import com.hrm.coffeeshop.shared.service.DocumentService;

import com.hrm.coffeeshop.common.*;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
public class EmployeeDocumentController {
    private final DocumentService svc;

    public EmployeeDocumentController(DocumentService svc) {
        this.svc = svc;
    }

    @PostMapping("/employees/me/documents")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<DocumentView> submitMine(@Valid @RequestBody SubmitRequest r) {
        return ApiResponse.ok("Document submitted", svc.submit(SecurityUtils.requireEmployeeId(), r));
    }

    @GetMapping("/employees/me/documents")
    public ApiResponse<List<DocumentView>> mine() { return ApiResponse.ok(svc.list(SecurityUtils.requireEmployeeId())); }
}
