# Story 005: Challenge Catalogue + Selection Storage

> **Epic**: Burnout & Challenge System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-07-20


## Context

**GDD**: `design/quick-specs/challenge-era-runs-2026-07-01.md`
**Requirement**: `TR-pcs-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013 (`ChallengeSystem` — new Autoload)
**ADR Decision Summary**: `ChallengeSystem` owns `_active_challenge_ids: Array[StringName]` as its own field — NOT via `HistoryFlagManager.set_flag()`/milestones as the quick-spec originally assumed. This correction exists because `HistoryFlagManager`'s milestone API is a documented one-way ratchet with no unset/clear mechanism (a known gap flagged during prestige-checkpoint Story 007's code review) — era-local challenge selections that must clear every era cannot live there. `ChallengeSystem`'s own `restore_state()`/`serialize_state()` is fully self-contained.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: None post-cutoff. Typed `Array[StringName]` is a safe 4.4+ feature, already vetted in this codebase (ADR-0012's Engine Compatibility table).

**Control Manifest Rules (this layer)**:
- Required: `restore_state(data: Dictionary)` boot protocol (ADR-0003)
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From `design/quick-specs/challenge-era-runs-2026-07-01.md` §1, §6, Challenge Catalogue section, scoped to this story per ADR-0013's storage correction:*

- [ ] GIVEN the 5 designed challenges (`brak_duszy`, `drama_bez_granic`, `przepros_na_niby`, `bez_tlumu`, `wypalony_ale_core`), WHEN `ChallengeSystem` initializes, THEN each is loadable by `id` with its `modifier_type`/`modifier_value`/`applies_to`/`meta_bonus_multiplier` fields intact, matching the quick-spec's Challenge Catalogue table exactly
- [ ] GIVEN the player selects 0 to `CHALLENGE_MAX_ACTIVE` (3 default) challenge IDs and confirms, WHEN selection completes, THEN `_active_challenge_ids` contains exactly the selected IDs
- [ ] GIVEN a 4th challenge is attempted when `CHALLENGE_MAX_ACTIVE` is already reached, THEN the selection is rejected — `_active_challenge_ids` does not grow past the cap
- [ ] GIVEN `_active_challenge_ids` has been persisted via `serialize_state()`, WHEN a fresh `ChallengeSystem.restore_state()` runs on that output, THEN the same set of IDs is restored, in the same order
- [ ] GIVEN a save predates this system (missing key), WHEN `restore_state({})` runs, THEN `_active_challenge_ids` defaults to an empty array — zero active challenges, matching the "normal run" baseline

---

## Implementation Notes

*Derived from ADR-0013's `ChallengeSystem` scope and the quick-spec's Challenge Catalogue table:*

```gdscript
extends Node

const CHALLENGE_MAX_ACTIVE: int = 3  # balance.json

var _active_challenge_ids: Array[StringName] = []

## Loaded once at startup from assets/data/challenges.json (per the quick-spec's
## own stated convention) or, if that pipeline isn't ready yet, a const
## Dictionary literal matching the same shape -- implementer's choice, but the
## 5 designed entries' exact field values (see quick-spec table) must be
## reproduced verbatim, not approximated.
var _CHALLENGE_CATALOGUE: Dictionary[StringName, Dictionary] = {}

func select_challenges(challenge_ids: Array[StringName]) -> bool:
	if challenge_ids.size() > CHALLENGE_MAX_ACTIVE:
		return false
	_active_challenge_ids = challenge_ids.duplicate()
	return true

func restore_state(data: Dictionary) -> void:
	var ids_in: Array = data.get("_active_challenge_ids", [])
	_active_challenge_ids.clear()
	for id_str: String in ids_in:
		_active_challenge_ids.append(StringName(id_str))

func serialize_state() -> Dictionary:
	var ids_out: Array[String] = []
	for id: StringName in _active_challenge_ids:
		ids_out.append(String(id))
	return {"_active_challenge_ids": ids_out}
```

Catalogue data source (`assets/data/challenges.json` vs. an in-code const table) is an implementation-time choice not mandated by ADR-0013 — either satisfies this story's ACs. If a data file is used, follow the same loading convention `CardContentDatabase` already established for its own JSON-backed content.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: applying the stored challenges' modifiers at reward resolution
- Story 007: reading the combined meta-bonus multiplier (this story only stores selections, doesn't compute derived values consumed elsewhere)
- Story 008: clearing `_active_challenge_ids` on era transition
- The Challenge Selection UI screen itself — future UI story; this story only implements the data-layer `select_challenges()` call the screen will eventually call

---

## QA Test Cases

**Logic — automated test specs:**

- **AC-1 (catalogue fidelity)**:
  - Given: `ChallengeSystem` initialized
  - When: each of the 5 real challenge IDs is looked up
  - Then: `modifier_type`/`modifier_value`/`applies_to`/`meta_bonus_multiplier` match the quick-spec's table exactly (e.g. `brak_duszy`: `reach_multiplier`, `0.3`, `["nagraj_vloga"]`, `2.0`)

- **AC-2 (selection storage)**:
  - Given: `select_challenges([&"brak_duszy", &"bez_tlumu"])`
  - When: called
  - Then: `_active_challenge_ids == [&"brak_duszy", &"bez_tlumu"]`, return value `true`

- **AC-3 (max-active cap rejection)**:
  - Given: `CHALLENGE_MAX_ACTIVE == 3`
  - When: `select_challenges()` called with 4 IDs
  - Then: returns `false`, `_active_challenge_ids` unchanged from its prior state (not partially updated)

- **AC-4 (round-trip persistence, order preserved)**:
  - Given: `_active_challenge_ids = [&"drama_bez_granic", &"przepros_na_niby"]`, `serialize_state()` called
  - When: a fresh instance's `restore_state()` runs on that output
  - Then: restored array matches exactly, same order

- **AC-5 (missing-key default)**:
  - Given: `restore_state({})`
  - When: called on a fresh instance
  - Then: `_active_challenge_ids.is_empty() == true`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/challenge/challenge_selection_storage_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (foundational ChallengeSystem story)
- Unlocks: Story 006 (modifier application reads `_active_challenge_ids`), Story 007 (meta-multiplier reads the same), Story 008 (era-reset clears it)

---

## Completion Notes
**Completed**: 2026-07-20
**Criteria**: 5/5 passing
**Deviations**: None blocking. One quality hardening during code review: `get_active_challenge_ids()` returns `.duplicate()` rather than the live internal array, closing a CHALLENGE_MAX_ACTIVE bypass vector external mutation would otherwise allow.
**Test Evidence**: `tests/unit/challenge/challenge_selection_storage_test.gd` — 14/14 passing, 0 errors, 0 orphans (verified live via gdUnit4 headless run); full `tests/unit/` suite (380 cases) also green after the new ChallengeSystem Autoload registration
**Code Review**: Complete — godot-gdscript-specialist (CLEAN) + qa-tester (TESTABLE, one low-priority advisory), both APPROVED
