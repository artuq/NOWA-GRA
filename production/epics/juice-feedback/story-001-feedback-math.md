# Story 001: FeedbackMath — Magnitude Formula + Tier Functions

> **Epic**: Juice/Feedback System
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: S (1–2h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-07-06

## Context

**GDD**: `design/gdd/juice-feedback-system.md`
**Requirements**: `TR-juice-001`, `TR-juice-003`, `TR-juice-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Juice/Feedback Architecture — Stateless FeedbackMath + Additive UI-Node Effects
**ADR Decision Summary**: `FeedbackMath` (`res://src/ui/feedback_math.gd`, `class_name FeedbackMath`, `extends RefCounted`) is a stateless static utility (ResourceFormulas precedent, ADR-0006) holding the magnitude formula and all tier functions. It reads `abs(delta)` only — the sign structurally cannot influence any output, making no-valence-coding a testable pure-function property.

**Secondary ADRs**: ADR-0006 (stateless-static-util precedent)

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: Pure GDScript math — no engine API beyond `log()`, `clampf()`, `absf()`. No post-cutoff APIs.

**Control Manifest Rules (Presentation layer)**:
- Required: stateless static utility for display-math (ResourceFormulas/CardSwipeMath precedent)
- Forbidden: instance vars or `@export` on the static utility (registry forbidden pattern for ResourceFormulas — same invariant applies); valence-coded feedback (registry forbidden pattern, ADR-0011)
- Guardrail: `magnitude()` is O(resources) ≤ 5 iterations — negligible

---

## Acceptance Criteria

*From GDD `juice-feedback-system.md` §Formulas + §Acceptance Criteria, scoped to the math only:*

- [ ] **GIVEN** deltas `{Cringe: +20, Morale: -3, Reach: +10}`, **THEN** `magnitude()` returns `max(20/35, 3/30, log(11)/log(41))` = **0.646** (GDD's worked example, ±0.001)
- [ ] **GIVEN** a bounded resource (Cringe norm 35, Morale norm 30), **THEN** contribution = `|delta| / norm_ref`, and magnitude is clamped to [0,1] inclusive
- [ ] **GIVEN** an unbounded resource (Reach, Sponsors, Haters) with a delta large enough to exceed 1.0 pre-clamp, **THEN** final magnitude is hard-clamped to 1.0
- [ ] **GIVEN** deltas across multiple resources, **THEN** magnitude = **maximum** of per-resource contributions — never sum or average
- [ ] **GIVEN** all-zero deltas, **THEN** `magnitude()` returns 0.0 and every tier function returns its lowest-tier (non-skip) value: `pulse_scale(0.0)` ≥ 1.02, `shake_amplitude_px(0.0)` == 0.0, `stinger_params(0.0).layers` == 1
- [ ] **GIVEN** any delta set `d`, **THEN** `magnitude(d) == magnitude(negated d)` — sign-invariance (no-valence-coding, the GDD's central guarantee)
- [ ] **GIVEN** magnitude tiers, **THEN** `shake_amplitude_px(m)` == 0 for m < 0.3; in [2,4]px for m in [0.3,0.7); capped for m in [0.7,1.0]. `pulse_scale(m)` in [1.02,1.05] low / up to [1.10,1.15] high, monotonically non-decreasing
- [ ] **GIVEN** a fuzz sweep of arbitrary delta dictionaries (deterministic seed-free value grid, not RNG), **THEN** magnitude is mathematically guaranteed ≤ 1.0 and ≥ 0.0

---

## Implementation Notes

*From ADR-0011 Decision §1:*

Create `res://src/ui/feedback_math.gd`:

```gdscript
class_name FeedbackMath
extends RefCounted

const Z_NORM_REF: float = 40.0        # unbounded log normalization (GDD tuning knob, safe 20-80)
const NORM_CRINGE: float = 35.0       # tracks CardContentDatabase cringe delta ceiling
const NORM_MORALE: float = 30.0       # tracks Resource System band gap

static func magnitude(deltas: Dictionary) -> float
static func pulse_scale(m: float) -> float         # 1.02..1.15 per GDD tiers
static func shake_amplitude_px(m: float) -> float  # 0 below 0.3; 2..4 mid; capped high
static func shake_duration_sec(m: float) -> float  # 0 below 0.3; <=0.15 mid; capped high
static func stinger_params(m: float) -> Dictionary # {layers: 1..3, tail_sec: 0.08..0.9, saturation: 0..1}
```

- Bounded set: `{&"Cringe": NORM_CRINGE, &"Morale": NORM_MORALE}`; every other key uses the log formula. Resource keys are the English StringNames used project-wide (&"Reach", &"Cringe", &"Morale", &"Sponsors", &"Haters").
- Only `absf(delta)` is ever read — do not branch on sign anywhere.
- All tuning values are `const` (ACTION_REWARDS tech-debt posture — extraction to data later).
- No instance state, no `@export` — same invariant comment as `resource_formulas.gd` lines 10–13.

---

## Out of Scope

- Story 002: ResourceHud count-up/flash (consumes this math)
- Story 003: CardScreen pulse/shake/stinger (consumes this math)
- Audio asset production — post-art-bible `/asset-spec`
- External data extraction of tuning consts

---

## QA Test Cases

*Derived from GDD §Acceptance Criteria (qa-lead classification in GDD §H: Logic, BLOCKING).*

- **AC-1**: GDD worked example
  - Given: `{&"Cringe": 20.0, &"Morale": -3.0, &"Reach": 10.0}`
  - When: `FeedbackMath.magnitude(deltas)`
  - Then: `0.646 ± 0.001`
  - Edge cases: each contribution asserted separately (0.571 / 0.100 / 0.646)

- **AC-2**: bounded linear ratio
  - Given: `{&"Cringe": 35.0}` → 1.0; `{&"Cringe": 17.5}` → 0.5; `{&"Morale": 30.0}` → 1.0
  - Edge: `{&"Cringe": 70.0}` → clamped 1.0

- **AC-3**: unbounded log clamp
  - Given: `{&"Reach": 40.0}` → `log(41)/log(41)` = 1.0 exactly; `{&"Reach": 100000.0}` → clamped 1.0

- **AC-4**: max not sum
  - Given: two resources each contributing 0.5 → magnitude 0.5 (not 1.0)

- **AC-5**: zero deltas → lowest tier still defined
  - Given: `{}` and `{&"Reach": 0.0}` → magnitude 0.0; `pulse_scale(0.0) >= 1.02`; `shake_amplitude_px(0.0) == 0.0`; `stinger_params(0.0)["layers"] == 1`

- **AC-6**: sign-invariance (no-valence-coding) — dedicated test function per GDD §H
  - Given: value grid of delta sets, each mirrored with negated values
  - Then: `magnitude(d) == magnitude(-d)` exactly, for every pair

- **AC-7**: tier boundaries
  - Given: m in {0.0, 0.29, 0.3, 0.69, 0.7, 1.0}
  - Then: shake 0 / 0 / ≥2px / ≤4px / high-tier / capped; pulse monotone non-decreasing across the grid

- **AC-8**: fuzz clamp sweep
  - Given: deterministic grid of extreme values (±1e6, ±0.001, mixed keys, unknown resource keys)
  - Then: 0.0 ≤ magnitude ≤ 1.0 always; unknown keys treated as unbounded (log), never crash

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/feedback/feedback_math_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 002 (Action channel), Story 003 (Card channel)

## Completion Notes
**Completed**: 2026-07-06
**Criteria**: 8/8 passing (all automated)
**Deviations**: 1 — shake amplitude/duration consts retuned same-day beyond the GDD's placeholder ranges (2-4/8px → 6-8/12px, 0.10-0.25s → 0.30-0.40s) after feel-test + QA video review showed the original values fully masked by the scale-pulse ("As Designed / Needs Tweak"). GDD updated in sync; doubly justified by the web target (no haptics channel there).
**Test Evidence**: Logic: tests/unit/feedback/feedback_math_test.gd (20 tests PASSED)
**Code Review**: Complete — godot-gdscript-specialist + qa-tester (combined epic review); all findings resolved
