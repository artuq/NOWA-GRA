# Story 002: Weighted Card Selection Formula

> **Epic**: Decision Card System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-24

## Context

**GDD**: `design/gdd/decision-card-system.md`
**Requirement**: `TR-dcs-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Decision Card weighting and cooldown implementation
**ADR Decision Summary**: Card selection is a cumulative-weight roll over the eligible pool (Story 001's output), using a per-instance `RandomNumberGenerator` with a `set_seed()` test hook for deterministic testing. `weight(card) = base_weight + (current_Cringe / 100) × intensity(card)`.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: `RandomNumberGenerator` is a stable pre-4.3 API. No post-cutoff concerns.

**Implementation note — `intensity(card)` is derived, not stored:**
ADR-0005's pseudocode reads `card.intensity` as if it were a stored property. The real `CardContentDatabase` Dictionary has no `intensity` field — per the GDD's own Formulas section, `intensity(card)` is **defined as** "the risky option's Cringe delta (for risky/safe cards) or 0 (for neutral cards)." This story must derive it at selection time: for a risky/safe card, find the option whose `counter_increments` contains `&"risky_choices_count"` and read its `resource_deltas[&"Cringe"]`; for a neutral card (no `counter_increments` on either option), `intensity = 0`.

**Control Manifest Rules (Core layer)**:
- Required: Use direct method calls for ownership-clear reads (`ResourceManager.get_resource(&"Cringe")`, `HistoryFlagManager.has_milestone(...)`) — source: ADR-0001
- Required: No random seeds in automated tests except via an explicit test-only hook — source: coding-standards.md determinism rule. `set_seed()` exists exactly for this.

---

## Acceptance Criteria

*From GDD `design/gdd/decision-card-system.md` § Acceptance Criteria, scoped to this story (weighting at both Cringe extremes, milestone exclusion, and the two selection-degenerate-case edge cases):*

- [ ] GIVEN Cringe=0, all 12 eligible, WHEN weights computed, THEN every card = exactly `base_weight`=10.
- [ ] GIVEN the above, WHEN probabilities computed, THEN uniform 8.33% each (10/120).
- [ ] GIVEN Cringe=100, all 12 eligible, WHEN weights computed, THEN exactly: `staged_drama`=45, `leaked_dm`=42, `cancel_threat`=40, `exposed_friend`=38, `hater_callout`=35, `competitor_drama`=34, `sponsor_offer_shady`=32, `apology_tour`=30, each neutral card=10.
- [ ] GIVEN the above (pool weight=336), WHEN probabilities computed, THEN exactly: `staged_drama`=13.4%, `leaked_dm`=12.5%, `cancel_threat`=11.9%, `exposed_friend`=11.3%, `hater_callout`=10.4%, `competitor_drama`=10.1%, `sponsor_offer_shady`=9.5%, `apology_tour`=8.9%, each neutral=3.0%.
- [ ] GIVEN Cringe=100, WHEN comparing top card (45) to a neutral card (10), THEN ratio = 4.5x.
- [ ] GIVEN a card's chosen option's `milestone_to_set` is already set, WHEN the pool is built, THEN excluded, zero weight.
- [ ] GIVEN a card has no `milestone_to_set` (or unset), WHEN the pool is built, THEN remains eligible regardless of past appearances.
- [ ] GIVEN exactly 1 card remains eligible, WHEN selection runs, THEN selected with 100% probability, same formula, no special case.
- [ ] GIVEN Cringe=0, pool contains only risky/safe cards (no neutral eligible), WHEN weights computed, THEN all = `base_weight`=10, equal probability.

---

## Implementation Notes

*Derived from ADR-0005's `_weighted_pick()` pseudocode, translated to the real Dictionary API and the GDD's exact `intensity(card)` definition:*

```gdscript
# Added to DecisionCardSystem (Story 001's Autoload)

const BASE_WEIGHT: float = 10.0  # Tuning Knob, safe range 5-20

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    # ...Story 001's existing _ready() body...
    _rng.randomize()

## Test hook only — production code never calls this. Allows tests to pin
## _rng to a fixed seed, satisfying coding-standards.md's "no random seeds"
## determinism rule for the weighted-pick statistical tests.
func set_seed(s: int) -> void:
    _rng.seed = s

func _card_intensity(card: Dictionary) -> float:
    for option: Dictionary in card["options"]:
        if option["counter_increments"].has(&"risky_choices_count"):
            return option["resource_deltas"].get(&"Cringe", 0.0)
    return 0.0  # neutral card: no option increments risky_choices_count

func _card_weight(card: Dictionary, current_cringe: float) -> float:
    return BASE_WEIGHT + (current_cringe / 100.0) * _card_intensity(card)

## Picks one card from [param pool] via a cumulative-weight roll. Pool must
## be non-empty (Story 001's _check_pool() only calls this when pool.size() > 0).
func _weighted_pick(pool: Array[Dictionary]) -> Dictionary:
    var current_cringe: float = ResourceManager.get_resource(&"Cringe")
    var weights: Array[float] = []
    var total: float = 0.0
    for card: Dictionary in pool:
        var w: float = _card_weight(card, current_cringe)
        weights.append(w)
        total += w
    var roll: float = _rng.randf() * total
    var cumulative: float = 0.0
    for i in pool.size():
        cumulative += weights[i]
        if roll <= cumulative:
            return pool[i]
    return pool[-1]  # float-rounding fallback, never reached in practice
```

- **Milestone exclusion is Story 001's `_is_milestone_exhausted()`** — already filters the pool before this story's `_weighted_pick()` ever sees it. This story's milestone-related ACs are tested by confirming the pool *passed in* already excludes the right cards (i.e., re-verifying Story 001's filter from this story's perspective, not re-implementing it).
- **`set_seed()` is a deliberate test-only escape hatch** — production code (Story 003's `present_next_card()` equivalent) never calls it. Document this clearly so a future reviewer doesn't flag it as dead code.
- **Exact weight/probability assertions require reading `BASE_WEIGHT` from the named constant**, never hardcoding `10`/`45`/etc. as bare literals in tests, matching this codebase's established constants-not-literals convention (`action_system.gd`, `history_flag_manager.gd`, `save_system.gd`).
- **No `class_name`**, same convention.

---

## Out of Scope

*Handled by Story 001 / Story 003 — do not implement here:*

- Story 001: pool eligibility (`trigger_condition` filtering, milestone-exhaustion filtering) — this story receives an already-filtered pool.
- Story 003: `presenting`→`resolving` transition, applying the chosen card's effects.
- `trigger_condition` expression grammar beyond `"always"` — same exclusion as Story 001.
- Card-count scaling guardrail (Tuning Knobs: re-validate weight spread past ~20 cards) — explicitly deferred per the GDD, not testable at 12-card MVP scale.

---

## QA Test Cases

*Sourced directly from the GDD's own GIVEN/WHEN/THEN acceptance criteria.*

- **AC-1/AC-2**: Cringe=0 uniform weights
  - Given: Cringe=0, all 12 cards in the pool
  - When: weights computed for each
  - Then: every weight == `BASE_WEIGHT` (10.0); every probability == 10/120 ≈ 8.33%
  - Edge cases: confirms the scaling term `(0/100) × intensity` is exactly 0 for every card, including the highest-intensity ones

- **AC-3/AC-4/AC-5**: Cringe=100 exact weights, probabilities, and ratio
  - Given: Cringe=100, all 12 cards in the pool
  - When: weights computed
  - Then: exact values per the GDD table (`staged_drama`=45 ... each neutral=10), exact probabilities (sum=336 total weight), and a 4.5x ratio between the top card and a neutral card
  - Edge cases: this locks the entire reference table from the GDD's Formulas section in one assertion sweep — any future change to a card's Cringe delta or `BASE_WEIGHT` will be caught here

- **AC-6**: milestone-excluded card has zero weight (i.e., is absent from the pool entirely, not present-with-zero-weight)
  - Given: a milestone-bearing card's milestone is set
  - When: the pool passed to `_weighted_pick()` is built (by Story 001)
  - Then: that card is absent from the pool array
  - Edge cases: confirms this story's selection logic never needs to special-case a "zero-weight" entry — exclusion happens upstream

- **AC-7**: non-milestone card remains eligible regardless of past appearances
  - Given: a card with no `milestone_to_set` on any option, already selected/resolved once before
  - When: the pool is rebuilt
  - Then: still present
  - Edge cases: this is implicitly tested by NOT excluding it — no special "already appeared" tracking exists anywhere in this system

- **AC-8**: single-card pool selects with 100% certainty
  - Given: a pool with exactly 1 card
  - When: `_weighted_pick()` runs (any RNG seed)
  - Then: that card is always returned
  - Edge cases: run with multiple different seeds via `set_seed()` to confirm no seed produces a different (impossible) result

- **AC-9**: Cringe=0 with only risky/safe cards in the pool
  - Given: Cringe=0, pool contains only the 8 risky/safe cards (no neutral cards eligible — simulate via a pool slice)
  - When: weights computed
  - Then: all == `BASE_WEIGHT` (10.0), equal probability (1/8 each)
  - Edge cases: confirms the formula doesn't implicitly depend on neutral cards being present

**Statistical/determinism testing note**: AC-3/4/5's exact weight and probability values are deterministic (pure math, no RNG involved in computing weights). Only the final card *pick* uses `_rng.randf()` — use `set_seed()` to pin a specific roll value when testing which card a given roll selects (e.g., confirm `roll=0.0` always selects the first card in cumulative order, `roll=total` selects the last).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/decision_card_system/weighted_selection_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Cooldown Mechanism & Pool Eligibility) must be DONE; this story's `_weighted_pick()` is called with the pool Story 001 builds.
- Unlocks: Story 003 (Card Presentation & Resolution — resolves the card this story selects).

---

## Completion Notes
**Completed**: 2026-06-24
**Criteria**: 9/9 passing (none deferred)
**Deviations**: None open — code review found `_weighted_pick()` had no internal empty-pool guard; fixed with a `push_error()` + `{}` return before this gate, not left open.
**Test Evidence**: Logic — `tests/unit/decision_card_system/weighted_selection_test.gd`, 8/8 passing (full regression 145/145 passing)
**Code Review**: Complete — `/code-review` APPROVED (after empty-pool guard fix); LP-CODE-REVIEW gate APPROVE; QL-TEST-COVERAGE gate ADEQUATE
