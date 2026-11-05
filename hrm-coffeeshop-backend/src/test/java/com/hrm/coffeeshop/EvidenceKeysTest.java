package com.hrm.coffeeshop;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.shared.service.EvidenceKeys;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

/** Quyền sở hữu ảnh chấm công: chỉ dùng được ảnh do chính mình upload. */
class EvidenceKeysTest {
    private static final String OWN = "attendance-evidence/42/20261014/3f2b1c9e-8a7d-4e5f-9b1a-0c2d3e4f5a6b.jpg";

    @Test
    void acceptsOwnKey() {
        assertDoesNotThrow(() -> EvidenceKeys.requireOwnedAttendanceEvidence(OWN, 42L));
    }

    @Test
    void rejectsAnotherEmployeesKey() {
        assertThrows(BusinessException.class, () -> EvidenceKeys.requireOwnedAttendanceEvidence(OWN, 7L));
    }

    @Test
    void rejectsPathTraversalAndWrongPurpose() {
        assertThrows(BusinessException.class, () -> EvidenceKeys.requireOwnedAttendanceEvidence(
                "attendance-evidence/42/../7/20261014/3f2b1c9e-8a7d-4e5f-9b1a-0c2d3e4f5a6b.jpg", 42L));
        assertThrows(BusinessException.class, () -> EvidenceKeys.requireOwnedAttendanceEvidence(
                "private-documents/employee-42/3f2b1c9e-8a7d-4e5f-9b1a-0c2d3e4f5a6b.jpg", 42L));
    }

    @Test
    void rejectsNullKeyAndNullEmployee() {
        assertThrows(BusinessException.class, () -> EvidenceKeys.requireOwnedAttendanceEvidence(null, 42L));
        assertThrows(BusinessException.class, () -> EvidenceKeys.requireOwnedAttendanceEvidence(OWN, null));
    }
}
