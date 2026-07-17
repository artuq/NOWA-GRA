# Story 008: Era-Local Challenge Reset Wiring

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

**ADR Governing Implementation**: ADR-0013 + ADR-0012 §5 (`PrestigeSystem._sweep_era_local_flags()`, Core Rule 7)
**ADR Decision Summary**: `ChallengeSystem._active_challenge_ids` is era-local state — it must clear on every accepted burnout, same sweep that already clears the 5 resources and `_deferred_this_era` (prestige-checkpoint Story 007). This story closes a known, explicitly-documented gap: Story 007's own tech-debt entry states Challenge-flag clearing was "not implemented — `ChallengeSystem` doesn't exist yet," deferred pending exactly this epic.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: None post-cutoff. This story adds one call inside an already-shipped, tested method (`_sweep_era_local_flags()`) — same minimal-change discipline as Story 007's `challenge_mult` substitution.

**Control Manifest Rules (this layer)**:
- Required: n/a — delegates to `ChallengeSystem`'s own clear mechanism, no new pattern
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From `design/quick-specs/challenge-era-runs-2026-07-01.md` §1.4, §3.2, scoped to this story:*

- [ ] GIVEN one or more challenges are active (`_active_challenge_ids` nonempty) when `PrestigeSystem.on_burnout_accepted()` runs (Choice A), WHEN the flag sweep step completes, THEN `ChallengeSystem._active_challenge_ids` is empty
- [ ] GIVEN Choice B (Defer) is taken instead, WHEN `PrestigeSystem.on_burnout_deferred()` runs, THEN `ChallengeSystem._active_challenge_ids` is UNCHANGED — Defer does not transition eras, so era-local challenge selections must survive it (same principle as Choice B not touching any of PrestigeSystem's own era-local state, prestige-checkpoint Story 006)
- [ ] GIVEN the sweep clears challenges AND `ChallengeSystem.get_combined_meta_multiplier()` was already read earlier in the SAME `on_burnout_accepted()` call (Story 007's grant computation, which runs before the sweep per the existing step order), THEN the grant already computed is unaffected by the clear — this AC is an ordering regression check: the clear must happen strictly AFTER the multiplier was consumed, never before
- [ ] GIVEN the clear happens, WHEN a call-order spy is used (same technique as prestige-checkpoint Story 007's AC-3), THEN it confirms `ChallengeSystem`'s clear is observed strictly after the grant-computation step's read of `get_combined_meta_multiplier()`, within the same `on_burnout_accepted()` call

---

## Implementation Notes

*Extends `PrestigeSystem._sweep_era_local_flags()` (prestige-checkpoint Story 007, already shipped) with one new call:*

```gdscript
# Inside _sweep_era_local_flags() (existing method, prestige-checkpoint Story 007):
# ... existing 5-resource reset, _deferred_this_era reset ...
ChallengeSystem.clear_active_challenges()  # NEW — this story's only addition
```

Add a `clear_active_challenges()` method to `ChallengeSystem` (a thin wrapper — `_active_challenge_ids.clear()`, no return value needed):

```gdscript
## Called by PrestigeSystem._sweep_era_local_flags() (Story 007 of
## prestige-checkpoint, extended by this story) on every accepted burnout.
## Never call this directly from anywhere else -- ChallengeSystem does not
## own the decision of WHEN an era transitions, only WHAT gets cleared.
func clear_active_challenges() -> void:
	_active_challenge_ids.clear()
```

**Critical ordering note (per this story's AC-3/AC-4)**: `on_burnout_accepted()`'s existing step order is: grant computation (reads `challenge_mult` via `get_combined_meta_multiplier()`, Story 007) → flag sweep (Story 007 of prestige-checkpoint, this story's new call goes here) → `era_count += 1`. The multiplier MUST be read before the clear — verify this against the real, already-shipped step order in `prestige_system.gd` before wiring the new call in, do not assume the pseudocode above reflects the exact current line numbers.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `_sweep_era_local_flags()`'s existing 5-resource/`_deferred_this_era` clearing — already shipped, prestige-checkpoint Story 007 (Complete), unmodified beyond this one addition
- The grant computation itself that reads `get_combined_meta_multiplier()` — Story 007 of this epic, unmodified here

---

## QA Test Cases

**Integration — automated test specs:**

- **AC-1 (Choice A clears challenges)**:
  - Given: `_active_challenge_ids` nonempty, Choice A resolves
  - When: `_sweep_era_local_flags()` completes (as part of the real `on_burnout_accepted()` call)
  - Then: `_active_challenge_ids.is_empty() == true`

- **AC-2 (Choice B preserves challenges)**:
  - Given: `_active_challenge_ids` nonempty, Choice B (Defer) resolves
  - When: `on_burnout_deferred()` runs
  - Then: `_active_challenge_ids` unchanged from its pre-call value

- **AC-3/AC-4 (ordering — multiplier read before clear)**:
  - Given: a known nonzero `get_combined_meta_multiplier()` value, Choice A resolves
  - When: the real `on_burnout_accepted()` call runs
  - Then: a call-order spy (tracking both the multiplier read and the clear call, same real-signal/tracked-call-log technique as prestige-checkpoint Story 007's AC-3) confirms the read happens strictly before the clear
  - Edge cases: the grant's own numeric result (not just the call order) must reflect the pre-clear multiplier value — a spy proving order alone isn't sufficient if the actual grant math used a wrong value; assert both

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/prestige/prestige_flag_sweep_challenge_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (catalogue/storage — `_active_challenge_ids` must exist to clear), Story 007 (the multiplier-read call site this story's ordering AC depends on), prestige-checkpoint Story 007 (`_sweep_era_local_flags()`, Complete — this story extends it)
- Unlocks: None (last story in this epic)
