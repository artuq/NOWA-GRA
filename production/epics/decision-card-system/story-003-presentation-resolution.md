# Story 003: Card Presentation & Resolution

> **Epic**: Decision Card System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S (2-3h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-24

## Context

**GDD**: `design/gdd/decision-card-system.md`
**Requirement**: `TR-dcs-001`, `TR-dcs-002` (resolution-side completion of both requirements)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Decision Card weighting and cooldown implementation (primary — resolution order); ADR-0001: Autoload singleton vs. event bus (secondary)
**ADR Decision Summary**: On player choice, `resource_deltas` are applied to `ResourceManager` strictly before `counter_increments`/`milestone_to_set` are applied to `HistoryFlagManager`. Resolution resets the cooldown counter (Story 001) for the next cycle.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: No post-cutoff API — pure cross-Autoload method calls in a fixed order.

**Implementation note — `HistoryFlagManager.record_choice()` doesn't exist:**
ADR-0005's pseudocode calls a `record_choice(id, option)` method that was never built. The real `HistoryFlagManager` API (per the GDD's own Detailed Design rule 3: "`counter_increments`/`milestone_to_set` → History Flag System") is `increment_counter(name, amount)` and `set_milestone(name)` — call both directly for whichever keys the chosen option has.

**Control Manifest Rules (Core layer)**:
- Required: Use direct method calls for ownership-clear writes (`ResourceManager.apply_delta(...)`, `HistoryFlagManager.increment_counter(...)`/`set_milestone(...)`) — source: ADR-0001. This story is the canonical example of "caller is the sole trigger of a state mutation it owns."
- Required: resolution order is architecturally locked by ADR-0005 — `resource_deltas` always applied before `counter_increments`/`milestone_to_set`, never interleaved or reversed.

---

## Acceptance Criteria

*From GDD `design/gdd/decision-card-system.md` § Acceptance Criteria, scoped to this story (presentation/resolution state transitions, resolution order, and the repeat-allowed edge case):*

- [ ] GIVEN `presenting`, WHEN the player chooses, THEN → `resolving`.
- [ ] GIVEN `resolving`, WHEN effects applied, THEN → `cooldown` immediately.
- [ ] GIVEN a choice made, WHEN entering `resolving`, THEN `resource_deltas` applied to Resource System strictly before `counter_increments`/`milestone_to_set` applied to History Flag System.
- [ ] GIVEN a chosen option has both `resource_deltas` and `milestone_to_set`, WHEN resolution completes, THEN milestone recorded only after the resource write completes; card becomes excludable starting the next `checking` cycle.
- [ ] GIVEN a non-milestone card just resolved, WHEN cooldown elapses and `checking` runs again, THEN that card may be selected again — no repeat-prevention.

---

## Implementation Notes

*Derived from ADR-0005's `resolve_choice()` pseudocode, translated to the real Dictionary/HistoryFlagManager API:*

```gdscript
# Added to DecisionCardSystem (Stories 001+002's Autoload)

var _presented_card: Dictionary = {}  # empty == no card currently presented

func present_next_card(pool: Array[Dictionary]) -> void:
    # Called from Story 001's _check_pool() once it has a non-empty pool.
    _presented_card = _weighted_pick(pool)  # Story 002
    state = State.PRESENTING

## Called when the player chooses an option (option_index: 0 or 1). Card UI
## (undesigned) will eventually call this; for now it's the public seam
## tests drive directly.
func resolve_choice(option_index: int) -> void:
    state = State.RESOLVING
    var option: Dictionary = _presented_card["options"][option_index]

    # Resolution order is architecturally locked (ADR-0005): resource_deltas
    # BEFORE counter_increments/milestone_to_set. Never reverse or interleave.
    if not option["resource_deltas"].is_empty():
        ResourceManager.apply_delta(option["resource_deltas"])

    for counter_name: StringName in option["counter_increments"]:
        HistoryFlagManager.increment_counter(counter_name, option["counter_increments"][counter_name])
    if option.has("milestone_to_set"):
        HistoryFlagManager.set_milestone(option["milestone_to_set"])

    _presented_card = {}
    _actions_until_check = COOLDOWN_ACTIONS  # Story 001's cooldown counter — reset for next cycle
    state = State.COOLDOWN
```

- **`resource_deltas` keys are already `StringName` per Card Content Database's Story 001** (`&"Reach"`, `&"Cringe"`, etc.) — `ResourceManager.apply_delta()` accepts this directly, no translation needed at this boundary.
- **"Milestone recorded only after the resource write completes"** is satisfied by simple statement ordering in GDScript (synchronous, no `await` in this method) — no explicit synchronization primitive needed; the AC is about *logical* ordering, which sequential statements already guarantee.
- **No repeat-prevention is correct, not a gap** — per the GDD's own edge case, nothing in this system tracks "this card just appeared" beyond the milestone mechanism (Stories 001/002). Do not add a cooldown-per-card or recency tracker — that would contradict the GDD's explicit edge case.
- **`resolve_choice(option_index: int)`** uses an integer index (0 or 1) rather than a `StringName`/label lookup, matching the card schema's `options: [option_A, option_B]` array structure directly — simplest correct interface given exactly 2 options per card (Card Content Database's own AC-1 guarantee).

---

## Out of Scope

*Handled by Stories 001/002 / future epics — do not implement here:*

- Story 001: cooldown counter mechanics, pool-building, `trigger_condition`/milestone filtering.
- Story 002: the weighted-pick algorithm that selects which card to present.
- Card UI (future epic): capturing the player's actual swipe/tap input and calling `resolve_choice()` — this story only implements the method Card UI will eventually call; no UI exists yet.
- `OnboardingGate` integration — same exclusion as Stories 001/002.
- Juice/Feedback System's resolution-beat hook — no interface defined yet (Vertical Slice per the GDD's Dependencies section).

---

## QA Test Cases

*Sourced directly from the GDD's own GIVEN/WHEN/THEN acceptance criteria.*

- **AC-1**: presenting→resolving on choice
  - Given: `state == PRESENTING`, a card is set in `_presented_card`
  - When: `resolve_choice(0)` (or `1`) is called
  - Then: `state` transitions through `RESOLVING` to `COOLDOWN` by the time the call returns (synchronous — test the end state, since there's no intermediate frame to observe)
  - Edge cases: confirm `_presented_card` is cleared (back to `{}`) after resolution

- **AC-2**: resolving→cooldown immediately after effects applied
  - Given: as above
  - When: `resolve_choice()` completes
  - Then: `state == COOLDOWN`, `_actions_until_check == COOLDOWN_ACTIONS`
  - Edge cases: this re-confirms Story 001's cooldown reset is correctly triggered from the resolution path, not just the empty-pool path

- **AC-3**: resolution order — resource_deltas before counter_increments/milestone_to_set
  - Given: a card option with both `resource_deltas` and `counter_increments` (e.g. `exposed_friend`'s risky option: Reach/Cringe/Morale deltas + `risky_choices_count` +1)
  - When: `resolve_choice()` runs
  - Then: `ResourceManager`'s values reflect the delta, AND `HistoryFlagManager`'s counter reflects the increment — order verified by instrumenting both Autoloads' write-notification signals (`ResourceManager.resource_changed`) and confirming the resource signal fires before any `HistoryFlagManager` state changes are observable
  - Edge cases: use a card whose risky option carries a `milestone_to_set` too (`staged_drama`) to test the 3-way ordering (resource → counter → milestone) in one assertion

- **AC-4**: milestone recorded only after resource write, card excludable next cycle
  - Given: `staged_drama`'s risky option chosen (has both `resource_deltas` and `milestone_to_set`)
  - When: `resolve_choice()` completes
  - Then: `HistoryFlagManager.has_milestone(&"card.staged_drama.chosen_risky")` is `true`; rebuilding the pool (Story 001's `_build_eligible_pool()`) afterward excludes `staged_drama`
  - Edge cases: confirms the excludability is observable on the *next* `_check_pool()` call, not synchronously during resolution itself

- **AC-5**: non-milestone card may repeat
  - Given: a non-milestone card (e.g. `hater_callout`) resolved once
  - When: the pool is rebuilt on a subsequent cycle
  - Then: `hater_callout` is still present — no tracking prevents it from being selected again
  - Edge cases: this is a negative test (confirming the ABSENCE of repeat-prevention logic) — the simplest valid implementation is to not write any such tracking at all, which this story's Implementation Notes already specify

**Test isolation note**: like `save_core_test.gd` and `card_content_database_test.gd`, this suite touches the real `ResourceManager`/`HistoryFlagManager` Autoloads — snapshot and restore their state around each test (same pattern as those suites), and use `CardContentDatabase.get_card(id)` to pull real card data for test fixtures rather than inventing synthetic cards.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/decision_card_system/card_resolution_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Cooldown Mechanism & Pool Eligibility) and Story 002 (Weighted Card Selection Formula) must both be DONE — this story resolves the card they select and resets the cooldown they manage.
- Unlocks: Card UI (future epic, calls `resolve_choice()` once built); Class Path System (future Vertical Slice epic, relies on the `risky_choices_count`/`safe_choices_count` writes this story performs being accurate).
