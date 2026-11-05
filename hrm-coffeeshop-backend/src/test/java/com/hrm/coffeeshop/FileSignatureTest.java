package com.hrm.coffeeshop;

import com.hrm.coffeeshop.common.FileSignature;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;

/** DEC-PDF: whitelist theo chữ ký tệp; DOC/DOCX/XLS/XLSX và định dạng khác bị từ chối. */
class FileSignatureTest {

    @Test
    void recognisesAllowedFormats() {
        assertEquals(Optional.of(FileSignature.PDF), FileSignature.sniff("%PDF-1.7\n...".getBytes(StandardCharsets.US_ASCII)));
        assertEquals(Optional.of(FileSignature.JPEG), FileSignature.sniff(new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0}));
        assertEquals(Optional.of(FileSignature.PNG), FileSignature.sniff(new byte[]{(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A}));
        byte[] webp = "RIFF\0\0\0\0WEBPVP8 ".getBytes(StandardCharsets.ISO_8859_1);
        assertEquals(Optional.of(FileSignature.WEBP), FileSignature.sniff(webp));
    }

    @Test
    void rejectsOfficeFormatsAndUnknownBytes() {
        // DOCX/XLSX là gói ZIP (PK\x03\x04); DOC/XLS cũ là OLE2 (D0 CF 11 E0)
        assertTrue(FileSignature.sniff(new byte[]{'P', 'K', 3, 4, 0, 0, 0, 0}).isEmpty());
        assertTrue(FileSignature.sniff(new byte[]{(byte) 0xD0, (byte) 0xCF, 0x11, (byte) 0xE0, 0, 0, 0, 0}).isEmpty());
        assertTrue(FileSignature.sniff("hello world".getBytes(StandardCharsets.US_ASCII)).isEmpty());
        // PDF có rác trước tiêu đề bị từ chối (chặt hơn spec)
        assertTrue(FileSignature.sniff(" %PDF-1.4".getBytes(StandardCharsets.US_ASCII)).isEmpty());
    }

    @Test
    void declaredContentTypeMustMatchRealFormat() {
        assertTrue(FileSignature.PDF.matchesDeclared("application/pdf"));
        assertTrue(FileSignature.PDF.matchesDeclared("application/pdf; charset=binary"));
        assertTrue(FileSignature.PDF.matchesDeclared(null));
        assertTrue(FileSignature.PDF.matchesDeclared("application/octet-stream"));
        assertFalse(FileSignature.PDF.matchesDeclared("image/png"));
        assertTrue(FileSignature.JPEG.matchesDeclared("image/jpg"));
    }
}
