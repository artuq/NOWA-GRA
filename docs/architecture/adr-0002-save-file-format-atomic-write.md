# ADR-0002: Save File Format and Atomic Write Strategy

## Status
Accepted (2026-06-20, following independent /architecture-review — verdict CONCERNS overall but no conflicts or blockers against this ADR specifically)

## Date
2026-06-19

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | Core (Save/Load) |
| **Knowledge Risk** | LOW — `FileAccess`, `JSON`, and file rename operations are stable, pre-4.3 APIs; no documented 4.4-4.6 breaking change touches this domain |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Low residual risk: `user://` on Android maps to private internal storage (`getFilesDir()`), not scoped storage/SAF — a same-volume `rename()` there is a real POSIX rename and is atomic at the filesystem level, same as desktop. No device verification required beyond standard QA. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload singleton architecture) — `SaveSystem` is implemented as the Autoload that owns this file format, per ADR-0001's state ownership table |
| **Enables** | ADR-0003 (Scene management/boot order) — boot sequence's first step (`SaveSystem.load_save()`) depends on this format being defined |
| **Blocks** | Any Core/Foundation epic involving persisted state (ResourceManager, HistoryFlagManager, DecisionCardSystem cooldown, OnboardingGate phase) |
| **Ordering Note** | None beyond the above |

## Context

### Problem Statement
`Król Cringe'u` is a mobile idle game where the OS can kill the app process at any moment (backgrounding, low memory, user force-quit) with no guaranteed shutdown hook beyond a pause/suspend notification. The save system must guarantee that an interrupted write never corrupts the previous save — a half-written file is worse than a slightly stale one. `save-persistence-system.md` already specifies the high-level behavior (2s debounce, mobile lifecycle flush, `schema_version` field, corruption → reset fallback); this ADR fixes the concrete file format and write mechanism that implements it.

### Constraints
- Godot 4.6.3, GDScript, Android primary target (iOS later)
- No threading (per `architecture.md` Principle 1) — write must be fast enough to run synchronously without blocking a frame noticeably
- Must survive process kill at any point during a write without corrupting the prior save
- Must support a `schema_version` field for future migration (per `save-persistence-system.md`)

### Requirements
- Save data must be human-readable for debugging during development (favors JSON over binary)
- Write must be atomic from the OS's perspective: either the new save is fully there, or the old one still is — never a partial file
- Must integrate with `SaveSystem.mark_dirty()` / `save_now()` / `load_save()` interface already locked by ADR-0001

## Decision

Use **JSON** as the save file format, written via **temp-file-write-then-rename** for atomicity:

1. Serialize game state to a `Dictionary`, convert via `JSON.stringify()`.
2. Write the JSON string to `user://save.tmp` via `FileAccess.open(path, FileAccess.WRITE)`.
3. Close the file handle explicitly (forces flush).
4. Rename `user://save.tmp` to `user://save.json` via `DirAccess.rename_absolute()`, overwriting the previous save in a single filesystem operation.
5. On load: if `user://save.json` is missing, corrupted (JSON parse failure), or has an unrecognized `schema_version`, treat as first session (per `save-persistence-system.md`'s existing fallback rule) — never crash.

If the process is killed between steps 1-3, `save.json` (the previous save) is untouched — the `.tmp` file is simply discarded/overwritten on the next write attempt. If killed during step 4 (the rename itself), the filesystem's rename is a single atomic operation at the OS level — there is no partial-rename state to land in.

### Architecture Diagram
```
[Game state mutation] -> SaveSystem.mark_dirty() -> debounce Timer (2s) -or- lifecycle pause signal
                                |
                                v
                    SaveSystem.save_now()
                                |
                                v
            Dictionary -> JSON.stringify() -> write to user://save.tmp
                                |
                                v
                  DirAccess.rename_absolute(save.tmp -> save.json)   [atomic swap]
```

### Autosave suppression window *(added 2026-07-13, `/propagate-design-change` on `prestige-checkpoint-system.md`'s `/design-review`)*

`save-persistence-system.md` triggers autosave on card-resolution events via `mark_dirty()`'s 2s debounce (Architecture Diagram above). Prestige/Checkpoint System's era-transition sequence needs a bounded window where that trigger is inert — Choice A's resolution IS a card resolution, so an unmodified autosave could fire mid-sequence (after meta-bonus grant, before the flag sweep completes) and persist a half-transitioned state. This is a new capability layered on top of the existing debounce/`save_now()` flow, not a change to it:

```gdscript
func suppress_autosave() -> void:
    _autosave_suppressed = true
    # any pending debounce Timer is NOT cancelled — only prevented from
    # firing save_now() while suppressed; it re-arms normally on resume

func resume_autosave() -> void:
    _autosave_suppressed = false
```

`mark_dirty()`'s debounce Timer callback checks `_autosave_suppressed` before calling `save_now()` and no-ops (re-checking on the timer's next natural fire, not queuing a catch-up call) if suppressed. Lifecycle-pause-triggered saves (app backgrounding) are **not** subject to this flag — an OS-initiated background-kill risk always takes priority over an in-progress logical transition; the suppression only governs the routine 2s-debounce path. Callers MUST pair every `suppress_autosave()` with a `resume_autosave()` in the same synchronous call chain (no `await` between them, same constraint as `prestige-checkpoint-system.md`'s call-contract lock) — an unpaired suppression would silently disable autosave indefinitely.

### Key Interfaces
```gdscript
# SaveSystem (Autoload) — interface locked by ADR-0001, implementation defined here
const SAVE_PATH = "user://save.json"
const TEMP_PATH = "user://save.tmp"
const SCHEMA_VERSION = 1

func suppress_autosave() -> void  # added 2026-07-13, see Autosave suppression window above
func resume_autosave() -> void    # added 2026-07-13, see Autosave suppression window above

func save_now() -> void:
    var data := _gather_state()  # Dictionary, includes "schema_version": SCHEMA_VERSION
    var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    file.close()  # flushes userspace buffers; does not fsync — acceptable for partial-write
                  # protection (this ADR's actual goal), not airtight against power-loss-class failure
    var err := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
    if err != OK:
        push_error("Save rename failed: %s — .tmp file retained for retry" % err)
        return
    save_flushed.emit()

func load_save() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}  # triggers first-session init
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed == null or typeof(parsed) != TYPE_DICTIONARY or parsed.get("schema_version") != SCHEMA_VERSION:
        return {}  # corrupted or unrecognized schema -> first-session fallback
    return parsed
```

## Alternatives Considered

### Alternative A: Godot `ConfigFile`
- **Description**: Use Godot's built-in `ConfigFile` class (INI-style sections/keys) for save data.
- **Pros**: Built-in, no manual JSON parsing needed, handles some type coercion automatically.
- **Cons**: INI format doesn't naturally express nested structures (the flag log and pattern counters in History Flag System are inherently nested/list-like) without flattening into awkward key names. Less human-readable for debugging arbitrary nested game state than JSON.
- **Rejection Reason**: Game state shape (nested dictionaries, lists of flags) doesn't fit `ConfigFile`'s flat key-value model well; would require manual flattening that JSON avoids natively.

### Alternative B: Binary `ResourceSaver` (.tres/.res)
- **Description**: Define save state as a custom `Resource` subclass, serialize via `ResourceSaver.save()`.
- **Pros**: Native Godot serialization, can save typed objects directly.
- **Cons**: Binary format isn't human-readable for debugging during a solo-dev development cycle. `Resource`-based save data couples save format to Godot's class system, making schema migration (`schema_version` bumps) more awkward — old `Resource` class shapes can become unloadable across engine versions in ways a plain JSON dictionary cannot.
- **Rejection Reason**: Debuggability and migration-safety lost for no compensating benefit at this project's save-data complexity (a handful of dictionaries/lists, not asset-like data).

### Alternative C: JSON + atomic temp-file-rename — CHOSEN
Described above. Matches `save-persistence-system.md`'s existing design intent exactly.

## Consequences

### Positive
- Atomicity guarantee holds even under process kill at any point except mid-rename, where the OS rename syscall itself is atomic
- JSON is trivially inspectable during development (open the file, read it)
- `schema_version` field gives a clean, simple migration path — bump the constant, branch on old value during `load_save()`

### Negative
- JSON write is a full-file rewrite each time (no incremental/delta save) — acceptable given this project's save data size (a handful of resources, flags, counters — not megabytes) and the 2s debounce already coalescing frequent mutations

### Risks
- **Risk**: `close()` flushes userspace buffers but does not call `fsync()` — under power-loss-class failure (not just process kill), the temp file's contents could theoretically not yet be on persistent storage when rename occurs.
  - **Mitigation**: Accepted residual risk — this ADR protects against partial-write corruption (the actual failure mode for an app-killed-by-OS scenario), not power-loss. Revisit only if real-world corruption reports surface.
- **Risk**: A `Dictionary`-shaped save with no schema enforcement beyond `schema_version` could silently accept malformed data if a future bug writes a bad dictionary.
  - **Mitigation**: Out of scope for this ADR — `save-persistence-system.md`'s corruption fallback (treat as first session) already covers the failure mode; stricter schema validation can be a future ADR if it becomes a real problem.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| save-persistence-system.md | Atomic write via temp-file + rename | Decision section steps 1-5 implement this exactly |
| save-persistence-system.md | `schema_version` field, increment-only | `SCHEMA_VERSION` constant + check in `load_save()` |
| save-persistence-system.md | Corruption/schema-mismatch → treat as first session | `load_save()` returns `{}` on any parse failure or version mismatch |
| save-persistence-system.md | 2s debounce, mobile lifecycle flush | Implemented at the `mark_dirty()`/`save_now()` call-site level (ADR-0001's interface), not redefined here |
| offline-progress-system.md | Reads `last_save_timestamp` to compute offline elapsed time | This ADR's save dictionary includes a timestamp field written on every `save_now()` call |

## Performance Implications
- **CPU**: Negligible — JSON serialization of a small dictionary (a few KB at most) runs well under a frame budget, and only happens at most every 2s (debounced) or on lifecycle pause
- **Memory**: Negligible — entire save data held in memory briefly during stringify/parse
- **Load Time**: Single small file read + JSON parse at boot — sub-millisecond for this data size
- **Network**: N/A

## Migration Plan
N/A — first save format for this project.

## Validation Criteria
- Manually kill the app process (via ADB `am kill` or force-stop) mid-save on a target Android device; confirm the previous save is intact on relaunch, never corrupted
- Confirm `load_save()` returns `{}` (not a crash) when given a hand-corrupted `save.json` (e.g., truncated mid-write)
- Confirm a `schema_version` mismatch (manually edit the saved value to `999`) triggers first-session fallback, not a crash

## Related Decisions
- ADR-0001 (Autoload singleton architecture) — defines the `SaveSystem` interface this ADR implements
- ADR-0003 (Scene management/boot order) — consumes `load_save()`'s return value as the first boot step
- `design/gdd/save-persistence-system.md` — source GDD this ADR implements
