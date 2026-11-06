package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.shared.service.FaceVerificationClient;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;

/** Only the external face provider is replaced; permissions, storage, GPS and SQL remain real. */
@AutoConfigureMockMvc
@SpringBootTest(properties = "app.attendance.face-verification-required=true")
class AttendanceFacePolicyIT extends AttendanceFlowSupport {
    @MockBean FaceVerificationClient face;

    @Test void requiredFaceCannotSilentlyPassWhenProviderHasNotRun() throws Exception {
        when(face.verify(nullable(String.class), anyString(), anyLong()))
                .thenReturn(new FaceVerificationClient.Result("NOT_RUN", "NOT_RUN", "none"));
        activeDevice();
        long shift = assign(day);
        assertTrue(api(employeeUser, "GET", "/attendance/me/current?assignmentId=" + shift, null, 200)
                .path("data").path("photoRequired").asBoolean());
        assertEquals("FACE_VERIFICATION_UNAVAILABLE", api(employeeUser, "POST", "/attendance/check-in", body(shift, false), 503)
                .path("error").path("code").asText());
        assertEquals(0, countAttendanceOfShift(shift));
    }

    @Test void spoofIsRejectedAndOnlyVerifiedLiveMatchIsRecordedAsPassed() throws Exception {
        activeDevice();
        long shift = assign(day);
        when(face.verify(nullable(String.class), anyString(), anyLong()))
                .thenReturn(new FaceVerificationClient.Result("MATCH", "SPOOF", "test-provider"));
        assertEquals("FACE_VERIFICATION_FAILED", api(employeeUser, "POST", "/attendance/check-in", body(shift, false), 422)
                .path("error").path("code").asText());
        assertEquals(0, countAttendanceOfShift(shift));
        when(face.verify(nullable(String.class), anyString(), anyLong()))
                .thenReturn(new FaceVerificationClient.Result("MATCH", "LIVE", "test-provider"));
        long attendance = api(employeeUser, "POST", "/attendance/check-in", body(shift, false), 200)
                .path("data").path("attendanceId").asLong();
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.AttendanceVerification WHERE AttendanceId=? AND VerificationType='FACE_LIVENESS' AND VerificationStatus='PASSED'", Integer.class, attendance));
    }
}
