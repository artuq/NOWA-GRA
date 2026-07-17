# Story 007: Meta-Bonus Multiplier Pull into PrestigeSystem

> **Epic**: Burnout & Challenge System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: S (1-2h)
> **Manifest Version**: 2026-06-20
> **Last Updated**:


## Context

**GDD**: `design/quick-specs/challenge-era-runs-2026-07-01.md`
**Requirement**: `TR-pcs-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013 (`PrestigeSystem`'s one new call site) + ADR-0012 (`on_burnout_accepted()`, locked entry point)
**ADR Decision Summary**: `PrestigeSystem.on_burnout_accepted()`'s `challenge_mult` stub (hardcoded `1.0` since Story 003 of prestige-checkpoint, with an explicit "future story" comment) is replaced by a real call to `ChallengeSystem.get_combined_meta_multiplier()`. This is the ONLY change to already-shipped `PrestigeSystem` code in this entire epic — one line, no signature change.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: The read is a synchronous getter over an `Array`/`Dictionary` lookup — no signals, no I/O — satisfies ADR-0012's zero-await binding constraint by construction, already verified during ADR-0013's `/architecture-review`.

**Control Manifest Rules (this layer)**:
- Required: pull-model getter pattern (ADR-0010 §5a precedent, `get_active_sponsor_multiplier()`)
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From `design/quick-specs/challenge-era-runs-2026-07-01.md` §5 (Meta-Bonus Interaction), scoped to this story:*

- [ ] GIVEN zero active challenges, WHEN `PrestigeSystem.on_burnout_accepted()` computes a grant, THEN `challenge_mult == 1.0` (identical to current shipped behavior — this story must not change grant outcomes for the zero-challenge case, only for the nonzero case)
- [ ] GIVEN one or more active challenges with known `meta_bonus_multiplier` values, WHEN `on_burnout_accepted()` computes a grant, THEN `challenge_mult` equals `ChallengeSystem.get_combined_meta_multiplier()`'s real return value at that moment — e.g. two challenges with `meta_bonus_multiplier` 2.0 and 2.5 both active → `challenge_mult == 5.0`
- [ ] GIVEN this story's change, WHEN the full prestige suite (`tests/unit/prestige/` + `tests/integration/prestige/`, 80 tests as of prestige-checkpoint epic close) is re-run, THEN all previously-passing tests still pass — the stub replacement must not regress any of Stories 001-009's existing coverage

---

## Implementation Notes

*Derived from ADR-0013's exact one-line change:*

```gdscript
# BEFORE (shipped, prestige-checkpoint Story 003):
var challenge_mult: float = 1.0

# AFTER (this story):
var challenge_mult: float = ChallengeSystem.get_combined_meta_multiplier()
```

Locate this line inside `on_burnout_accepted()` — it currently sits right before the `PrestigeFormulas.grant_magnitude(bonus_type, tier, challenge_mult, is_first)` call. Every other line of that method is untouched.

**Regression discipline**: this story's test suite must include the existing prestige-checkpoint stories' worked examples (e.g. `PrestigeFormulas.grant_magnitude()`'s Tier-1 `0.1071` example from Story 003) re-run with `challenge_mult` now sourced from `ChallengeSystem` instead of hardcoded, confirming the zero-challenge case is byte-identical to before.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `ChallengeSystem.get_combined_meta_multiplier()`'s own implementation — Story 005/006's catalogue is the data source; this story only wires the existing getter (per ADR-0013's spec) into the call site
- Any other line of `on_burnout_accepted()` — locked, prestige-checkpoint epic (Complete), not reopened beyond this one substitution

---

## QA Test Cases

**Integration — automated test specs:**

- **AC-1 (zero-challenge baseline unchanged)**:
  - Given: `ChallengeSystem._active_challenge_ids` empty
  - When: `on_burnout_accepted()` runs with the same inputs as an existing Story 003 worked example
  - Then: grant result matches that worked example exactly (e.g. `0.1071` for the Tier-1 first-burnout `META_REACH_MULT` case)

- **AC-2 (nonzero challenge multiplier flows through)**:
  - Given: two challenges active with `meta_bonus_multiplier` 2.0 and 2.5 (`get_combined_meta_multiplier() == 5.0`)
  - When: `on_burnout_accepted()` runs
  - Then: the grant computation used `challenge_mult == 5.0` — verify via `PrestigeFormulas.grant_magnitude()`'s own `pow(challenge_mult, META_CHALLENGE_SCALING_EXPONENT)` term producing the expected scaled value, not just that SOME different number came out

- **AC-3 (full-suite regression)**:
  - Given: this story's change is applied
  - When: `tests/unit/prestige/` + `tests/integration/prestige/` run in full
  - Then: 80/80 (or whatever the current count is at implementation time) still pass, 0 regressions

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/prestige/prestige_challenge_multiplier_wiring_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (catalogue/storage), Story 006 (not strictly required for this story's own logic, but establishes `get_combined_meta_multiplier()`'s real data source — implement Story 005 first at minimum)
- Unlocks: None
