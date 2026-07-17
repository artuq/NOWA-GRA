# Story 002: Forced Card Injection with Guard Rails

> **Epic**: Burnout & Challenge System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (2-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**:


## Context

**GDD**: `design/quick-specs/final-burnout-2026-07-01.md`
**Requirement**: `TR-pcs-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013 §Decision (`BurnoutSystem` pseudocode, `_try_inject_burnout_card()`)
**ADR Decision Summary**: Card injection uses the already-shipped `DecisionCardSystem.inject_priority_card()` (ADR-0012 §4, Story 002 of prestige-checkpoint). This story implements the two guard rails ADR-0013's own validation pass required: checking `inject_priority_card()`'s real `bool` return (it can fail), and gating injection on `DecisionCardSystem.state == COOLDOWN` to avoid clobbering an in-progress normal card.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: `inject_priority_card(card_id: StringName) -> bool` — verified real signature (not `-> void` as ADR-0012's original pseudocode showed; corrected in the architecture registry 2026-07-17). Callers MUST check the return value.

**Control Manifest Rules (this layer)**:
- Required: n/a — delegates to `DecisionCardSystem`'s existing API, no new pattern
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From `design/quick-specs/final-burnout-2026-07-01.md` §1, §3, scoped to this story and ADR-0013's guard-rail corrections:*

- [ ] GIVEN `_cringe_sustained_seconds >= BURNOUT_THRESHOLD` and `_card_pending == false` and `DecisionCardSystem.state == COOLDOWN`, WHEN the injection attempt runs, THEN `DecisionCardSystem.inject_priority_card(BURNOUT_CARD_ID)` is called, and on a `true` return, `_card_pending = true` and `_cringe_sustained_seconds = 0.0`
- [ ] GIVEN the same trigger condition but `DecisionCardSystem.state != COOLDOWN` (a normal card is mid-cycle), WHEN the injection attempt runs, THEN injection is skipped — `_card_pending` stays `false`, `_cringe_sustained_seconds` is NOT reset, and the attempt retries on a subsequent frame once `state` returns to `COOLDOWN`
- [ ] GIVEN `inject_priority_card()` returns `false` (misconfigured `BURNOUT_CARD_ID`, or a priority card already pending from elsewhere), WHEN the injection attempt runs, THEN a `push_error()` is logged, `_card_pending` stays `false`, and the attempt retries next frame — this must NEVER silently soft-lock (permanently stuck `_card_pending == false` with the threshold condition satisfied but no further attempts)
- [ ] GIVEN the Burnout Card is presented (`_card_pending == true`), THEN no normal card can be checked/presented until it resolves — verified via `DecisionCardSystem`'s existing `state` machine (this story does not add a new suspension mechanism, it relies on `inject_priority_card()`'s already-shipped `PRESENTING` takeover)

---

## Implementation Notes

*Derived from ADR-0013's `_try_inject_burnout_card()` (already fully specified in the ADR — implement as written, do not deviate):*

```gdscript
func _try_inject_burnout_card() -> void:
	if DecisionCardSystem.state != DecisionCardSystem.State.COOLDOWN:
		return  # mid-cycle on a normal card -- retry next frame, no reset
	if DecisionCardSystem.inject_priority_card(BURNOUT_CARD_ID):
		_card_pending = true
		_cringe_sustained_seconds = 0.0
	else:
		push_error("BurnoutSystem: inject_priority_card(%s) returned false -- " %
			BURNOUT_CARD_ID + "verify this id exists in CardContentDatabase")
```

Called from Story 001's `_process()` at the point marked "card injection trigger is Story 002" — wire this call in at `_cringe_sustained_seconds >= BURNOUT_THRESHOLD and not _card_pending`.

**Validation Criterion (ADR-0013, BLOCKING at implementation time)**: `BURNOUT_CARD_ID` (`&"final_burnout"` default) must be confirmed against the real Wypalenie card entry in `CardContentDatabase` before this ships — write a regression test asserting `CardContentDatabase.get_card(BurnoutSystem.BURNOUT_CARD_ID)` resolves to a real, non-empty entry. A mismatch here is exactly the silent-soft-lock class this story's third AC guards against at the call level; this test guards it at the content-config level.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the trigger timer itself (this story only reacts to the threshold-crossing condition)
- Story 003: what happens after the card is resolved (Choice A/B routing)
- Card content authoring itself (`CardContentDatabase`'s Wypalenie entry) — assumed to already exist or be authored in parallel; this story's regression test will catch a missing/misnamed entry loudly rather than silently

---

## QA Test Cases

**Integration — automated test specs:**

- **AC-1 (successful injection)**:
  - Given: threshold crossed, `DecisionCardSystem.state == COOLDOWN`
  - When: `_try_inject_burnout_card()` runs
  - Then: `inject_priority_card()` called with `BURNOUT_CARD_ID`; on `true`, `_card_pending` and timer-reset both happen

- **AC-2 (deferred injection, no clobbering)**:
  - Given: threshold crossed, `DecisionCardSystem.state == PRESENTING` (mock a normal card mid-flight)
  - When: `_try_inject_burnout_card()` runs
  - Then: `inject_priority_card()` is NOT called; `_card_pending` stays false; a subsequent call after `state` returns to `COOLDOWN` succeeds
  - Edge cases: `state == CHECKING`, `state == RESOLVING` — both must also defer

- **AC-3 (failed injection is loud, not silent)**:
  - Given: `inject_priority_card()` mocked/forced to return `false`
  - When: `_try_inject_burnout_card()` runs
  - Then: `push_error()` called (assert via `assert_error()`, same gdUnit4 technique already established in `tests/unit/prestige/prestige_persistence_test.gd`); `_card_pending` stays false, retries possible next call

- **AC-4 (normal card suspension via existing state machine)**:
  - Given: Burnout Card successfully injected (`_card_pending == true`)
  - When: `DecisionCardSystem._check_pool()` (or equivalent normal-flow check) is invoked
  - Then: it observes `state == PRESENTING` (already the Burnout card) and does not attempt to present anything else — this is `inject_priority_card()`'s existing, already-tested guarantee; this AC is a regression check that BurnoutSystem's usage doesn't break it, not a new mechanism

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/burnout/burnout_card_injection_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (trigger timer provides the threshold-crossing condition this story reacts to)
- Unlocks: Story 003 (Choice A/B routing needs a successfully-presented card to resolve)
