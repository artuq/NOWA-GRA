# Story 001: Stepped Offline Simulation

> **Epic**: Offline Progress System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2.0 days — provisional, per Sprint 5's producer feasibility gate; the loop logic and its tests are explicitly the least compressible part if this overruns)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-24

## Context

**GDD**: `design/gdd/offline-progress-system.md`
**Requirement**: `TR-off-001` — Stepped 1-minute simulation loop, capped at 1440 iterations (24h)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Offline Simulation Loop Implementation
**ADR Decision Summary**: Single synchronous `while` loop over fixed 60-second steps, capped at 1440 iterations (24h), applying H/M/Mult/Z formulas in that fixed order via a new shared `ResourceFormulas` static-method utility class (no instance state, ever) also consumed by live-play `ActionSystem`/`ResourceManager` — guaranteeing online/offline formula consistency by construction.

**Engine**: Godot 4.6.3 | **Risk**: LOW — pure GDScript math loop, no engine-specific API risk
**Engine Notes**: None required — no post-cutoff APIs used.

**Control Manifest Rules (this layer — Core)**:
- Required: Autoload singleton (per ADR-0001's boot order, after Resource System/Save System)
- Forbidden: threading (per `architecture.md` Principle 1) — confirmed unnecessary, worst case is sub-millisecond
- Guardrail: `ResourceFormulas` must remain stateless (static functions only) — no instance vars, no `@export` fields, ever; both this Autoload and `ActionSystem` call it independently and any shared state would silently leak across unrelated contexts

---

## Acceptance Criteria

*From GDD `design/gdd/offline-progress-system.md`, scoped to this story:*

**Cringe constancy:**
- [ ] Given `simulate_offline` is called with a fixed Cringe value, the Cringe value used in every step's `H_rate` calculation is identical from the first step to the last (read once before the loop, never reassigned inside it)

**Stepped evolution — Hatersi:**
- [ ] Worked example (Cringe=50, H0=5, M0=80%, Δt=24h) produces `H_rate≈0.27/min` constant and `final_H≈394` (±2%)
- [ ] Per-step update follows `H_new = H_old + H_rate×(dt/60)`, with `dt=60` for interior steps
- [ ] With `H0=0`, H still increases per the same formula; early Z gains are nonzero but small relative to a higher-H0 run

**Stepped evolution — Morale:**
- [ ] When `H≤N_buffer` for a step, `M_drain=0` for that step
- [ ] When `H>N_buffer`, `M_drain = M_drain_per_hater×(H-N_buffer)^M_drain_exp`, with M floored at 0
- [ ] The worked example produces `final_M≈0%` (±1pp)
- [ ] If M reaches 0 before the final step, `Mult(M)=0.5x` applies for all remaining steps (intentional design, not a bug — do not "fix" this)

**Stepped evolution — Zasięgi:**
- [ ] Each step's `Z_step = H×Z_per_hater×Mult(M)×(dt/60)`, using the **post-update** H and M for that step (fixed ordering: H, then M, then Mult, then Z — never reordered)
- [ ] The worked example produces `total_Z_gained` within 28,000–29,000
- [ ] With `Δt=0`, `total_Z_gained=0`, `final_H=H0`, `final_M=M0` (the loop never executes)

**Cap behavior:**
- [ ] `Δt=200,000s` (exceeds the 86400s cap) → only the first 1440 steps execute, `capped=true`
- [ ] `Δt=86400s` exactly → all 1440 steps execute, `capped=false` (boundary is inclusive, not exceeded)
- [ ] `Δt=86401s` → exactly 1440 steps execute (the trailing 1 second is discarded, not rounded into a 1441st step), `capped=true`

**Defined edge cases:**
- [ ] `Δt=0` → zero gain, no error, returns immediately with input values unchanged
- [ ] `Δt>86400` → result is identical to a standalone run with `Δt=86400` exactly (deterministic, reproducible — the function does not need to know *how much* it was capped by, only that it was)
- [ ] `H0=0` → no division-by-zero, no NaN, no negative values anywhere in the output; all outputs ≥0
- [ ] `M0=0%` at the start → `Mult(M)=0.5x` from step 1 onward
- [ ] A 1.5-step duration (`Δt=90`) is handled correctly — the loop's final iteration uses `dt=min(60, remaining)`, i.e. a partial 30-second final step, not a full 60-second one

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines — implement exactly as specified, this is not a paraphrase:*

```gdscript
# OfflineProgressSystem (Autoload)
const MAX_OFFLINE_CAP_SECONDS := 86400
const OFFLINE_STEP_SECONDS := 60

var last_simulation_result: Dictionary = {}  # transient, read-once by a future Offline Report Screen — never serialized by SaveSystem

func simulate_offline(elapsed_seconds: int) -> Dictionary:
    var capped := elapsed_seconds > MAX_OFFLINE_CAP_SECONDS
    var remaining: int = min(elapsed_seconds, MAX_OFFLINE_CAP_SECONDS)
    var cringe_fixed: float = ResourceManager.get_resource(&"Cringe")
    var h: float = ResourceManager.get_resource(&"Hatersi")
    var m: float = ResourceManager.get_resource(&"Morale")
    var z_gained: float = 0.0

    while remaining > 0:
        var dt: int = min(OFFLINE_STEP_SECONDS, remaining)
        var dt_minutes: float = dt / 60.0

        # Fixed order per offline-progress-system.md Core Rules: H, then M, then Mult, then Z
        var h_rate := ResourceFormulas.haters_growth_rate(cringe_fixed)
        h += h_rate * dt_minutes

        var m_drain := ResourceFormulas.morale_drain_rate(h)
        m = max(0.0, m - m_drain * dt_minutes)

        var mult := ResourceFormulas.action_effectiveness_multiplier(m)
        z_gained += h * Z_PER_HATER * mult * dt_minutes

        remaining -= dt

    var result := {
        "final_H": h,
        "final_M": m,
        "total_Z_gained": z_gained,
        "capped": capped,
    }
    last_simulation_result = result
    return result
```

**Correction discovered during implementation (2026-06-24)**: ADR-0006's text above describes `ResourceFormulas` as something this story creates — that's stale. `res://src/core/resource_formulas.gd` already exists in full, built during the Resource System epic (Stories 003-005, all Complete), including a fourth function, `passive_zasiegi_income(hatersi_count, morale_mult, elapsed_seconds)`, that ADR-0006 predates and never mentions. This story's actual scope is therefore smaller than the ADR implies: only `OfflineProgressSystem` itself (the loop sequencing `ResourceFormulas`' already-tested static calls) is new code here. The implementation calls `ResourceFormulas.passive_zasiegi_income()` for the Z step rather than reimplementing the `Z_PER_HATER` multiplication inline as ADR-0006's pseudocode shows — using the real, already-tested function instead of duplicating its math, consistent with the ADR's own stated goal of one shared implementation. Do not modify `ActionSystem` in this story; it does not yet call `ResourceFormulas` at all (separate future migration), and that remains out of scope here.

**Known GDD deviation — reentrancy AC dropped, documented per user decision (2026-06-24):**
The GDD's Acceptance Criteria section includes: *"GIVEN `computing` or `presenting`, WHEN a second app-start event fires before the cycle completes, THEN `simulate_offline` is not invoked a second time concurrently."* This scenario is structurally unreachable given the actual architecture: ADR-0003 establishes that `BootController._ready()` runs exactly once per cold start (Godot's main-scene lifecycle cannot fire `_ready()` twice within one process), and `simulate_offline()` itself is a synchronous, sub-millisecond loop (per ADR-0006's Performance Implications) — there is no "mid-cycle" window for a second invocation to race against, either within one process or across a killed/relaunched process (no in-memory state survives a process kill to be re-entered). This was a known open question in the GDD itself (`## Open Questions`: *"Re-entrancy guard for rapid repeated app launches — flagged by qa-lead, no explicit lock rule defined"*), never resolved by ADR-0003 or ADR-0006 despite the GDD's stated target of resolving it "before `/architecture-decision`." Resolution: drop the AC from this story rather than add a guard with no real trigger path to test against. Add this as a one-line code comment on `simulate_offline()`, not a defensive guard clause.

---

## Out of Scope

*Handled by a future epic — do not implement here:*

- **TR-off-002** (launch-time boot sequencing, ADR-0003): `BootController`, calling `simulate_offline()` at boot, applying the result to `ResourceManager`, and routing to the Offline Report Screen vs. Main scene based on the 300s threshold. None of `BootController`, the Offline Report Screen, or the Main scene exist yet — this requires a future Boot/Scene-Management epic once those Presentation-layer pieces are built.
- Migrating `ActionSystem`'s existing live-play formula logic to call the new `ResourceFormulas` static functions — `ResourceFormulas` is created correctly by this story, but rewiring `ActionSystem` to consume it is separate scope (must not break Action System's existing, already-Complete tests).
- Offline Report Screen presentation (formatting, "you were away for X" copy, capped-flag messaging) — undesigned, owned by a future UI epic.

---

## QA Test Cases

*Test specs reused from `production/qa/qa-plan-sprint-5-2026-06-24.md` (written 2026-06-24, before this story existed — generated directly from the GDD since no story file existed yet at QA-plan time).*

- **AC: Cringe constancy**
  - Given: `simulate_offline` called with `Cringe_fixed=50` and `Δt` spanning multiple steps
  - When: every step executes
  - Then: the Cringe value read in step 1's `H_rate` calculation equals the Cringe value read in the final step's calculation
  - Edge cases: single-step run (Δt=60) and max-length run (Δt=86400) — same invariant must hold at both extremes

- **AC: Stepped Hatersi evolution (worked example)**
  - Given: Cringe=50, H0=5, M0=80%, Δt=24h (86400s)
  - When: `simulate_offline(86400)` completes
  - Then: `final_H≈394` (±2%), and `H_rate≈0.27/min` holds constant per-step (spot-check at step 1, step 720, step 1440)
  - Edge cases: H0=0 (still increases, no special-case branch)

- **AC: Stepped Morale evolution (worked example)**
  - Given: same worked example inputs
  - When: simulation completes
  - Then: `final_M≈0%` (±1pp); confirm `M_drain=0` while `H≤N_buffer` and the nonzero formula applies once `H>N_buffer`
  - Edge cases: M reaches 0 before the final step → confirm `Mult(M)=0.5x` for all subsequent steps (not a bug); M0=0% at start → confirm `Mult(M)=0.5x` from step 1

- **AC: Stepped Zasięgi evolution (worked example)**
  - Given: same worked example inputs
  - When: simulation completes
  - Then: `total_Z_gained` falls within 28,000–29,000; confirm each step's Z calculation uses **post-update** H and M (test by asserting order-of-operations, e.g. via a formula-call-order spy, not just the final total)
  - Edge cases: Δt=0 → `total_Z_gained=0`, `final_H=H0`, `final_M=M0`

- **AC: Cap behavior**
  - Given: Δt=200,000s / Δt=86400s / Δt=86401s (three separate test cases)
  - When: `simulate_offline()` is called with each
  - Then: 1440/1440/1440 steps execute respectively; `capped` = true/false/true respectively
  - Edge cases: the 86400/86401 boundary pair is the critical assertion — off-by-one here is the most likely real bug

- **AC: Partial final step**
  - Given: Δt=90 (1.5 steps)
  - When: simulation completes
  - Then: exactly 2 iterations execute, the second with `dt=30` (not `dt=60`)
  - Edge cases: Δt=1 (single-second run, smallest nonzero case)

- **AC: No NaN/negative/division-by-zero**
  - Given: H0=0, Δt=86400 (worst case for early-loop degenerate values)
  - When: simulation completes
  - Then: every step's `final_H`, `final_M`, `total_Z_gained` are finite, non-negative numbers

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/offline_progress_system/offline_simulation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Resource System (Complete), Save/Persistence System (Complete) — both provide the `ResourceManager` reads this story's `simulate_offline()` consumes
- Unlocks: A future Boot/Scene-Management epic (TR-off-002, ADR-0003) — cannot start until `simulate_offline()`'s output shape is fixed by this story

---

## Completion Notes
**Completed**: 2026-06-24
**Criteria**: 19/19 passing (reentrancy AC dropped per documented decision — structurally unreachable given the actual architecture)
**Deviations**: 1 advisory, already documented in this file's Implementation Notes — `ResourceFormulas` already existed (Resource System epic) before this story began; ADR-0006's claim that this story creates it was stale, corrected here rather than left silently wrong
**Test Evidence**: Logic — `tests/unit/offline_progress_system/offline_simulation_test.gd`, 14/14 passing (full regression 166/166 passing)
**Code Review**: Complete — `/code-review` APPROVED (engine specialist CLEAN; qa-tester found 4 real coverage gaps, all fixed with new tests before this closure)
