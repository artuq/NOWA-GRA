# Story 001: Cooldown Mechanism & Pool Eligibility

> **Epic**: Decision Card System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-24

## Context

**GDD**: `design/gdd/decision-card-system.md`
**Requirement**: `TR-dcs-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Decision Card weighting and cooldown implementation (primary); ADR-0001: Autoload singleton vs. event bus (secondary)
**ADR Decision Summary**: Cooldown is an integer counter (not a `Timer`), decremented on every `ActionSystem.action_completed` signal. When it reaches 0, the system checks all cards' `trigger_condition` and milestone-exclusion status to build the eligible pool; if non-empty, advances to `presenting` (Story 002 picks the card); if empty, resets the counter and retries on the next action.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: Pure GDScript state machine + signal connection — no post-cutoff API, no engine-version-sensitive behavior.

**Critical implementation note — ADR-0005's pseudocode is stale, do not follow it literally:**
ADR-0005's `Implementation Guidelines` section's code sample assumes `OnboardingGate.is_card_suppressed()` exists and that cards have `.intensity`/`.id` properties (Resource-style). Neither matches reality:
- `OnboardingGate` **does not exist yet** and is **explicitly out of scope** for this story (see Out of Scope below) — do not call, stub, or reference it.
- `CardContentDatabase.get_all_cards()` (Story 001 of the Card Content Database epic, already Complete) returns `Array[Dictionary]`, **not** `Resource` objects. Access fields via dictionary keys (`card["id"]`, `card["trigger_condition"]`, `card["options"]`), never dot-notation.

**Control Manifest Rules (Core layer)**:
- Required: Implement every Core/Foundation module as a Godot Autoload singleton — source: ADR-0001
- Required: Use direct method calls when the caller is the sole trigger of a state mutation it owns; use signals when multiple unrelated modules subscribe to the same event — source: ADR-0001. `DecisionCardSystem` subscribes to `ActionSystem.action_completed` (a signal, since multiple modules listen to it) and will later call `ResourceManager`/`HistoryFlagManager` directly (ownership-clear writes, Story 003).
- Required: Register Autoloads in the canonical order — `DecisionCardSystem` is not yet in the documented canonical list (it's a newer module than ADR-0001's original enumeration); insert it after `ActionSystem` in `project.godot` (it depends on `ActionSystem.action_completed` existing and ready), and note the canonical-order list should be updated to include it.

---

## Acceptance Criteria

*From GDD `design/gdd/decision-card-system.md` § Acceptance Criteria, scoped to this story (state transitions, cooldown mechanism, and the two edge cases that are direct consequences of pool-eligibility checking):*

- [ ] GIVEN `cooldown`, WHEN 2 actions complete, THEN → `checking`.
- [ ] GIVEN `checking` with ≥1 eligible card, WHEN evaluation completes, THEN → `presenting` with exactly one card selected. *(This story builds the eligible pool and confirms the transition; Story 002 owns the weighted-pick algorithm that chooses which card.)*
- [ ] GIVEN `checking` with 0 eligible cards, WHEN evaluation completes, THEN → `cooldown` (reset), no card presented.
- [ ] GIVEN a card just resolved, THEN cooldown requires 2 completed actions before next `checking`.
- [ ] GIVEN `cooldown` with 1 of 2 actions done, WHEN 1 more completes, THEN → `checking` (not before).
- [ ] GIVEN reset to `cooldown` due to empty pool, WHEN 2 actions complete from that point, THEN → `checking` again — empty pool never permanently halts the loop.
- [ ] GIVEN all milestone cards exhausted and nothing else passes `trigger_condition`, THEN pool empty, returns to `cooldown`, retried after next 2 actions.
- [ ] GIVEN all 12 MVP cards use `trigger_condition="always"`, THEN every non-excluded card passes — filtering is a no-op for MVP.

---

## Implementation Notes

*Derived from ADR-0005's Decision (cooldown counter mechanism) and the GDD's Detailed Design § Core Rules (cooldown + threshold mechanism), translated to the real `Dictionary`-based `CardContentDatabase` API:*

```gdscript
extends Node

const COOLDOWN_ACTIONS: int = 2  # design/registry/entities.yaml: decision_card_cooldown

enum State { COOLDOWN, CHECKING, PRESENTING, RESOLVING }
var state: State = State.COOLDOWN

var _actions_until_check: int = COOLDOWN_ACTIONS

func _ready() -> void:
    ActionSystem.action_completed.connect(_on_action_completed)

func _on_action_completed(_action_id: StringName, _rewards: Dictionary) -> void:
    if state != State.COOLDOWN:
        return  # already checking/presenting/resolving — do not double-trigger
    _actions_until_check -= 1
    if _actions_until_check <= 0:
        state = State.CHECKING
        _check_pool()

## [param cards_override] threads through to _build_eligible_pool() — same
## test-only seam, same null-sentinel contract. Production code calls this
## with no argument.
func _check_pool(cards_override: Variant = null) -> void:
    var pool: Array[Dictionary] = _build_eligible_pool(cards_override)
    if pool.is_empty():
        _actions_until_check = COOLDOWN_ACTIONS
        state = State.COOLDOWN
        return
    state = State.PRESENTING
    # Story 002 takes over from here: weighted-pick from `pool`.

## [param cards_override] is a test-only seam, default `null` (unused —
## production code never passes this argument). When non-null (including an
## explicitly empty `[]`), this method filters that array instead of
## CardContentDatabase.get_all_cards() — added per QL-STORY-READY (2026-06-24)
## specifically so AC-3 (empty pool) can be tested with a genuinely empty
## input, since all 12 real MVP cards use trigger_condition=="always" and can
## never be reduced to a true empty pool through milestone exclusion alone
## (max 3 of 12 are milestone-bearing). `null` (not an empty array) is the
## "unused" sentinel precisely so a test passing `[]` is distinguishable from
## a caller passing nothing at all.
func _build_eligible_pool(cards_override: Variant = null) -> Array[Dictionary]:
    var source: Array[Dictionary] = Array(cards_override, TYPE_DICTIONARY, "", null) if cards_override != null else CardContentDatabase.get_all_cards()
    var pool: Array[Dictionary] = []
    for card: Dictionary in source:
        if not _trigger_condition_met(card["trigger_condition"]):
            continue
        if _is_milestone_exhausted(card):
            continue
        pool.append(card)
    return pool

func _trigger_condition_met(condition: String) -> bool:
    # MVP: only "always" is used by any of the 12 cards. A real expression
    # parser (e.g. "risky_choices_count >= 3") is explicitly out of scope —
    # GDD Open Questions defers grammar design to Vertical Slice+.
    return condition == "always"

func _is_milestone_exhausted(card: Dictionary) -> bool:
    # Story 002 also reads this when building its own pool view — kept here
    # since it's pool-eligibility logic, not weighting logic.
    for option: Dictionary in card["options"]:
        if option.has("milestone_to_set") and HistoryFlagManager.has_milestone(option["milestone_to_set"]):
            return true
    return false
```

- **`_actions_until_check` is reset to `COOLDOWN_ACTIONS` in two places**: after an empty-pool retry, and (in Story 003) after a card resolves. This story only implements the empty-pool reset path; Story 003 implements the post-resolution reset.
- **The `state != State.COOLDOWN` guard in `_on_action_completed`** prevents double-triggering if `action_completed` somehow fires while a card is already being presented/resolved — not explicitly required by any single AC, but a direct consequence of the state machine being single-flow (only one card presented at a time, matching ADR-0005's "single-concurrency" note for `present_next_card()`).
- **No `class_name`**, matching the established no-`class_name` Autoload convention.
- **This story stops at `state = State.PRESENTING`** — it does not implement card selection (Story 002) or resolution (Story 003). Tests for this story drive `_check_pool()` directly and assert the resulting `state` and whether `_build_eligible_pool()` returned a non-empty/empty pool, not which card was chosen.

---

## Out of Scope

*Handled by neighbouring stories / future epics — do not implement here:*

- Story 002: the weighted-random selection algorithm (`_weighted_pick()`) that chooses which card from the eligible pool to present.
- Story 003: `presenting`→`resolving`→`cooldown` transitions, applying `resource_deltas`/`counter_increments`/`milestone_to_set`, and resetting `_actions_until_check` after a resolution.
- `OnboardingGate.is_card_suppressed()` / `force_cooldown_zero()` — `OnboardingGate` doesn't exist yet; ADR-0005 mentions these for future awareness only. Not in any GDD acceptance criterion. A future story (once `OnboardingGate` epic exists) will wire this in.
- `trigger_condition` expression grammar beyond the literal string `"always"` — GDD Open Questions explicitly defers parser design to Vertical Slice+; this story only needs exact-string-match on `"always"`.
- Card UI / presentation — Card UI is undesigned; this story's `presenting` state has no UI consequence yet.

---

## QA Test Cases

*No QA plan existed for this epic at story-creation time — these specs are sourced directly from the GDD's own GIVEN/WHEN/THEN acceptance criteria.*

- **AC-1**: cooldown→checking after 2 actions
  - Given: fresh `DecisionCardSystem`, `state == COOLDOWN`
  - When: `ActionSystem.action_completed` fires twice
  - Then: `state == CHECKING` (transiently, then settles to PRESENTING or COOLDOWN per pool result)
  - Edge cases: verify the transition happens on exactly the 2nd signal, not the 1st or 3rd

- **AC-2**: checking→presenting with ≥1 eligible card
  - Given: at least 1 card passes `trigger_condition` and is not milestone-exhausted
  - When: `_check_pool()` runs
  - Then: `state == PRESENTING`
  - Edge cases: all 12 cards use `"always"` and none have set milestones — the default MVP case

- **AC-3**: checking→cooldown with 0 eligible cards
  - Given: the test-only `cards_override = []` seam added per QL-STORY-READY (2026-06-24) — a genuinely empty array, since the real 12-card database can never reach true zero-eligible through milestone exclusion alone (only 3 of 12 cards are milestone-bearing)
  - When: `_check_pool([])` runs
  - Then: `state == COOLDOWN`, `_actions_until_check` reset to `COOLDOWN_ACTIONS` — exercising the real empty-pool branch end-to-end, not a partial/indirect proxy
  - Edge cases: this is the GDD's own flagged edge case — empty pool must not permanently halt the loop. Production code never calls `_check_pool()`/`_build_eligible_pool()` with an explicit argument — `null` is the production path.

- **AC-4/AC-5**: cooldown requires exactly 2 actions
  - Given: cooldown just reset (post-resolution or post-empty-pool)
  - When: 1 action completes
  - Then: still `COOLDOWN`, not yet `CHECKING`
  - When: a 2nd action completes
  - Then: now `CHECKING`
  - Edge cases: off-by-one is the entire point of this test — 1 action must NOT trigger checking

- **AC-6**: empty-pool retry doesn't permanently halt
  - Given: pool was empty once, reset to `COOLDOWN`
  - When: 2 more actions complete
  - Then: → `CHECKING` again (the system retries, doesn't get stuck)
  - Edge cases: simulate 2 consecutive empty-pool cycles to confirm no degradation

- **AC-7**: milestone exhaustion excludes a card from the pool
  - **AMENDED 2026-06-24 (during implementation)**: rather than setting the 3 real production milestone strings (`card.staged_drama.chosen_risky`, `card.cancel_threat.apologized`, `card.algorithm_hack.saved`), the test uses a **synthetic card + a dedicated test-only milestone** (`test.decision_card_pool.fixture`). Reason: `HistoryFlagManager` milestones can never be unset (documented immutability), so permanently setting any of the 3 real production milestones during this test would silently exclude those cards from every OTHER suite that runs afterward in the same test invocation (e.g. a future Story 002 suite asserting "all 12 cards eligible at Cringe=100" would then see only 9). Testing `_is_milestone_exhausted()`'s logic against synthetic input proves the same code path without that cross-suite contamination risk.
  - Given: a synthetic card whose option has `milestone_to_set` pointing to the test-only milestone, with that milestone set via `HistoryFlagManager.set_milestone()`; a companion synthetic card with no `milestone_to_set` at all
  - When: `_build_eligible_pool([synthetic_card])` runs for each
  - Then: the milestone-set card's pool is empty (excluded); the no-milestone card's pool contains exactly 1 entry (remains eligible)
  - Edge cases: two separate test functions (`test_card_with_set_milestone_is_excluded_from_pool`, `test_card_without_milestone_remains_eligible`) rather than one combined assertion, for clearer failure isolation

- **AC-8**: trigger_condition filtering is a no-op for MVP
  - Given: all 12 cards have `trigger_condition == "always"`
  - When: `_build_eligible_pool()` runs (no milestones set)
  - Then: pool contains all 12 cards
  - Edge cases: confirms `_trigger_condition_met()` doesn't accidentally exclude anything in the default MVP state

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/decision_card_system/cooldown_pool_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Card Content Database (Complete), History Flag System (Complete), Action System (Complete) — all three already exist and provide the APIs this story reads.
- Unlocks: Story 002 (Weighted Card Selection Formula — picks from the pool this story builds); Story 003 (Card Presentation & Resolution — resets the cooldown this story manages).

---

## Completion Notes
**Completed**: 2026-06-24
**Criteria**: 8/8 passing (none deferred)
**Deviations**: None open — ADR-0005's stale Implementation Guidelines pseudocode (assumed Resource-object cards, `HistoryFlagManager.record_choice()`, `OnboardingGate.is_card_suppressed()`) was documented in the story, the code header, and now also annotated directly in ADR-0005 itself with an Implementation Note pointing to the corrected version.
**Test Evidence**: Logic — `tests/unit/decision_card_system/cooldown_pool_test.gd`, 9/9 passing (full regression 137/137 passing)
**Code Review**: Complete — `/code-review` APPROVED (after 2 fixes: untested double-trigger guard, stale AC-7 doc text); LP-CODE-REVIEW gate APPROVE; QL-TEST-COVERAGE gate ADEQUATE
