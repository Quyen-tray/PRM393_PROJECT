package com.hrm.coffeeshop.common;

import java.util.Locale;
import java.util.Optional;

/**
 * Whitelist định dạng tệp được chấp nhận, nhận dạng theo chữ ký đầu tệp (magic bytes).
 * Không tin Content-Type hay đuôi tệp do client gửi. DOC/DOCX/XLS/XLSX và mọi định dạng khác bị từ chối.
 */
public enum FileSignature {
    JPEG("image/jpeg", "jpg"),
    PNG("image/png", "png"),
    WEBP("image/webp", "webp"),
    PDF("application/pdf", "pdf");

    private final String mime;
    private final String ext;

    FileSignature(String mime, String ext) {
        this.mime = mime;
        this.ext = ext;
    }

    public String mime() { return mime; }
    public String ext() { return ext; }

    public static Optional<FileSignature> sniff(byte[] b) {
        if (b.length >= 3 && (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8 && (b[2] & 0xFF) == 0xFF) return Optional.of(JPEG);
        if (b.length >= 8 && (b[0] & 0xFF) == 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G') return Optional.of(PNG);
        if (b.length >= 12 && b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F'
                && b[8] == 'W' && b[9] == 'E' && b[10] == 'B' && b[11] == 'P') return Optional.of(WEBP);
        // PDF: bắt đầu bằng "%PDF-" (không cho phép rác trước tiêu đề)
        if (b.length >= 5 && b[0] == '%' && b[1] == 'P' && b[2] == 'D' && b[3] == 'F' && b[4] == '-') return Optional.of(PDF);
        return Optional.empty();
    }

    /** Content-Type khai báo phải khớp định dạng thật. Bỏ trống hoặc octet-stream thì chấp nhận. */
    public boolean matchesDeclared(String header) {
        if (header == null || header.isBlank()) return true;
        String base = header.split(";")[0].trim().toLowerCase(Locale.ROOT);
        if (base.isEmpty() || base.equals("application/octet-stream")) return true;
        return base.equals(mime) || (this == JPEG && base.equals("image/jpg"));
    }
}
