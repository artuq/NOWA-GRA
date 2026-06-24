# Story 001: MVP Card Content — Schema & 12-Card Data Table

> **Epic**: Card Content Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-24

## Context

**GDD**: `design/gdd/card-content-database.md`
**Requirement**: No dedicated `TR-card-*` entry exists in `docs/architecture/tr-registry.yaml` — this module is pure static data, correctly treated as low architectural risk and not separately tracked, per the epic's own GDD Requirements table. Not a gap; flag for `/architecture-review` only if this changes.

**ADR Governing Implementation**: ADR-0001: Autoload singleton vs. event bus
**ADR Decision Summary**: `CardContentDatabase` is a Godot Autoload singleton, read-only data access pattern — other modules (Decision Card System, Juice/Feedback System) read it directly; it owns no mutation logic and emits no signals.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: Pure GDScript typed const data declarations — no engine-version-sensitive behavior, no post-cutoff APIs.

**Control Manifest Rules (Foundation layer)**:
- Required: Implement every Core/Foundation module as a Godot Autoload singleton — source: ADR-0001
- Required: Register Autoloads in the canonical order: `ResourceManager`, `HistoryFlagManager`, `CardContentDatabase`, `SaveSystem`, `ActionSystem`, ... — source: ADR-0001. **This story must insert `CardContentDatabase` into `project.godot` between `HistoryFlagManager` and `SaveSystem`** (current order is `ResourceManager`, `HistoryFlagManager`, `SaveSystem`, `ActionSystem` — do not append at the end).
- Forbidden: Never introduce a central `EventBus` autoload — source: ADR-0001 (not applicable here — no signals involved)

**Critical translation note — GDD uses Polish labels, codebase uses English keys:**
The GDD's content tables label resources in Polish (`Zasięgi`, `Sponsorzy`) — this is known, tracked doc-sync tech debt (Sprint 4 item 4-3, carried over from Sprint 3's 3-4). The actual `ResourceManager` Autoload (`src/core/resource_manager.gd`) uses **English keys only**: `&"Reach"`, `&"Cringe"`, `&"Haters"`, `&"Morale"`, `&"Sponsors"`. This story's data **must use the English keys** — do not write `"Zasięgi"` or `"Sponsorzy"` anywhere in the implementation. Translation table:

| GDD label | Codebase key (`StringName`) |
|---|---|
| Zasięgi | `&"Reach"` |
| Cringe | `&"Cringe"` |
| Morale | `&"Morale"` |
| Sponsorzy | `&"Sponsors"` |
| (Hatersi, not used by any card in this GDD) | `&"Haters"` |

Similarly, `History Flag System`'s counters use the same English-style snake_case already established (`&"risky_choices_count"`, `&"safe_choices_count"`) — these match the GDD's own counter names exactly, no translation needed there.

---

## Acceptance Criteria

*From GDD `design/gdd/card-content-database.md` § Acceptance Criteria, verbatim (17 criteria), scoped to this single story since the data table is authored once:*

**Schema validity:**
- [ ] GIVEN any of the 12 MVP cards, WHEN inspecting `options`, THEN it contains exactly 2 entries.
- [ ] GIVEN any card, WHEN inspecting top-level fields, THEN `id`, `trigger_condition`, `text`, `options` are all present and non-empty.
- [ ] GIVEN the full 12-card set, WHEN comparing `id` values, THEN no two cards share the same `id`.

**resource_deltas / counter_increments contract:**
- [ ] GIVEN any option, WHEN inspecting `resource_deltas`, THEN it is present as a `Dictionary[StringName, float]` (empty dict valid, missing field is not).
- [ ] GIVEN one of the 8 risky/safe pairs, WHEN inspecting both options' `counter_increments`, THEN exactly one increments `risky_choices_count` by 1 and the other increments `safe_choices_count` by 1 — never both, never neither.
- [ ] GIVEN one of the 4 neutral cards, WHEN inspecting both options, THEN `counter_increments` is absent/empty on both, and `resource_deltas` is non-empty on at least one.
- [ ] ~~GIVEN a risky/safe pair, WHEN comparing risky vs safe `Reach` deltas, THEN the ratio is between 1.4x and 1.8x for all 8 pairs.~~ **AMENDED 2026-06-24 (discovered during implementation)**: the GDD's own authored numbers violate this bound for 3 of 8 pairs — `staged_drama` (220/120 = 1.833), `leaked_dm` (190/105 = 1.810), `cancel_threat` (200/110 = 1.818). The other 5 pairs (`exposed_friend` 1.80, `sponsor_offer_shady` 1.778, `hater_callout` 1.647, `competitor_drama` 1.70, `apology_tour` 1.579) are within bounds. Per user decision: implement the GDD's actual table values as-is (the 3 outliers read as intentional — higher-stakes/milestone-bearing cards getting a slightly steeper risk/reward ratio), and the test locks the real measured ratio per card rather than a blanket 1.4-1.8 assertion. This is a GDD content defect relative to its own stated Tuning Knob, not an implementation bug — flag in Completion Notes as a deviation, do not silently "fix" the GDD's numbers as part of this story.
- [ ] GIVEN any `counter_increments` entry, WHEN inspecting its value, THEN it is a positive integer (1, per spec).

**Milestone-bearing cards (3 specific cards):**
- [ ] GIVEN `staged_drama`, WHEN inspecting the risky option, THEN `milestone_to_set = "card.staged_drama.chosen_risky"`; the safe option has none.
- [ ] GIVEN `cancel_threat`, WHEN inspecting the safe option, THEN `milestone_to_set = "card.cancel_threat.apologized"`; the risky option has none.
- [ ] GIVEN `algorithm_hack`, WHEN inspecting the safe option, THEN `milestone_to_set = "card.algorithm_hack.saved"`; the risky option has none.
- [ ] GIVEN the remaining 9 cards, WHEN inspecting all options, THEN no `milestone_to_set` is present anywhere.

**Sponsorzy (→ Sponsors) qualifying-card rule:**
- [ ] ~~GIVEN all 12 cards, WHEN inspecting every option's `resource_deltas` for a `&"Sponsors"` key, THEN it appears only on `sponsor_offer_shady` and `brand_deal_choice` options, absent everywhere else.~~ **AMENDED 2026-06-24 (discovered during implementation)**: the GDD's own neutral-card content table gives `fan_in_trouble` a `Sponsorzy -1` value on both options (a sponsor-patience cost), contradicting this AC's literal wording. The GDD's "Resolved open question" section clarifies the real rule: "qualifying" = the card's *premise* is a sponsor/brand/monetization offer, not "touches the Sponsors resource at all." Corrected AC: the `&"Sponsors"` key may appear on any card as a flat cost/reward, but a **positive** `&"Sponsors"` reward (the qualifying-card gate from Resource System's resolved Open Question) is restricted to `sponsor_offer_shady` and `brand_deal_choice` only. `fan_in_trouble`'s `-1.0` (a cost, never positive) does not violate this.
- [ ] GIVEN `sponsor_offer_shady` and `brand_deal_choice`, WHEN inspecting their options, THEN each has at least one option with `resource_deltas[&"Sponsors"] > 0`.
- [ ] **(new, replaces the amended AC above)** GIVEN any card OTHER than `sponsor_offer_shady`, `brand_deal_choice`, or `fan_in_trouble`, WHEN inspecting `resource_deltas` for a `&"Sponsors"` key, THEN it is absent. GIVEN `fan_in_trouble`, WHEN inspecting `resource_deltas[&"Sponsors"]` on both options, THEN the value is `-1.0` (a cost, not a qualifying reward).

**Defined edge cases:**
- [ ] GIVEN an option with a negative `Reach`/`Sponsors` value, WHEN checking whether this database clamps it, THEN the value is accepted and stored as-is — no floor exists at this layer by design.
- [ ] GIVEN milestone `card.algorithm_hack.saved`, WHEN searching the 12-card set for any `trigger_condition` referencing it, THEN no match is found — expected (forward hook), not a defect.
- [ ] GIVEN the 9 options without `milestone_to_set` outside the 3 milestone-bearing cards (plus the non-milestone option on each of those 3), WHEN checking for the field, THEN its absence is correct, not missing data.

---

## Implementation Notes

*Derived from ADR-0001 + GDD Detailed Design § Core Rules (card schema), with the resource-key translation applied throughout:*

```gdscript
extends Node

## Card schema (per design/gdd/card-content-database.md):
## {
##   "id": String, "trigger_condition": String, "text": String,
##   "options": [option_A, option_B]  // exactly 2
## }
## option: {
##   "label": String,
##   "resource_deltas": Dictionary[StringName, float],   // e.g. {&"Reach": 180.0, &"Cringe": 28.0}
##   "counter_increments": Dictionary[StringName, int],  // e.g. {&"risky_choices_count": 1}
##   "milestone_to_set": StringName,  // optional, omit key entirely if not set
## }
const CARDS: Array[Dictionary] = [
    {
        "id": "exposed_friend",
        "trigger_condition": "always",
        "text": "...",  # narrative text — not specified by this GDD/story, placeholder acceptable
        "options": [
            {"label": "...", "resource_deltas": {&"Reach": 180.0, &"Cringe": 28.0, &"Morale": -10.0}, "counter_increments": {&"risky_choices_count": 1}},
            {"label": "...", "resource_deltas": {&"Reach": 100.0, &"Cringe": -8.0, &"Morale": 6.0}, "counter_increments": {&"safe_choices_count": 1}},
        ],
    },
    # ... remaining 11 cards, values from the GDD's MVP content table (Detailed Design § Core Rules)
]

func get_card(card_id: String) -> Dictionary:
    for card in CARDS:
        if card["id"] == card_id:
            return card
    return {}

func get_all_cards() -> Array[Dictionary]:
    return CARDS
```

- **All 12 cards' numeric values come directly from the GDD's MVP content table** (Detailed Design § Core Rules) — do not invent or round values. Only the resource-key *labels* are translated (Zasięgi→Reach, Sponsorzy→Sponsors); the numbers themselves are copied exactly.
- **`text` and `label` fields**: the GDD does not specify exact narrative copy for most cards (only 3 have `resolution_reaction` content). Placeholder text is acceptable for this story — narrative content authoring is tracked separately (GDD's Open Questions: "resolution_reaction content for the remaining 9 cards," owner narrative-director/writer). Do not block this story on missing prose.
- **No `milestone_to_set` key at all** (not even an empty string) on the 9 options that don't set one — use `dict.has("milestone_to_set")` semantics, not `dict["milestone_to_set"] == ""`, so the "absence is correct" edge case is structurally enforced, not just conventionally true.
- **No `class_name`**, matching the established no-`class_name` Autoload convention (`resource_manager.gd`, `history_flag_manager.gd`, `save_system.gd`).
- **Read-only module**: no `apply_delta`-style write methods, no signals — this Autoload only exposes lookups (`get_card`, `get_all_cards`). Decision Card System owns reading this data and writing to `ResourceManager`/`HistoryFlagManager`.

---

## Out of Scope

*Handled by Decision Card System (future story) or other GDDs — do not implement here:*

- Decision Card System: evaluating `trigger_condition` strings, selecting/weighting which card to show, applying `resource_deltas`/`counter_increments`/`milestone_to_set` to the real `ResourceManager`/`HistoryFlagManager` Autoloads, enforcing milestone non-repetition, resolving simultaneous `trigger_condition` collisions.
- Resource System (separate GDD, future revision): whether `Reach`/`Sponsors` should have a floor at 0 — explicitly flagged as an open gap in the GDD, not resolved here.
- `resolution_reaction` content for the 9 cards that don't yet have it — narrative/content authoring task, not a code blocker for this story.
- Any UI/visual presentation of cards — `design/ux/decision-card.md` (per the GDD's own UX Flag), not this story.

---

## QA Test Cases

*Derived directly from the GDD's own GIVEN/WHEN/THEN acceptance criteria — no separate QA plan existed for this epic at story-creation time, so these specs are sourced straight from the GDD rather than an intermediate plan document.*

- **AC-1**: exactly 2 options per card
  - Given: any of the 12 cards
  - When: inspecting `options`
  - Then: `options.size() == 2`
  - Edge cases: check all 12, not just a sample

- **AC-2**: required top-level fields present
  - Given: any card
  - When: inspecting `id`, `trigger_condition`, `text`, `options`
  - Then: all non-empty
  - Edge cases: empty string `""` must fail this check, not just missing key

- **AC-3**: unique IDs
  - Given: the full 12-card set
  - When: comparing all `id` values pairwise (or via a Set)
  - Then: no duplicates
  - Edge cases: case-sensitivity — `"Exposed_Friend"` vs `"exposed_friend"` should be treated as distinct unless explicitly normalized

- **AC-4**: resource_deltas shape
  - Given: any option
  - When: inspecting `resource_deltas`
  - Then: present, typed `Dictionary[StringName, float]`, empty dict is valid but missing key is not
  - Edge cases: the 4 neutral cards' options with zero resource impact still need an empty (not absent) dict where applicable

- **AC-5**: exactly one counter per risky/safe pair
  - Given: each of the 8 risky/safe pairs
  - When: inspecting both options' `counter_increments`
  - Then: exactly one has `risky_choices_count`, the other has `safe_choices_count`
  - Edge cases: neither option should have both keys; neither should have neither key

- **AC-6**: neutral cards have no counter increments
  - Given: each of the 4 neutral cards
  - When: inspecting both options
  - Then: `counter_increments` absent/empty on both; `resource_deltas` non-empty on at least one
  - Edge cases: `burnout_warning`'s "spread into small actions" option has only a Morale delta — confirm it still counts as non-empty `resource_deltas`

- **AC-7**: Reach ratio 1.4x-1.8x
  - Given: each of the 8 risky/safe pairs
  - When: comparing risky vs safe `Reach` delta
  - Then: ratio in [1.4, 1.8] inclusive
  - Edge cases: compute exactly from the GDD table values (e.g. `exposed_friend`: 180/100 = 1.8, the upper boundary exactly)

- **AC-8**: counter increment values are positive integers
  - Given: any `counter_increments` entry across all cards
  - When: inspecting its value
  - Then: equals 1 (per spec — not just ">0")
  - Edge cases: none of the 12 cards' counters are anything other than 1, per the GDD table

- **AC-9, AC-10, AC-11**: milestone-bearing cards
  - Given: `staged_drama`, `cancel_threat`, `algorithm_hack` respectively
  - When: inspecting the specified option
  - Then: exact `milestone_to_set` string match; the other option has no key at all
  - Edge cases: exact string match, not just "has a milestone" — typos would pass a looser check

- **AC-12**: remaining 9 cards have no milestones anywhere
  - Given: the other 9 cards (all options)
  - When: checking for `milestone_to_set`
  - Then: key absent on every option
  - Edge cases: this includes the *non*-milestone option on each of the 3 milestone-bearing cards too (12 cards × 2 options − 3 milestone options = 21 options must have no key)

- **AC-13**: Sponsors key restricted to 2 cards
  - Given: all 12 cards, all options
  - When: inspecting `resource_deltas` for a `&"Sponsors"` key
  - Then: present only on `sponsor_offer_shady` and `brand_deal_choice` options
  - Edge cases: check both options of every other card explicitly absent, not just "not checked"

- **AC-14**: qualifying cards have a positive Sponsors option
  - Given: `sponsor_offer_shady`, `brand_deal_choice`
  - When: inspecting their options
  - Then: at least one option per card has `resource_deltas[&"Sponsors"] > 0`
  - Edge cases: `brand_deal_choice` per the GDD table has Sponsors +3/+1 on both options — at least one (both, in fact) qualifies

- **AC-15**: negative deltas accepted as-is
  - Given: an option with a negative `Reach`/`Sponsors` value (e.g. `brand_deal_choice` A: Reach -40)
  - When: stored in the data table
  - Then: value accepted, no clamping/flooring at this layer
  - Edge cases: confirm the stored value is the exact negative number from the GDD table, not clamped to 0

- **AC-16**: algorithm_hack forward hook has no current consumer
  - Given: milestone `"card.algorithm_hack.saved"`
  - When: searching all 12 cards' `trigger_condition` strings for a reference to it
  - Then: no match found
  - Edge cases: this is a static-content check (string search), not a runtime behavior test

- **AC-17**: absence of milestone_to_set is correct, not missing
  - Given: the 21 non-milestone options (per AC-12's count)
  - When: checking for the field
  - Then: structurally absent (`not dict.has("milestone_to_set")`), confirming the data author didn't accidentally omit real data
  - Edge cases: same data as AC-12 — this AC frames it as a positive correctness check rather than a negative search

**Not automatable as runtime tests** (per GDD's own "Not testable against this GDD alone" list — explicitly out of scope, not deferred): milestone non-repetition enforcement, simultaneous `trigger_condition` collision resolution, resource floor/clamp behavior, and runtime application of `resource_deltas` to a real resource pool — all depend on the undesigned Decision Card System or on Resource System's own spec, not this story.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/card_content_database/card_content_database_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (Foundation layer, pure static data — no other system must exist first; values must *respect* Resource System's and History Flag System's existing key/counter names, both already Complete)
- Unlocks: Decision Card System (reads this data via `get_card()`/`get_all_cards()` to evaluate `trigger_condition`, select/weight cards, and apply their effects)

---

## Completion Notes
**Completed**: 2026-06-24
**Criteria**: 17/17 passing (none deferred)
**Deviations**: 3 advisory, logged as tech debt — (1) AC-7 amended, 3 of 8 GDD-authored Reach ratios exceed the GDD's own 1.4-1.8x bound, implemented as-authored; (2) AC-13 amended, `fan_in_trouble`'s Sponsors cost contradicted the literal "only 2 cards" wording, corrected to distinguish costs from qualifying rewards; (3) no test asserts `CardContentDatabase`'s resource keys exist in `ResourceManager`'s actual key set — silent drift risk, flagged by LP-CODE-REVIEW.
**Test Evidence**: Logic — `tests/unit/card_content_database/card_content_database_test.gd`, 18/18 passing (full regression 128/128 passing)
**Code Review**: Complete — `/code-review` APPROVED; LP-CODE-REVIEW gate APPROVE; QL-TEST-COVERAGE gate ADEQUATE
