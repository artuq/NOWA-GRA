# Architecture Review Report

**Date**: 2026-07-14
**Engine**: Godot 4.6.3
**GDDs Reviewed**: 16 · **ADRs Reviewed**: 12 (11 Accepted, 1 Proposed)
**Mode**: full — focused on ADR-0012, the only non-Accepted decision (all others cleared in prior reviews 2026-06-20 → 2026-07-06)

---

## Traceability Summary

All systems except Prestige/Checkpoint were covered and Accepted in prior reviews and are
unchanged. This review's live surface is the Prestige/Checkpoint System (TR-pcs-*).

| TR-ID | Requirement | ADR Coverage | Status |
|-------|-------------|--------------|--------|
| TR-pcs-001 | PrestigeSystem autoload, synchronous read-then-reset entry point | ADR-0012 §1-2 | ✅ Covered |
| TR-pcs-002 | F1/F1b/F2/F3a-d META_BONUS formulas, unit-testable | ADR-0012 §3 | ✅ Covered |
| TR-pcs-003 | `DecisionCardSystem.inject_priority_card()` (Core Rule 6) | ADR-0012 §4 | ✅ Covered |
| TR-pcs-004 | Flag classification sweep — era-local vs meta-persistent (Core Rule 7) | ADR-0012 §5 | ✅ Covered |
| TR-pcs-005 | Save/restore era_count, per-type totals, meta flags | ADR-0012 §6 | ✅ Covered |
| TR-pcs-006 | Autosave suppression window (steps 1-5), resume before `era_transitioned` | ADR-0002 §suppression + ADR-0012 §2 | ✅ Covered |
| TR-pcs-007 | BurnoutSystem + ChallengeSystem mechanics | — | ❌ Gap |

Totals: 6 covered, 0 partial, 1 gap.

## Coverage Gaps

❌ **TR-pcs-007**: BurnoutSystem and ChallengeSystem have locked quick-specs
(`final-burnout-2026-07-01.md`, `challenge-era-runs-2026-07-01.md`) but no ADR.
ADR-0012 orchestrates the era transition those systems trigger, but does not
architecturally specify the systems themselves.
- Domain: Core / Progression
- Engine Risk: LOW
- Suggested action: either a lightweight ADR for the Burnout/Challenge autoloads,
  or an explicit ruling that the locked quick-specs are sufficient architectural
  spec, before their implementation stories (Sprint 11 11-2) are marked Ready.
- Not blocking ADR-0012 acceptance — ADR-0012 only covers PrestigeSystem's orchestration.
- **RESOLVED 2026-07-14 (post-review ruling)**: user ruled the locked quick-specs
  (`final-burnout-2026-07-01.md`, `challenge-era-runs-2026-07-01.md`) sufficient as
  architectural spec for these two systems; no separate ADR required. TR-pcs-007 is now
  ✅ covered. With this, all 7 prestige requirements are covered — the CONCERNS verdict's
  sole gap is closed.

## Cross-ADR Conflicts

None. ADR-0012 verified against its four dependencies:

- **Data ownership**: PrestigeSystem owns `era_count`, `meta_bonus_totals`, and prestige
  flags (stored as HistoryFlagManager milestones); ClassPathSystem owns affiliation/tier.
  No shared-authority conflict.
- **Autosave atomicity (ADR-0002)**: ADR-0002 exempts lifecycle-pause saves from
  suppression. Safe here — ADR-0012 §2 steps 1-5 run in one synchronous call stack with
  no `await`, so no lifecycle event can interleave mid-sequence. The synchronous
  guarantee is what makes the exemption sound.
- **Card FSM (ADR-0005/0008)**: `inject_priority_card` adds a `priority_card_pending`
  state orthogonal to the existing cooldown→checking→presenting→resolving cycle.
  Additive, same precedent as ADR-0010 §2's `card_resolved`.
- **Boot order (ADR-0003)**: PrestigeSystem registered below its four dependencies;
  `restore_state()` positioned after ClassPathSystem's. No dependency cycle.

## ADR Dependency Order

ADR-0012 depends on ADR-0001, ADR-0002, ADR-0003, ADR-0010 — all Accepted.
No unresolved dependencies, no cycles. ADR-0012 is implementable immediately upon acceptance.

Dependency claims verified against shipped code:
- `reset_era_state` / `get_tier` / `get_active_path` / `get_active_multiplier` exist in
  `src/core/class_path_system.gd`.
- `suppress_autosave` / `resume_autosave` specced in ADR-0002 §"Autosave suppression
  window"; code implementation pending (implementation-time, not an architecture blocker).
- `get_active_sponsor_multiplier` specced in ADR-0010 §5a; code pending.
- `inject_priority_card`, PrestigeSystem, BurnoutSystem, ChallengeSystem are new — nothing to migrate.

## GDD Revision Flags

None — all GDD assumptions consistent with verified engine behaviour.

## Engine Compatibility Issues

None. ADR-0012's only post-cutoff API is typed `Dictionary[StringName, float]` (Godot 4.4+),
correctly flagged and safe in 4.6.3. No deprecated APIs referenced (deprecated-apis.md
entries are all 3D / GDExtension / Android OBB — irrelevant to this 2D idle system).

**Engine specialist consultation**: folded. ADR-0012 already carries an embedded
godot-gdscript-specialist review (2026-07-13) whose two findings are baked into its
Validation Criteria (full call-graph `await`/`CONNECT_DEFERRED` grep; `assert()` stripped
in release builds). No fresh spawn — the sole engine concern (typed Dictionary) is vetted.

## Architecture Document Coverage

No orphaned architecture. Prestige/Checkpoint is systems-index #17 (Alpha, Designed);
ADR-0012 is its first and only ADR.

---

## Verdict: CONCERNS

ADR-0012 is complete, conflict-free, engine-clean, and all four dependencies are Accepted —
it clears to move **Proposed → Accepted**, unblocking PrestigeSystem implementation.

One coverage gap remains (TR-pcs-007): BurnoutSystem/ChallengeSystem have locked quick-specs
but no ADR. Their implementation stories need either a lightweight ADR or an explicit
"quick-spec sufficient" ruling before being marked Ready. This does not block ADR-0012.

### Pre-gate Checklist

- ✅ `tests/unit/`, `tests/integration/`
- ✅ `.github/workflows/tests.yml`
- ✅ `design/accessibility-requirements.md`
- ✅ `design/ux/interaction-patterns.md`

### Required Follow-ups (priority order)

1. Move ADR-0012 status Proposed → Accepted (this review's verdict supports it).
2. Resolve TR-pcs-007: lightweight ADR for BurnoutSystem/ChallengeSystem, or ruling that
   their quick-specs suffice, before Sprint 11 11-2 stories are Ready.
3. `/ux-design` pass on Prestige — meta-bonus visibility surface is a GDD-declared BLOCKING
   prerequisite for its implementation stories (not an architecture gap, but gates the epic).
