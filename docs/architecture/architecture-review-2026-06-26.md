# Architecture Review Report

> Date: 2026-06-26
> Engine: Godot 4.6.3 / GDScript
> GDDs Reviewed: 14 (11 MVP set + systems-index)
> ADRs Reviewed: 9 (+ master architecture.md, control-manifest.md)
> Mode: /architecture-review full
> Verdict: **PASS** (prior reviews 2026-06-20/24/25 all CONCERNS)

---

## What changed since 2026-06-25

- **ADR-0008 `Proposed → Accepted`** (2026-06-26) — the sole blocker from the prior
  review is cleared. Card UI epic shipped (3 stories Complete, suite 240/240).
- **ADR-0009 added** (`Proposed → Accepted` in this review) — Offline Report Screen:
  standalone scene, transient result hand-off, single-fire dismiss. Covers
  **TR-ors-001**, previously the last deferred gap.

## Traceability Summary

| | Count |
|---|---|
| Total requirements (registry) | 14 |
| ✅ Covered | 14 (was 13) |
| ⚠️ Partial | 0 |
| ❌ Gap | 0 (was 1) |

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
| TR-cui-001 | card-ui | ADR-0008 (Accepted) | ✅ |
| TR-ors-001 | offline-report-screen | ADR-0009 (Accepted) | ✅ |

Full MVP coverage. No remaining gaps.

## Cross-ADR Conflicts

**None.** ADR-0009 fills the Offline Report Screen's own architecture; ADR-0003
already owns the boot orchestration and even names the report scene path — the two
are complementary, not overlapping. The `elapsed_seconds` key ADR-0009 adds to
`OfflineProgressSystem.last_simulation_result` is an *additive* augmentation written
by `BootController` (the same component ADR-0003 owns) — no state-ownership conflict.

The scene-swap (ADR-0009) vs modal (ADR-0008, Card UI) difference is a **justified
divergence, not a pattern conflict**: the report is a launch-only gate *before* play
(nothing live beneath to preserve); Card UI is a modal *over* live play. Opposite
lifecycles → opposite mechanisms (ADR-0009 §1 + Alternative 1).

### ADR Dependency Order (topologically sorted)

```
Foundation:    ADR-0001 → ADR-0002 → ADR-0003
Core:          ADR-0004 (→0001), ADR-0005 (→0001,0004), ADR-0006 (→0001,0003)
Presentation:  ADR-0007 (→0001,0004) → ADR-0008 (→0001,0007)
               ADR-0009 (→0001,0003,0006,0007)
```

No cycles. All 9 ADRs Accepted; every dependency edge resolves to an Accepted ADR.

## GDD Revision Flags (Architecture → Design Feedback)

None — no GDD assumption conflicts with verified engine behaviour.

Two ADR-0009 deviations from `offline-report-screen.md` are documented and
behaviour-equivalent (advisory, not revision flags):
- GDD "full-screen modal" → ADR makes it a full-screen *scene*; both block all
  interaction, only the mechanism word differs.
- GDD `presenting → idle` state machine → ADR expresses the lifecycle via scene
  flow (no reader for the state). Simplification, not contradiction.

## Engine Compatibility

Engine: Godot 4.6.3.

- All 9 ADRs agree on Godot 4.6.3.
- **Post-Cutoff APIs Used:** None across any ADR.
- **Deprecated API references:** None.
- ADR-0009 self-rates LOW risk — uses only `Control`, `Button`,
  `change_scene_to_file`, `Tween` (`create_tween`), all stable well before 4.4. It
  carries a same-day (2026-06-26) engine-specialist note on the full-rect `Button`
  dismiss pattern (avoids `_gui_input`/`_unhandled_input` double-fire).

**Engine specialist consultation:** skipped. ADR-0009 already embeds a same-day
specialist verdict; re-litigating a 0-day-old decision would be redundant —
consistent with the prior handling of ADR-0007/0008.

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

## Verdict: PASS

All 14 MVP requirements covered by Accepted ADRs, zero cross-ADR conflicts,
engine-consistent (Godot 4.6.3, no post-cutoff or deprecated APIs), all pre-gate
artifacts present. ADR-0009 is accepted as part of this independent review (no design
defect, no conflict, no engine issue found), unblocking the Offline Report Screen epic.

### Next

- `/gate-check pre-production` is viable — all pre-gate artifacts exist.
- Offline Report Screen epic is unblocked: `/create-epics offline-report-screen`
  → `/create-stories` → `/dev-story`.
