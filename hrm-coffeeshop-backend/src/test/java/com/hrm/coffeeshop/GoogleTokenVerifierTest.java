package com.hrm.coffeeshop;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.config.AppProperties;
import com.hrm.coffeeshop.shared.service.GoogleTokenVerifier;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/** Các trường hợp không cần gọi mạng tới Google. */
class GoogleTokenVerifierTest {
    private static GoogleTokenVerifier verifier(String clientIds) {
        AppProperties props = new AppProperties("Asia/Ho_Chi_Minh", null, new AppProperties.Google(clientIds), null,
                null, null);
        return new GoogleTokenVerifier(props);
    }

    @Test
    void parseClientIdsHandlesCommasSpacesAndBlanks() {
        assertEquals(List.of("a.apps.googleusercontent.com", "b.apps.googleusercontent.com"),
                GoogleTokenVerifier.parseClientIds(" a.apps.googleusercontent.com, b.apps.googleusercontent.com ,, "));
        assertEquals(List.of("a"), GoogleTokenVerifier.parseClientIds("a,a"));
        assertTrue(GoogleTokenVerifier.parseClientIds(null).isEmpty());
        assertTrue(GoogleTokenVerifier.parseClientIds("  ").isEmpty());
    }

    @Test
    void missingClientIdGivesClearConfigError() {
        BusinessException e = assertThrows(BusinessException.class, () -> verifier("").verify("a.b.c"));
        assertEquals(ErrorCode.INTERNAL_ERROR, e.getCode());
        assertTrue(e.getMessage().contains("GOOGLE_CLIENT_ID"));
    }

    @Test
    void malformedTokenIsInvalidToken() {
        GoogleTokenVerifier v = verifier("x.apps.googleusercontent.com");
        assertEquals(ErrorCode.INVALID_TOKEN, assertThrows(BusinessException.class, () -> v.verify("abc")).getCode());
        assertEquals(ErrorCode.INVALID_TOKEN, assertThrows(BusinessException.class, () -> v.verify("  ")).getCode());
        assertEquals(ErrorCode.INVALID_TOKEN, assertThrows(BusinessException.class, () -> v.verify(null)).getCode());
    }
}
