#!/usr/bin/env python3
"""Sinh entity JPA + repository từ config.sql (nguồn sự thật = DDL)."""
import re, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from repo_extras import EXTRAS

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PKG = "com.hrm.coffeeshop"
BASE = f"{ROOT}/src/main/java/com/hrm/coffeeshop"

def read(p):
    return open(p, encoding="utf-8-sig").read().replace("\r\n", "\n")

# Nguồn sự thật duy nhất: infra/sqlserver/config.sql (DDL schema).
CONFIG = f"{ROOT}/infra/sqlserver/config.sql"
if not os.path.exists(CONFIG):
    raise FileNotFoundError(f"Không tìm thấy {CONFIG} — đây là nguồn DDL duy nhất.")
sql = read(CONFIG)
sql = re.sub(r"--[^\n]*", "", sql)

def body_of(text, start):
    depth, i = 0, start
    while True:
        c = text[i]
        if c == "(": depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0: return text[start + 1:i]
        i += 1

def split_top(body):
    parts, depth, cur = [], 0, ""
    for c in body:
        if c == "(": depth += 1
        if c == ")": depth -= 1
        if c == "," and depth == 0:
            parts.append(cur.strip()); cur = ""
        else:
            cur += c
    if cur.strip(): parts.append(cur.strip())
    return parts

TYPES = {"BIGINT": "Long", "INT": "Integer", "SMALLINT": "Short", "TINYINT": "Short",
         "BIT": "Boolean", "DECIMAL": "BigDecimal", "DATE": "LocalDate", "TIME": "LocalTime",
         "DATETIME2": "Instant", "VARCHAR": "String", "NVARCHAR": "String"}

def camel(n): return n[0].lower() + n[1:]

def parse_col(part):
    m = re.match(r"(\w+)\s+(\w+)(\(\s*(?:MAX|\d+(?:\s*,\s*\d+)?)\s*\))?(.*)$", part, re.S)
    name, typ, rest = m.group(1), m.group(2).upper(), m.group(4) or ""
    up = rest.upper()
    d = re.search(r"DEFAULT\s+('[^']*'|\d+|SYSUTCDATETIME\(\))", rest, re.I)
    return dict(name=name, jtype=TYPES[typ], pk="PRIMARY KEY" in up, identity="IDENTITY" in up,
                notnull=("NOT NULL" in up) or ("PRIMARY KEY" in up),
                default=d.group(1) if d else None)

tables = {}   # name -> dict(cols=[...], pk=[...])
for m in re.finditer(r"CREATE TABLE dbo\.(\w+)\s*\(", sql):
    name = m.group(1)
    cols, pk = [], []
    for part in split_top(body_of(sql, m.end() - 1)):
        if re.match(r"CONSTRAINT\b", part, re.I):
            pm = re.search(r"PRIMARY KEY\s*\(([^)]*)\)", part, re.I)
            if pm: pk = [x.strip() for x in pm.group(1).split(",")]
            continue
        c = parse_col(part); cols.append(c)
        if c["pk"]: pk.append(c["name"])
    tables[name] = dict(cols=cols, pk=pk)

for m in re.finditer(r"ALTER TABLE dbo\.(\w+)\s+ADD\s+(\w+\s+\w+(?:\([^)]*\))?[^;]*);", sql):
    t = m.group(1)
    if t in tables:
        c = parse_col(m.group(2))
        if not any(x["name"] == c["name"] for x in tables[t]["cols"]):
            tables[t]["cols"].append(c)

def default_expr(c):
    d, t = c["default"], c["jtype"]
    if d is None or not c["notnull"]: return ""
    if d == "SYSUTCDATETIME()": return " = Instant.now()"
    if d.startswith("'"): return f' = "{d[1:-1]}"'
    if t == "Boolean": return " = Boolean.TRUE" if d == "1" else " = Boolean.FALSE"
    if t == "Integer": return f" = {d}"
    if t == "Short": return f" = (short) {d}"
    if t == "Long": return f" = {d}L"
    if t == "BigDecimal": return f' = new BigDecimal("{d}")'
    return ""

def cap(n): return n[0].upper() + n[1:]

def gen_entity(tn, t):
    cols, pk = t["cols"], t["pk"]
    composite = len(pk) > 1
    L = [f"package {PKG}.domain;", "",
         "import jakarta.persistence.*;",
         "import java.io.Serializable;", "import java.math.BigDecimal;", "import java.time.*;", "import java.util.Objects;", "",
         "/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */",
         "@Entity", f'@Table(name = "{tn}")']
    if composite: L.append(f"@IdClass({tn}.Pk.class)")
    L.append(f"public class {tn} {{")
    if composite:
        L.append("    public static class Pk implements Serializable {")
        for p_ in pk:
            ct = next(c for c in cols if c["name"] == p_)
            L.append(f"        private {ct['jtype']} {camel(p_)};")
        L.append("        public Pk() {}")
        L.append("        public Pk(" + ", ".join(f"{next(c for c in cols if c['name']==p_)['jtype']} {camel(p_)}" for p_ in pk) + ") {")
        for p_ in pk: L.append(f"            this.{camel(p_)} = {camel(p_)};")
        L.append("        }")
        for p_ in pk:
            ct = next(c for c in cols if c["name"] == p_)
            L.append(f"        public {ct['jtype']} get{cap(camel(p_))}() {{ return {camel(p_)}; }}")
            L.append(f"        public void set{cap(camel(p_))}({ct['jtype']} v) {{ this.{camel(p_)} = v; }}")
        L.append("        @Override public boolean equals(Object o) {")
        L.append(f"            if (this == o) return true;")
        L.append(f"            if (!(o instanceof Pk other)) return false;")
        L.append("            return " + " && ".join(f"Objects.equals({camel(p_)}, other.{camel(p_)})" for p_ in pk) + ";")
        L.append("        }")
        L.append("        @Override public int hashCode() { return Objects.hash(" + ", ".join(camel(p_) for p_ in pk) + "); }")
        L += ["    }", ""]
    has_updated = False
    for c in cols:
        if c["name"] in pk:
            L.append("    @Id")
            if c["identity"]: L.append("    @GeneratedValue(strategy = GenerationType.IDENTITY)")
        if c["name"] == "RowVersion": L.append("    @Version")  # khóa lạc quan
        L.append(f'    @Column(name = "{c["name"]}")')
        L.append(f"    private {c['jtype']} {camel(c['name'])}{default_expr(c)};")
        if c["name"] == "UpdatedAt": has_updated = True
    L.append("")
    L.append(f"    public {tn}() {{}}")
    L.append("")
    for c in cols:
        f, jt = camel(c["name"]), c["jtype"]
        L.append(f"    public {jt} get{cap(f)}() {{ return {f}; }}")
        L.append(f"    public void set{cap(f)}({jt} {f}) {{ this.{f} = {f}; }}")
    if has_updated:
        L += ["", "    @PreUpdate", "    void touch() { this.updatedAt = Instant.now(); }"]
    L.append("}")
    return "\n".join(L) + "\n"

def gen_repo(tn, t):
    pk = t["pk"]
    if len(pk) > 1: idt = f"{tn}.Pk"
    else: idt = next(c["jtype"] for c in t["cols"] if c["name"] == pk[0])
    extra = EXTRAS.get(tn, "")
    return f"""package {PKG}.repository;

import {PKG}.domain.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.*;
import java.util.*;

public interface {tn}Repository extends JpaRepository<{tn}, {idt}> {{
{extra}}}
"""

for tn, t in tables.items():
    open(f"{BASE}/domain/{tn}.java", "w", encoding="utf-8").write(gen_entity(tn, t))
    open(f"{BASE}/repository/{tn}Repository.java", "w", encoding="utf-8").write(gen_repo(tn, t))
print(len(tables), "tables:", ", ".join(tables))
