# Codex Shared State Homes Design

Date: 2026-11-03

## Intent

Use `.codex`, `.codex-1`, and `.codex-2` as three independently authenticated `CODEX_HOME` directories. Keep one canonical `config.toml` and shared conversation/runtime data under `C:\Users\Baonv\.codex-shared`, so all three homes see the same settings, sessions, history, skills, plugins, rules, memories, and goals.

## Current state

- In the inspected PowerShell environment, `CODEX_HOME` is unset, so the CLI default is `.codex`. The Codex executable is `C:\Users\Baonv\AppData\Local\Programs\OpenAI\Codex\bin\codex.exe`.
- `.codex-shared` already exists and contains its own `config.toml`, `AGENTS.md`, `rules`, `skills`, `sessions`, history/index files, SQLite directory, and lock files. `.codex-1`, `.codex-2`, and `.codex-bin` exist but are empty.
- `.codex` has one rollout file; `.codex-shared` has seven. Their relative rollout paths do not collide. Their `history.jsonl` and `session_index.jsonl` files are separate.
- Both homes contain the same 49 skill files (matching relative paths and SHA-256 hashes). The plugin cache is under `.codex\plugins\cache`; `.codex-shared` has no plugin cache yet.
- `.codex\config.toml` and `.codex-shared\config.toml` have the same main model, effort, project trust, and Windows settings. The shared config already sets `sqlite_home` to `.codex-shared\sqlite`; the TUI availability counter differs.
- The SQLite database families exist in both homes under matching names, but with different sizes and WAL/SHM state. Read-only inspection found matching table names and primary-key layouts for goals, logs, queue, state, and thread history. The `memories` database did not open in that inspection. The current `.codex` rollout and WAL were active during inspection.
- The current repository has no root `AGENTS.md` or `.agents/skills`. Existing `.gitignore` changes are outside this design and must be left untouched.

## Approaches

1. Use native `--profile` files under one `CODEX_HOME`. Rejected because the accounts must remain independent.
2. Keep each home’s SQLite database separate and share only transcript files and static assets. Rejected because the user chose to share SQLite-backed index, memories, and goals too.
3. Keep authentication per home while linking a common config and data store to `.codex-shared`. Selected because it meets the separate-account and shared-state requirements.

## Design

Make `.codex-shared\config.toml` canonical and link each profile home’s `config.toml` to that same file. Use the shared file as the base (including its current TUI availability counter), retain the matching model, reasoning, project trust, and Windows settings, keep `sqlite_home` pointed at `.codex-shared\sqlite`, and set file-based credential storage so Codex reads or writes each account’s own `auth.json` under its `CODEX_HOME`. Keep installation identity, `cap_sid`, app-server controls, sandbox, temporary files, and local caches private to each home.

Share `sessions`, `history.jsonl`, `session_index.jsonl`, `session_index.jsonl.lock`, `skills`, `plugins\cache`, `rules`, `AGENTS.md`, `thread-writer-locks`, `.sqlite-maintenance.lock`, and the SQLite database directory. Use directory junctions for shared directories and same-volume NTFS hardlinks for shared files because Windows denied file-symbolic-link creation. Hardlinks expose one file object through each home; the shared path remains canonical, and editors that replace a file atomically can detach the other links, so relink after such an edit. Do not hard-link or alias SQLite database files: SQLite uses path-derived WAL/SHM files and documents multi-path use of one database as undefined. Every new process must open the one canonical `sqlite_home` path. Keep plugin staging and app-server control/lock directories local. Add PowerShell launchers for `codex-1` and `codex-2` under `.codex-bin`; leave the default `codex` invocation on `.codex` and do not modify PATH.

Before linking, preserve non-auth source data and merge the distinct rollout files and JSONL records into `.codex-shared`. The user explicitly directed proceeding while the current session is active. Do not terminate clients. The already-running `.codex` process keeps its original SQLite connection until it exits, even after the shared config is installed; retain its local database files and merge any later writes after that process closes. Hard-link the active rollout and session-index lock into the shared tree when possible so their existing handles still refer to common file objects. Local history/index handles may continue writing to preserved pending files, so keep those files for a later delta sync. Merge committed SQLite application rows into the canonical shared databases only through SQLite transactions after schemas and row conflicts are understood. Require identical migration versions, descriptions, success states, and checksums; preserve the shared migration timestamps and execution durations. The singleton `backfill_state` row may merge timestamps with `MAX` only when `id`, `status`, and `last_watermark` match; otherwise treat it as a conflict. If a schema or migration identity differs, or any other distinct rows conflict on a primary key, roll back that database merge and preserve both source sets; do not print row payloads.

## Constraints and acceptance

- Keep `config.toml` common and `auth.json` separate for `.codex`, `.codex-1`, and `.codex-2`.
- Do not read, copy, or expose credential contents; do not launch Codex or perform login during setup.
- The user has authorized proceeding while Codex clients remain active; never terminate them. Preserve original files, and do not rename or replace an open SQLite database.
- Preserve source data in a dated backup before merge or link creation; never overwrite occupied destinations.
- Share all selected data only through `.codex-shared`; keep account-specific and transient process files local.
- Do not change the current user PATH or `.gitignore`.
- Check Windows file-hardlink support before cutover. If unavailable, stop rather than silently creating independent config copies. After config edits, confirm hardlinks still share the canonical file object.
- Verify link targets and shared config paths before first use; leave new profiles unauthenticated for the user to sign in separately.
