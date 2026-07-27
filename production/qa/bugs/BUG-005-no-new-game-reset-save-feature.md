# BUG-005: No "New Game" / "Reset Save" feature — game always resumes the existing save, cannot start fresh in-game

**Severity**: S3 — Missing feature, no data loss/crash, but blocks a normal player expectation | **Status**: Open | **Found**: 2026-07-27 (Sprint 12 story 12-3, live playtest) | **Existed since**: project inception (never designed)

## Repro
1. Play far enough to unlock action slots 4-6 (Collab/Interview/Course) — i.e. make ≥6 risky-or-safe card choices and hit the two slot-6 milestone cards.
2. Re-launch the project (F5 from editor, or a fresh app open).
3. **Actual**: the game loads the existing `user://save.json` — all prior unlocks, era count, meta-bonus, resources persist. There is no way to start a genuinely fresh game from within the app.
4. **Expected (player mental model)**: "starting a new game" should present a fresh onboarding, 3 unlocked base actions + 3 locked slots, Reach 0 / Cringe 0 / Morale 100.

Observed in the wild: user re-ran expecting a fresh start, saw all 6 action slots unlocked + Reach 351 / Cringe 57 / a live `pato_streamer.best_tier.5` save. The save (`~/Library/Application Support/Godot/app_userdata/King of Cringe/save.json`) contained `risky_choices_count: 42`, `safe_choices_count: 8`, both slot-6 milestones set, `era_count: 1`, `META_REACH_MULT: 0.25` — i.e. the accumulated T5 playthrough, not a fresh game.

## Root cause (NOT a gating bug — gating works)
This is a missing feature, not a defect in existing code. Confirmed:
- `boot_controller.gd` / `save_system.gd` always `load_save()` + `restore_state()` on every module at boot from `user://save.json`.
- `HistoryFlagManager` exposes only `reset_counter(name)` (single counter) — no bulk clear, and milestones are a documented one-way ratchet (never cleared).
- The only save-deletion path in the codebase is test-only (`save_system.gd:62`, active only when `SAVE_PATH` is repointed to `save.test.json`).
- Action-slot unlocks (`action_unlocks.gd`) gate on monotonic counters + never-cleared milestones, so once unlocked they are permanent **for the life of the save file** — by design (meta-progression survives era resets; only a full save wipe would reset it).
- The gating logic itself is correct: `test_fresh_game_gated_slots_locked` passes on a fresh HistoryFlagManager (slots 4-6 lock when counters=0 / no milestones). The screenshot showed everything unlocked purely because the save persisted, not because the gate failed.

Key distinction: **era reset (Wypalenie)** wipes era-local state (affiliation, current resources) but keeps meta (unlocks, best-tier, meta-bonus). **New Game** is a different, unimplemented concept: wipe the *entire* save, meta included.

## Fix (not done — needs a design decision first)
Add a "New Game" / "Reset Save" affordance. Open design questions before implementing:
- Where does it live? (Settings screen is the natural home — `settings_screen.gd` exists.)
- Confirmation dialog required (destructive — wipes meta-progression). What copy/tone (deadpan, per art-bible §1)?
- Wipe scope: delete `user://save.json` and re-run the boot sequence into a fresh default state? Or a dedicated `reset_all()` across every Autoload? (File-delete + reboot is simpler and matches how the test path already does it.)
- Should the pre-wipe save be backed up automatically, or a hard wipe?

## Workaround (used 2026-07-27 for the playtest)
Renamed `save.json` → `save.backup-t5-2026-07-27.json` manually so the next boot starts fresh; the T5 save is recoverable by renaming back. Must stop any running instance first, or its autosave recreates `save.json` from in-memory state.
