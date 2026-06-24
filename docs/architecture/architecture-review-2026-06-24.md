# Architecture Review Report

> Date: 2026-06-24
> Engine: Godot 4.6.3 / GDScript
> GDDs Reviewed: 11 (MVP set)
> ADRs Reviewed: 7 (+ master architecture.md)
> Mode: /architecture-review full
> Verdict: **CONCERNS** (improved — prior review 2026-06-20 also CONCERNS)

---

## What changed since 2026-06-20

- ADR-0001 → ADR-0006 all moved `Proposed` → **Accepted**.
- Stale `OS.get_unix_time()` reference fixed (architecture.md:35 now uses
  `Time.get_unix_time_from_system()`; remaining hits are historical review prose
  and the control-manifest "never use this" rule).
- All four pre-gate artifacts now exist (`tests/unit`, `tests/integration`,
  `.github/workflows/tests.yml`, `design/accessibility-requirements.md`,
  `design/ux/interaction-patterns.md`).
- ADR-0007 (Action UI scene structure + Autoload binding) added — status `Proposed`.

## Traceability Summary

| | Count |
|---|---|
| Total requirements (registry) | 14 |
| ✅ Covered | 12 (was 11) |
| ⚠️ Partial | 0 (was 1) |
| ❌ Gap (deferred by design) | 2 |

**TR-aui-001 upgraded ⚠️ partial → ✅ covered**: ADR-0007 scopes ADR-0004's
`get_progress()` per-frame polling to `RunningActionOverlay` via `set_process()`,
satisfying action-ui.md's "every frame, not throttled" requirement.

The 2 remaining gaps (TR-cui-001 Card UI swipe, TR-ors-001 Offline Report Screen)
remain **deliberately deferred** per architecture.md §"Can defer to implementation"
— straightforward Control-node patterns, low risk. ADR-0007 now establishes the
Presentation-layer precedent they would follow.

## Cross-ADR Conflicts

None structural — no state-ownership, dependency-cycle, or performance-budget
conflicts. Dependency graph is clean and topologically sound:

```
Foundation:    ADR-0001 → ADR-0002 → ADR-0003
Core:          ADR-0004 (→0001), ADR-0005 (→0001,0004), ADR-0006 (→0001,0003)
Presentation:  ADR-0007 (→0001,0004)   [Proposed]
```

No cycles. ADR-0007 is the only ADR not yet Accepted — its dependencies
(ADR-0001, ADR-0004) are both Accepted, so it is ready for sign-off.

## GDD Revision Flags (Architecture → Design Feedback)

One verified-engine-reality conflict, resolved in this review:

| Doc | Assumption | Reality (ADR-0007 + engine specialist 2026-06-24) | Action |
|-----|-----------|---------------------------------------------------|--------|
| technical-preferences.md; action-system.md:129; action-ui.md:120; architecture.md:39; adr-0004 diagram | UI uses `TouchScreenButton` | Plain `Button` is correct; `TouchScreenButton` is a legacy `Node2D` control not integrated with `Control` layout/theming, discouraged | **FIXED 2026-06-24** — annotations updated to `Button`, design intent ("large touch areas, no hover-only") preserved |

Design intent was never in conflict — only the stale node-type annotation. No
systems-index status change: this was documentation lag behind an Accepted ADR,
not a design defect.

## Engine Compatibility

All 7 ADRs agree on Godot 4.6.3, declare zero post-cutoff APIs, and reference no
deprecated APIs. ADR-0007 self-rates MEDIUM knowledge risk (Modern editor theme /
4.4-4.6 UI rendering unverified for this use case) but uses only stable
`Control`/`Button`/`ProgressBar`/`_process()` primitives — acceptable.

No fresh engine-specialist consultation was spawned: ADR-0007 already carries a
specialist verdict dated 2026-06-24 (Button vs TouchScreenButton); re-litigating a
two-day-old specialist decision would be redundant.

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

Not PASS, due to two advisory items:

1. **ADR-0007 is `Proposed`, not `Accepted`** — per the project's "ADR must be
   Accepted before implementation" rule, Action UI epic stories are blocked until
   it is signed off. Its dependencies are already Accepted; this is a process gate.
2. **TouchScreenButton → Button annotation drift** — fixed in this review across
   5 documents; listed here for the audit trail.

Not FAIL: Foundation + Core fully covered, zero structural conflicts,
engine-consistent, all pre-gate artifacts present.

### Required Actions (priority order)

1. Move ADR-0007 from `Proposed` to `Accepted` (review + sign off) to unblock the
   Action UI epic.
2. (Optional) Author Presentation-layer ADRs for Card UI / Offline Report Screen,
   or formally sign off the deferral recorded in tr-registry.yaml.

### Next

- `/gate-check pre-production` is now viable — all pre-gate artifacts exist.
- Re-run `/architecture-review` after ADR-0007 is Accepted to confirm the verdict
  clears to PASS.
