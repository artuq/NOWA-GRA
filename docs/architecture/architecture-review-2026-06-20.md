# Architecture Review Report

> Date: 2026-06-20
> Engine: Godot 4.6.3 / GDScript
> GDDs Reviewed: 11 (MVP set)
> ADRs Reviewed: 6 (+ master architecture.md)
> Mode: /architecture-review full
> Verdict: **CONCERNS**

---

## Traceability Summary

| | Count |
|---|---|
| Total technical requirements | 17 |
| ✅ Covered | 12 |
| ⚠️ Partial | 1 |
| ❌ Gap (deferred by design) | 4 |

## Traceability Matrix

| TR-ID | GDD | Requirement | ADR | Status |
|---|---|---|---|---|
| TR-res-001 | resource-system.md | Traceable resource mutations; shared formula source | ADR-0001, ADR-0006 | ✅ |
| TR-hist-001 | history-flag-system.md | Flag log + pattern counters | ADR-0001 | ✅ |
| TR-save-001 | save-persistence-system.md | Autoload-owned save I/O | ADR-0001, ADR-0002 | ✅ |
| TR-save-002 | save-persistence-system.md | Atomic temp-write + rename | ADR-0002 | ✅ |
| TR-save-003 | save-persistence-system.md | schema_version + corruption fallback | ADR-0002 | ✅ |
| TR-off-001 | offline-progress-system.md | Stepped 1440-iteration simulation loop | ADR-0006 | ✅ |
| TR-off-002 | offline-progress-system.md | Launch-time init sequencing | ADR-0003 | ✅ |
| TR-act-001 | action-system.md | Timer + single-concurrency enforcement | ADR-0004 | ✅ |
| TR-dcs-001 | decision-card-system.md | Weighted pick (Cringe-scaled) | ADR-0005 | ✅ |
| TR-dcs-002 | decision-card-system.md | Action-count cooldown | ADR-0005 | ✅ |
| TR-onb-001 | onboarding-tutorial.md | Card suppression + force-cooldown gate | ADR-0001, ADR-0003, ADR-0005 | ✅ |
| TR-aui-001 | action-ui.md | Per-frame progress poll | ADR-0004 `get_progress()` | ⚠️ partial |
| TR-cui-001 | card-ui.md | Swipe/drag modal presentation | — | ❌ deferred |
| TR-ors-001 | offline-report-screen.md | Offline result presentation screen | — | ❌ deferred |

The ❌ Presentation-layer items are **deliberately deferred** by `architecture.md`
(§Required ADRs → "Can defer to implementation"): straightforward Control-node
patterns fully specified in their GDDs' Formulas sections, low architectural risk.
Not blocking gaps.

## Cross-ADR Conflicts

None. State ownership is clean — `ResourceManager` solely owns the 5 currencies and
Morale bands; no two ADRs claim the same state. `ResourceFormulas` is a single shared
static class (ADR-0006), eliminating online/offline formula divergence by construction.
Boot/init order is consistent between ADR-0001 (autoload order) and ADR-0003 (restore order).

## ADR Dependency Order (topologically sorted)

```
Foundation:  ADR-0001 (autoload pattern) — root, enables all others
             ADR-0002 (save format)        requires 0001
Init:        ADR-0003 (boot order)         requires 0001, 0002
Core:        ADR-0004 (action timer)       requires 0001
             ADR-0005 (card weighting)     requires 0001, 0004
             ADR-0006 (offline loop)       requires 0001, 0003
```

No cycles. **All 6 ADRs are currently `Status: Proposed`.** ADR-0001 states it must be
Accepted before any other ADR; per its own rule, no module is implementable until
ADR-0001 → ADR-0006 are moved to Accepted. Process gate, not a design defect.

## GDD Revision Flags

None — all GDD assumptions are consistent with verified engine behaviour.

## Engine Compatibility Issues

All 6 ADRs agree on Godot 4.6.3, declare LOW knowledge risk, use zero post-cutoff APIs,
and reference no deprecated APIs. One real flag:

| Location | Issue | Fix |
|---|---|---|
| architecture.md:35; adr-0003 step 4 prose (line 51) | References `OS.get_unix_time()` — removed in Godot 4 (moved to the `Time` singleton in the 3→4 migration) | Use `Time.get_unix_time_from_system()` — ADR-0003's actual code (lines 87-88) already does this correctly |

Documentation/prose inconsistency only; the implementable code is already correct.

## Architecture Document Coverage

`architecture.md` covers all 11 MVP systems across its layer map; no orphaned
architecture. Vertical-Slice+ systems (Class Path, Team/Staff, Prestige, etc.) are
correctly out of scope for this MVP review.

---

## Verdict: CONCERNS

Not FAIL: Foundation and Core layers fully covered, zero cross-ADR conflicts,
engine-consistent. Not PASS due to three advisory items:

1. All 6 ADRs are `Proposed`, not `Accepted` — blocks implementation start per ADR-0001's own rule.
2. One stale `OS.get_unix_time()` reference in two docs (trivial fix).
3. 3 Presentation-layer TRs intentionally have no ADR (acceptable, but worth explicit sign-off).

### Required Actions (priority order)

1. Move ADR-0001 → ADR-0006 from `Proposed` to `Accepted` (review and sign off).
2. Fix the `OS.get_unix_time()` reference in `architecture.md` and `adr-0003`.
3. Run `/test-setup` — no `tests/` dirs or CI workflow exist yet.
4. Run `/ux-design` — no `design/accessibility-requirements.md` or `design/ux/interaction-patterns.md`.
5. (Optional) Author Presentation-layer ADRs for Card UI / Offline Report Screen, or sign off the deferral.

### Pre-gate Checklist (for /gate-check pre-production)

- ❌ `tests/unit/` + `tests/integration/` — missing → `/test-setup`
- ❌ `.github/workflows/tests.yml` — missing → `/test-setup`
- ❌ `design/accessibility-requirements.md` — missing → `/ux-design`
- ❌ `design/ux/interaction-patterns.md` — missing → `/ux-design`

`/gate-check pre-production` is not yet viable until the above exist.
