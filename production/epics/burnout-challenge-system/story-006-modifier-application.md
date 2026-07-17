# Story 006: Modifier Application at Reward Resolution

> **Epic**: Burnout & Challenge System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (2-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**:


## Context

**GDD**: `design/quick-specs/challenge-era-runs-2026-07-01.md`
**Requirement**: `TR-pcs-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013 (`ChallengeSystem.get_modifier()`, pull-model)
**ADR Decision Summary**: `ActionSystem` reads `ChallengeSystem.get_modifier(action_id, axis)` at reward resolution time, after the Morale multiplier (Formula C), as a second multiplicative pass — pull-model, same shape as `ClassPathSystem.get_active_multiplier()` (ADR-0010 §3), no push/signal coupling.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: None post-cutoff. Pure synchronous getter read, no signals involved in the modifier path itself.

**Control Manifest Rules (this layer)**:
- Required: `ResourceFormulas`-style stateless composition where applicable — `get_modifier()` itself is a pure function of `_active_challenge_ids` + the catalogue, no side effects
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From `design/quick-specs/challenge-era-runs-2026-07-01.md` §2, §4 (Modifier Application, Stacking), scoped to this story:*

- [ ] GIVEN `brak_duszy` is active (`reach_multiplier`, `0.3`, applies to `nagraj_vloga`), WHEN `Nagraj vloga`'s Reach reward resolves with `Mult(M)=1.0`, base=5, THEN `final_reach = 5 × 1.0 × 0.3 = 1.5` → round-half-up → `2`
- [ ] GIVEN `drama_bez_granic` is active (`cringe_multiplier`, `2.0`, applies to `zrob_drame`), WHEN `Zrób dramę`'s Cringe delta resolves with declared `+20`, THEN `effective_cringe_delta = 20 × 2.0 = 40`, passed to `ResourceManager` (still subject to its own `[0,100]` clamp — this story does not duplicate that clamp)
- [ ] GIVEN two challenges both target the same axis on the same action, THEN their modifiers stack multiplicatively (e.g. two `0.5×` Reach modifiers on the same action → effective `0.25×`)
- [ ] GIVEN `bez_tlumu` is active (`reach_multiplier`, `0.5`, `applies_to: "all"`), WHEN ANY base action's Reach resolves, THEN the `0.5×` applies — verify the `"all"` sentinel is handled distinctly from an explicit action-ID array
- [ ] GIVEN no challenge targets a given `(action_id, axis)` pair, WHEN `get_modifier()` is called, THEN it returns `1.0` (no-op, not a missing-key error)
- [ ] GIVEN `modifier_value` in a hypothetically misconfigured catalogue entry is `0.0`, WHEN `get_modifier()` computes the product, THEN the result is clamped to `CHALLENGE_MODIFIER_FLOOR` (0.05 default), never allowing a true zero to reach `ResourceManager`
- [ ] GIVEN Formula D (passive Reach from Haters, computed in `OfflineProgressSystem`/live-play passive tick), THEN no challenge modifier ever affects it — verify by grep that `ChallengeSystem.get_modifier()` is never called from that formula's call site, same offline-exclusion verification technique already established elsewhere in this codebase

---

## Implementation Notes

*Derived from ADR-0013's `get_modifier()` (already fully specified — implement as written) and the quick-spec's Rule 2/4:*

```gdscript
func get_modifier(action_id: StringName, axis: StringName) -> float:
	var product: float = 1.0
	for challenge_id: StringName in _active_challenge_ids:
		var entry: Dictionary = _CHALLENGE_CATALOGUE[challenge_id]
		if entry["modifier_type"] != axis:
			continue
		var applies_to: Variant = entry["applies_to"]
		if applies_to != "all" and not (applies_to as Array).has(action_id):
			continue
		product *= entry["modifier_value"]
	return maxf(CHALLENGE_MODIFIER_FLOOR, product)
```

`ActionSystem`'s call site (per the quick-spec's exact formula):

```gdscript
# Reach axis — second multiplicative pass after Formula C's Mult(M):
final_reach = base_reach * morale_multiplier * ChallengeSystem.get_modifier(action_id, &"reach_multiplier")

# Cringe/Morale axes — flat lookup deltas, modifier scales the declared delta
# before it reaches ResourceManager.apply_delta():
effective_cringe_delta = declared_cringe_delta * ChallengeSystem.get_modifier(action_id, &"cringe_multiplier")
effective_morale_delta = declared_morale_delta * ChallengeSystem.get_modifier(action_id, &"morale_multiplier")
```

Round-half-up is `ActionSystem`'s existing convention (already used for Formula C's own Mult(M) application) — reuse it, do not introduce a different rounding rule for the challenge pass.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: the catalogue/selection storage this story reads from
- `ResourceManager`'s own clamp behavior — unmodified, receives already-modified deltas transparently
- Formula D (passive Reach) — explicitly excluded, verified not modified, but the passive-income code itself is Resource System epic territory (already shipped, Complete), not touched here

---

## QA Test Cases

**Integration — automated test specs:**

- **AC-1/AC-2 (worked examples from the quick-spec)**: direct tests against the stated inputs/outputs, exact values

- **AC-3 (multiplicative stacking, same axis)**:
  - Given: two mocked catalogue entries both `reach_multiplier=0.5` on the same `action_id`
  - When: `get_modifier(action_id, &"reach_multiplier")` called
  - Then: returns `0.25`

- **AC-4 (`"all"` sentinel)**:
  - Given: `bez_tlumu` active (`applies_to: "all"`)
  - When: `get_modifier()` called for several different `action_id`s on `reach_multiplier`
  - Then: all return `0.5`, not just the ones in an explicit list

- **AC-5 (no-op default)**:
  - Given: no active challenge targets `(action_id, axis)`
  - When: `get_modifier()` called
  - Then: returns exactly `1.0`

- **AC-6 (floor clamp)**:
  - Given: a mocked catalogue entry with `modifier_value = 0.0`
  - When: `get_modifier()` computes
  - Then: returns `CHALLENGE_MODIFIER_FLOOR` (0.05), not `0.0`

- **AC-7 (Formula D exclusion)**:
  - Given: any active challenge combination
  - When: passive Reach income computes (existing Formula D call site)
  - Then: value is identical with or without challenges active — grep-based static check (no cross-call to `ChallengeSystem`) plus a behavioral test, same dual-verification style as `ResourceFormulas`' own cross-call guarantee test

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/challenge/challenge_modifier_resolution_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (catalogue + active-selection storage), Action System epic (Complete — `ActionSystem`'s reward resolution call site already exists, this story adds one call into it)
- Unlocks: None (independent of Story 007/008)
