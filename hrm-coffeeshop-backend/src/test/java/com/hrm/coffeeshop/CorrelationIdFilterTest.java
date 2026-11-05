package com.hrm.coffeeshop;

import com.hrm.coffeeshop.config.CorrelationIdFilter;
import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.junit.jupiter.api.Assertions.*;

class CorrelationIdFilterTest {
    private final CorrelationIdFilter filter = new CorrelationIdFilter();

    @AfterEach
    void clearMdc() { MDC.clear(); }

    @Test
    void preservesSafeClientIdAndReturnsItInResponse() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader(CorrelationIdFilter.HEADER, "trace-123.A");
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = (req, res) -> assertEquals("trace-123.A", MDC.get("correlationId"));

        filter.doFilter(request, response, chain);

        assertEquals("trace-123.A", request.getAttribute(CorrelationIdFilter.ATTRIBUTE));
        assertEquals("trace-123.A", response.getHeader(CorrelationIdFilter.HEADER));
        assertNull(MDC.get("correlationId"), "MDC must be cleared after request");
    }

    @Test
    void replacesUnsafeClientId() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader(CorrelationIdFilter.HEADER, "bad\nid");
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter.doFilter(request, response, (req, res) -> {});

        String id = (String) request.getAttribute(CorrelationIdFilter.ATTRIBUTE);
        assertNotNull(id);
        assertTrue(id.matches("[0-9a-fA-F-]{36}"));
        assertEquals(id, response.getHeader(CorrelationIdFilter.HEADER));
    }
}
