# VERTICAL SLICE - NOT FOR PRODUCTION

**Validation Question**: Does a player, starting from nothing, experience the core
fantasy (control over their "content business" + first satirical card choice) within
3-5 minutes, without developer guidance — and can we build one such loop in 1-3
weeks at representative quality?

## How to run

1. Open Godot 4.6.3, "Import" this directory (`project.godot` is at this folder's root).
2. Press Play (or F5). A one-line framing screen appears ("Everyone's watching.
   Act accordingly — or don't.") — tap anywhere to dismiss (shown once per session,
   added after a playtest found players had no context for why they were clicking).
3. Tap/click any of the 3 action buttons ("Record a Vlog", "Start Drama", "Apologize Online").
   Each runs its timer (4-9s) with a live progress bar.
4. Complete all 3 different action types at least once (repeating one type doesn't count,
   per onboarding-tutorial.md's variety-gate) — the first Decision Card then appears
   after your next completed action.
5. Swipe (or click-drag with mouse) the card left/right past ~30% of screen width,
   or flick it quickly, to commit to an option. Releasing short of that bounces it back.
6. After committing, the card shows a short **resolution reaction** (e.g. "Sponsorship
   logged. 3 viewers asked if the product works. 0 received an answer.") with a
   scale-pulse/shake scaled by how big the outcome was — then the card closes on its own.
7. Resource values (Reach, Cringe, Haters, Morale, Sponsors) update live in the top
   HUD, with a brief flash on each changed value, after every action and card resolution.

**Language note**: player-facing content (UI labels, action names, card copy) is in
English per project decision (2026-06-20) — this is now the target player-facing
language for the whole game, not just this slice. Internal GDD/design-doc terminology
may still reference the original Polish names; treat the English versions here as
authoritative for what ships to players going forward.

## Scope (what's IN this slice)

- Resource System (5 currencies, in-memory)
- Action System (3 actions, Timer + single-concurrency — ADR-0004)
- Onboarding/Tutorial gate (variety-gate, force-cooldown-zero — onboarding-tutorial.md)
- Decision Card System (weighted pick by Cringe, action-count cooldown — ADR-0005)
- Card Content Database — **3 REAL cards with actual satirical copy** (not placeholder
  text), per the Creative Director's explicit condition at the Pre-Production gate-check
- Action UI (3-zone layout: HUD, Action Grid, Running Action Overlay)
- Card UI (swipe-to-commit, distance OR velocity, per card-ui.md's formulas)
- **Juice/Feedback System** (added after the 1st run's PIVOT) — magnitude formula,
  resource-label flash on Action System events, scale-pulse + shake (scaled by
  magnitude, never valence) + **resolution payoff text** (Reigns-style reaction)
  on Decision Card resolution. **No audio** — no sound assets exist in this slice;
  the audio stinger channel from `juice-feedback-system.md` is unimplemented here.
- **Floating delta popups** ("+3 Sponsors" style, size/lift scaled by magnitude) —
  added after 2nd-run feedback that the HUD flash alone was too subtle to register
  as a reward ("I do it and forget it"). Not in the original GDD as a named pattern;
  treat as a candidate addition to `juice-feedback-system.md` if it proves effective.

## Scope (what's OUT of this slice)

- Save/Persistence System — no save/load, state resets on relaunch
- Offline Progress System / Offline Report Screen
- The remaining 9 of 12 cards (full Card Content Database)
- Locked Action Grid slots (no `unlock_threshold` source of truth exists yet — flagged
  gap in action-ui.md, correctly out of scope here too)
- Any real art (placeholder Godot default theme throughout)

## Known limitations of this slice's code (NOT production patterns)

- UI built procedurally in `main.gd` rather than hand-authored `.tscn` node trees —
  faster to build/iterate for a throwaway slice, but production should use proper
  scene composition per `docs/architecture/architecture.md`'s Module Ownership.
- No `restore_state()` methods (ADR-0003's boot sequence) — this slice has no save,
  so there's nothing to restore.
- Single `main.gd` script owns all UI — production splits this into Action UI / Card UI
  per their respective GDDs and the Module Ownership map.
