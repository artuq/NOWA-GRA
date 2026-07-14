## PrestigeSystem orchestrates the era-transition sequence: it reads Class
## Path state before it is cleared, triggers the reset, and (in later
## stories) computes and grants a permanent META_BONUS, sweeps era-local vs
## meta-persistent flags, then saves and signals.
##
## Implements TR-pcs-001 / ADR-0012 §1-2: registered as a new Core Autoload,
## below ClassPathSystem, DecisionCardSystem, SaveSystem, and
## HistoryFlagManager in Project Settings -> Autoload — PrestigeSystem
## depends on all four; none of them reference PrestigeSystem back
## (one-directional dependency discipline, same precedent ADR-0010 §1
## established for ClassPathSystem).
##
## Story 001 (this file) implements ONLY the orchestration skeleton and the
## read-then-reset ordering guarantee — the critical deliverable is that
## on_burnout_accepted() is a single synchronous call chain with zero
## await/CONNECT_DEFERRED/call_deferred anywhere in it or its call graph
## (ADR-0012 §2, binding constraint; Control Manifest's Core Layer Forbidden
## Approaches, story-specific addition). The following steps are
## intentionally stubbed/no-op placeholders here, filled in by later
## stories:
##   - META_BONUS grant computation (PrestigeFormulas.grant_magnitude() +
##     applying the result to meta_bonus_totals) — Story 003/004
##   - Flag classification sweep, era-local vs meta-persistent (Core Rule 7)
##     — Story 007
##   - ChallengeSystem.get_combined_meta_multiplier() — ChallengeSystem does
##     not exist yet (no ADR yet, TR-pcs-007) — this call is omitted
##     entirely rather than stubbed against a non-existent Autoload. Story
##     003/004 adds it back once ChallengeSystem ships.
## get_meta_bonus_total() (ADR-0012's Key Interfaces) is likewise deferred to
## Story 003/004 — there is no meta_bonus_totals state to read yet.
##
## Usage example:
##   PrestigeSystem.on_burnout_accepted()  # called by BurnoutSystem's Choice A handler
extends Node

## Fires only after the full synchronous on_burnout_accepted() sequence
## completes (ADR-0012 §2) — never mid-sequence, never via a deferred call.
signal era_transitioned

## Number of eras completed (transitions triggered by Choice A so far).
## Persisted via serialize_state()/restore_state() (ADR-0003 boot protocol).
var era_count: int = 0

## Story-001-only test-observability hook: the tier value captured in step 1
## of on_burnout_accepted(), before ClassPathSystem.reset_era_state() runs.
## Not part of ADR-0012's Key Interfaces — a real consumer (PrestigeFormulas
## .grant_magnitude()) is added by Story 003/004, at which point this field
## becomes redundant with that call's own argument and may be removed. Exists
## only so this story's tests can prove the read-before-reset ordering
## without a grant computation to spy on yet (AC-1/AC-3 in
## story-001-orchestration-core.md, both of which reference a spy on a value
## that doesn't exist until Story 003/004).
var _last_captured_tier: int = -1


## Single entry point for "Choice A confirmed" (ADR-0012 §2). Performs the
## era-transition sequence synchronously, in order:
##   1. Read ClassPathSystem's active path + tier BEFORE any reset — this is
##      the exact ordering the GDD flags as bug-prone: reading after reset
##      would silently observe already-zeroed values
##   2. Suppress autosave for the duration of the transition (SaveSystem) —
##      Choice A's resolution is itself a card resolution, which would
##      otherwise be able to autosave mid-sequence
##   3. Reset ClassPathSystem's era-local state
##   4. [STUBBED — Story 003/004] META_BONUS grant computation
##   5. [STUBBED — Story 007] flag classification sweep (Core Rule 7)
##   6. Increment era_count
##   7. Save, resume autosave, then fire era_transitioned — nothing above
##      this line may yield control before completing
##
## BINDING CONSTRAINT (ADR-0012 §2): zero `await`, zero `CONNECT_DEFERRED`,
## zero `call_deferred` anywhere in this method or anything it calls. This is
## not a style preference — a violation silently breaks the read-before-reset
## ordering guarantee this method exists to provide, with no compile error.
##
## Example:
##   PrestigeSystem.on_burnout_accepted()
func on_burnout_accepted() -> void:
	var path_id: StringName = ClassPathSystem.get_active_path()
	var tier: int = ClassPathSystem.get_tier(path_id) if path_id != &"" else 0
	_last_captured_tier = tier

	SaveSystem.suppress_autosave()

	ClassPathSystem.reset_era_state()

	# [STUBBED — Story 003/004] META_BONUS grant computation:
	# PrestigeFormulas.grant_magnitude(bonus_type, tier, challenge_mult,
	# is_first_burnout) -> _apply_grant(bonus_type, grant). `tier` above is
	# already captured and ready for that story to consume as-is.
	# [STUBBED — Story 007] flag classification sweep (Core Rule 7):
	# _sweep_era_local_flags() delegating to HistoryFlagManager.

	era_count += 1

	SaveSystem.save_now()
	SaveSystem.resume_autosave()

	era_transitioned.emit()


## Returns the number of eras completed so far.
func get_era_count() -> int:
	return era_count


## Restores persisted state per the ADR-0003 boot protocol, called by
## BootController after ClassPathSystem.restore_state() (no ordering
## dependency between the two at boot time). Story 001 scope: era_count
## only — per-type META_BONUS totals and meta-persistent flags are added by
## Story 009's fuller persistence pass. Missing key defaults safely to `0`
## (first-session case, `data == {}`).
##
## Example:
##   PrestigeSystem.restore_state(data.get("prestige", {}))
func restore_state(data: Dictionary) -> void:
	era_count = int(data.get("era_count", 0))


## Serializes persisted state for SaveSystem.save_now(). Story 001 scope:
## era_count only (see restore_state() doc comment).
##
## Example:
##   var data: Dictionary = PrestigeSystem.serialize_state()
func serialize_state() -> Dictionary:
	return {"era_count": era_count}
