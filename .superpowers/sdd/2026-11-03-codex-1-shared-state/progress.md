# SDD ledger — plan: docs/superpowers/plans/2026-11-03-codex-1-shared-state.md

Ruling: Continue while the current Codex session remains active; do not terminate it. Preserve the `.codex` SQLite files at their current paths, merge only a committed online snapshot into `.codex-shared`, and retain post-snapshot writes for a later delta sync — this leaves the live session temporarily split across local and shared state if it writes after the snapshot.

Ruling: The pre-existing `setup-codex-profiles.ps1` is not executable as-is: it moves live SQLite files, requires all Codex processes to exit, replaces existing shared paths, and modifies PATH. Replace its workflow with a new one that backs up first, merges transactionally, preserves current writers, and never edits PATH — the cost if this assessment is wrong is that a previously usable helper remains unused.

Pre-flight: Task 1 supplies SQLite snapshots and file backups consumed by Tasks 2–4. Task 2 supplies the shared transcript/assets tree consumed by Task 4. Task 3 supplies the shared SQLite store selected by Task 4 config. Resolve active-writer path replacement by preserving local history/index files for final sync and hard-linking rollout/lock files before replacing their directories.

Ruling: The `py` launcher reports a Python runtime path that no longer exists, while `sqlite3.exe` is installed. Use the installed SQLite CLI for online backups, staged preflight merges, and per-database transactions instead of installing a runtime — the cost if wrong is relying on shell behavior that differs from Python's backup API; mitigated by integrity checks and preflight before any live merge.

Ruling: Share `session_index.jsonl.lock` alongside the JSONL file and preserve its active file object by hard-linking it when possible — the cost if Codex does not use that lock is minor extra serialization among profiles.

Ruling: Windows rejected file symbolic links with `Administrator privilege required` before backup creation. Use same-volume NTFS hardlinks for ordinary shared files and directory junctions for shared trees, while continuing to forbid SQLite hardlinks — this preserves file-object sharing without requiring admin, but an editor that atomically replaces the canonical config can detach other profile links.

Execution note: The hardlink probe succeeded. The first setup attempt stopped at the first snapshot loop because a script variable collided with PowerShell's read-only `$HOME`; it created only an empty timestamped backup directory. Renamed the variable to `$homePath`; no source files or profile paths had been changed.

Ruling: All six DBs have the same schema and migration versions; `description`, `success`, and `checksum` match, while only `installed_on` and `execution_time` differ. Keep the existing shared migration bookkeeping and merge application tables only — the cost if those timestamp fields are meaningful application data is loss of the source-side migration timing metadata, which remains preserved in the source DB and dated backup.

Execution note: Online snapshots and file backups completed. SQLite preflight stopped at the migration-metadata comparison before any shared DB or profile path was modified. A read-only summary confirmed the differences are limited to migration timestamps/durations; the helper now checks migration identities and retains the shared timestamps.

Ruling: `state_5.sqlite/backfill_state` is a checked singleton (`id = 1`); the two copies agree on `status` and `last_watermark` and differ only in `last_success_at` and `updated_at`. Merge those timestamps with `MAX` inside the DB transaction, while asserting the stable fields still match — the cost if those fields do not represent recency is that the shared checkpoint may retain a later timestamp, while both original rows remain in the source DB and backup.

Execution note: A read-only conflict scan found no other conflicting tables in the six database snapshots; `backfill_state` is the only one.

Ruling: The active `.codex` snapshot had one `state_5.sqlite/threads` row whose only differences were integer `updated_at`, `updated_at_ms`, and `tokens_used`; every stable field matched, and the source values were not lower than shared. Merge those three fields with `MAX` under schema and stable-field assertions — this preserves the latest timestamp and highest observed token count, while the source database and online backup retain the full original row.

Ruling: The active snapshot also had one `thread_history_projection_state` row whose only differences were integer `next_rollout_byte_offset` and `next_rollout_ordinal`; `thread_id` and all stable fields matched, and neither source cursor was lower than shared. Merge both cursors with `MAX` under schema and stable-field assertions — this preserves the highest observed projection point, with both original database families retained.

Execution note: One delta attempt initially pointed at `.codex\sqlite`; the source databases are directly under `.codex`. That attempt created only an empty backup directory and changed no database. A subsequent staging attempt exposed that the generated transaction assertion still compared the three thread progress fields; the helper was corrected before a live merge. The next preflight exposed the projection cursors above, which received the narrow checked rule.

Execution note: Online snapshot `C:\Users\Baonv\.codex-shared\migration-backups\delta-20261103-205626-018` passed preflight and merged into the six existing shared SQLite files. Post-merge read-only checks found no source rows missing, no remaining conflicts under the documented progress rules, zero foreign-key violations, and `PRAGMA integrity_check = ok` for all six databases. The source thread progress fields and projection cursors were confirmed no lower than shared.

Execution note: Final link/config/launcher audit passed for `.codex`, `.codex-1`, and `.codex-2`. Their shared regular files are NTFS hardlinks, shared data directories are junctions, and both launchers plus the shared `sqlite_home` and file credential setting are present. `.codex\auth.json` exists; the two new homes have no `auth.json`; no auth content was read or copied. The held `.sqlite-maintenance.lock` was not hashed; `fsutil` confirmed its hardlink identity.

Pending: The active session remains open by user direction. Its existing `.codex` SQLite connection and the old `history.jsonl`/`session_index.jsonl` handles remain preserved; the local SQLite files and JSONL files under `pending-live` are not deleted. Rollout and writer-lock file objects are linked into shared. Writes after the latest SQLite snapshot, plus history/index writes through the old handles, require a final delta sync after the session exits. No Codex process was terminated; no sign-in, client launch, or PATH change was performed.

Final review: self-review (no subagent tool). Confirmed the setup script's link audit uses `fsutil hardlink list` and junction targets from `Get-Item.Target`; PowerShell parser accepted the SQLite helper. Plan checkbox for the post-exit final SQLite delta remains open.

Execution note: User reported that `codex-1` and `codex-2` were not recognized from CMD. Root cause: both existing launchers were `.ps1` files under `.codex-bin`, which was not on PATH; CMD does not resolve a bare name to a PowerShell script. `where.exe codex` showed the installed CLI's `bin` directory is already on PATH. Added `codex-1.cmd` and `codex-2.cmd` beside `codex.exe`; each invokes its existing PowerShell launcher and forwards arguments. Verified `cmd.exe /d /c "where codex-1 && where codex-2"` resolves both shim paths and inspected their contents. PATH was unchanged and Codex was not launched.

Final review: self-review (no subagent tool). Confirmed the CMD shims are in the existing Codex `bin` PATH directory, point to the expected `.codex-bin` launchers, and resolve under both CMD and PowerShell command lookup. No Codex process was started.
