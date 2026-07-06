# Story 003: Card Channel — Scale-Pulse + Shake + Stinger Structure

> **Epic**: Juice/Feedback System
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M (3–4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-07-06

## Context

**GDD**: `design/gdd/juice-feedback-system.md`
**Requirements**: `TR-juice-002` (Card half), `TR-juice-005`, `TR-juice-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Juice/Feedback Architecture — Stateless FeedbackMath + Additive UI-Node Effects
**ADR Decision Summary**: CardScreen computes magnitude locally from the presented card's option deltas at the resolve call site (no signal changes), then plays: scale-pulse (tween up to `pulse_scale(m)` and back to `Vector2.ONE` in one chain), visual-offset shake around the captured rest position (zero below m=0.3), and a layered audio stinger via one AudioStreamPlayer child with an explicit null-stream guard. Defensive guards: `resolve()` sets `pivot_offset` itself; `_on_card_presented()` resets `scale = Vector2.ONE`; `_notification()` extended to kill juice tweens in RESOLVING state.

**Secondary ADRs**: ADR-0008 (CardScreen modal architecture), ADR-0007 (zone ownership)

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: Card node's parent is a plain Control (no auto-layout) — position/scale tweens don't fight a container (engine-specialist verified). Null-stream `AudioStreamPlayer.play()` behavior on 4.6.3 unverified — the explicit `if stream != null` guard is mandatory, not optional.

**Control Manifest Rules (Presentation layer)**:
- Required: UI reads, never mutates game state; shake is a visual offset only — touch targets must not move (technical-preferences.md)
- Forbidden: valence-coded feedback (registry, ADR-0011) — same pulse/shake/stinger params for win and loss at equal magnitude; no pitch/harmony variation
- Guardrail: one tween handle per effect, kill-before-restart

---

## Acceptance Criteria

*From GDD §Acceptance Criteria "Two distinct feedback channels" + "No-valence-coding" + ADR-0011 §3:*

- [ ] **GIVEN** a card resolution with magnitude in [0, 0.3), **THEN** only scale-pulse plays — shake amplitude is exactly 0
- [ ] **GIVEN** magnitude in [0.3, 0.7), **THEN** scale-pulse + light shake (2–4px, ≤150ms) both play
- [ ] **GIVEN** magnitude in [0.7, 1.0], **THEN** bigger pulse (up to 1.10–1.15) + stronger shake, capped at the high-tier ceiling
- [ ] **GIVEN** the pulse tween completes or is interrupted, **THEN** the Card node's scale is `Vector2.ONE` when the next card presents (chain returns to ONE + `_on_card_presented()` defensive reset)
- [ ] **GIVEN** `resolve()` is called directly (no prior drag), **THEN** the pulse is center-anchored — `resolve()` sets `pivot_offset = size / 2.0` itself
- [ ] **GIVEN** the shake, **THEN** it offsets the Card node's visual position around the captured rest position and returns exactly to rest — layout/anchors untouched, touch bounds unchanged
- [ ] **GIVEN** two card resolutions of opposite outcome (win/loss) at equal magnitude, **THEN** pulse scale, shake amplitude/duration, and stinger params are identical (no-valence-coding)
- [ ] **GIVEN** the stinger player has no stream assigned (pre-art-bible state), **THEN** the play call no-ops silently via the explicit `if stream != null` guard — no error, no warning spam
- [ ] **GIVEN** the app is backgrounded during RESOLVING, **THEN** juice tweens are killed by `_notification()` (extended beyond the current DRAGGING-only branch) and the next card presents at a clean scale/position
- [ ] **GIVEN** CardScreen's existing resolution payoff beat (`resolution_beat_seconds` + `resolution_beat_per_char`), **THEN** its effective display duration clamps within the GDD's [1.5, 2.5]s bounds for text lengths 0 / 30 / 60 / 200 chars — verify and, if current constants sit outside, retune the exported defaults to match (TR-juice-005 partial closure)

---

## Implementation Notes

*From ADR-0011 §3 (read the ADR's Decision section in full before implementing):*

1. In CardScreen's resolve path (before `DecisionCardSystem.resolve_choice()`): `var m: float = FeedbackMath.magnitude(option["resource_deltas"])` — the option Dictionary is already in hand; **no signal or payload changes anywhere**.
2. Scale-pulse: one tween chain `scale → pulse_scale(m) → Vector2.ONE`, pivot centered (`resolve()` sets `pivot_offset = _card_node.size / 2.0` defensively — do not rely on the drag path).
3. Shake: tween a visual offset around `_card_rest_position` (already captured for bounce-back) using `shake_amplitude_px(m)` / `shake_duration_sec(m)`; skip entirely when amplitude == 0. Fires only in RESOLVING — structurally non-overlapping with DRAGGING.
4. Stinger: add one `AudioStreamPlayer` child (scene or code). Read `stinger_params(m)`; apply layer count/tail/saturation to the (future) streams. Guard: `if player.stream != null: player.play()`. `# TODO: art-bible-pending` on stream slots.
5. `_on_card_presented()`: add `_card_node.scale = Vector2.ONE` beside the existing position/rotation resets.
6. `_notification(NOTIFICATION_APPLICATION_PAUSED)`: extend the existing handler to also kill pulse/shake tweens when `state == RESOLVING` (currently returns early for anything but DRAGGING).
7. TR-juice-005 verification: compute the payoff beat's effective duration at text lengths {0, 30, 60, 200} against the GDD clamp [1.5, 2.5]s; adjust the exported defaults if out of bounds (data change, not logic change).

---

## Out of Scope

- Story 001: FeedbackMath (dependency)
- Story 002: Action channel (ResourceHud)
- Stinger audio assets and their layer mixing — post-art-bible `/asset-spec system:juice-feedback-system`
- Reduce-motion toggle — GDD Open Question, owned by accessibility requirements revision (Polish)
- Rebuilding the payoff beat — it exists; this story only verifies/retunes its clamp

---

## QA Test Cases

*Derived from GDD §Acceptance Criteria (qa-lead classification in GDD §H).*

**Automated (Integration):**

- **AC-1**: tier gating
  - Given: CardScreen via scene_runner; synthetic cards with deltas producing m ≈ 0.1 / 0.5 / 0.9
  - When: resolve each
  - Then: shake tween absent / present with amp in [2,4]px / present capped; pulse target matches `pulse_scale(m)`
  - Edge: m exactly 0.3 and 0.7 (boundary ownership per FeedbackMath tiers)

- **AC-2**: scale returns to ONE
  - Given: resolve with m ≈ 0.9, then present next card immediately (interrupt mid-pulse)
  - Then: `_card_node.scale == Vector2.ONE` at next present

- **AC-3**: direct resolve() pivot
  - Given: `resolve(0)` called with no prior touch
  - Then: `pivot_offset == size / 2.0` during the pulse

- **AC-4**: rest-position return
  - Given: shake at high tier completes
  - Then: Card position == rest position exactly (±0.01px)

- **AC-5**: no-valence-coding
  - Given: two synthetic options with mirrored deltas (equal magnitude, opposite signs)
  - Then: identical pulse target, shake amplitude/duration, stinger params dictionaries

- **AC-6**: null-stream guard
  - Given: stinger player with `stream == null`
  - When: resolve at any magnitude
  - Then: no error output; no play attempted (assert via guard branch / player.playing == false)

- **AC-7**: backgrounding during RESOLVING
  - Given: resolve at high tier, then send `NOTIFICATION_APPLICATION_PAUSED` mid-effect
  - Then: juice tweens killed; next present is clean (scale ONE, rest position)

- **AC-8**: payoff clamp verification (TR-juice-005)
  - Given: resolution_reaction lengths 0 / 30 / 60 / 200 chars
  - Then: effective beat duration in [1.5, 2.5]s; 0 → floor, ≥60 → ceiling (within the exported defaults' tolerance)

**Manual (Visual/Feel — advisory addendum, evidence doc):**

- **Feel-1**: tier feel sign-off — resolve low/mid/high magnitude cards on device/editor; pulse+shake reads as "weight," not "verdict"; screenshot/video per tier
- **Feel-2**: touch targets undisplaced — during max shake, option labels/buttons remain tappable at their layout positions
- **Feel-3**: blind valence test (GDD's central AC) — a tester watching feedback only (text obscured) cannot tell a big win from a big disaster at equal magnitude

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/card_ui/card_feedback_test.gd` — must exist and pass
**Advisory addendum**: `production/qa/evidence/juice-card-feel-evidence.md` — Feel-1..3 walkthrough + sign-off (Visual/Feel tier, non-blocking for /story-done but required before epic close per EPIC.md DoD)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (FeedbackMath) must be DONE
- Unlocks: None (last story in epic; audio assets arrive via /asset-spec later)

## Completion Notes
**Completed**: 2026-07-06
**Criteria**: 8/8 automated passing + Feel-1..3 executed (developer session + external QA video review ×2, sign-offs in evidence doc)
**Deviations**: 3 advisory — (1) payoff-beat GDD conflict resolved: clamp [1.5, 2.5]s applies to the TEXT-driven part (juice GDD pacing intent), card-ui.md's milestone bonus (+1s) rides on top (max 3.5s) — documented in code and tests; (2) shake retune beyond GDD placeholder ranges (see story-001 note); (3) formal obscured-text A/B valence session deferred to the Vertical Slice playtest (structurally guaranteed + observationally confirmed meanwhile).
**Test Evidence**: Integration: tests/integration/card_ui/card_feedback_test.gd (12 tests PASSED); Visual/Feel: production/qa/evidence/juice-card-feel-evidence.md — EXECUTED, 2 sign-offs
**Code Review**: Complete — combined epic review; stale-shake-tween WARNING fixed + covered by test
