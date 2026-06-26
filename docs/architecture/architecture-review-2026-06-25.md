# Architecture Review Report

> Date: 2026-06-25
> Engine: Godot 4.6.3 / GDScript
> GDDs Reviewed: 14 (11 MVP set + systems-index)
> ADRs Reviewed: 8 (+ master architecture.md, control-manifest.md)
> Mode: /architecture-review full
> Verdict: **CONCERNS** (improved — prior reviews 2026-06-20 and 2026-06-24 also CONCERNS)

---

## What changed since 2026-06-24

- **ADR-0007 `Proposed → Accepted`** — the sole blocker from the prior review is
  cleared. The Action UI epic is unblocked (Stories 001–004 have since shipped per
  session state).
- **ADR-0008 added** (`Proposed`, 2026-06-25) — Card UI modal + swipe gesture +
  one additive `DecisionCardSystem.card_presented(card)` signal. Covers
  **TR-cui-001**, previously a deferred gap.
- **tr-registry.yaml** bumped v2 → v3: TR-cui-001 `gap → covered`, `adr: [ADR-0008]`.

## Traceability Summary

| | Count |
|---|---|
| Total requirements (registry) | 14 |
| ✅ Covered | 13 (was 12) |
| ⚠️ Partial | 0 |
| ❌ Gap (deferred by design) | 1 (was 2) |

### Matrix

| TR-ID | System | ADR Coverage | Status |
|-------|--------|--------------|--------|
| TR-res-001 | resource-system | ADR-0001, ADR-0006 | ✅ |
| TR-hist-001 | history-flag-system | ADR-0001 | ✅ |
| TR-save-001 | save-persistence-system | ADR-0001, ADR-0002 | ✅ |
| TR-save-002 | save-persistence-system | ADR-0002 | ✅ |
| TR-save-003 | save-persistence-system | ADR-0002 | ✅ |
| TR-off-001 | offline-progress-system | ADR-0006 | ✅ |
| TR-off-002 | offline-progress-system | ADR-0003 | ✅ |
| TR-act-001 | action-system | ADR-0004 | ✅ |
| TR-dcs-001 | decision-card-system | ADR-0005 | ✅ |
| TR-dcs-002 | decision-card-system | ADR-0005 | ✅ |
| TR-onb-001 | onboarding-tutorial | ADR-0001, ADR-0003, ADR-0005 | ✅ |
| TR-aui-001 | action-ui | ADR-0004, ADR-0007 | ✅ |
| TR-cui-001 | card-ui | ADR-0008 (Proposed) | ✅ |
| TR-ors-001 | offline-report-screen | — | ❌ Gap (deferred) |

The remaining gap (TR-ors-001, Offline Report Screen) is **deliberately deferred**
per architecture.md §"Can defer to implementation" — a straightforward, low-risk
Control-node screen. ADR-0007 and ADR-0008 now establish the Presentation-layer
precedent it would follow.

## Cross-ADR Conflicts

**None.** No state-ownership, dependency-cycle, integration-contract, or
performance-budget conflicts. ADR-0008's only state change is an *additive* signal
on `DecisionCardSystem`, exactly mirroring the `action_started` signal ADR-0007
added to `ActionSystem` — no breaking change, no ownership conflict.

### ADR Dependency Order (topologically sorted)

```
Foundation:    ADR-0001 → ADR-0002 → ADR-0003
Core:          ADR-0004 (→0001), ADR-0005 (→0001,0004), ADR-0006 (→0001,0003)
Presentation:  ADR-0007 (→0001,0004) [Accepted] → ADR-0008 (→0001,0007) [Proposed]
```

No cycles. ADR-0008 is the only ADR not yet Accepted; both its dependencies
(ADR-0001, ADR-0007) are Accepted, so it is ready for sign-off.

## GDD Revision Flags (Architecture → Design Feedback)

None — all GDD assumptions are consistent with verified engine behaviour. GDD edits
since 2026-06-24 (`action-system.md`, `action-ui.md`, `resource-system.md`) were the
TouchScreenButton→Button annotation fix and the Polish→English resource-key drift
fix, both already resolved in prior work — no new technical requirements introduced.

## Engine Compatibility

Engine: Godot 4.6.3.

- All 8 ADRs agree on Godot 4.6.3.
- **Post-Cutoff APIs Used:** None across any ADR.
- **Deprecated API references:** None.
- ADR-0008 self-rates MEDIUM knowledge risk (project's first gesture input + first
  modal) but uses only stable `Control`, `Tween` (`create_tween`),
  `InputEventScreenTouch`/`InputEventScreenDrag`, `mouse_filter`, and `pivot_offset`
  — all stable well before 4.4. It already carries an engine-specialist verdict
  dated 2026-06-25 (mouse_filter hit-order mechanism correction; single-touch
  `index`-based rejection; `_gui_input` vs `_input` routing).

**Engine specialist consultation:** skipped. ADR-0008 already embeds a same-day
specialist verdict; re-litigating a 0-day-old specialist decision would be
redundant — consistent with the prior review's handling of ADR-0007.

## Architecture Document Coverage

`architecture.md` covers all 11 MVP systems; no orphaned architecture.
Vertical-Slice+ systems remain correctly out of scope for this MVP review.

## Pre-gate Checklist (for /gate-check pre-production)

- ✅ `tests/unit/` + `tests/integration/`
- ✅ `.github/workflows/tests.yml`
- ✅ `design/accessibility-requirements.md`
- ✅ `design/ux/interaction-patterns.md`

All pre-gate items pass.

---

## Verdict: CONCERNS

Not PASS, due to one advisory item:

1. **ADR-0008 is `Proposed`, not `Accepted`** — per the project's "ADR must be
   Accepted before implementation" rule, Card UI epic stories are gated until
   sign-off. Its dependencies are already Accepted; this is a process gate, not a
   design defect.

Not FAIL: Foundation + Core fully covered, zero structural conflicts,
engine-consistent, all pre-gate artifacts present. The single remaining gap is a
deliberately deferred low-risk Presentation screen.

### Required Actions (priority order)

1. Sign off **ADR-0008** (`Proposed → Accepted`) to unblock the Card UI epic.
2. (Done in this review) tr-registry.yaml updated: TR-cui-001 → covered.
3. (Optional) Author an Offline Report Screen ADR, or formally record the
   TR-ors-001 deferral as accepted.

### Next

- `/gate-check pre-production` is viable — all pre-gate artifacts exist.
- Re-run `/architecture-review` after ADR-0008 is Accepted to confirm the verdict
  clears to PASS.
