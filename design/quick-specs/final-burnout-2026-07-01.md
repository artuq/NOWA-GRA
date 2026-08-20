# Quick Design Spec: Final Burnout (Era Transition)

**Type**: New Small System
**Scope**: Defines the trigger, mandatory choice card, and era-transition semantics for Final
Burnout — the game's only "real stake" mechanic. Does **not** specify the full
Prestige/Checkpoint implementation (system #17, systems-index.md) — that requires
`/design-system` in Alpha. This spec is the design anchor the Prestige/Checkpoint GDD builds
around.
**Date**: 2026-07-01
**Estimated Implementation**: Design anchor only — full implementation ~3–4 weeks in Alpha
alongside Prestige/Checkpoint System

> **REVISION (2026-07-17, ADR-0013)**: `era_count`, `_deferred_this_era`, the five-resource
> reset, and the META_BONUS grant now live on **`PrestigeSystem`** (ADR-0012, shipped and
> closed), not BurnoutSystem as originally specced below. BurnoutSystem's real scope is now
> just the trigger detector + forced-card mechanics (Core Rules 1-3) — Choice A/B (Core Rules
> 4-5) route synchronously into `PrestigeSystem.on_burnout_accepted()`/`on_burnout_deferred()`.
> The `era_transitioned(new_era, meta_bonus_granted)` signal below is now
> **`PrestigeSystem.era_transitioned`** (no arguments — read `get_era_count()`/
> `get_meta_bonus_total()` instead). `HistoryFlagManager.set_flag(...)` calls below are now
> **`set_milestone(...)`** (the real shipped method name). See ADR-0013's ownership-split table
> for the authoritative correction before implementing any BurnoutSystem story.

## Overview

When the player sustains Cringe at 100 for `BURNOUT_THRESHOLD` continuous seconds in active
play, a mandatory Decision Card — *"Wypalenie"* (Final Burnout) — is force-injected into the
DecisionCardSystem, bypassing normal pool selection and cooldowns. The player faces a genuine
binary choice: **(A) Accept Burnout** — era ends, all resources reset, and one permanent
meta-bonus carries forward into the next era; or **(B) Defer Once** — pay
`BURNOUT_DEFER_MORALE_COST` Morale to postpone, usable only once per era. This is not a
game-over. It is a narrative checkpoint: build empire → inevitable burnout → era reset =
structural satire (Pillar 3). The player always chooses; nothing is done to them without
consent (Pillar 2).

## Core Rules

### 1. Trigger

- A new Autoload `BurnoutSystem` tracks `_cringe_sustained_seconds: float` via `_process(delta)`.
- `ActionScreen` explicitly enables the detector for its lifecycle and disables it on teardown.
  Boot, Start, Offline Report, and Challenge Selection never enable it. Leaving active play pauses
  the accumulated live-play time without resetting it or emitting a warning cancellation.
- Each live-play frame: if Cringe ≥ 100.0 → `_cringe_sustained_seconds += delta`. If Cringe
  < 100.0 → `_cringe_sustained_seconds = 0.0`.
- When `_cringe_sustained_seconds >= BURNOUT_THRESHOLD` **and** `_card_pending == false`:
  inject the Burnout Card and set `_card_pending = true`. Reset `_cringe_sustained_seconds = 0.0`.
- Offline simulation does **not** increment `_cringe_sustained_seconds`. `restore_state()`
  resets the timer to 0.0 — each session starts fresh (no "surprise burnout" on app open,
  Pillar 4).

### 2. Warning State

- When `_cringe_sustained_seconds >= BURNOUT_WARNING_THRESHOLD`: emit
  `burnout_warning_changed(true, seconds_remaining: float)` — seconds remaining =
  `BURNOUT_THRESHOLD - _cringe_sustained_seconds`.
- Each subsequent frame while warning is active: emit
  `burnout_warning_changed(true, seconds_remaining)` (for HUD countdown).
- If Cringe drops below 100 while warning is active: emit `burnout_warning_changed(false, 0.0)`
  and reset timer.
- HUD wires to this signal for a visible countdown (separate UI story — same pattern as
  `shield_changed`).

### 3. The Burnout Card

- Card ID: `BURNOUT_CARD_ID` (a dedicated entry in CardContentDatabase, not drawn from the
  normal pool).
- Force-injected via `DecisionCardSystem.inject_priority_card(BURNOUT_CARD_ID)` — bypasses
  cooldown, weighting, and the normal eligible pool entirely. Presented immediately on the
  next available frame after injection.
- **Cannot be dismissed** without choosing A or B. No swipe-to-background. ActionSystem
  auto-suspends (same behaviour as `card_presented` signal already triggers). A `_card_pending`
  boolean on BurnoutSystem prevents any normal card from appearing while the Burnout Card is
  active.
- Full-screen emphasis presentation (visual treatment = separate UI story; mechanically
  identical to a normal card but with different scene/chrome).

### 4. Choice A — Accept Burnout

1. `era_count += 1` (new meta-state on BurnoutSystem, persisted).
2. All five resources reset to era-start defaults: Cringe=0, Morale=100, Haters=0, Reach=0,
   Sponsors=0.
3. All queued actions cleared (`ActionSystem.clear_queue()`).
4. History flags: **era-local flags cleared**; **meta-persistent flags preserved** (exact
   classification defined in Prestige/Checkpoint GDD — this spec defers to it).
5. One `META_BONUS` granted. **Shape**: a single stackable persistent upgrade that carries
   across all future eras. **Content**: defined by Prestige/Checkpoint GDD — this spec commits
   only to the shape (one bonus per accepted burnout, additive stack, bounded max TBD).
6. `HistoryFlagManager.set_flag("burnout_accepted_era_" + str(era_count))`.
7. `_deferred_this_era = false` (resets for new era).
8. `_card_pending = false`.
9. Signal: `era_transitioned(new_era: int, meta_bonus_granted: StringName)`.

### 5. Choice B — Defer (once per era)

- Available only if `_deferred_this_era == false`. If already deferred, Choice B is shown
  greyed with tooltip: *"Już raz odłożyłeś/aś wypalenie — tym razem musisz wybrać."*
- `ResourceManager.apply_delta({&"Morale": -BURNOUT_DEFER_MORALE_COST})` (Morale clamps at
  0 — survivable, not a death spiral; Morale recovers normally after).
- `_deferred_this_era = true`.
- `_cringe_sustained_seconds = 0.0`.
- `_card_pending = false`.
- `HistoryFlagManager.set_flag("burnout_deferred_era_" + str(era_count + 1))`.
- Signal: `burnout_deferred(era: int, morale_cost: float)`.

### 6. Persistence

`BurnoutSystem.serialize_state()` / `restore_state()` persists:
- `era_count: int`
- `_deferred_this_era: bool`
- `_card_pending: bool` — persisted (if app closes mid-card, card re-presents on next boot)
- `_cringe_sustained_seconds`: **NOT** persisted — resets to 0.0 at restore_state (offline
  safety, Pillar 4).

## Tuning Knobs

| Knob | Default | Range | Category | Rationale |
|------|---------|-------|----------|-----------|
| `BURNOUT_THRESHOLD` | 300s (5 min) | 120–600s | gate | 5 min at Cringe=100 = significant pressure before trigger; survives offline gaps |
| `BURNOUT_WARNING_THRESHOLD` | 180s (3 min) | 60–BURNOUT_THRESHOLD | feel | 2 min of visible countdown before trigger — enough time to react |
| `BURNOUT_DEFER_MORALE_COST` | 50.0 | 20–70 | feel/gate | Half of max — meaningful cost that doesn't guarantee death-spiral at low Morale bands |
| `BURNOUT_CARD_ID` | `"final_burnout"` | — | config | CardContentDatabase key |

All numeric values must live in `assets/data/balance.json` (or equivalent), not hardcoded.

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| ResourceManager | Read Cringe; apply_delta for defer cost; reset all 5 resources on accept | No structural change — existing API |
| DecisionCardSystem | `inject_priority_card()` method needed (new API, not currently in GDD) | Add injection path — design at Prestige/Checkpoint GDD time |
| ActionSystem | Already suspends on `card_presented` — no change | No action |
| HistoryFlagManager | `set_flag()` — already exists | No action |
| SaveSystem | BurnoutSystem added to serialize/restore cycle | Add at implementation time |
| ActionScreen | Owns the ephemeral live-play enable/disable boundary | Lifecycle calls only |
| Prestige/Checkpoint System | **Designed around this spec** — defines META_BONUS content, flag classification (era-local vs meta-persistent), era-start default values | Full GDD required (Alpha) |

## Acceptance Criteria

- [ ] `_cringe_sustained_seconds` increments only when Cringe = 100.0; resets to 0.0 when Cringe < 100.0
- [ ] The timer is paused outside ActionScreen (including Start, Offline Report, and Challenge Selection) and resumes when live play returns
- [ ] Burnout Card injected exactly once when timer reaches `BURNOUT_THRESHOLD`; not re-injected while `_card_pending`
- [ ] Warning signal emitted when timer ≥ `BURNOUT_WARNING_THRESHOLD`; cancelled when Cringe drops below 100
- [ ] Burnout Card cannot be dismissed without A or B; normal card pool suspended while card is active
- [ ] Choice A: all 5 resources reset to era-start defaults; `era_count` increments; meta-bonus flag set; `era_transitioned` signal emitted
- [ ] Choice B: `BURNOUT_DEFER_MORALE_COST` deducted; `_deferred_this_era = true`; timer resets; `burnout_deferred` signal emitted
- [ ] After deferral, Choice B is greyed/unavailable on next trigger in same era
- [ ] `_card_pending` persists across save/load; Burnout Card re-presents on next boot if interrupted mid-choice
- [ ] `_cringe_sustained_seconds` does NOT persist — resets to 0.0 on restore_state
- [ ] Offline simulation (OfflineProgressSystem.simulate_offline()) does not trigger or advance the burnout timer

## Systems Index

Prestige/Checkpoint System (#17) is already in `design/gdd/systems-index.md` (Alpha, Feature
layer). This quick-spec is the foundational design anchor — reference it in the
Prestige/Checkpoint GDD's Context section when `/design-system prestige-checkpoint` runs in
Alpha.

**No systems-index update required** for this spec alone** — BurnoutSystem is a sub-component
of the Prestige/Checkpoint epic, not a standalone tracked system.

## DDR Reference

**DDR-0001 #5 ruling** (`design/decisions/ddr-0001-post-mvp-mechanics-pillar-rulings.md`):
> "Must be a narrative checkpoint / era-transition, never a game-over; the card needs genuine
> binary stakes (accept burnout & reset with a meta-bonus, OR defer once at a large Morale
> cost) so it stays 'a decision with memory,' not something done to the player without consent.
> Design it now so the Prestige/Checkpoint System (Alpha) is built around it, not retrofitted."

## Open Questions

- **Action-count trigger as an alternative to real-time `BURNOUT_THRESHOLD`** (added 2026-07-22, external designer feedback via user) — current trigger is sustained wall-clock time (300s default) at Cringe=100. Critique: for a mobile session, several real-time minutes staring at a ceiling value risks boredom, and backgrounding the app during the countdown loses the tension entirely. Proposed alternative: gate on a count of decision cards drawn while at Cringe=100 (e.g., "Wypalenie appears after 5 cards pulled at max Cringe") instead of elapsed seconds. This would match the project's existing precedent — Decision Card cooldown is already action-count-based, not time-based (`docs/registry/architecture.yaml` api_decision, ADR-0005) — so a card-count trigger here would be internally consistent with that convention, not a novel mechanic. **Not evaluated for balance/feel yet** — would change `BurnoutSystem`'s `_process(delta)` timer-accumulation model (Core Rule 1) to a card-count listener instead, and would ripple into `wypalenie-card-modal.md`'s Player Context on Arrival (currently assumes a felt real-time countdown) and the HUD warning indicator's display format (seconds remaining vs. cards remaining). *Owner: unassigned — real alternative worth a design pass, not a tuning-knob tweak, before Alpha implementation of BurnoutSystem's trigger.*
- **In-card stalling minigame ("swipe away hater comments") to buy decision time** (added 2026-07-22, external designer feedback via user) — proposed as a physical, frantic interaction during the Wypalenie card window, distinct from the actual A/B choice. Tension with the just-designed `wypalenie-card-modal.md` (Core Rule 3: "cannot be dismissed without choosing A or B," and DDR-0001 #5's "genuine binary stakes," immediate-weight framing) — adding a delay/busywork layer before the real choice may dilute rather than sharpen the moment's weight, though it isn't strictly forbidden by any anti-pillar (it's new scope, not a rule violation). *Owner: unassigned — needs a Player Fantasy discussion (does stalling serve the "one truly heavy choice" feeling, or undercut it?) before any design work starts.*
