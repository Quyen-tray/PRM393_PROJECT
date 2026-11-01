package com.hrm.coffeeshop.shared.controller;

import com.hrm.coffeeshop.shared.dto.StoreDto.StoreView;
import com.hrm.coffeeshop.shared.service.StoreService;

import com.hrm.coffeeshop.common.ApiResponse;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
public class SharedStoreController {
    private final StoreService store;

    public SharedStoreController(StoreService store) {
        this.store = store;
    }

    @GetMapping("/stores/current")
    public ApiResponse<StoreView> current() { return ApiResponse.ok(store.view(store.current())); }
}
