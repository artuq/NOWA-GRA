## PrestigeSystem orchestrates the era-transition sequence: it reads Class
## Path state before it is cleared, triggers the reset, computes and grants
## a permanent META_BONUS, and (in later stories) sweeps era-local vs
## meta-persistent flags, then saves and signals.
##
## Implements TR-pcs-001 / ADR-0012 §1-2: registered as a new Core Autoload,
## below ClassPathSystem, DecisionCardSystem, SaveSystem, and
## HistoryFlagManager in Project Settings -> Autoload — PrestigeSystem
## depends on all four; none of them reference PrestigeSystem back
## (one-directional dependency discipline, same precedent ADR-0010 §1
## established for ClassPathSystem).
##
## Story 001 implemented the orchestration skeleton and the read-then-reset
## ordering guarantee. Story 003 filled in step 4: META_BONUS grant
## computation via PrestigeFormulas.grant_magnitude()/
## variety_bonus_increment(). Story 004 wires both grant call sites
## (_apply_grant()/_check_variety_bonus()) through PrestigeFormulas.
## apply_stacking_and_cap() — every grant now clamps at
## PrestigeFormulas.META_BONUS_MAX[bonus_type] (F2, Core Rule 1) instead of
## accumulating unbounded. The four first_burnout_bonus_used[type] flags and
## variety_bonus_used are tracked as HistoryFlagManager milestones (ADR-0012
## §1), same pattern ClassPathSystem uses for its own per-path milestones
## (class_path_system.gd's reset_era_state(), "class_path.{path}.best_tier.
## {N}" naming) — here: "prestige.first_burnout_used.{type}" and
## "prestige.variety_bonus_used". Story 006 (this revision) adds
## on_burnout_deferred() — Choice B (Defer)'s own, much simpler entry point:
## a Morale cost via ResourceManager's existing clamp plus a
## "burnout_deferred_era_N" HistoryFlagManager milestone, deliberately
## calling none of Choice A's grant machinery.
##
## The following steps remain intentionally stubbed/no-op placeholders,
## filled in by later stories:
##   - Flag classification sweep, era-local vs meta-persistent (Core Rule 7)
##     — Story 007
##   - ChallengeSystem.get_combined_meta_multiplier() — ChallengeSystem does
##     not exist yet (no ADR yet, TR-pcs-007). This story passes a fixed
##     challenge_mult of 1.0 (GDD F1: "1.0 if no challenges active") rather
##     than stubbing a call against a non-existent Autoload. Whichever
##     future story wires ChallengeSystem in must replace this literal with
##     a real ChallengeSystem.get_combined_meta_multiplier() call.
##
## Usage example:
##   PrestigeSystem.on_burnout_accepted()  # called by BurnoutSystem's Choice A handler
##   PrestigeSystem.get_meta_bonus_total(&"META_REACH_MULT")  # -> 0.1071 after one grant
extends Node

## Fires only after the full synchronous on_burnout_accepted() sequence
## completes (ADR-0012 §2) — never mid-sequence, never via a deferred call.
signal era_transitioned

## Number of eras completed (transitions triggered by Choice A so far).
## Persisted via serialize_state()/restore_state() (ADR-0003 boot protocol).
var era_count: int = 0

## Permanent, additive-per-type META_BONUS running totals (ADR-0012 §1).
## Keys are the four META_BONUS type StringNames (PrestigeFormulas.
## BASE_INCREMENT's keys); a missing key means "never granted yet" (0.0),
## not an error — always read via get_meta_bonus_total(), never indexed
## directly, so callers get the 0.0 default for free. Each write routes
## through PrestigeFormulas.apply_stacking_and_cap() (Story 004, F2), so a
## value here is always clamped at PrestigeFormulas.META_BONUS_MAX[type] —
## never exceeds it. Persisted via serialize_state()/restore_state().
var meta_bonus_totals: Dictionary[StringName, float] = {}

## Maps each Class Path id to the single META_BONUS type it grants on
## burnout (GDD's meta_bonus_types table / entities.yaml's `active_path`
## field). Fixed at four entries, one per locked Class Path — not a tuning
## knob, not exposed as external config (the pairing is a design identity,
## not a balance number).
const _BONUS_TYPE_BY_PATH: Dictionary[StringName, StringName] = {
	&"pato_streamer": &"META_REACH_MULT",
	&"guru_celebryta": &"META_SPONSOR_MULT",
	&"ekspert_niszowy": &"META_HATERS_RESIST",
	&"biznesmen_contentu": &"META_SPONSOR_FLOOR",
}

## All four META_BONUS types, used by _check_variety_bonus()'s cross-type
## scan (F1b). Kept as a separate list (rather than deriving it from
## _BONUS_TYPE_BY_PATH.values() on every call) for clarity — same four keys
## as PrestigeFormulas.BASE_INCREMENT/META_BONUS_MAX.
const _ALL_BONUS_TYPES: Array[StringName] = [
	&"META_REACH_MULT", &"META_SPONSOR_MULT", &"META_HATERS_RESIST", &"META_SPONSOR_FLOOR",
]

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
##   4. META_BONUS grant computation (Story 003) + stacking/cap (Story 004):
##      if a path was active, compute this era's grant via
##      PrestigeFormulas.grant_magnitude() and apply it to meta_bonus_totals
##      through PrestigeFormulas.apply_stacking_and_cap() (F2's clamp), then
##      run the cross-type variety-completionist check (F1b), also clamped
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

	# Step 4 (Story 003): META_BONUS grant computation (F1) + variety check
	# (F1b). ChallengeSystem does not exist yet (TR-pcs-007, no ADR yet) — a
	# fixed challenge_mult of 1.0 is used ("1.0 if no challenges active" per
	# GDD F1) rather than stubbing a call against a non-existent Autoload.
	# Whichever future story wires ChallengeSystem in must replace this
	# literal with a real ChallengeSystem.get_combined_meta_multiplier() call.
	if path_id != &"":
		var bonus_type: StringName = _BONUS_TYPE_BY_PATH.get(path_id, &"")
		if bonus_type != &"":
			var challenge_mult: float = 1.0
			var is_first: bool = _first_burnout_pending(bonus_type)
			var grant: float = PrestigeFormulas.grant_magnitude(bonus_type, tier, challenge_mult, is_first)
			_apply_grant(bonus_type, grant)
			if is_first:
				HistoryFlagManager.set_milestone(StringName("prestige.first_burnout_used." + String(bonus_type)))
	_check_variety_bonus()  # Core Rule 4c — fires at most once per save

	# [STUBBED — Story 007] flag classification sweep (Core Rule 7):
	# _sweep_era_local_flags() delegating to HistoryFlagManager.

	era_count += 1

	SaveSystem.save_now()
	SaveSystem.resume_autosave()

	era_transitioned.emit()


## Single entry point for "Choice B (Defer) confirmed" (Story 006, GDD's
## Choice B — Defer, Morale Floor, No Grant). Deliberately NOT a branch
## inside on_burnout_accepted() — ADR-0012 §2 frames Choice A and Choice B as
## distinct paths, and Defer's body is intentionally much smaller: it never
## reads ClassPathSystem, never resets era-local state, and never touches
## meta_bonus_totals/era_count. The Morale-cost mechanic itself
## (BURNOUT_DEFER_MORALE_COST) is owned by BurnoutSystem's own quick-spec
## (final-burnout-2026-07-01.md) — this method accepts the cost as an
## explicit argument rather than importing or hardcoding that constant, so
## PrestigeSystem stays ignorant of BurnoutSystem's tuning (same
## one-directional-dependency discipline as ADR-0012 §1 — BurnoutSystem is
## the future caller, passing its own BURNOUT_DEFER_MORALE_COST).
##
## Performs, in order:
##   1. ResourceManager.apply_delta({&"Morale": -morale_cost}) — Morale is
##      already one of ResourceManager's _CLAMPED_KEYS (floor 0, ceiling
##      100), so this reuses the existing clamp mechanism rather than
##      reimplementing a floor here (GDD AC: "Morale clamps to 0, never
##      negative").
##   2. HistoryFlagManager.set_milestone() writes "burnout_deferred_era_N",
##      N = era_count (Defer does not transition eras — era_count is not
##      incremented here — so "the current era" is simply this field's
##      present value, unlike Choice A's "completed era" framing). Same
##      milestone mechanism as ClassPathSystem's "class_path.{path}.
##      best_tier.{N}" pattern (ADR-0010 §1) and this file's own
##      "prestige.first_burnout_used.{type}" flags — flat "burnout_deferred_
##      era_N" naming (no "prestige." prefix) matches the GDD's own AC
##      wording and final-burnout-2026-07-01.md §5's naming verbatim.
##
## Deliberately does NOT call ClassPathSystem.get_active_path()/get_tier(),
## does NOT call ClassPathSystem.reset_era_state(), does NOT call
## PrestigeFormulas.grant_magnitude()/apply_stacking_and_cap(), and does NOT
## touch meta_bonus_totals or era_count — Choice B grants nothing (GDD Edge
## Cases). tests/unit/prestige/prestige_defer_test.gd's static source-scan
## enforces this at the source level, not just via one test run's observed
## behavior.
##
## Example:
##   PrestigeSystem.on_burnout_deferred(BurnoutSystem.BURNOUT_DEFER_MORALE_COST)
func on_burnout_deferred(morale_cost: float) -> void:
	ResourceManager.apply_delta({&"Morale": -morale_cost})
	HistoryFlagManager.set_milestone(StringName("burnout_deferred_era_" + str(era_count)))


## Returns true if [param bonus_type] has never received a first-burnout
## grant yet (Core Rule 4b — per-type flag, not global). Backed by a
## HistoryFlagManager milestone, same pattern ClassPathSystem uses for its
## own per-path milestones (ADR-0012 §1).
func _first_burnout_pending(bonus_type: StringName) -> bool:
	return not HistoryFlagManager.has_milestone(StringName("prestige.first_burnout_used." + String(bonus_type)))


## Adds [param grant] to [param bonus_type]'s running total, clamped at
## PrestigeFormulas.META_BONUS_MAX[bonus_type] (F2, Core Rule 1 — Story 004).
## Routes through PrestigeFormulas.apply_stacking_and_cap() unconditionally:
## a type already sitting at its cap still calls this, absorbing the grant
## with zero effect rather than skipping the call — this is what guarantees
## a fully-absorbed grant never blocks on_burnout_accepted()'s reset/save
## sequence (no softlock, per this story's Implementation Notes).
func _apply_grant(bonus_type: StringName, grant: float) -> void:
	var current_total: float = meta_bonus_totals.get(bonus_type, 0.0)
	var cap: float = PrestigeFormulas.META_BONUS_MAX[bonus_type]
	meta_bonus_totals[bonus_type] = PrestigeFormulas.apply_stacking_and_cap(bonus_type, current_total, grant, cap)


## Cross-type variety-completionist check (GDD Formula F1b, Core Rule 4c).
## Fires at most once per save: the moment all four META_BONUS_total[type]
## values are simultaneously nonzero (checked as a side-effect of every
## accepted-burnout grant, including the very grant that makes the fourth
## type nonzero for the first time — this method runs AFTER _apply_grant()
## in on_burnout_accepted(), never before), each of the four types
## additionally receives PrestigeFormulas.variety_bonus_increment(type), and
## the "prestige.variety_bonus_used" milestone is set so this never fires
## again. Same F2 clamp as _apply_grant() (Story 004): each type's flat
## variety increment is applied through PrestigeFormulas.
## apply_stacking_and_cap() too, so a type already at its cap when the
## completionist bonus fires absorbs its share with zero effect, same as any
## other grant (AC-11 — variety_bonus_increment() itself is cap-agnostic by
## design; this loop is what layers F2's clamp on top).
func _check_variety_bonus() -> void:
	if HistoryFlagManager.has_milestone(&"prestige.variety_bonus_used"):
		return
	for bonus_type: StringName in _ALL_BONUS_TYPES:
		if meta_bonus_totals.get(bonus_type, 0.0) <= 0.0:
			return
	for bonus_type: StringName in _ALL_BONUS_TYPES:
		var current_total: float = meta_bonus_totals.get(bonus_type, 0.0)
		var cap: float = PrestigeFormulas.META_BONUS_MAX[bonus_type]
		var increment: float = PrestigeFormulas.variety_bonus_increment(bonus_type)
		meta_bonus_totals[bonus_type] = PrestigeFormulas.apply_stacking_and_cap(bonus_type, current_total, increment, cap)
	HistoryFlagManager.set_milestone(&"prestige.variety_bonus_used")


## Returns the number of eras completed so far.
func get_era_count() -> int:
	return era_count


## Returns [param bonus_type]'s current permanent running total, or `0.0` if
## it has never been granted yet (ADR-0012 Key Interfaces). Always safe to
## call with any of the four META_BONUS type StringNames, even before the
## first grant.
##
## Example:
##   PrestigeSystem.get_meta_bonus_total(&"META_REACH_MULT")  # -> 0.0 before any grant
func get_meta_bonus_total(bonus_type: StringName) -> float:
	return meta_bonus_totals.get(bonus_type, 0.0)


## Restores persisted state per the ADR-0003 boot protocol, called by
## BootController after ClassPathSystem.restore_state() (no ordering
## dependency between the two at boot time). Story 003 scope adds
## meta_bonus_totals (Dictionary, String keys per the JSON-serialization
## convention ADR-0002/ADR-0010 already established — StringName is not a
## JSON type) to Story 001's era_count. The four first_burnout_bonus_used
## [type]/variety_bonus_used flags are HistoryFlagManager milestones (ADR-
## 0012 §1) and are restored through HistoryFlagManager's own existing
## restore path, not duplicated here. Missing keys default safely (`0` era
## count, empty totals dict — first-session case, `data == {}`).
##
## Example:
##   PrestigeSystem.restore_state(data.get("prestige", {}))
func restore_state(data: Dictionary) -> void:
	era_count = int(data.get("era_count", 0))
	meta_bonus_totals.clear()
	var totals_in: Dictionary = data.get("meta_bonus_totals", {})
	for key in totals_in:
		meta_bonus_totals[StringName(key)] = float(totals_in[key])


## Serializes persisted state for SaveSystem.save_now(). Story 003 scope
## adds meta_bonus_totals (plain String keys — see restore_state()'s doc
## comment) to Story 001's era_count.
##
## Example:
##   var data: Dictionary = PrestigeSystem.serialize_state()
func serialize_state() -> Dictionary:
	var totals_out: Dictionary = {}
	for key: StringName in meta_bonus_totals:
		totals_out[String(key)] = meta_bonus_totals[key]
	return {"era_count": era_count, "meta_bonus_totals": totals_out}
