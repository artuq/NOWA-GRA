# ADR-0011: Juice/Feedback Architecture — Stateless FeedbackMath + Additive UI-Node Effects

## Status
Accepted (2026-07-06, following independent /architecture-review in a separate session — verdict PASS: no cross-ADR conflicts, engine-clean (no post-cutoff/deprecated APIs), all five dependencies ADR-0001/0004/0007/0008/0010 Accepted. The review's one advisory item — count-up vs. ResourceHud instant `resource_changed` update — is folded into §2 below.)

## Date
2026-07-06

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | UI / Audio / Animation |
| **Knowledge Risk** | LOW — `Tween` (`create_tween()`), `AudioStreamPlayer`, `Control.modulate`, `Label` are all pre-4.3 stable APIs; no post-cutoff API used. 4.6's glow-effect change (mobile renderer) is irrelevant — the label flash is a `modulate` pulse, not WorldEnvironment glow |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` (only 3D `SkeletonIK3D` deprecation — not applicable), `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Shake offset must not displace touch targets (assert layout position unchanged, only visual offset) — covered by an AC |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload/signal rules); ADR-0004 (`action_completed` carries final post-scaling deltas); ADR-0008 + ADR-0010 (`card_resolved` signal shape); ADR-0007 (Action UI zones — ResourceHud owns label chrome) |
| **Enables** | Sprint 9 stories 9-2 (Juice core implementation); future `/asset-spec system:juice-feedback-system` (stinger assets) |
| **Blocks** | Story 9-2 cannot begin until this ADR is Accepted |
| **Ordering Note** | No new Autoload is introduced, so no boot-order change. UI nodes (ResourceHud, CardScreen) already sit in scenes instantiated after all Autoloads are ready — their signal connections in `_ready()` are safe by construction |

## Context

### Problem Statement
`juice-feedback-system.md` (GDD, Designed 2026-06-20) defines a magnitude formula and two sensory feedback channels (subtle for actions, strong for cards) with a hard no-valence-coding rule. The architectural question: where does this logic live — a new Autoload, a central effect-conductor node, or inside the existing UI nodes — without violating the Presentation-layer rule (UI reads, never owns game state) and without adding a critical-path dependency for what is an optional polish layer.

### Codebase reality check (changes the GDD's assumed scope)
- `resolution_reaction` **already exists on every option of all 12 cards** in CardContentDatabase — the GDD's hard dependency ("field doesn't exist yet") is already satisfied.
- CardScreen **already implements the resolution payoff beat** (`resolution_beat_seconds` + `resolution_beat_per_char` + milestone bonus) — GDD Core Rules 5–6 are live. This ADR does NOT reimplement payoff; it only adds the sensory channels alongside it.
- What remains to build: the magnitude formula, the label flash + count-up (action channel), the scale-pulse + shake + audio stinger (card channel).

### Constraints
- GDScript-only, no threading (ADR-0001); no central EventBus (ADR-0001 forbidden pattern)
- Presentation layer must not own or mutate game state (control-manifest Presentation rules)
- This system has **no persisted state** (GDD Edge Cases: no `restore_state()`) — an Autoload per ADR-0001 is for Core/Foundation modules with owned state; this system owns none
- Shake must be a visual offset only — touch targets must not move (technical-preferences.md large-touch-area rule)
- No art bible yet — audio/visual token values are placeholders flagged `# TODO: art-bible-pending`

### Requirements
- Magnitude formula per GDD Formulas (linear ratio for bounded resources, log-compressed for unbounded, max-of-contributions, hard clamp [0,1])
- Two mutually exclusive channels: Action (count-up + flash, no shake) and Card (pulse + shake + stinger, magnitude-scaled)
- No-valence-coding guarantee must be structurally testable (same magnitude → identical parameters)
- Zero-magnitude events still play the lowest-tier effect

## Decision

**Alternative A: stateless `FeedbackMath` static class + additive effect code in the existing UI nodes.** No new Autoload, no conductor node, no new signals.

### 1. `FeedbackMath` — stateless static utility (precedent: `ResourceFormulas`, ADR-0006)

`res://src/ui/feedback_math.gd`, `class_name FeedbackMath`. Pure static functions, no instance state, no `@export`:

```gdscript
static func magnitude(deltas: Dictionary) -> float
    # max over resources of contribution(r), hard-clamped [0,1]
    # bounded (Cringe: norm 35, Morale: norm 30): |delta| / norm_ref
    # unbounded (Reach, Sponsors, Haters): log(1+|delta|) / log(1+Z_NORM_REF), Z_NORM_REF=40

static func pulse_scale(m: float) -> float        # 1.02..1.15 per GDD tiers
static func shake_amplitude_px(m: float) -> float # 0 below 0.3; 2..4px mid; capped high tier
static func shake_duration_sec(m: float) -> float # 0 below 0.3; <=0.15 mid; capped high tier
static func stinger_params(m: float) -> Dictionary # {layers: int 1..3, tail_sec: float 0.08..0.9, saturation: float 0..1}
```

All tuning constants live as `const` in FeedbackMath (same tech-debt posture as `ACTION_REWARDS` — extraction to external data when balance tuning begins). Signed deltas: only `abs()` is ever read — the sign structurally cannot influence any output, which makes the no-valence-coding rule testable as a pure function property.

### 2. Action channel — inside ResourceHud (additive)

ResourceHud already subscribes to `ResourceManager.resource_changed`. Add a subscription to `ActionSystem.action_completed(action_id, rewards)`:
- **Count-up**: tween the displayed number from old to new over a fixed short duration (matching the Offline Report Screen's existing count-up pattern) — content scales with magnitude, duration does not. **Reconciliation with the existing `resource_changed` handler**: `resource_changed` fires *before* `action_completed` (via `apply_delta()`) and snaps the label to the new value, so by the time `_on_action_completed()` runs the label already shows the end value — reading it gives no "old" start. Instead the handler derives the start from the payload: `start = end − rewards[r]` (the `action_completed` deltas are exactly what `apply_delta()` applied). It animates the label from that computed start up to `end`. To avoid a visible jump-to-end-then-restart, the `resource_changed` handler skips its snap for any resource that has a live (or same-frame pending) count-up tween, letting the count-up own that label until it settles on `end` (architecture-review advisory, 2026-07-06).
- **Label flash**: one `create_tween()` pulse on the pill's **`self_modulate`** — NOT `modulate`, which cascades multiplicatively to the child value Label and would tint the number text, violating the GDD's "number stays legible, chrome-only flash" rule (engine-specialist finding, 2026-07-06). 150–200ms fixed, ONE neutral color token (`# TODO: art-bible-pending`), identical regardless of delta sign.
- No shake, no audio in this channel — structurally absent, not disabled.

### 3. Card channel — inside CardScreen (additive)

CardScreen's `resolve_choice()` call site already has the chosen option's `resource_deltas` in hand **before** resolving. Compute `var m: float = FeedbackMath.magnitude(option["resource_deltas"])` locally — **no change to any signal, no new payload field**:
- **Scale-pulse**: tween `Card` node scale to `FeedbackMath.pulse_scale(m)` and back to `Vector2.ONE` in the same tween chain. Additionally, `_on_card_presented()` gains a defensive `_card_node.scale = Vector2.ONE` reset (mirroring its existing position/rotation resets) so an interrupted pulse can never leak a wrong scale into the next card (engine-specialist finding). `resolve()` sets `pivot_offset = _card_node.size / 2.0` itself rather than relying on the drag path having set it (direct/test callers would otherwise pulse from the top-left corner).
- **Shake**: tween a visual offset on the Card node's `position` around its rest position (rest position already captured for bounce-back) — layout untouched, touch bounds unaffected. Amplitude/duration from FeedbackMath; zero below magnitude 0.3.
- **Audio stinger**: one `AudioStreamPlayer` child (bus: default) with up to 3 layered one-shot streams (transient / sub-thump / noise-tail). `stinger_params(m)` selects layer count, tail, saturation. Until stinger assets exist (post-art-bible `/asset-spec`), an explicit guard (`if player.stream != null: player.play()`) makes the no-op contract code-level rather than an assumed engine default (null-stream `play()` behavior on 4.6.3 unverified — engine-specialist note).
- Runs alongside the existing resolution payoff beat — pulse/shake fire at resolution moment, payoff text continues as-is.

### 4. What this decision explicitly does NOT create
- No `JuiceSystem` Autoload, no `feedback_requested` signal, no conductor node
- No new state anywhere — `FeedbackMath` is stateless; effects are fire-and-forget tweens owned by the node they animate
- No changes to ActionSystem, DecisionCardSystem, ResourceManager, or any Core module
- No GDD `payoff complete` signal — CardScreen already owns its payoff timing internally; the GDD's abstract "signals Card UI" interaction is realized as same-node sequencing (flagged in GDD sync below)

### Architecture Diagram

```
ActionSystem.action_completed ──────→ ResourceHud._on_action_completed()
  (final deltas)                          ├─ FeedbackMath.magnitude(rewards)
                                          ├─ count-up tween (fixed duration)
                                          └─ label flash tween (150-200ms, 1 token)

CardScreen.resolve gesture ─────────→ CardScreen (locally, pre-resolve_choice)
  (option.resource_deltas in hand)        ├─ FeedbackMath.magnitude(deltas)
                                          ├─ scale-pulse + shake tweens (Card node)
                                          ├─ AudioStreamPlayer stinger (params by m)
                                          └─ existing resolution payoff beat (unchanged)

FeedbackMath (static, stateless) ←── called by both; owns all formulas + tuning consts
```

### Key Interfaces

```gdscript
# res://src/ui/feedback_math.gd — the ONLY new API surface
class_name FeedbackMath
extends RefCounted  # matches ResourceFormulas precedent (ADR-0006)
static func magnitude(deltas: Dictionary) -> float
static func pulse_scale(m: float) -> float
static func shake_amplitude_px(m: float) -> float
static func shake_duration_sec(m: float) -> float
static func stinger_params(m: float) -> Dictionary
```

## Alternatives Considered

### Alternative B: `JuiceSystem` Autoload emitting `feedback_requested(channel, magnitude)`
- **Description**: Autoload #10 subscribes to `action_completed`/`card_resolved`, computes magnitude, re-emits a UI-facing signal; UI nodes subscribe to it.
- **Pros**: Single place to see all feedback logic; UI nodes stay dumb.
- **Cons**: An Autoload with no owned state contradicts ADR-0001's rationale (Autoloads exist to own state/lifecycle); adds a signal-relay hop that is exactly the "central event dispatch" pattern ADR-0001 rejects in EventBus form; `card_resolved` doesn't carry deltas, so JuiceSystem would need a signal payload change (breaking) or a DecisionCardSystem query API (new coupling).
- **Rejection Reason**: More moving parts and a Core-facing change for zero functional gain over local computation where the deltas already are.

### Alternative C: Conductor CanvasLayer node in the main scene
- **Description**: A `JuiceConductor` node instanced in action_screen.tscn orchestrates all effects across child UI zones.
- **Pros**: No Autoload; effects centralized.
- **Cons**: Cross-zone reach-ins (conductor animating ResourceHud's labels and CardScreen's card) violate ADR-0007's zone-ownership principle — each Action UI zone owns its own chrome; a conductor mutating other zones' nodes is exactly the coupling ADR-0007 prevents.
- **Rejection Reason**: Breaks established zone ownership for a centralization benefit this project's scale doesn't need.

## Consequences

### Positive
- Zero new architecture: no Autoload, no signal, no boot-order change — the entire decision is one static class + two additive node edits
- No-valence-coding is structurally guaranteed (FeedbackMath reads only `abs(delta)`) and unit-testable as a pure-function property
- Effects degrade gracefully: missing stinger assets no-op silently (explicit null-stream guard); backgrounding mid-effect relies on OS-level process suspension plus the `_on_card_presented()` scale reset — CardScreen's `_notification()` handler is additionally extended to kill juice tweens in the `RESOLVING` state (it currently only covers `DRAGGING`), making the clean-state claim structural rather than assumed (engine-specialist finding)

### Negative
- Feedback logic lives in two UI nodes rather than one place — acceptable at 2 channels; revisit (Alternative B) if a third channel appears
- Stinger audio ships structurally silent until art-bible + `/asset-spec` deliver assets — the audio AC can only be structurally verified (params correct), not aurally, this sprint

### Risks
- **Tween pile-up on rapid events**: actions complete every 4–9s; a new count-up may start before the old finishes. Mitigation: each effect kills its own previous tween before starting (single tween handle per effect, standard pattern already used by CardScreen's bounce tween).
- **Shake vs. drag interaction**: card shake and swipe-drag both move the Card node. Mitigation: shake fires only at resolution, when state is RESOLVING and input is no longer tracked — structurally non-overlapping with DRAGGING.
- **Placeholder tokens drift**: `# TODO: art-bible-pending` values may ship to release if the art bible slips again (3rd gate-check risk). Mitigation: flagged in tech-debt register at implementation.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| juice-feedback-system.md | Magnitude formula (linear/log, max, clamp) | `FeedbackMath.magnitude()` — pure static, unit-tested including fuzz clamp |
| juice-feedback-system.md | Action channel: count-up + flash, no shake | ResourceHud additive subscription; shake structurally absent from this node |
| juice-feedback-system.md | Card channel: pulse + shake + stinger by magnitude tiers | CardScreen local computation + tweens + AudioStreamPlayer |
| juice-feedback-system.md | No-valence-coding (central guarantee) | FeedbackMath reads `abs()` only; dedicated unit test asserts sign-invariance |
| juice-feedback-system.md | Resolution payoff timing | Already implemented in CardScreen (resolution beat) — verified, not rebuilt |
| juice-feedback-system.md | Zero-magnitude still plays lowest tier | Effects always fire; magnitude only scales parameters, never gates execution |
| juice-feedback-system.md | Backgrounding leaves clean state | Fire-and-forget tweens; no state to restore — no `restore_state()` by design |

## Performance Implications
- **CPU**: 2–4 short tweens per event (events are 4–9s apart) — negligible. `magnitude()` is O(resources) ≤ 5 iterations.
- **Memory**: One AudioStreamPlayer + a handful of preloaded short streams (once assets exist) — negligible.
- **Load Time**: None.
- **Network**: N/A.

## Migration Plan
1. Create `src/ui/feedback_math.gd` + unit tests (`tests/unit/feedback/`)
2. ResourceHud: add `action_completed` subscription, count-up + flash tweens
3. CardScreen: add magnitude computation + pulse/shake tweens + AudioStreamPlayer child (no streams yet)
4. No changes to any Core module, scene structure, or save format

## Validation Criteria
- Unit: `magnitude()` boundary pairs from GDD ACs (Cringe 20/35, log example 0.646), fuzz sweep proving clamp ≤ 1.0
- Unit: sign-invariance — `magnitude(d) == magnitude(-d)` for arbitrary delta sets (no-valence-coding)
- Unit: tier functions (pulse/shake/stinger params) at tier boundaries 0.0 / 0.3 / 0.7 / 1.0
- Integration: action event triggers flash+count-up and never shake; card resolution triggers pulse(+shake at m≥0.3) and never count-up
- Manual (Visual/Feel evidence): shake does not displace touch targets; feel sign-off per tier

## Related Decisions
- ADR-0001 (Autoload rationale — why NOT an Autoload here), ADR-0006 (ResourceFormulas stateless precedent), ADR-0007 (zone ownership — why not a conductor), ADR-0004/0008/0010 (source signals)
- `design/gdd/juice-feedback-system.md`
