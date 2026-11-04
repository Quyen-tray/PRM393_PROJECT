package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "DocumentType")
public class DocumentType {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "DocumentTypeId")
    private Integer documentTypeId;
    @Column(name = "DocumentCode")
    private String documentCode;
    @Column(name = "DocumentName")
    private String documentName;
    @Column(name = "IsActive")
    private Boolean isActive = Boolean.TRUE;

    public DocumentType() {}

    public Integer getDocumentTypeId() { return documentTypeId; }
    public void setDocumentTypeId(Integer documentTypeId) { this.documentTypeId = documentTypeId; }
    public String getDocumentCode() { return documentCode; }
    public void setDocumentCode(String documentCode) { this.documentCode = documentCode; }
    public String getDocumentName() { return documentName; }
    public void setDocumentName(String documentName) { this.documentName = documentName; }
    public Boolean getIsActive() { return isActive; }
    public void setIsActive(Boolean isActive) { this.isActive = isActive; }
}
