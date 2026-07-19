# Story 003: Choice Routing into PrestigeSystem

> **Epic**: Burnout & Challenge System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (2-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-07-19


## Context

**GDD**: `design/quick-specs/final-burnout-2026-07-01.md`
**Requirement**: `TR-pcs-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013 §Decision (`BurnoutSystem._on_card_resolved()`) + ADR-0012 (`PrestigeSystem.on_burnout_accepted()`/`on_burnout_deferred()`, locked entry points)
**ADR Decision Summary**: The player's Accept/Defer choice reaches `PrestigeSystem` via `BurnoutSystem` listening to `DecisionCardSystem.card_resolved` (the existing additive-signal precedent, ADR-0008/ADR-0010) and routing synchronously — no new coupling on `DecisionCardSystem`, no `await`/`CONNECT_DEFERRED` anywhere in the chain, satisfying ADR-0012's binding ordering guarantee.

This story also adds one new getter to the already-shipped `PrestigeSystem` (`has_deferred_this_era() -> bool`), decided during this epic's story-planning: BurnoutSystem needs to know whether Defer was already used this era (to grey out Choice B on a second trigger, per the quick-spec's §5 requirement), but `_deferred_this_era` is a private field with no existing read access. This is the same class of minimal, lowest-risk change ADR-0013 already made for `challenge_mult` — one getter, no signature change to `on_burnout_accepted()`/`on_burnout_deferred()`.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: Default (non-`CONNECT_DEFERRED`) `Signal.connect()` runs the handler synchronously within the emitter's call stack — stable pre-4.3 Godot behavior, already verified for this exact pattern during ADR-0013's validation.

**Control Manifest Rules (this layer)**:
- Required: zero `await`/`CONNECT_DEFERRED`/`call_deferred` anywhere in `_on_card_resolved()` → `on_burnout_accepted()`'s combined call graph (ADR-0012's binding constraint, inherited)
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From `design/quick-specs/final-burnout-2026-07-01.md` §4-5, scoped to this story and ADR-0012/0013's actual ownership split:*

- [x] GIVEN the Wypalenie card resolves with `option_chosen == &"Accept the Burnout"` (the real authored label, `card_content_database.gd`, Story 002), WHEN `BurnoutSystem._on_card_resolved()` runs, THEN `_card_pending` is set to `false` AND `PrestigeSystem.on_burnout_accepted()` is called — in that order, same frame, same call stack
- [x] GIVEN the Wypalenie card resolves with `option_chosen == &"Defer the Burnout"` (the real authored label), WHEN `BurnoutSystem._on_card_resolved()` runs, THEN `_card_pending` is set to `false` AND `PrestigeSystem.on_burnout_deferred(BURNOUT_DEFER_MORALE_COST)` is called
- [x] GIVEN any OTHER card resolves (`card_id != BURNOUT_CARD_ID`), WHEN `card_resolved` fires, THEN `BurnoutSystem` takes no action — `_card_pending` and neither `PrestigeSystem` entry point are touched
- [x] GIVEN `PrestigeSystem.has_deferred_this_era()` returns `true` (Defer was already used this era), WHEN the Wypalenie card would next be presented, THEN the card's Defer option is unavailable/greyed — this AC covers `PrestigeSystem`'s new getter existing and returning the correct value; the actual UI greying is a separate future UI story, out of scope here
- [x] GIVEN `_OPTION_LABEL_ACCEPT`/`_OPTION_LABEL_DEFER` consts (added at story-readiness time, 2026-07-19, to guard against label drift), THEN they exactly match `CardContentDatabase`'s real `final_burnout` entry's two option `"label"` fields — a regression test, not a runtime check

---

## Implementation Notes

*Derived from ADR-0013's `_on_card_resolved()` pseudocode, CORRECTED at story-readiness time (2026-07-19) against the real option labels Story 002 authored — the ADR's original `&"accept"`/`&"defer"` were placeholders, never the shipped values:*

```gdscript
## The two literal strings below MUST exactly match card_content_database.gd's
## final_burnout entry's option "label" fields -- card_resolved's option_chosen
## is derived from that label (decision_card_system.gd:311), not a semantic
## id (see BurnoutSystem.BURNOUT_CARD_ID's own doc comment, Story 002). A
## future copy/localization pass touching either label breaks this silently
## unless the guard below (explicit push_error on an unrecognized third
## value) catches it.
const _OPTION_LABEL_ACCEPT: StringName = &"Accept the Burnout"
const _OPTION_LABEL_DEFER: StringName = &"Defer the Burnout"

func _on_card_resolved(card_id: StringName, _path_tag: StringName, option_chosen: StringName) -> void:
	if card_id != BURNOUT_CARD_ID:
		return
	_card_pending = false
	if option_chosen == _OPTION_LABEL_ACCEPT:
		PrestigeSystem.on_burnout_accepted()
	elif option_chosen == _OPTION_LABEL_DEFER:
		PrestigeSystem.on_burnout_deferred(BURNOUT_DEFER_MORALE_COST)
	else:
		push_error("BurnoutSystem: unrecognized Wypalenie option_chosen '%s' -- " % option_chosen +
			"neither Accept nor Defer branch taken, card content may have drifted from routing logic")
```

Connected in `_ready()`: `DecisionCardSystem.card_resolved.connect(_on_card_resolved)`.

**Validation Criterion (ADR-0013, tightened at story-readiness time)**: use an explicit `if/elif/else` with a `push_error()` on an unrecognized third value (as above), not the ADR's original simplified `if/else` — an `else`-catches-everything branch would silently treat any label drift as a Defer, which is worse than a loud error. Add a regression test asserting the two consts exactly match `CardContentDatabase.get_card(BurnoutSystemScript.BURNOUT_CARD_ID)["options"]`'s real label fields, so a future content edit fails this story's test suite instead of silently breaking routing.

**New `PrestigeSystem` getter** (add to `src/core/prestige_system.gd`, one line + doc comment, same minimal-change pattern as the `challenge_mult` stub replacement):

```gdscript
## Whether Choice B (Defer) has already been used this era. BurnoutSystem
## reads this to grey out the Defer option on a second same-era trigger
## (quick-spec final-burnout-2026-07-01.md §5) — PrestigeSystem owns
## _deferred_this_era (Story 006); this is its only external read access.
func has_deferred_this_era() -> bool:
	return _deferred_this_era
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the card injection itself (this story only handles what happens after resolution)
- The Defer-greyed-out UI treatment itself — future UI story, this story only ensures the data (`has_deferred_this_era()`) is correctly readable
- `PrestigeSystem.on_burnout_accepted()`/`on_burnout_deferred()`'s internal behavior — already shipped, prestige-checkpoint epic (Complete), not reopened here

---

## QA Test Cases

**Integration — automated test specs:**

- **AC-1 (Accept routes correctly)**:
  - Given: `card_resolved` emits with `card_id == BURNOUT_CARD_ID`, `option_chosen == &"Accept the Burnout"` (real label)
  - When: `_on_card_resolved()` runs
  - Then: `_card_pending == false`; a spy/real-call-count on `PrestigeSystem.on_burnout_accepted()` confirms exactly one call

- **AC-2 (Defer routes correctly)**:
  - Given: same, `option_chosen == &"Defer the Burnout"` (real label)
  - When: `_on_card_resolved()` runs
  - Then: `_card_pending == false`; `PrestigeSystem.on_burnout_deferred(BURNOUT_DEFER_MORALE_COST)` called exactly once with the correct cost argument

- **AC-5 (label drift guard, added at story-readiness time)**:
  - Given: `_OPTION_LABEL_ACCEPT`/`_OPTION_LABEL_DEFER` consts
  - When: compared against `CardContentDatabase.get_card(BURNOUT_CARD_ID)["options"]`'s real `"label"` fields
  - Then: exact match — this test fails loudly if a future content edit changes either label without updating routing

- **AC-3 (other cards ignored)**:
  - Given: `card_resolved` emits with a different `card_id`
  - When: `_on_card_resolved()` runs
  - Then: neither `PrestigeSystem` entry point is called; `_card_pending` unchanged

- **AC-4 (has_deferred_this_era getter)**:
  - Given: `PrestigeSystem.on_burnout_deferred()` has been called once this era (real call, not mocked)
  - When: `has_deferred_this_era()` is read
  - Then: returns `true`; after a subsequent `on_burnout_accepted()` (new era), returns `false` again (verify the getter reflects Story 006's own era-reset semantics, not a stale cached value)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/burnout/burnout_choice_routing_test.gd` — must exist and pass

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: Story 002 (a successfully-injected card must exist to resolve), prestige-checkpoint Story 001 (`on_burnout_accepted()`) and Story 006 (`on_burnout_deferred()`/`_deferred_this_era`) — both Complete
- Unlocks: Story 004 (persistence needs the full trigger→resolve cycle to test against)

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 5/5 passing
**Deviations**: ADVISORY — stale option_chosen values (&"accept"/&"defer") corrected at story-readiness time against Story 002's real card labels, before implementation began; real bug fix in already-shipped prestige-checkpoint Story 006 code (`_deferred_this_era` never set true, confirmed against source quick-spec, fixed and reverified); a real cross-test signal double-counting bug found and fixed during test development (documented, empirically verified clean via full 605-test suite run).
**Test Evidence**: Integration — `tests/integration/burnout/burnout_choice_routing_test.gd` (12 tests)
**Code Review**: Complete — APPROVED
