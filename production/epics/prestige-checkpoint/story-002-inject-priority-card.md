# Story 002: inject_priority_card() Contract

> **Epic**: Prestige/Checkpoint System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S (1-2h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-07-14


## Context

**GDD**: `design/gdd/prestige-checkpoint-system.md`
**Requirement**: `TR-pcs-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 §4 (`DecisionCardSystem.inject_priority_card()`)
**ADR Decision Summary**: General-purpose forced-card injection, additive to `DecisionCardSystem`. Adds a `priority_card_pending` state orthogonal to the existing `cooldown → checking → presenting → resolving` cycle. Bypasses `_build_eligible_pool()`'s filtering entirely.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: None post-cutoff.

**Control Manifest Rules (this layer)**:
- Required: Decision Card cooldown stays a plain `int` counter (ADR-0005) — this story must not disturb that; the cooldown keeps accumulating underneath while a priority card is pending
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From GDD `design/gdd/prestige-checkpoint-system.md` §inject_priority_card() Contract, scoped to this story:*

- [ ] GIVEN no priority card is pending, WHEN `inject_priority_card("final_burnout")` is called, THEN it presents on the next available frame, bypassing pool selection, weighting, and cooldown entirely
- [ ] GIVEN a priority card is pending, WHEN a normal pool-selected card would present, THEN presentation is blocked until the priority card resolves
- [ ] GIVEN a priority card is pending, WHEN `inject_priority_card()` is called again with a different `card_id`, THEN the call is rejected (returns `false`/error), no queueing, the originally pending card remains sole

---

## Implementation Notes

*Derived from ADR-0012 §4:*

```gdscript
func inject_priority_card(card_id: StringName) -> void:
    assert(not _priority_card_pending, "inject_priority_card called while one is already pending")
    _priority_card_pending = true
    var card: Dictionary = CardContentDatabase.get_card(card_id)
    present_next_card([card])
```

Note (godot-gdscript-specialist review, ADR-0012): `assert()` is stripped in exported release builds — it's a dev-time guard only. The re-call rejection AC (3rd bullet above) needs a real runtime guard (early `return false`), not just the `assert`, since it must hold in release builds too.

The cooldown counter keeps accumulating underneath while `_priority_card_pending` is true, so a normal card is immediately eligible the instant the priority card resolves — verify this explicitly, it's easy to accidentally freeze the counter alongside blocking presentation.

**Performance**: no impact — `inject_priority_card()` is a discrete call (Choice A trigger, a rare event), not per-frame or per-action.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- BurnoutSystem's own logic for *when* to call `inject_priority_card("final_burnout")` — that's TR-pcs-007 (Blocked, no ADR yet for BurnoutSystem itself)

---

## QA Test Cases

**Integration — automated test specs:**

- **AC-1 (first call presents immediately)**:
  - Given: no priority card pending, normal pool has eligible cards
  - When: `inject_priority_card(card_id)` called
  - Then: the injected card presents next, not a pool-selected card; pool/weighting/cooldown logic never consulted for this presentation

- **AC-2 (blocks normal presentation)**:
  - Given: priority card pending
  - When: normal `_check_pool()` would otherwise present a card
  - Then: no normal card presents until the priority card resolves

- **AC-3 (rejects concurrent injection)**:
  - Given: priority card pending
  - When: `inject_priority_card()` called again with a different `card_id`
  - Then: returns `false` (or equivalent rejection), the originally pending card is unchanged
  - Edge cases: release-build behavior (assert stripped) — the rejection must be a real runtime check, not solely the `assert`

- **AC-4 (cooldown keeps accumulating)**:
  - Given: priority card pending
  - When: N actions complete during the pending window
  - Then: on resolution, the cooldown counter reflects those N completions — a normal card is eligible immediately if the counter's threshold is met

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/decision_card_system/inject_priority_card_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (independent of PrestigeSystem's orchestration internals — pure DecisionCardSystem extension)
- Unlocks: BurnoutSystem's forced-card mechanic (out of this epic's scope, TR-pcs-007)

## Completion Notes
**Completed**: 2026-07-14
**Criteria**: 4/4 passing
**Deviations**: ADVISORY — return type resolved as bool (story's sample said void); AC-3's release-build claim honestly documented as code-review-verified, not test-verified. A BLOCKING soft-lock bug (unknown card_id crashing resolve_choice()) was found and fixed during code review — not a remaining deviation.
**Test Evidence**: Integration — `tests/integration/decision_card_system/inject_priority_card_test.gd` (6 tests, all passing)
**Code Review**: Complete — APPROVED
