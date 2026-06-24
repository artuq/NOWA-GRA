# Story 001: Core Save/Load — State Transitions, Atomic Write & Schema Fallback

> **Epic**: Save/Persistence System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-24

## Context

**GDD**: `design/gdd/save-persistence-system.md`
**Requirement**: `TR-save-001`, `TR-save-002`, `TR-save-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Save file format and atomic write (primary); ADR-0001: Autoload singleton vs. event bus (secondary — Autoload registration/interface)
**ADR Decision Summary**: `SaveSystem` is a Godot Autoload. Save format is JSON, written to `user://save.tmp` then atomically renamed to `user://save.json` via `DirAccess.rename_absolute()`. Every save includes an increment-only `schema_version`; load falls back to first-session defaults on a missing file, JSON parse failure, or version mismatch — never crashes, never attempts partial migration.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: `FileAccess`/`DirAccess`/`JSON.stringify()`/`JSON.parse_string()` are stable pre-4.3 APIs — no 4.4–4.6 breaking change touches them. No post-cutoff API verification required.

**Control Manifest Rules (Foundation layer)**:
- Required: Save format is JSON via `JSON.stringify()` to `user://save.tmp`, then atomically renamed to `user://save.json` via `DirAccess.rename_absolute()` — check the returned `Error`, retain the `.tmp` file and log on failure rather than silently losing it — source: ADR-0002
- Required: Every save payload includes a `schema_version` field, increment-only; on load, a version mismatch or JSON parse failure falls back to first-session defaults — never crash — source: ADR-0002
- Required: Every module owning persisted state implements `restore_state(data: Dictionary) -> void`, called by `BootController`; missing keys must default safely (first-session case, `data == {}`) — source: ADR-0003 (this story implements `SaveSystem`'s side of the contract; `ResourceManager` and `HistoryFlagManager` must each expose `restore_state()` as part of this story's scope, since they don't yet have one)
- Required: Implement every Core/Foundation module as a Godot Autoload singleton; register in the canonical order `ResourceManager`, `HistoryFlagManager`, `CardContentDatabase`, `SaveSystem`, `ActionSystem`, ... — source: ADR-0001 (insert `SaveSystem` after `HistoryFlagManager`, before `ActionSystem` — `CardContentDatabase` doesn't exist yet, so the new order becomes `ResourceManager`, `HistoryFlagManager`, `SaveSystem`, `ActionSystem`)

---

## Acceptance Criteria

*From GDD `design/gdd/save-persistence-system.md` § Acceptance Criteria, scoped to this story. **Amended per QL-STORY-READY gate (2026-06-24)**: the GDD's round-trip criteria for `decision_card_state` (cooldown state, `resolved_milestone_cards`) are NOT included below — Decision Card System does not exist yet (only its `EPIC.md` placeholder), so testing that round-trip is currently impossible. This story's save schema writes `decision_card_state` as a fixed empty/default placeholder (`{"cooldown_actions_remaining": 0, "resolved_milestone_cards": []}`) with no round-trip test — that round-trip is explicitly deferred to a follow-up story once the Decision Card System epic exists (see Out of Scope below).*

**State transitions:**
- [ ] GIVEN app launching, no save file exists, WHEN initialization completes, THEN `uninitialized → loading → ready`, `ResourceManager` and `HistoryFlagManager` report defaults.
- [ ] GIVEN a valid, schema-matching save file exists, WHEN the app starts and loads it, THEN `uninitialized → loading → ready`, `ResourceManager` and `HistoryFlagManager`'s state matches the file.
- [ ] GIVEN `ready`, WHEN `save_now()` is called, THEN `ready → saving → ready`.
- [ ] GIVEN load has already happened once this session, WHEN any subsequent save-triggering event occurs, THEN the system never re-enters `loading` — only `ready ↔ saving` for the rest of the session.

**Save/load round-trip correctness (scoped to ResourceManager + HistoryFlagManager only):**
- [ ] GIVEN a specific resource snapshot (via `ResourceManager`), WHEN saved then reloaded, THEN values match exactly.
- [ ] GIVEN specific milestone flags/counters (via `HistoryFlagManager`), WHEN saved then reloaded, THEN they match exactly.
- [ ] GIVEN a save already exists, WHEN a second save is triggered after further changes, THEN the new file is a complete, independent snapshot — loading it never references the prior file.
- [ ] GIVEN any save write, WHEN the file is inspected, THEN it contains a correct `schema_version` and a `last_saved_at` matching that write's time.

**Defined edge cases:**
- [ ] GIVEN no save file exists, WHEN the app starts, THEN defaults initialize, `ready` reached, no error surfaced.
- [ ] GIVEN a corrupted/unparseable save file, WHEN load is attempted, THEN falls back to defaults, `ready` reached, no crash/error shown.
- [ ] GIVEN a save write in progress (`saving`, temp-file step), WHEN the app is killed before atomic rename, THEN the previously complete save loads intact on next launch — no partial data. *(Simulated via file-system state assertions — see Implementation Notes — not a literal process kill.)*
- [ ] GIVEN a save write completes its rename step, WHEN inspected, THEN the file reflects the full new snapshot, no remnant of the previous save.
- [ ] GIVEN a `schema_version` mismatch in an otherwise valid file, WHEN load is attempted, THEN discarded — defaults initialize, `ready` reached, no partial migration attempted.
- [ ] GIVEN a completed save operation, WHEN the app restarts, THEN only the final renamed file is read — any stray temp file from an interrupted prior operation is never loaded.

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines + GDD Detailed Design § Core Rules:*

```gdscript
extends Node

const SAVE_PATH: String = "user://save.json"
const TEMP_PATH: String = "user://save.tmp"
const SCHEMA_VERSION: int = 1

enum State { UNINITIALIZED, LOADING, READY, SAVING }
var _state: State = State.UNINITIALIZED

func _ready() -> void:
    _state = State.LOADING
    var data: Dictionary = load_save()
    ResourceManager.restore_state(data.get("resources", {}))
    HistoryFlagManager.restore_state(data.get("history_flags", {}))
    _state = State.READY

func save_now() -> void:
    _state = State.SAVING
    var data: Dictionary = {
        "schema_version": SCHEMA_VERSION,
        "last_saved_at": Time.get_unix_time_from_system(),
        "resources": ResourceManager.serialize_state(),
        "history_flags": HistoryFlagManager.serialize_state(),
        "decision_card_state": {"cooldown_actions_remaining": 0, "resolved_milestone_cards": []},
    }
    var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    file.close()
    var err := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
    if err != OK:
        push_error("Save rename failed: %s — .tmp file retained for retry" % err)
        _state = State.READY
        return
    _state = State.READY

func load_save() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed == null or typeof(parsed) != TYPE_DICTIONARY or parsed.get("schema_version") != SCHEMA_VERSION:
        return {}
    return parsed
```

- **`ResourceManager` and `HistoryFlagManager` each need a new `restore_state(data: Dictionary) -> void` and `serialize_state() -> Dictionary` method** as part of this story's scope (per ADR-0003's restore_state contract) — neither currently has one (Sprint 1/2 didn't need persistence). `restore_state({})` (the first-session/empty case) must default every value safely, matching each module's existing in-memory defaults.
- **`decision_card_state` is written as a fixed placeholder**, never read back into any real module (none exists yet) — this is intentional, not a bug, and not round-trip-tested.
- **Atomic-write-survives-kill is simulated**, not tested via a literal process kill: write to `TEMP_PATH`, intentionally do NOT call `rename_absolute()`, then assert `FileAccess.file_exists(SAVE_PATH)` still returns the previous save's content unchanged (or `{}` first-session) and `load_save()` ignores the stray `.tmp` file entirely.
- **No `class_name`**, matching `resource_manager.gd`/`action_system.gd`/`history_flag_manager.gd`'s existing no-`class_name` Autoload convention.
- **Autoload registration**: insert `SaveSystem` in `project.godot` between `HistoryFlagManager` and `ActionSystem` — the canonical order's `CardContentDatabase` slot doesn't exist yet, so it's simply skipped, not left as a gap.
- **`Time.get_unix_time_from_system()`**, never `OS.get_unix_time()` (removed in Godot 4) — per ADR-0003's engine compatibility note, explicitly re-flagged here since this is the first story to need a timestamp.

---

## Out of Scope

*Handled by neighbouring stories / future epics — do not implement here:*

- Story 002: the `mark_dirty()` debounce/coalescing mechanism and the mobile lifecycle flush — this story only implements the underlying `save_now()`/`load_save()` write/read mechanics that Story 002 will trigger on a timer.
- Decision Card System (future epic): real `decision_card_state` round-trip (cooldown state, `resolved_milestone_cards`) — this story writes a fixed placeholder only. A follow-up story must extend `save_now()`/`load_save()` and add the round-trip test once that epic exists.
- Offline Progress System (future epic): consuming `last_saved_at` to compute `Δt` — this story only writes the field correctly; consumption is downstream, undesigned work.
- Schema migration logic — explicitly out of scope per the GDD; a version mismatch is always treated as "file doesn't exist," never partially migrated.
- Storage-full write failure, concurrent/multi-instance write protection — not yet designed per the GDD's own "not testable against this GDD alone" list.

---

## QA Test Cases

*Sourced from `production/qa/qa-plan-sprint-3-2026-06-24.md` (Automated Tests Required § 3-2), split to this story's scope. Decision Card System items from the original plan are excluded per the AC amendment above.*

- **AC-1**: first launch, no save file
  - Given: no `user://save.json` exists
  - When: app initializes
  - Then: `uninitialized → loading → ready`; `ResourceManager`/`HistoryFlagManager` report defaults
  - Edge cases: confirms the empty-`{}` path through `restore_state()` for both modules

- **AC-2**: launch with a valid existing save
  - Given: a valid, schema-matching save file
  - When: app starts and loads it
  - Then: `uninitialized → loading → ready`; both modules' state matches the file
  - Edge cases: round-trip values must match exactly, not approximately

- **AC-3**: triggered save transitions state
  - Given: `ready`
  - When: `save_now()` called
  - Then: `ready → saving → ready`
  - Edge cases: state must return to `ready`, not get stuck in `saving`

- **AC-4**: no re-entering `loading` mid-session
  - Given: load already happened once this session
  - When: any subsequent save-triggering event occurs
  - Then: only `ready ↔ saving` thereafter, never back to `loading`
  - Edge cases: trigger multiple saves in sequence to confirm

- **AC-5**: resource snapshot round-trip
  - Given: a specific `ResourceManager` snapshot
  - When: saved then reloaded
  - Then: values match exactly
  - Edge cases: use non-default values for at least 2 resources to avoid a false-positive on defaults

- **AC-6**: history flag round-trip
  - Given: specific milestone flags/counters via `HistoryFlagManager`
  - When: saved then reloaded
  - Then: match exactly
  - Edge cases: include at least one set milestone and one non-zero counter

- **AC-7**: independent snapshots
  - Given: a save already exists
  - When: a second save triggered after further changes
  - Then: the new file is complete and independent — loading it never references the prior file
  - Edge cases: change a value between saves and confirm only the latest value loads

- **AC-8**: schema_version and last_saved_at correctness
  - Given: any save write
  - When: the file is inspected
  - Then: correct `schema_version`, `last_saved_at` matches that write's time
  - Edge cases: compare `last_saved_at` against `Time.get_unix_time_from_system()` called immediately before/after, allowing for the call's own latency

- **AC-9**: no save file → defaults
  - Given: no save file exists
  - When: app starts
  - Then: defaults initialize, `ready` reached, no error
  - Edge cases: same as AC-1, restated as the GDD's own edge case

- **AC-10**: corrupted file → defaults
  - Given: a corrupted/unparseable save file
  - When: load attempted
  - Then: falls back to defaults, `ready` reached, no crash
  - Edge cases: write deliberately malformed JSON to `user://save.json` before the test

- **AC-11**: kill before atomic rename → previous save survives
  - Given: a save write in progress (temp-file step)
  - When: the rename step is intentionally skipped (simulated kill)
  - Then: the previously complete save loads intact, no partial data
  - Edge cases: assert via file-system state, not a literal process kill (per Sprint 3 risk register)

- **AC-12**: completed rename → full new snapshot
  - Given: a save write completes its rename step
  - When: inspected
  - Then: file reflects the full new snapshot, no remnant of the previous save
  - Edge cases: confirm `.tmp` file no longer exists after a successful rename

- **AC-13**: schema_version mismatch → defaults, no migration
  - Given: a `schema_version` mismatch in an otherwise valid file
  - When: load attempted
  - Then: discarded, defaults initialize, `ready` reached, no partial migration
  - Edge cases: write a valid JSON file with `schema_version: 999` and confirm full fallback

- **AC-14**: stray temp file never loaded
  - Given: a completed save operation, plus a stray leftover `.tmp` file from a prior interrupted operation
  - When: app restarts
  - Then: only the final renamed file is read; the stray `.tmp` is ignored
  - Edge cases: write a `.tmp` file with different content than `.json` and confirm the `.json` content wins

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/save_persistence_system/save_core_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (Foundation layer; `ResourceManager` and `HistoryFlagManager` — the two peer systems this story integrates with — are both already Complete)
- Unlocks: Story 002 (Debounce/Coalescing & Mobile Lifecycle Flush builds on this story's `save_now()`/`load_save()`)

---

## Completion Notes
**Completed**: 2026-06-24
**Criteria**: 14/14 passing (none deferred; AC-1/AC-9 are the literal same GDD scenario, merged into one test)
**Deviations**: None — `decision_card_state` placeholder per the story's explicit scope amendment; one code-review finding (unguarded `FileAccess.open()` null-deref risk) was fixed before this gate, not left open
**Test Evidence**: Integration — `tests/integration/save_persistence_system/save_core_test.gd`, 13/13 passing (full regression 103/103 passing, re-verified twice for isolation leakage)
**Code Review**: Complete — `/code-review` APPROVED (after one fix applied); LP-CODE-REVIEW gate APPROVE; QL-TEST-COVERAGE gate ADEQUATE
