# Architecture Review Report

**Date**: 2026-07-17
**Engine**: Godot 4.6.3
**GDDs Reviewed**: 16 + 3 quick-specs · **ADRs Reviewed**: 13 (12 Accepted, 1 Proposed)
**Mode**: full — live surface is ADR-0013 (BurnoutSystem/ChallengeSystem), the only
decision changed since the 2026-07-14 review. ADR-0001→0012 unchanged and Accepted.

---

## Traceability Summary

Registry `tr-registry.yaml` v6 is the requirements baseline (30 TRs). All systems except
BurnoutSystem/ChallengeSystem were covered and Accepted in prior reviews and are unchanged.
This review's live surface is TR-pcs-007, now backed by ADR-0013 (was a "quick-spec
sufficient" ruling on 2026-07-14; now a real ADR).

| TR-ID | Requirement | ADR Coverage | Status |
|-------|-------------|--------------|--------|
| TR-pcs-007 | BurnoutSystem trigger + ChallengeSystem selection/modifiers | ADR-0013 | ✅ Covered (pending ADR-0013 Accept) |

Registry totals: 30 requirements — 27 covered, 3 partial, 0 gaps.

Pre-existing partials (unchanged, non-blocking, all with documented deferral notes):
- **TR-cps-005** — reset_era_state era-transition wiring. *Note now stale*: the note says
  "BurnoutSystem era_transitioned wiring deferred," but ADR-0012 (shipped) put the reset
  sweep — including `ClassPathSystem.reset_era_state()` — on PrestigeSystem, and ADR-0013
  confirms BurnoutSystem only *routes* into it. Recommend upgrading to covered (see registry note below).
- **TR-cps-007 (class-path)** — path multipliers excluded from offline; behaviour correct,
  awaiting a one-line ADR-0010 clarification. Untouched by this review.
- **TR-juice-005** — resolution payoff text duration; verify against GDD clamp at Story 9-2.

## Coverage Gaps

None. TR-pcs-007 — the sole open gap from the 2026-07-14 review — is now closed by ADR-0013,
which converts the prior "quick-specs sufficient" ruling into a proper architectural decision
with an ownership-split table, pull-model getters, and validation criteria.

## Cross-ADR Conflicts

None. ADR-0013 verified against its three dependencies (ADR-0012, ADR-0001, ADR-0010) and
the shipped code:

- **Data ownership** — ADR-0013 is *additive*, not a revision. It ratifies the ownership the
  shipped `prestige_system.gd` already holds (`era_count`, `meta_bonus_totals`, reset sweep,
  no-arg `era_transitioned` signal — all verified at `src/core/prestige_system.gd:68,185,274,403,414`).
  BurnoutSystem owns only trigger state (`_cringe_sustained_seconds`, `_card_pending`);
  ChallengeSystem owns only `_active_challenge_ids`. No shared authority.
- **Integration contracts (verified against shipped code)** —
  `DecisionCardSystem.inject_priority_card(card_id) -> bool` (`decision_card_system.gd:273`),
  `card_resolved(card_id, path_tag, option_chosen)` emitted synchronously in `resolve_choice()`
  (`decision_card_system.gd:56`, emit with no `await`/`call_deferred`),
  `State.COOLDOWN` enum (`:33`), `PrestigeSystem.on_burnout_accepted()`/`on_burnout_deferred(morale_cost)`
  (`:185`,`:274`), `challenge_mult` stub at `:203`. All exist as ADR-0013 assumes.
- **PrestigeSystem change surface** — exactly one line (`challenge_mult` stub `1.0` → real
  `ChallengeSystem.get_combined_meta_multiplier()`). No signature change, no reopening of the
  closed prestige-checkpoint epic. Lowest-risk possible integration.
- **ADR-0012 zero-await constraint** — inherited correctly. `_on_card_resolved` →
  `on_burnout_accepted()` runs synchronously within `resolve_choice()`'s call stack (normal
  non-deferred signal connection). The Challenge Selection UI flow runs *after*
  `era_transitioned` fires, so its `await` usage is outside the constrained window. ADR-0013
  draws the constraint boundary correctly at the signal emission.
- **Per-frame read safety** — ADR-0013's mitigation ("ResourceManager._process never writes
  Cringe") verified: `resource_manager.gd:67-73` `_process` only decrements
  `_shield_remaining_seconds`. No same-frame read-after-write hazard regardless of Autoload
  `_process` order.

## ADR Dependency Order

ADR-0013 depends on ADR-0012, ADR-0001, ADR-0010 — all Accepted. No unresolved dependencies,
no cycles. Implementable immediately upon acceptance.

**New boot-order constraint (implementation requirement, not a conflict)**: `BurnoutSystem`
must register strictly *after* `DecisionCardSystem` (its `_ready()` connects to
`DecisionCardSystem.card_resolved`) — identical to the constraint `ClassPathSystem` already
satisfies (`class_path_system.gd:219`). Current `[autoload]` block: DecisionCardSystem is
position 8; BurnoutSystem/ChallengeSystem/PrestigeSystem are net-new. PrestigeSystem is
already registered at position 11; appending BurnoutSystem/ChallengeSystem after it satisfies
the constraint trivially. No ordering constraint exists between Burnout/Challenge and
PrestigeSystem (calls into it happen at runtime post-boot, not from `_ready()`).

## GDD Revision Flags (Architecture → Design Feedback)

ADR-0013 documents its own GDD-sync debt — two quick-specs carry an ownership model the
shipped code and ADR-0012/0013 have superseded. These are the design-side flags:

| Doc | Stale assumption | Reality (ADR-0012/0013 + shipped code) | Action |
|-----|-----------------|----------------------------------------|--------|
| `design/quick-specs/final-burnout-2026-07-01.md` §4/§6 | `BurnoutSystem` persists `era_count`, `_deferred_this_era` via its own serialize/restore | Those fields live on `PrestigeSystem` (shipped); BurnoutSystem persists `_card_pending` only | Revise / add superseding note |
| `design/quick-specs/final-burnout-2026-07-01.md` §4 step 9 | `BurnoutSystem.era_transitioned(new_era, meta_bonus_granted)` | Real signal is `PrestigeSystem.era_transitioned` (no args) | Revise |
| `design/quick-specs/challenge-era-runs-2026-07-01.md` §1.1 / §3.1 | pushes multiplier via BurnoutSystem; `HistoryFlagManager.set_flag(...)` | pull-model `get_combined_meta_multiplier()`; real method is `set_milestone(...)` | Revise |

These are advisory (documentation drift), not blocking. `/dev-story` reads the governing ADR
before the quick-spec, so ADR-0013's ownership-split table is authoritative in practice.

## Engine Compatibility Issues

None. ADR-0013 uses only pre-4.3-stable APIs (`_process(delta)`, `Signal.connect()`,
`Dictionary`/`StringName`, `Array[StringName]`, `maxf()`) — same class already vetted by
ADR-0012. No post-cutoff APIs beyond typed collections (Godot 4.4+, safe in 4.6.3). No
deprecated APIs referenced — `deprecated-apis.md` entries (SkeletonIK3D and other 3D/GDExtension
items) are irrelevant to this 2D idle system.

**Engine specialist consultation**: not spawned. ADR-0013 carries no novel engine surface —
it reuses ADR-0012's already-vetted API class and embeds its own godot-gdscript-level analysis
(the `_process`/signal-synchrony/`inject_priority_card` return-value risks are all in its Risks
section with mitigations). No new engine concern to escalate.

## Architecture Document Coverage

No orphaned architecture. BurnoutSystem/ChallengeSystem are the trigger + challenge layer of
Prestige/Checkpoint (systems-index #17, Alpha); ADR-0013 is their first and only ADR.
`systems-index.md` does not list Burnout/Challenge as separate rows (they live under Prestige/
Checkpoint) — acceptable, they are sub-systems of #17, not independent index entries.

---

## Verdict: CONCERNS

ADR-0013 is complete, conflict-free, engine-clean, and all three dependencies are Accepted.
Every shipped-code claim it makes was verified this review. It clears to move
**Proposed → Accepted**, unblocking BurnoutSystem/ChallengeSystem `/create-stories`.

Two advisory follow-ups keep this from a clean PASS:
1. ADR-0013 is still **Proposed** — TR-pcs-007 coverage is provisional until it is Accepted.
2. Two quick-specs carry documented ownership drift (GDD Revision Flags above) — a doc-sync
   pass is recommended before any story is written directly against them.

Neither blocks acceptance. Registry has zero true gaps.

### Pre-gate Checklist

- ✅ `tests/unit/`, `tests/integration/`
- ✅ `.github/workflows/tests.yml`
- ✅ `design/accessibility-requirements.md`
- ✅ `design/ux/interaction-patterns.md`

### Required Follow-ups (priority order)

1. Move ADR-0013 status **Proposed → Accepted** (this review's verdict supports it).
2. Doc-sync pass (or superseding note) on both quick-specs per the GDD Revision Flags table,
   before `/create-stories` on BurnoutSystem/ChallengeSystem.
3. Registry hygiene: upgrade **TR-cps-005** partial → covered (its deferral note is now stale —
   the reset wiring shipped on PrestigeSystem via ADR-0012, confirmed by ADR-0013).
4. `/create-stories prestige-checkpoint` (or a new burnout/challenge epic) once ADR-0013 is
   Accepted — the two Autoloads currently have zero code, only quick-specs.
