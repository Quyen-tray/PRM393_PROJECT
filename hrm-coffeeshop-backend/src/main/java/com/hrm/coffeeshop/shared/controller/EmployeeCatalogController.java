package com.hrm.coffeeshop.shared.controller;
import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.repository.AppUserRepository;
import com.hrm.coffeeshop.shared.dto.DocumentDto.CatalogItem;
import com.hrm.coffeeshop.shared.service.DocumentService;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
public class EmployeeCatalogController {
    public record LinkableUser(Long userId, String email, String displayName) {}
    private final AppUserRepository users;
    private final DocumentService documents;
    public EmployeeCatalogController(AppUserRepository users, DocumentService documents) { this.users=users; this.documents=documents; }
    @GetMapping("/employees/linkable-users")
    @PreAuthorize("hasAuthority('EMPLOYEE_MANAGE')")
    public ApiResponse<PageResponse<LinkableUser>> linkable(@RequestParam(defaultValue="") String q,@PageableDefault(size=20) Pageable pageable) {
        return ApiResponse.ok(PageResponse.of(users.findLinkable(q.trim(),pageable),u->new LinkableUser(u.getUserId(),u.getEmail(),u.getDisplayName())));
    }
    @GetMapping("/employees/{id}/documents/catalog")
    public ApiResponse<List<CatalogItem>> catalog(@PathVariable Long id) { return ApiResponse.ok(documents.catalogFor(id)); }
}
