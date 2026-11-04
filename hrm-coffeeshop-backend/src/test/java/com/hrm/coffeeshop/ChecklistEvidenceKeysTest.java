package com.hrm.coffeeshop;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.shared.service.EvidenceKeys;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

/** Minh chứng checklist: chỉ dùng được ảnh do chính nhân viên upload (TC35). */
class ChecklistEvidenceKeysTest {
    private static final String OWN = "checklist-evidence/42/3f2b1c9e-8a7d-4e5f-9b1a-0c2d3e4f5a6b.png";

    @Test
    void acceptsOwnKey() {
        assertDoesNotThrow(() -> EvidenceKeys.requireOwnedChecklistEvidence(OWN, 42L));
    }

    @Test
    void rejectsAnotherEmployeesKey() {
        assertThrows(BusinessException.class, () -> EvidenceKeys.requireOwnedChecklistEvidence(OWN, 7L));
    }

    @Test
    void rejectsAttendanceKeyAndTraversal() {
        assertThrows(BusinessException.class, () -> EvidenceKeys.requireOwnedChecklistEvidence(
                "attendance-evidence/42/20261014/3f2b1c9e-8a7d-4e5f-9b1a-0c2d3e4f5a6b.png", 42L));
        assertThrows(BusinessException.class, () -> EvidenceKeys.requireOwnedChecklistEvidence(
                "checklist-evidence/42/../7/3f2b1c9e-8a7d-4e5f-9b1a-0c2d3e4f5a6b.png", 42L));
    }
}
