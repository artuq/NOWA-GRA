# Architecture Review Report

> Date: 2026-07-01
> Engine: Godot 4.6.3 / GDScript
> GDDs Reviewed: 14 (11 MVP set + systems-index) + class-path-system quick-spec
> ADRs Reviewed: 10 (9 Accepted + ADR-0010 Proposed)
> Mode: /architecture-review full
> Verdict: **PASS** (MVP set unchanged from 2026-06-26; ADR-0010 clear to accept)

---

## What changed since 2026-06-26

- **ADR-0010 added** (Proposed) — Class Path System: new `ClassPathSystem` Autoload,
  additive `card_resolved` signal on DecisionCardSystem, pull-model
  `get_active_multiplier()`, `restore_state`/`reset_era_state` API.
- New quick-specs added (challenge-era-runs, final-burnout, soft-reach-cap,
  locked-slot-preview, sponsor-network-shield, milestone-gated-action-slots,
  action-queue-auto-repeat) — not yet ADR-backed; correctly out of scope until they
  enter implementation.

## Traceability Summary

MVP set unchanged: all 14 MVP requirements remain ✅ Covered by Accepted ADRs
(no regressions). The delta is the **Class Path System** (systems-index #12,
Vertical Slice / Alpha), governed by `design/quick-specs/class-path-system-2026-07-01.md`
and newly addressed by ADR-0010.

### New requirements (Class Path System)

| TR-ID | Requirement | ADR-0010 | Status |
|-------|-------------|----------|--------|
| TR-cps-001 | ClassPathSystem Autoload owns affiliation floats [0–100]/path, tier ints [0–5], active path | §1 | ✅ |
| TR-cps-002 | Card resolution → additive `card_resolved` signal → path counter + affiliation recalc | §2, §4 | ✅ |
| TR-cps-003 | ActionSystem applies tier multiplier via pull-model `get_active_multiplier(action_id)` | §5 | ✅ |
| TR-cps-004 | Save/restore affiliation + tier via `restore_state(data)` (ADR-0003 pattern) | §7 | ✅ |
| TR-cps-005 | `reset_era_state` resets era-local state, preserves meta milestone flags | §6 | ⚠️ Partial — BurnoutSystem wiring deferred to Alpha (API contract only) |
| TR-cps-006 | Tier-5 signature card add/remove to DecisionCardSystem pool | — | ❌ Gap — Alpha scope; `signature_card_unlocked/removed` named in quick-spec but absent from ADR-0010 interface |
| TR-cps-007 | Path multipliers excluded from offline progress by default (Pillar 4) | implicit | ⚠️ Partial — ADR-0006 owns the offline formula and never calls `get_active_multiplier`, so behaviour is correct, but ADR-0010 does not state the exclusion explicitly |

Totals (new): 4 ✅ Covered, 2 ⚠️ Partial, 1 ❌ Gap — all partials/gap are Alpha-scoped
deferrals explicitly staged in the quick-spec's MVP/VS/Alpha split.

## Cross-ADR Conflicts

**None.** ADR-0010 follows the established additive-signal precedent (ADR-0007
`action_started`, ADR-0008 `card_presented`). `card_resolved` is emitted at the end of
`resolve_choice()`, after `HistoryFlagManager.increment_counter()` — additive, no state
ownership change to the Complete DecisionCardSystem backend. The pull-model multiplier
keeps ActionSystem fully ignorant of ClassPathSystem (no circular dependency). State
ownership is clean: **HistoryFlagManager** owns the `_choices_count` counters and
`resolve_path_eligibility()`; **ClassPathSystem** owns the affiliation float and tier
state; **ResourceManager** retains sole ownership of resource mutation (investment uses
the existing `apply_delta()`).

### ADR Dependency Order

ADR-0010 `Depends On`: ADR-0001, ADR-0003, ADR-0005, ADR-0008 — **all Accepted.**
No unresolved edges, no dependency cycle. Boot-order rule satisfied: ClassPathSystem
registered as Autoload #9, below DecisionCardSystem (its signal emitter) per ADR-0001;
`restore_state` called below DecisionCardSystem's in the ADR-0003 boot sequence.

```
Foundation:    ADR-0001 → ADR-0002 → ADR-0003
Core:          ADR-0004 (→0001), ADR-0005 (→0001,0004), ADR-0006 (→0001,0003)
Presentation:  ADR-0007 (→0001,0004) → ADR-0008 (→0001,0007)
               ADR-0009 (→0001,0003,0006,0007)
Feature:       ADR-0010 (→0001,0003,0005,0008)   [Proposed]
```

## GDD Revision Flags (Architecture → Design Feedback)

No **engine-reality** conflicts → no formal `Needs Revision` flags. Two design-side
housekeeping notes (advisory — belong to the design/quick-design workflow, not written
by this review):

- `design/gdd/history-flag-system.md` still documents a **2-path stub** Path Resolution
  Algorithm; the quick-spec extends it to 4-path and answers its `margin`/`threshold_min`
  open questions. The GDD should catch up when Class Path enters implementation.
- `design/gdd/systems-index.md` #12 Class Path System is `Not Started` with no Design Doc;
  the quick-spec asks for status → `Specced`.

## Engine Compatibility

Engine: Godot 4.6.3.

- All 10 ADRs agree on Godot 4.6.3.
- **Post-Cutoff APIs Used:** None across any ADR (ADR-0010 uses only Autoload, signal,
  `Dictionary`, `float`, `StringName` — all pre-4.3 stable).
- **Deprecated API references:** None.
- ADR-0010 self-rates LOW knowledge risk.

**Engine specialist consultation: not spawned.** ADR-0010 is engine-trivial and this
matches the prior handling of same-day ADRs (0007/0008/0009). Note: unlike ADR-0009,
ADR-0010 does not carry an *embedded* specialist sign-off — offer a consultation if a
domain second opinion is desired before acceptance.

## Architecture Document Coverage

`architecture.md` covers all 11 MVP systems; no orphaned architecture. Class Path System
is Vertical-Slice/Alpha and correctly outside the MVP architecture doc scope.

---

## Verdict: PASS

All 14 MVP requirements remain covered by Accepted ADRs; ADR-0010 introduces no
cross-ADR conflicts and is engine-clean (Godot 4.6.3, no post-cutoff or deprecated APIs).
The two partials + one gap (TR-cps-005 / 006 / 007) are all Alpha-scoped deferrals
explicitly staged in the quick-spec's MVP/VS/Alpha split — not blockers. ADR-0010
(a Vertical-Slice/Alpha feature) is clear to move Proposed → Accepted, unblocking
Stories 8-2 (Class Path Core) and 8-3 (Class Path HUD).

### Recommended ADR-0010 edits before acceptance (optional, one line each)

1. State explicitly that `get_active_multiplier()` is **not** called by the ADR-0006
   offline loop (locks in TR-cps-007 / Pillar 4).
2. Note the Tier-5 `signature_card_unlocked/removed` signal contract (DecisionCardSystem
   pool mutation) as deferred to the Alpha signature-card/BurnoutSystem ADR (closes the
   TR-cps-006 ambiguity).

### Next

- Accept ADR-0010 (Proposed → Accepted) to unblock the Class Path stories, or apply the
  two optional edits first.
- Re-run `/architecture-review` after the Alpha quick-specs (final-burnout,
  challenge-era-runs, etc.) receive their own ADRs.
