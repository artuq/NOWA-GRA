# ADR-0018: Era-Transition Scene Swap — Challenge Selection Screen

## Status
Accepted (2026-07-24, following independent `/architecture-review` in a fresh session — verdict PASS: shipped code (commit 05d74f5, story 12-2) verified accurate to the ADR line-by-line, zero cross-ADR conflicts, engine-clean, all dependencies (ADR-0009/0014/0017) Accepted. TR-nav-005 registered.)

## Date
2026-07-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | Core / Scene Management |
| **Knowledge Risk** | LOW — `get_tree().change_scene_to_file()` and signal-driven scene swaps are stable, pre-4.3 patterns, same domain as ADR-0003/ADR-0009 |
| **References Consulted** | `docs/architecture/adr-0003-scene-management-boot-order.md`, `docs/architecture/adr-0009-offline-report-screen-scene-data-handoff.md`, `docs/architecture/adr-0014-main-navigation-coordinator.md`, `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Scene-transition timing on a real device across a live era transition (not just cold boot) before production |
| **Engine Specialist Validation** | `godot-specialist`, 2026-07-23 — confirmed synchronous `change_scene_to_file()` call and Autoload signal auto-cleanup on scene free are both safe. Found and fixed one blocking issue: an earlier draft's back-gesture snippet used `get_viewport().set_input_as_handled()`, a no-op for `NOTIFICATION_WM_GO_BACK_REQUEST` (that notification has no "handled" flag), and misattributed the pattern to ADR-0009 (which contains no back-gesture code at all — only ADR-0014 does). Corrected to reuse ADR-0014's exact mechanism verbatim (Decision point 5, Key Interfaces). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0009 (Accepted — standalone-scene precedent this extends), ADR-0014 (Accepted — `action_screen.gd` as scene-owned coordinator, the pattern this reuses rather than duplicates), ADR-0017 (Accepted — `PrestigeSystem.get_last_grant()`, the API this screen reads) |
| **Enables** | Challenge Selection Screen implementation (Sprint 12, story 12-2) |
| **Blocks** | 12-2 cannot start until this is Accepted; 12-3 (playtest of the full era loop) transitively blocked since it needs 12-2 |
| **Ordering Note** | ADR-0003 covers only boot-time scene sequencing; ADR-0014 covers only panel coordination *inside* `action_screen.tscn`. Neither covers a scene swap triggered by a runtime gameplay signal fired mid-session — that gap is what this ADR closes. |

## Context

### Problem Statement
`PrestigeSystem.era_transitioned` (a bare signal, no payload, `src/core/prestige_system.gd:65`) fires today with zero listeners anywhere in the codebase. `design/ux/challenge-selection-screen.md` requires that firing this signal immediately swap the live gameplay scene to a new `challenge_selection.tscn`, and swap back on Confirm — a full scene-to-scene round trip triggered by a runtime event, not by boot (ADR-0003) or by a panel-open action inside an already-active scene (ADR-0014). No existing ADR assigns ownership of "listen for `era_transitioned` and drive the scene swap."

### Constraints
- The live gameplay scene is `res://scenes/main/main.tscn` (project's `run/main_scene` is `res://scenes/boot/boot.tscn`, which hands off to `main.tscn` per ADR-0003) — `main.tscn` wraps `action_screen.tscn`'s content per ADR-0009's precedent. The UX spec's Navigation Position section says "`action_screen.tscn`"; this ADR corrects that to the actual live scene, `main.tscn`, without any GDD/UX-spec-visible behavior change (the content the player sees is the same either way).
- `era_transitioned` is bare — no payload today, and this ADR does not need to add one: the screen already resolves everything it needs (last grant, era number) via existing pull-model getters (`PrestigeSystem.get_last_grant()` per ADR-0017, `ChallengeSystem.get_challenge_data()`), not via signal arguments.
- The screen must appear "immediately... before any other era-start logic" (spec Rule 1) — the listener must act synchronously within the signal handler, not defer to a later frame or an `_process` poll.
- Confirm is the *only* exit; back-gesture/Esc must be ignored on this scene, same precedent as Offline Report Screen (ADR-0009's dismiss-gate, inverted — that screen has one required exit path too, just a different trigger).

### Requirements
- Scene swap must fire synchronously off `era_transitioned`, without introducing a new Autoload or a central event bus (forbidden pattern, `docs/registry/architecture.yaml`).
- Must not duplicate or compete with `MainNavCoordinator`'s (ADR-0014) `coordination_state` — that state machine governs panels *inside* `main.tscn`/`action_screen.tscn`; a scene swap leaves and re-enters the scene entirely, outside that state machine's scope by construction.
- Round-trip must return to the same live gameplay scene, not to boot or a fresh instance — `main.tscn`'s live in-memory state (any in-flight action timers, HUD state) does not need to survive the swap, since era transition already resets/re-derives gameplay-visible state (Core Rule 5 pattern established across Prestige/Challenge/Staff GDDs).

## Decision

**`main.tscn`'s own script (`action_screen.gd`, per ADR-0014's "scene-owned script coordinates scene-owned siblings" precedent) listens for `PrestigeSystem.era_transitioned` directly and drives the swap itself — no new Autoload, no new controller class.**

This mirrors ADR-0014's own resolution to an almost-identical question ("does a 4th coordinated surface justify extracting a new class?") by choosing the same answer: extend the existing scene-owned coordinator rather than introduce new machinery for one additional signal.

1. **Listener wiring**: `action_screen.gd`'s `_ready()` connects `PrestigeSystem.era_transitioned.connect(_on_era_transitioned)`, alongside its existing `MainNavCoordinator` signal connections (ADR-0014). This is a plain Autoload-signal connection — same shape as every other cross-system signal `action_screen.gd` already listens to (e.g. `DecisionCardSystem.card_presented`).

2. **`_on_era_transitioned()` calls `get_tree().change_scene_to_file("res://scenes/challenge_selection/challenge_selection.tscn")`** synchronously inside the handler — same idiom as ADR-0003's `BootController` and ADR-0009's dismiss handler. Per Godot's documented behavior (noted in ADR-0003), the actual swap is deferred to end-of-frame; nothing in `action_screen.gd` depends on `main.tscn` still being alive after this call, so the deferred-swap semantics are harmless here exactly as they were in ADR-0003/0009.

3. **No new signal payload, no new Autoload state.** `ChallengeSelectionScreen` (the new scene's script) reads everything it needs directly from existing pull-model getters in its own `_ready()`, the same pattern ADR-0009 established for Offline Report Screen reading `last_simulation_result`: `PrestigeSystem.get_last_grant()` (ADR-0017) for the recap header, `ChallengeSystem.get_challenge_data(id)` ×5 for the card catalogue, `ChallengeSystem.CHALLENGE_MAX_ACTIVE` for the cap. No constructor args, no scene-transition userdata, no transient Autoload field — unlike Offline Report Screen, every value here is already exposed via a queryable getter, so there is no missing-payload gap to bridge (Offline Report Screen needed `elapsed_seconds` added to a transient field only because `simulate_offline()`'s return shape lacked it; nothing analogous is missing here).

4. **Confirm drives the return swap.** `ChallengeSelectionScreen`'s Confirm handler calls `ChallengeSystem.select_challenges(challenge_ids)` (already-designed API, quick-spec Rule 3 — writes era-local flags via `HistoryFlagManager`), then `get_tree().change_scene_to_file("res://scenes/main/main.tscn")`. Symmetric with step 2: same idiom, opposite direction.

5. **Back-gesture/Esc ignored on this scene, reusing ADR-0014's exact mechanism, not inventing a new one.** `ChallengeSelectionScreen` overrides `_notification(NOTIFICATION_WM_GO_BACK_REQUEST)` (Android) as a plain no-op — same shape as `MainNavCoordinator`'s override (ADR-0014 §Architecture Diagram), just routing to nothing instead of `_on_back_gesture()`. This depends on `application/config/quit_on_go_back=false` already being set in `project.godot` (ADR-0014's one-line project-setting change, global, already covers this scene too — no new setting needed). On Web, there is no true back-gesture interception (ADR-0014's own documented constraint) — the same `JavaScriptBridge.eval()` preventive `history.pushState()` + `JavaScriptBridge.create_callback()` `popstate` pattern from ADR-0014 is reused here, registered in this scene's `_ready()`, with its `popstate` callback also a no-op. This is scoped to `ChallengeSelectionScreen` alone; it does not touch `MainNavCoordinator`'s back-gesture handling (ADR-0014), which only ever runs while `main.tscn` is the active scene.

6. **`coordination_state` (ADR-0014) is untouched by this transition.** When `main.tscn` is swapped out, `action_screen.gd`'s instance — and its `coordination_state` — is freed with it (Godot's default scene-swap behavior: the outgoing scene is queued for deletion). When the player returns via Confirm, `main.tscn` is reloaded fresh, `action_screen.gd`'s `_ready()` re-runs, and `coordination_state` re-initializes to `NO_OVERLAY` — the correct default for "just arrived at a new era," not a state that needs preserving across the swap.

### Architecture Diagram
```
PrestigeSystem.era_transitioned (fires: era reset just completed)
        |
action_screen.gd._on_era_transitioned()   [connected in _ready(), alongside
        |                                   existing MainNavCoordinator wiring]
change_scene_to_file(challenge_selection.tscn)
        |                [deferred to end-of-frame; main.tscn instance freed]
ChallengeSelectionScreen._ready()
  reads PrestigeSystem.get_last_grant()          -> recap header
  reads ChallengeSystem.get_challenge_data(id)×5 -> card catalogue
  reads ChallengeSystem.CHALLENGE_MAX_ACTIVE     -> selection cap
  local compute: combined_meta_multiplier (product of selected cards' multipliers)
        |
  back-gesture / Esc -> consumed, no-op (only exit is Confirm)
        |
ConfirmButton.pressed
  ChallengeSystem.select_challenges(challenge_ids)   [writes era-local flags]
        |
change_scene_to_file(main.tscn)
        |                [main.tscn reloads fresh; action_screen.gd._ready()
        |                 re-runs; coordination_state re-initializes]
  live gameplay resumes
```

### Key Interfaces
```gdscript
# action_screen.gd — new listener, alongside existing MainNavCoordinator wiring (ADR-0014)
func _ready() -> void:
    # ...existing MainNavCoordinator connections...
    PrestigeSystem.era_transitioned.connect(_on_era_transitioned)

func _on_era_transitioned() -> void:
    get_tree().change_scene_to_file("res://scenes/challenge_selection/challenge_selection.tscn")

# challenge_selection.gd — new scene script, reads via existing pull-model getters
class_name ChallengeSelectionScreen
extends Control

func _ready() -> void:
    var last_grant: Dictionary = PrestigeSystem.get_last_grant()  # ADR-0017: {granted, type, amount}
    # last_grant.granted == false -> render "Brak bonusu tej ery" (No Bonus Granted state)
    var challenges: Array[Dictionary] = []
    for id in ChallengeSystem.get_all_challenge_ids():
        challenges.append(ChallengeSystem.get_challenge_data(id))
    # ...render catalogue, wire toggles...

func _on_confirm_pressed() -> void:
    ChallengeSystem.select_challenges(_selected_ids)
    get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:  # Android — no-op, Confirm is the only exit
        pass  # deliberately does nothing; requires quit_on_go_back=false (ADR-0014, already set project-wide)

func _ready() -> void:
    # ...existing _ready() body above...
    if OS.has_feature("web"):
        _web_push_history_state()  # reuses ADR-0014's exact pattern; popstate callback is a no-op here
```

## Alternatives Considered

### Alternative 1: Dedicated `EraTransitionController` (BootController-style)
- **Description**: A new Autoload or scene-owned controller whose sole job is listening for `era_transitioned` and driving the scene swap, mirroring `BootController`'s role for the boot sequence.
- **Pros**: Single-responsibility class; if more runtime-triggered scene swaps appear later, there's a natural home for them.
- **Cons**: One listener for one signal does not justify a new persistent class — `BootController` earns its existence by owning an entire multi-step boot sequence (save restore, module `restore_state()` calls, threshold branching); this is a single `connect()` call and a single `change_scene_to_file()`. Introducing an Autoload for this is the same ceremony ADR-0009 explicitly rejected for OfflineProgressSystem's `presenting/idle` state machine.
- **Rejection Reason**: YAGNI — no second runtime-triggered scene swap exists yet to justify shared infrastructure. Revisit if a third one appears (same threshold ADR-0014 set for panel extraction: revisit at scale, not preemptively).

### Alternative 2: Modal overlay instead of scene swap (reuse Card UI's ADR-0008 pattern)
- **Description**: Mount Challenge Selection as a `mouse_filter=STOP` modal over the live `main.tscn`, like Card UI.
- **Pros**: One less scene file; avoids the deferred-swap timing subtlety entirely.
- **Cons**: Already explicitly rejected in the UX spec itself (`challenge-selection-screen.md`'s Navigation Position: "to NIE jest scena osiągalna przez normalną nawigację... wyłącznie automatyczny trigger") — the screen is a hard gate the player cannot dismiss without Confirm, structurally identical to Offline Report Screen's gate, not to Card UI's live-play interruption. A modal would leave the entire live gameplay scene (with its now-stale pre-reset resource HUD, action grid, etc.) alive underneath, contradicting the "new era already active" framing (spec: "Nowa era już aktywna... żaden kontekst UI z poprzedniej sceny nie jest przenoszony").
- **Rejection Reason**: Wrong lifecycle, same reasoning ADR-0009 already applied to Offline Report Screen vs. Card UI. A full scene swap correctly discards the pre-transition UI state instead of requiring it to be manually reset in place.

## Consequences

### Positive
- Closes the only remaining architectural gap blocking Challenge Selection Screen implementation (Sprint 12, story 12-2).
- Zero new Autoloads, zero new signals, zero new payload on `era_transitioned` — the smallest change that satisfies the UX spec.
- Directly reuses three already-Accepted patterns (ADR-0009's standalone-scene gate, ADR-0014's scene-owned-coordinator wiring, ADR-0017's pull-model grant query) rather than inventing a fourth.

### Negative
- `action_screen.gd` grows a second responsibility beyond `MainNavCoordinator` panel coordination (it now also listens for a scene-swap-triggering signal). This is a smaller version of the same growth ADR-0014 already accepted for that script (Consequences → Negative there: "action_screen.gd keeps absorbing entry points... revisit at scale, not preemptively"). This ADR does not change that threshold — it's one `connect()` call, not a new panel.
- The scene-swap-round-trip lifecycle (main → challenge_selection → main) is a new pattern distinct from both ADR-0003's one-way boot flow and ADR-0009's one-way launch-gate flow — future runtime-triggered swaps should look here first before inventing a third variant.

### Risks
- **Deferred-swap timing**: `change_scene_to_file()` defers to end-of-frame (same caveat ADR-0003 and ADR-0009 already documented) — nothing in `_on_era_transitioned()` or `_on_confirm_pressed()` depends on synchronous completion, so this is inherited-safe, not a new risk, but worth re-stating since this is the first *round-trip* use of the pattern (both prior ADRs were one-way). *Mitigation*: neither handler reads scene state after the call.
- **`main.tscn` state loss on swap**: any in-flight `ActionSystem` timer or unsaved UI-only state in `main.tscn` at the moment `era_transitioned` fires is discarded when the scene frees. *Mitigation*: `era_transitioned` only fires after `PrestigeSystem`'s full reset sequence completes (per ADR-0012's atomicity contract) — by construction, nothing gameplay-relevant should be "in flight" at that exact instant; this needs a specific check as part of 12-2's manual QA pass (added to the QA plan).
- **`change_scene_to_file()`'s `Error` return is not checked** in either handler (godot-specialist finding, 2026-07-23 validation pass). *Mitigation*: both target scene paths are static and known-good at author time (no dynamic path construction), matching the same unchecked-return precedent already accepted in ADR-0003 and ADR-0009 — not a new class of risk, just worth naming explicitly here since this is the third ADR to inherit it.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `design/ux/challenge-selection-screen.md` | Screen appears immediately on `era_transitioned`, before any other era-start logic (Rule 1) | Synchronous `connect()` + `change_scene_to_file()` in the signal handler itself |
| `design/ux/challenge-selection-screen.md` | Back-gesture/Esc always ignored, Confirm is the only exit | `NOTIFICATION_WM_GO_BACK_REQUEST` no-op override (Android) + reused `JavaScriptBridge` pushState/popstate no-op (Web), both scoped to `ChallengeSelectionScreen` only, same mechanism as ADR-0014 |
| `design/ux/challenge-selection-screen.md` | `MetaBonusGrantedLabel` shows the exact value the Wypalenie card previewed | Reads `PrestigeSystem.get_last_grant()` (ADR-0017) — same underlying `compute_next_grant()` data, not a re-derivation |
| `design/quick-specs/challenge-era-runs-2026-07-01.md` Rule 3 | Confirm writes era-local challenge flags | `ChallengeSystem.select_challenges()`, already-designed API, called before the return scene swap |

## Performance Implications
- **CPU/Memory**: negligible — two additional scene swaps per era transition (out, and back on Confirm), same cost class as the existing boot→main swap.
- **Load Time**: `challenge_selection.tscn` is a small static screen (5 cards + header + footer, no dynamic asset loading) — swap cost is dominated by Godot's standard scene-instantiation overhead, not asset I/O.

## Migration Plan
1. Build `challenge_selection.tscn` + `challenge_selection.gd` per the UX spec's Layout Specification and Component Inventory.
2. Add the `era_transitioned` listener + handler to `action_screen.gd`.
3. Wire `ChallengeSelectionScreen`'s Confirm handler to `ChallengeSystem.select_challenges()` + return swap.
4. Add the back-gesture/Esc suppression override.
5. Manual QA pass (per Sprint 12 QA plan, 12-2): confirm no in-flight `main.tscn` state (running action timer, open panel) causes a visible glitch across the swap — this is the one behavior this ADR flags as needing empirical confirmation, not just code review.

## Validation Criteria
- Integration test (mocked `PrestigeSystem`/`ChallengeSystem`, `tests/integration/challenge/challenge_selection_screen_test.gd` per the Sprint 12 QA plan): `era_transitioned.emit()` results in `challenge_selection.tscn` becoming the active scene; Confirm with 0/N selections both return to `main.tscn` with `select_challenges()` called correctly.
- Manual playtest (Sprint 12, story 12-3): a real era transition mid-session (not a test harness call) transitions cleanly with no visible main-scene state artifact.

## Related Decisions
- ADR-0003 (boot-time scene sequencing — contrast: this is runtime-triggered, not boot-triggered)
- ADR-0009 (Offline Report Screen standalone-scene precedent — this ADR's closest analog, extended to a round-trip instead of one-way)
- ADR-0014 (`action_screen.gd` as scene-owned coordinator — this ADR adds one listener to that same script rather than introducing new machinery)
- ADR-0017 (`PrestigeSystem.get_last_grant()` — the API this screen reads for its recap header)
- `design/ux/challenge-selection-screen.md` (the UX spec this ADR unblocks)
