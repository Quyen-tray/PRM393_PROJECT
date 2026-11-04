# Codex Shared State Homes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep independent logins in `.codex`, `.codex-1`, and `.codex-2` while sharing config, sessions, history, skills, plugins, rules, and SQLite state from `.codex-shared`.

**Architecture:** `.codex-shared` is the canonical store. Each `CODEX_HOME` keeps its own `auth.json` and process-local data, while NTFS hardlinks and directory junctions expose the common config and data. Two PowerShell launchers set `CODEX_HOME` for the new accounts; the default `codex` command continues to use `.codex`.

**Tech Stack:** Windows PowerShell, NTFS file hardlinks and directory junctions, SQLite CLI online backup and SQL transactions, installed Codex CLI.

**Spec:** `docs/superpowers/specs/2026-11-03-codex-1-shared-state-design.md`

## Global Constraints

- The user explicitly authorized proceeding with the current session active; never terminate it. The running `.codex` process keeps its original SQLite connection until exit, so preserve its local DB files and merge its final writes after that process closes. Treat active JSONL handles the same way unless a hard link can keep the current rollout writing into the shared sessions tree.
- Never read, copy, or expose `auth.json`; keep account credentials local to each `CODEX_HOME`.
- Keep `.codex-shared\config.toml` as the canonical config; use same-volume NTFS hardlinks for file paths because Windows denied symbolic-link creation. If hardlinks cannot be created, stop before changing profile paths.
- Back up every non-auth source path that will be merged or replaced before changing it; keep private/transient paths untouched and do not overwrite or delete any original database.
- Do not alias SQLite files with hardlinks or multiple paths. Do not merge if a database is unreadable, migration identities (version, description, success, checksum) differ, or distinct rows collide on a primary key outside the documented progress-field rules. Keep the canonical shared `installed_on` and `execution_time` migration metadata. For `backfill_state`, merge `last_success_at` and `updated_at` with `MAX` only when stable fields match. For `threads`, merge `updated_at`, `updated_at_ms`, and `tokens_used` with `MAX` only when `id` and every other field match and the expected integer schema is present. For `thread_history_projection_state`, merge `next_rollout_byte_offset` and `next_rollout_ordinal` with `MAX` only when `thread_id` and every other field match and the expected integer schema is present.
- Keep app-server controls, sandbox, temporary files, local caches, plugin staging, and installation identity private.
- Do not modify user PATH, `.gitignore`, or perform sign-in.

## Review Focus

- Active Codex writer or WAL sidecar: Task 1 uses SQLite online backup and leaves the active `.codex` database paths untouched.
- Duplicate rollout or JSONL records: Task 2 preserves originals and merges only unique records.
- Divergent SQLite schemas or primary-key rows: Task 3 stops before cutover instead of dropping records, except the documented `backfill_state`, `threads`, and projection-cursor progress fields when stable values match.
- A database is unreadable, has a schema/migration-identity mismatch, or has conflicting rows outside those progress rules: Task 3 stops before applying the affected merge and preserves both database families.
- Windows symbolic links unavailable: use hardlinks to the same NTFS file object, never independent config copies; SQLite database files remain unaliased.

---

### Task 1: Preflight and preserve current data

**Files and data:**
- Read: `C:\Users\Baonv\.codex\config.toml`, `history.jsonl`, `session_index.jsonl`, `session_index.jsonl.lock`, `sessions`, `skills`, `plugins\cache`, `thread-writer-locks`, `.sqlite-maintenance.lock`, and root SQLite files with sidecars.
- Read: `C:\Users\Baonv\.codex-shared\config.toml`, history/index, `session_index.jsonl.lock` if present, sessions, skills, rules, `AGENTS.md`, `thread-writer-locks`, `.sqlite-maintenance.lock`, and `sqlite` database files with sidecars.
- Create: a dated backup of all paths to be merged or replaced under `C:\Users\Baonv\.codex-shared\migration-backups\<timestamp>`.

**Interfaces:**
- Produces timestamped non-auth file snapshots and SQLite online backups for Tasks 2–4; live append-only files can receive a final delta after the active process exits.
- `auth.json` contents are never read or copied.

- [x] **Step 1: Record active Codex writers.** Check Codex CLI, app-server, IDE, and desktop process names without terminating them. The user has directed continuing with the current session active; record that the current process will retain its original SQLite connection until exit.
- [x] **Step 2: Recheck source and destination paths.** Confirm `.codex-shared` exists, `.codex-1`, `.codex-2`, and `.codex-bin` are still empty, and no paths are already links. Stop on any unexpected content.
- [x] **Step 3: Snapshot non-auth data.** Copy the two homes’ config, history/index and index lock, session files, skills, rules, plugin cache, writer locks, and other files that will be changed into a timestamped backup. Use SQLite’s online backup API for each database so committed WAL data is included consistently. Keep all originals in place.
- [x] **Step 4: Confirm the snapshot inventory.** Compare source and backup relative paths and sizes; record the SHA-256 manifest for non-SQLite files. Do not print transcript contents or credential material.

### Task 2: Merge transcript and static harness data

**Files and data:**
- Modify shared: `sessions`, `history.jsonl`, `session_index.jsonl`, `session_index.jsonl.lock`, `skills`, `plugins\cache`, `rules`, `AGENTS.md`, and `thread-writer-locks`.
- Source: matching items under `.codex`; destination: `.codex-shared`.

**Interfaces:**
- Produces one shared transcript/skills/plugin/rules tree without deleting source data.
- The seven shared rollout paths and one `.codex` rollout path currently have no relative-path collision.

- [x] **Step 1: Merge rollout files.** For each unique `.codex\sessions` rollout, hard-link it into `.codex-shared\sessions` so an already-open writer continues appending to the shared file object. If hard-link creation is unavailable, copy the complete-line snapshot and record that the active rollout needs a final delta sync. Preserve originals and stop on a conflicting destination.
- [x] **Step 2: Merge JSONL history and index.** Preserve both source files in the backup, retain the existing shared-file order, then append only unique complete lines from `.codex` in source order. Preserve any incomplete trailing bytes in the backup and note that active local history/index handles may need a final delta sync.
- [x] **Step 3: Confirm skills are already identical.** Recheck the 49 matching skill files by relative path and SHA-256; use `.codex-shared\skills` as canonical without overwriting it.
- [x] **Step 4: Populate the shared plugin cache.** Copy `.codex\plugins\cache` to `.codex-shared\plugins\cache`. Keep `.remote-plugin-install-staging` local and stop on any conflicting cache path.
- [x] **Step 5: Merge writer-lock filenames.** Preserve both homes’ thread-writer lock files in the shared directory. For same-name files, keep one only if contents match; stop on differing contents. Hard-link unique active local lock files before replacing the local directory path so open handles keep referring to the shared files.

### Task 3: Merge SQLite state without replacing databases

**Files and data:**
- Source databases: `C:\Users\Baonv\.codex\*.sqlite` and their sidecars.
- Canonical databases: `C:\Users\Baonv\.codex-shared\sqlite\*.sqlite` and their sidecars.

**Interfaces:**
- Produces committed source rows in the existing shared databases, checked transactionally without replacing any live database file.
- Does not modify the source databases or their backup copies.

- [x] **Step 1: Reopen every database read-only.** Compare SQLite versions, schema, indexes, primary keys, and migration identity fields (`version`, `description`, `success`, `checksum`) for each matching database. Ignore migration installation timestamps and execution durations, preserving the shared values. The user approved continuing with active writers, so use read-only snapshots for the source and do not rename or alias its live database files.
- [x] **Step 2: Compare primary-key rows.** Identify identical duplicate rows and conflicting rows in each matching table, including `logs.id`. For `backfill_state`, accept timestamp differences only when the singleton `id`, `status`, and `last_watermark` agree. For `threads`, accept differences only in integer `updated_at`, `updated_at_ms`, and `tokens_used` when `id` and all other fields match. For `thread_history_projection_state`, accept differences only in integer `next_rollout_byte_offset` and `next_rollout_ordinal` when `thread_id` and all other fields match. Do not expose row payloads in tool output.
- [x] **Step 3: Merge collision-free rows.** Using the online source snapshots, merge application tables into each existing shared DB under one SQLite transaction per database. Skip rows only when every column value matches, except that `backfill_state` timestamps, thread timestamps/token count, and projection cursors take the maximum under their documented stable-field checks. Do not merge `_sqlx_migrations` bookkeeping rows after migration identities match. If any other primary key maps to different values, roll back that database and leave both source sets intact.
- [x] **Step 4: Validate each canonical database.** Run `PRAGMA integrity_check` and compare row counts after each transaction. If any check fails, roll back the current transaction and preserve both source sets.
- [ ] **Step 5: Preserve the live source family.** Do not replace, hard-link, or rename any SQLite DB. Keep the `.codex` DB family at its current path because the active process keeps that connection; merge commits made after the latest online snapshot after it exits.

### Task 4: Point all homes at the shared store

**Files:**
- Modify: `C:\Users\Baonv\.codex-shared\config.toml`.
- Create file hardlinks and directory junctions under `.codex`, `.codex-1`, and `.codex-2`.
- Keep each existing `auth.json`, app-server controls, sandbox, temp, cache, package state, and installation identity local.

**Interfaces:**
- All three `CODEX_HOME` directories load the same `config.toml` and common runtime data.
- The shared config sets `sqlite_home = "C:/Users/Baonv/.codex-shared/sqlite"` and `cli_auth_credentials_store = "file"`.

- [x] **Step 1: Reconcile the canonical config.** Use `.codex-shared/config.toml` as the base, retain its current TUI availability counter, confirm the model, effort, project trust, and Windows settings match `.codex`, keep its SQLite path, and add `cli_auth_credentials_store = "file"`. Preserve `.codex`'s original config in the backup.
- [x] **Step 2: Confirm same-volume file-hardlink support.** Use a temporary hardlink inside `.codex-bin`, verify the shared file contents, and remove only that temporary link. Stop if Windows denies hardlink creation.
- [x] **Step 3: Preserve each existing path before linking.** For every existing `.codex` path to be linked, verify the dated snapshot copy first. Hard-link the active rollout, session-index lock, and writer-lock files into the shared tree before replacing their directory paths. Move active history/index originals into a `pending-live` backup location before linking the shared JSONL files; their open handles may continue writing to those preserved files until exit. If Windows refuses to replace an active path, leave it in place and record it for final delta sync. Do not move `auth.json`, `cap_sid`, or local process data.
- [x] **Step 4: Link the default home.** Hard-link `.codex\config.toml`, history/index, `session_index.jsonl.lock`, `AGENTS.md`, and `.sqlite-maintenance.lock` to shared files. Create junctions for sessions, skills, rules, thread-writer-locks, and `plugins\cache`. The currently running process applies the shared config/SQLite path only on its next launch.
- [x] **Step 5: Populate the two empty profile homes.** Create the same links under `.codex-1` and `.codex-2`; do not create or copy `auth.json`.
- [x] **Step 6: Create CLI launchers.** Create `.codex-bin\codex-1.ps1` and `.codex-bin\codex-2.ps1`. Each checks its home and shared config, sets `CODEX_HOME` for the installed CLI at `C:\Users\Baonv\AppData\Local\Programs\OpenAI\Codex\bin\codex.exe`, forwards arguments, and restores the caller’s prior environment. Add `codex-1.cmd` and `codex-2.cmd` beside the existing `codex.exe`; each forwards to its PowerShell launcher so both names resolve from the existing PATH without changing PATH. Do not launch Codex.

### Task 5: Audit the resulting layout

**Files and data:**
- Read-only inspection of all three homes, `.codex-shared`, the PowerShell launchers, and the CMD shims.

**Interfaces:**
- Produces a final link/config/credential-separation report before the user signs in.

- [x] **Step 1: Inspect every link target.** Confirm each shared file hardlink has the same contents as its canonical `.codex-shared` path, each directory junction resolves there, and no link points back to itself.
- [x] **Step 2: Inspect the common config.** Confirm all three `config.toml` paths are hardlinks to the canonical shared file, the SQLite path is exact, and the file credential setting is present once. Report that atomic replacement of the canonical config can detach hardlinks and the active process remains on its original database path until it exits.
- [x] **Step 3: Inspect account isolation.** Confirm `.codex` retains its original auth path, `.codex-1` and `.codex-2` have no auth files before first login, and no credentials were copied.
- [x] **Step 4: Inspect launcher targets.** Confirm both CMD shims resolve from CMD and forward arguments to the PowerShell launchers; confirm the scripts set the intended `CODEX_HOME`, invoke the verified CLI path, and restore the caller environment.
- [x] **Step 5: Report first-login commands.** Provide the two launcher paths and remind the user to sign into each account separately. Do not run login or start a Codex client.
