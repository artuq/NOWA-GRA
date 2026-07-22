# ADR-0014: Main Navigation Coordinator — Panel Ownership, Card-Interrupt Priority, Android/Web Back Gesture

## Status
Proposed

> **Revision note (2026-07-22)**: extended to cover a third coordinated panel, `BonusesPanel`, per `design/ux/meta-bonus-visibility.md` (`/ux-design` + `/ux-review` APPROVED same day, resolving `prestige-checkpoint-system.md`'s BLOCKING-before-Alpha meta-bonus visibility gap). The resolver architecture generalizes without change — `PANEL_OPEN` was never panel-specific — but every place this ADR originally said "two panels" or "six entry points" is corrected below to three panels / eight entry points.

## Date
2026-07-22

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | UI / Core |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/architecture/adr-0007-action-ui-scene-structure-autoload-binding.md` (scene-script precedent), `docs/architecture/adr-0008-card-ui-modal-swipe-integration.md` (mirror-not-hub precedent for CardScreen) |
| **Post-Cutoff APIs Used** | `NOTIFICATION_WM_GO_BACK_REQUEST` (stable pre-4.3 API, not post-cutoff — confirmed against `breaking-changes.md`, no 4.4-4.6 changes to this notification), `JavaScriptBridge.eval()`/`.create_callback()` (stable, Web export only) — none flagged in `breaking-changes.md` or `deprecated-apis.md` |
| **Verification Required** | Two known open Godot engine issues (both pre-existing, noted in the GDD's Engine Notes, neither blocks this ADR): godotengine/godot#105324 (possible multi-emission of `NOTIFICATION_WM_GO_BACK_REQUEST` across stacked scene instances — this project's single-coordinator-per-`action_screen.tscn` architecture likely reduces exposure, unconfirmed for 4.6.3) and godotengine/godot#64940 (`Quit On Go Back` reported not working correctly in some versions, unconfirmed status for 4.6.3). Smoke-test both on first Android implementation. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (Accepted — scene boot order; this ADR does not touch it, `MainNavCoordinator` lives entirely inside `action_screen.tscn`, downstream of ADR-0003's `main.tscn` hand-off), ADR-0007 (Accepted — establishes `action_screen.gd` as the root script for TopBar-owned UI, the precedent this ADR extends), ADR-0008 (Accepted — establishes the "mirror not hub" pattern for `CardScreen`, reused here verbatim for the `DecisionCardSystem` boundary) |
| **Enables** | Full implementation of the Main Navigation/Screen Flow GDD (currently zero lines of code) |
| **Blocks** | Any story implementing `MainNavCoordinator`, the Close-button rewiring fix (`settings_screen.gd:47-48`, `class_path_panel.gd:141-142`), or Android/Web back-gesture handling |
| **Ordering Note** | This ADR does not depend on ADR-0016 (planned — `DecisionCardSystem.inject_priority_card()` reentrancy guard). The coordinator's 5a no-op guard (defense-in-depth) is specified independently of that upstream fix landing. |

## Context

### Problem Statement

`design/gdd/main-navigation-screen-flow.md` is design-complete (3 `/design-review` rounds, all blocking findings resolved) but `MainNavCoordinator` — the module that owns "which of the coordinated overlay panels (`ClassPathPanel`, `SettingsScreen`, and — per this revision — `BonusesPanel`) is open" and enforces card-interrupt priority — has zero lines of code. Two real bugs already exist in shipped code that this coordinator must work around: `SettingsScreen._on_close_pressed()` (`settings_screen.gd:47-48`) and `ClassPathPanel`'s equivalent handler (`class_path_panel.gd:141-142`) both set `visible = false` directly on themselves, bypassing any future coordinator entirely. This ADR gives the coordinator a concrete architecture to implement against and formalizes the fix for both Close-button handlers. (`BonusesPanel` is new, unimplemented — it has no equivalent bug to fix, only a contract to follow from day one.)

### Constraints

- Must not modify ADR-0003's scene boot order or introduce a new scene — `MainNavCoordinator` lives inside the already-shipped `action_screen.tscn`.
- Must not become a hub for `CardScreen` — per ADR-0008 and the GDD's explicit "mirror not hub" rule, the coordinator reads `DecisionCardSystem.card_presented`/`.card_resolved` and `CardScreen.visibility_changed`, but never writes `CardScreen.visible`.
- Must not introduce a central event bus — forbidden by the existing registry entry (`docs/registry/architecture.yaml`, forbidden_patterns).
- The "same frame" guarantee (GDD Core Rules) requires every state change to resolve through one synchronous function call per entry point — no independent signal listeners racing each other.
- Eight real entry points must all route through the same resolver (GDD, "Punkty wejścia do resolvera," extended by this revision): PathButton press, SettingsButton press, BonusesButton press, ClassPathPanel close request, SettingsScreen close request, BonusesPanel close request, back-gesture handler, and the `DecisionCardSystem`/`CardScreen` read-only pair.
- Exit from `CARD_PRESENTED` must gate on `CardScreen.visibility_changed(false)`, not on `card_resolved` — `CardScreen`'s own resolution timer runs 1.5–3.5s+ after `card_resolved` fires (verified in `card_screen.gd`).
- Android: `application/config/quit_on_go_back` must be explicitly set `false` in `project.godot`, or the engine's synchronous `get_tree().quit()` fallback fires regardless of any handler.
- Web: no true back-gesture interception exists — only reaction-after-the-fact via `JavaScriptBridge` + a preventive `history.pushState()` pattern, needed for 3 of Rule 6's 4 branches (panel-open, card-presented, offline-report-visible); the "nothing visible" branch requires no interception at all.
- iOS is out of scope (user decision, 2026-07-22) — no back-gesture handling for that platform.

### Requirements

- Single source of truth: `coordination_state: CoordinationState` (enum `NO_OVERLAY`/`PANEL_OPEN`/`CARD_PRESENTED`), owned exclusively by `MainNavCoordinator`. `ClassPathPanel.visible`/`SettingsScreen.visible` are effects of state changes, never independently set.
- At most one of the three coordinator-owned panels visible at any time.
- Card presentation always wins collisions (`card_presented` > back-gesture > panel-tap, per the GDD's Edge Cases priority ordering), resolved deterministically within a single synchronous call.
- Both existing Close-button handlers must be rewired to go through the coordinator instead of self-setting `visible`.
- Back-gesture behavior must be correct on Android and Web without touching iOS.

## Decision

`MainNavCoordinator` is implemented as the existing `action_screen.gd` script (no new Autoload, no new scene) — it already sits at the root of `action_screen.tscn`, already owns `PathButton`/`SettingsButton` handling (ADR-0007), and already has `@onready` access to `%SettingsScreen` and `%ClassPathPanel` as unique-named siblings. `BonusesPanel` (new node, per `meta-bonus-visibility.md`) joins them as a third `@onready` sibling reference — same pattern, no architectural change.

### Architecture Diagram

```
action_screen.gd (ActionScreen, extends Control)
  var coordination_state: CoordinationState = NO_OVERLAY   # single source of truth

  Entry points (8, each a thin wrapper calling _apply_state_change()):
    _on_path_button_pressed()          -> requests PANEL_OPEN(ClassPathPanel)
    _on_settings_button_pressed()      -> requests PANEL_OPEN(SettingsScreen)
    _on_bonuses_button_pressed()       -> requests PANEL_OPEN(BonusesPanel)   [new, this revision]
    _on_class_path_close_requested()   -> requests NO_OVERLAY   [signal from ClassPathPanel]
    _on_settings_close_requested()     -> requests NO_OVERLAY   [signal from SettingsScreen]
    _on_bonuses_close_requested()      -> requests NO_OVERLAY   [signal from BonusesPanel, new this revision]
    _on_back_gesture()                 -> requests close-current-or-platform-default
    _on_card_presented()               -> forces CARD_PRESENTED [signal from DecisionCardSystem, read-only]
    _on_card_screen_visibility_changed()
                                        -> if CARD_PRESENTED and not _card_screen.visible: requests NO_OVERLAY
                                           [CanvasItem.visibility_changed carries no payload — reads
                                            _card_screen.visible directly, signal from CardScreen, read-only]

  _apply_state_change(new_state: CoordinationState) -> void:
    # the ONE synchronous resolver every entry point funnels through
    # sets coordination_state, then sets _class_path_panel.visible /
    # _settings_screen.visible / _bonuses_panel.visible as an EFFECT of
    # the new state — never touches CardScreen.visible under any branch

  _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:   # Android only
      _on_back_gesture()

  _ready() -> void:
    _class_path_panel.close_requested.connect(_on_class_path_close_requested)
    _settings_screen.close_requested.connect(_on_settings_close_requested)
    _bonuses_panel.close_requested.connect(_on_bonuses_close_requested)   # new, this revision
    DecisionCardSystem.card_presented.connect(_on_card_presented)
    _card_screen.visibility_changed.connect(_on_card_screen_visibility_changed)
    if OS.has_feature("web"):
      _web_push_history_state()   # initial pushState, re-pushed after each back reaction
```

### Key Interfaces

```gdscript
# ClassPathPanel (class_path_panel.gd) — new signal, Close handler rewired
signal close_requested
func _on_close_pressed() -> void:
    close_requested.emit()   # was: visible = false

# SettingsScreen (settings_screen.gd) — same pattern
signal close_requested
func _on_close_pressed() -> void:
    close_requested.emit()   # was: visible = false

# BonusesPanel (bonuses_panel.gd, new — this revision, per meta-bonus-visibility.md)
signal close_requested
func _on_close_pressed() -> void:
    close_requested.emit()   # same pattern from day one — no bypass bug to fix, unlike the other two

# ActionScreen / MainNavCoordinator (action_screen.gd)
enum CoordinationState { NO_OVERLAY, PANEL_OPEN, CARD_PRESENTED }
var coordination_state: CoordinationState = CoordinationState.NO_OVERLAY
# No public setter — coordination_state changes exclusively through the 8 entry
# points above, each funneling into the private _apply_state_change() resolver.
# Guarantee: after ANY of the 8 entry points returns, coordination_state and
# ClassPathPanel.visible/SettingsScreen.visible/BonusesPanel.visible are
# mutually consistent — no caller ever observes a torn state between them.
```

Android's `quit_on_go_back` requirement is a **Project Settings change**, not runtime code: `project.godot`'s `[application]` section must set `config/quit_on_go_back=false` explicitly (default is `true`). This is a one-line project-file change bundled into the same implementation story, not a code interface.

**Web JS→GDScript return path (godot-specialist finding)**: `JavaScriptBridge.eval()` alone only sends GDScript→JS; receiving the browser's `popstate` event back in GDScript requires `JavaScriptBridge.create_callback()` to register a GDScript-side callback that JS calls on `popstate`. The initial `history.pushState()` and each re-push after a reaction use `eval()`; the `popstate` listener that triggers `_on_back_gesture()` on Web is wired through `create_callback()`, registered once in `_ready()` alongside the initial `pushState()`.

## Alternatives Considered

### Alternative 1: New `MainNavCoordinator` Autoload singleton
- **Description**: Register a new Autoload following the same pattern as `ClassPathSystem`/`PrestigeSystem`/`BurnoutSystem`.
- **Pros**: Consistent with this project's dominant Feature/Core-layer pattern (Architecture Principle 4).
- **Cons**: The coordinated state (`coordination_state`, panel visibility) is meaningless outside `action_screen.tscn` — an Autoload would hold state for a scene that may not even be the active scene (e.g., during `offline_report.tscn`), needing extra guards for no benefit. It would also need to reach into the scene tree to find `%ClassPathPanel`/`%SettingsScreen` at runtime instead of using `@onready` — more fragile than a scene-owned script that already has direct references.
- **Rejection Reason**: Wrong lifetime model — this is scene-scoped coordination state, not global game state. `ActionUI` (ADR-0007) already established the "scene-owned script coordinates scene-owned siblings" pattern for exactly this shape of problem.

### Alternative 2: Central event bus (string-keyed signal dispatch)
- **Description**: A generic `EventBus` Autoload that all 6 entry points publish to, with `MainNavCoordinator` subscribing.
- **Pros**: Decouples publishers from the coordinator entirely.
- **Cons**: Explicitly forbidden by this project's registered architecture stance (`docs/registry/architecture.yaml`, forbidden_patterns: "Central EventBus autoload"). Also weakens the "same frame" synchronous-resolver guarantee the GDD requires — event bus dispatch commonly introduces signal-ordering ambiguity exactly where determinism is required (card-interrupt priority).
- **Rejection Reason**: Forbidden pattern; also directly undermines the GDD's core correctness requirement.

## Consequences

### Positive
- Zero new Autoloads, zero new scenes — extends an already-shipped, already-tested pattern (`action_screen.gd`, ADR-0007) rather than introducing a new architectural shape.
- Fixes two real, verified bugs (Close-button bypass) as part of the same change, not a separate cleanup pass.
- `close_requested` signals make `ClassPathPanel`/`SettingsScreen` fully testable in isolation (no dependency on being parented under `action_screen.tscn` to verify their own Close behavior).

### Negative
- `action_screen.gd` grows in responsibility (TopBar buttons + panel coordination + back-gesture handling + Web JS bridge glue), now across three coordinated panels instead of two — still well under the 40-line-per-method standard if each entry point stays a thin wrapper, but the file itself becomes the single busiest script in the UI layer, more so with each additional panel. If a fourth coordinated panel is ever proposed, revisit whether `action_screen.gd` should keep absorbing entry points or whether the resolver logic should extract into a plain (non-Autoload) helper class the script owns — not a concern yet at three.
- Android `quit_on_go_back=false` project-setting requirement is easy to silently regress if `project.godot` is ever hand-edited or merged carelessly — no code-level guard catches this.

### Risks
- godotengine/godot#105324 (possible multi-emission of `NOTIFICATION_WM_GO_BACK_REQUEST`) — mitigation: the resolver's `_apply_state_change()` is idempotent by construction (setting `coordination_state` to its current value is a safe no-op), so a duplicate notification in the same frame is harmless.
- Web `history.pushState()` re-push timing — mitigation: re-push happens synchronously inside `_apply_state_change()` for Web, not deferred, keeping the pushState trap always primed before the next possible back-gesture.
- `DecisionCardSystem.inject_priority_card()` reentrancy (tracked separately, ADR-0016 planned) — mitigation: Core Rule 5a's coordinator-side no-op guard is included in this ADR's `_on_card_presented()` regardless of ADR-0016's landing date.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| main-navigation-screen-flow.md | Core Rule 3-4: at most one panel visible, panels are `visible`-toggled siblings not separate scenes | `coordination_state` as single source of truth; panel `visible` flags are effects, never independently set |
| main-navigation-screen-flow.md | Core Rule 5/5a: card priority, guard against double `card_presented` | `_on_card_presented()` forces `CARD_PRESENTED`; no-ops if already in that state |
| main-navigation-screen-flow.md | Core Rule 6: Android/Web back gesture, redundant not primary affordance | `_notification(NOTIFICATION_WM_GO_BACK_REQUEST)` (Android) + `JavaScriptBridge`/`pushState` (Web), both routed through `_on_back_gesture()` |
| main-navigation-screen-flow.md | "Granica z CardScreen — mirror, nie hub" | Coordinator connects to `DecisionCardSystem`/`CardScreen` signals read-only; `CardScreen.visible` is never written by this ADR's code |
| main-navigation-screen-flow.md | "Migracja wymagana" — Close buttons bypass any coordinator | `close_requested` signal added to both panels, Close handlers rewired to emit instead of self-setting `visible` |
| main-navigation-screen-flow.md | "Punkty wejścia do resolvera" — entry points, one resolver | `_apply_state_change()` is the sole resolver; all 8 entry points (extended this revision) are thin wrappers around it |
| meta-bonus-visibility.md | BonusesPanel is a third coordinator-owned panel, same Close/back-gesture parity as the other two | `BonusesPanel` added as a third `@onready` sibling with its own `close_requested` signal, wired through the same resolver — no new architectural pattern |

## Performance Implications
- **CPU**: Negligible — signal-driven, no per-frame polling except the Android `_notification()` hook (event-driven, not polled) and Web's `JavaScriptBridge` calls (only on state transitions, not per-frame).
- **Memory**: Negligible — one new enum field, no new nodes.
- **Load Time**: None.
- **Network**: N/A.

## Migration Plan

1. Add `close_requested` signal to `class_path_panel.gd` and `settings_screen.gd`; replace both `_on_close_pressed()` bodies (`visible = false` → `close_requested.emit()`).
2. Implement `BonusesPanel` (`bonuses_panel.gd`, new — per `meta-bonus-visibility.md`) with `close_requested` wired from day one, no bypass to fix.
3. Add `coordination_state` enum + `_apply_state_change()` resolver + the 8 thin entry-point wrappers to `action_screen.gd`.
4. Connect all three `close_requested` signals (`ClassPathPanel`, `SettingsScreen`, `BonusesPanel`) in `action_screen.gd::_ready()`.
5. Connect `DecisionCardSystem.card_presented` and `%CardScreen.visibility_changed` (read-only).
6. Add `_notification(NOTIFICATION_WM_GO_BACK_REQUEST)` override (Android).
7. Add Web `JavaScriptBridge`/`pushState` glue, gated on `OS.has_feature("web")`.
8. Set `application/config/quit_on_go_back=false` in `project.godot`.
9. No changes required to `DecisionCardSystem`, `CardScreen`, `ClassPathSystem`, `PrestigeSystem`, `BurnoutSystem`, or `ChallengeSystem` — this ADR is additive on top of all of them.

## Validation Criteria

Covered by the GDD's existing Acceptance Criteria (state-machine tests, collision/priority tests, Close/back-gesture parity tests). Implementation story must include an integration test asserting `coordination_state` and both panels' `visible` fields are mutually consistent after each of the 6 entry points fires, including the triple-collision case (GDD Edge Cases).

## Related Decisions
- ADR-0003 (scene boot order — unmodified dependency)
- ADR-0007 (Action UI scene structure — the pattern this ADR extends)
- ADR-0008 (CardScreen mirror-not-hub — the boundary pattern this ADR reuses)
- ADR-0016 (planned — `DecisionCardSystem.inject_priority_card()` reentrancy guard; independent but related upstream fix)
- `design/gdd/main-navigation-screen-flow.md` (source GDD)
- `design/ux/meta-bonus-visibility.md` (2026-07-22 — the UX spec that motivated this revision, adding `BonusesPanel` as a third coordinated panel)
