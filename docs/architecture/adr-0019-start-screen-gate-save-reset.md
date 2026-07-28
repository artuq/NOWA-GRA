# ADR-0019: Start Screen Gate + New Game Save Reset

## Status
Proposed (2026-07-28 — code shipped same session, BUG-005 fix; needs independent `/architecture-review` in a fresh session to move to Accepted, same pattern as ADR-0018 which also shipped ahead of formal acceptance and was verified accurate)

## Date
2026-07-28

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | Core / Scene Management, Save Persistence |
| **Knowledge Risk** | LOW — `change_scene_to_file()`, `DirAccess.copy_absolute()`, static script vars are stable pre-4.3 patterns; same domain as ADR-0002/0003 |
| **References Consulted** | `adr-0002-save-file-format-atomic-write.md`, `adr-0003-scene-management-boot-order.md`, `adr-0009-offline-report-screen-scene-data-handoff.md`, `production/qa/bugs/BUG-005-no-new-game-reset-save-feature.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Web export: confirm the start screen renders and both exits work in the browser build (scene registered in export) |
| **Engine Specialist Validation** | Pending (fold into the `/architecture-review` pass) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted — atomic write reused for the fresh save), ADR-0003 (Accepted — boot sequence this gate wraps), ADR-0007 (Accepted — Button-based touch targets, inline confirm instead of a `ConfirmationDialog` Window) |
| **Enables** | BUG-005 closure; clean-slate playtests without manual save-file surgery |
| **Ordering Note** | ADR-0003's boot sequence is unchanged — the start screen is a gate *in front of* it, and both exits re-enter `boot.tscn` so ADR-0003 remains the only boot path. |

## Context

### Problem Statement
BUG-005: the game always resumes `user://save.json`; no in-app way to start fresh. Playtest 12-3 hit this live (T5 save resumed when a fresh game was expected; workaround was manual file renaming). User decision 2026-07-28: solve it with a start screen (Continue / New Game), not a Settings-buried reset button.

### Constraints
- First-time players must NOT see the screen — the first-card hook (quick-spec 2026-07-06) exists to get a new player into gameplay near-instantly on portals (15-second rule); a one-option screen would be pure friction.
- New Game is destructive (wipes meta-progression, a documented one-way ratchet) — needs confirmation and should not vaporize the only copy of the save.
- `reduce_motion` (SettingsSystem) is an accessibility preference, not progression — it must survive the wipe (art-bible §7 MANDATE would otherwise be silently reset).
- Test isolation (Sprint 9, 9-3): all new file paths must repoint under GdUnit like `SAVE_PATH`/`TEMP_PATH` do.

## Decision

1. **Start screen as a boot gate, not a boot replacement.** `BootController._ready()` routes to `start_screen.tscn` when `should_show_start_screen(data, _start_screen_shown)` — i.e. the save has real progress (`has_progress()`: a `"resources"` block exists) AND the screen hasn't been offered this app launch (`static var _start_screen_shown`, session-scoped, survives the scene round-trip, resets each process). Both exits set nothing themselves — they `change_scene_to_file()` back to `boot.tscn`, and the flag makes the second pass fall through to the normal ADR-0003 sequence. Offline sim therefore runs on Continue (elapsed keeps accruing while the screen is up — correct, not a bug).
2. **Fresh players skip it.** `{}` (first session) and the post-reset settings-only save both fail `has_progress()` → straight into the game, first-card hook intact.
3. **`SaveSystem.reset_save() -> bool`** (New Game): stop the debounce timer (pre-reset in-memory state must not re-persist), copy `SAVE_PATH` → `BACKUP_PATH` (`user://save.backup.json`, single rolling slot), then atomically write a minimal fresh save: `schema_version` + `last_saved_at` + `settings` only. If the backup copy fails, return `false` and leave the save untouched — never delete the only copy. The shared atomic tail is extracted as `_write_atomic()` (used by `save_now()` and `reset_save()`), ADR-0002 semantics unchanged.
4. **Inline confirm, not a `Window`.** The destructive confirm is plain Controls inside the scene (backdrop + panel + Delete/Cancel), per ADR-0007's Button-based touch-target rule and to avoid `ConfirmationDialog`/`Window` behavior differences in the web export.
5. **Test seams follow the house pattern**: `scene_swap_requested(path)` signal + retargetable `boot_scene_path` (OfflineReportScreen precedent), routing predicate static and argument-driven.

## Consequences

**Positive**: BUG-005 closed; clean-slate playtests in-app; accidental-tap-proof (confirm + rolling backup, the exact manual workaround from 2026-07-27 now automatic); zero change to ADR-0003's sequence or its tests (all drive `boot_with()` directly).

**Negative / accepted trade-offs**: returning players pay one extra tap per cold boot (user decision — accepted for the ceremonial entry and future save-slot room); one rolling backup only (a second New Game overwrites the first backup — deliberate, not a save-slot system); Burnout/Challenge Autoloads are not re-restored on reset because they are not persisted at all yet (their save wiring is a known, separately-tracked gap — when it lands, `boot_with()`'s restore list and this reset flow pick it up together).

**Files**: `src/core/boot_controller.gd`, `src/core/save_system.gd`, `src/ui/start_screen.gd` (NEW), `scenes/start_screen/start_screen.tscn` (NEW), `tests/integration/start_screen/start_screen_flow_test.gd` (NEW, 5 tests), `tests/integration/save_persistence_system/reset_save_test.gd` (NEW, 5 tests).
