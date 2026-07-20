## ChallengeSystem owns era-local Challenge Selection: which of the 5 designed
## challenges the player has chosen to run this era, and the static catalogue
## of their modifier data. It owns nothing BurnoutSystem or PrestigeSystem
## already own -- this Autoload's only job is storing the current selection
## and exposing it (and the static catalogue) for other systems to read.
##
## Implements TR-pcs-007 / ADR-0013 "ChallengeSystem (new Autoload, independent
## of both BurnoutSystem and PrestigeSystem)": registered as a new Core
## Autoload. No `_ready()` cross-system wiring exists yet (Story 006/007/008
## add the read call sites in ActionSystem/PrestigeSystem, not here) and no
## Autoload ordering constraint applies to this system per ADR-0013's own
## Ordering Note ("No ordering constraint exists between BurnoutSystem/
## ChallengeSystem and PrestigeSystem itself").
##
## Story 005 (this revision) implements the Challenge Catalogue (the 5
## designed challenges' static data, verbatim from
## design/quick-specs/challenge-era-runs-2026-07-01.md's Challenge Catalogue
## section) plus selection storage (select_challenges()/
## restore_state()/serialize_state()). ADR-0013's storage correction applies:
## _active_challenge_ids is this Autoload's own field, NOT
## HistoryFlagManager.set_flag()/milestones as the quick-spec originally
## assumed -- HistoryFlagManager's milestone API is a documented one-way
## ratchet with no unset/clear mechanism (flagged during prestige-checkpoint
## Story 007's code review), and era-local challenge selections must clear
## every era (Story 008's job, not this story's).
##
## The catalogue is a plain const Dictionary literal, not a JSON data file --
## no assets/data/ directory exists anywhere in this project yet, and every
## other ADR-described "should be a data file eventually" tuning table already
## shipped as a const (BurnoutSystem's BURNOUT_THRESHOLD, ClassPathSystem's
## _INVESTMENT_RATE_TABLE, PrestigeFormulas' BASE_INCREMENT) -- this follows
## that same already-shipped pattern (docs/tech-debt-register.md tracks the
## project-wide extraction-to-real-data-file item; not yet scheduled).
##
## The following remain intentionally out of this story's scope, for later
## stories in this epic:
##   - Story 006: applying the stored challenges' modifiers at reward resolution
##   - Story 007: reading the combined meta-bonus multiplier
##   - Story 008: clearing _active_challenge_ids on era transition
##   - The Challenge Selection UI screen itself (future UI story)
##
## Usage example:
##   ChallengeSystem.select_challenges([&"brak_duszy", &"bez_tlumu"])
##   ChallengeSystem.get_challenge_data(&"brak_duszy")["modifier_value"]  # -> 0.3
extends Node

## Maximum simultaneous active challenges (quick-spec §4.4: "no hard cap... but
## balance.json should define CHALLENGE_MAX_ACTIVE (default: 3)"). Plain const
## per this file's header comment -- no balance.json exists yet in this
## project.
const CHALLENGE_MAX_ACTIVE: int = 3

## Hard floor applied to get_modifier()'s stacked product (quick-spec §6 /
## Formulas table, "safety" category) -- prevents a misconfigured catalogue
## entry (modifier_value == 0.0) from ever zeroing a reward outright. Plain
## const per this file's header comment -- no balance.json exists yet in this
## project.
const CHALLENGE_MODIFIER_FLOOR: float = 0.05

## The 5 designed challenges (design/quick-specs/challenge-era-runs-2026-07-01.md,
## "Challenge Catalogue (5 Designed Examples)" section), field values
## reproduced verbatim from that section's per-challenge tables -- not
## approximated. `applies_to` is either an Array[StringName] of affected
## action ids, or the literal String "all" (bez_tlumu only, per its own table
## row) meaning every base action -- callers reading this field must handle
## both shapes; Story 006 (modifier application) owns interpreting it, this
## story only stores it faithfully.
##
## One correction from the quick-spec's own literal text (found+fixed during
## Story 006's implementation, 2026-07-20): `przepros_na_niby` and
## `wypalony_ale_core` both target the quick-spec's `przepros_w_internecie`
## action id, but the real, already-shipped `ActionSystem.ACTION_REWARDS` key
## is `przeprosiny` (action-system epic, Complete) -- same "the quick-spec is
## the stale artifact, not the shipped code" precedent ADR-0013 itself already
## established for other terminology drift in these same quick-specs (its own
## "GDD SYNC REQUIRED" section). Left uncorrected, these two challenges'
## modifiers would silently never match any real action id and never apply in
## actual gameplay -- `get_modifier()`'s Array.has() check would always miss.
const _CHALLENGE_CATALOGUE: Dictionary[StringName, Dictionary] = {
	&"brak_duszy": {
		"id": &"brak_duszy",
		"name": "Influencer bez duszy",
		"modifier_type": &"reach_multiplier",
		"modifier_value": 0.3,
		"applies_to": [&"nagraj_vloga"],
		"meta_bonus_multiplier": 2.0,
	},
	&"drama_bez_granic": {
		"id": &"drama_bez_granic",
		"name": "Drama queen bez granic",
		"modifier_type": &"cringe_multiplier",
		"modifier_value": 2.0,
		"applies_to": [&"zrob_drame"],
		"meta_bonus_multiplier": 2.5,
	},
	&"przepros_na_niby": {
		"id": &"przepros_na_niby",
		"name": "Przeproś, ale nie za bardzo",
		"modifier_type": &"cringe_multiplier",
		"modifier_value": 0.3,
		"applies_to": [&"przeprosiny"],
		"meta_bonus_multiplier": 1.8,
	},
	&"bez_tlumu": {
		"id": &"bez_tlumu",
		"name": "Bez tłumu nie ma show",
		"modifier_type": &"reach_multiplier",
		"modifier_value": 0.5,
		"applies_to": "all",
		"meta_bonus_multiplier": 3.0,
	},
	&"wypalony_ale_core": {
		"id": &"wypalony_ale_core",
		"name": "Wypalony, ale core",
		"modifier_type": &"morale_multiplier",
		"modifier_value": 0.6,
		"applies_to": [&"przeprosiny"],
		"meta_bonus_multiplier": 2.0,
	},
}

## The player's currently selected challenge ids for this era, in selection
## order. Empty means "normal run, no challenges active" -- the safe default
## every save (including saves that predate this system) restores to.
## Persisted via serialize_state()/restore_state() -- Story 005.
var _active_challenge_ids: Array[StringName] = []


## Returns [param challenge_id]'s static catalogue entry (modifier_type/
## modifier_value/applies_to/meta_bonus_multiplier/name/id), or an empty
## Dictionary if the id is not one of the 5 designed challenges. Callers
## should treat an empty return as "unknown challenge id", not crash on a
## missing key.
func get_challenge_data(challenge_id: StringName) -> Dictionary:
	return _CHALLENGE_CATALOGUE.get(challenge_id, {})


## Sets the active challenge selection for this era, replacing any prior
## selection. Rejects (returns false, leaves _active_challenge_ids completely
## unchanged -- not partially updated) if [param challenge_ids] exceeds
## CHALLENGE_MAX_ACTIVE. Does not validate that each id is a real catalogue
## entry -- the Challenge Selection UI screen (future story) is expected to
## only ever offer real catalogue ids; this method's contract is purely about
## the count cap, per this story's own ACs.
##
## Example:
##   ChallengeSystem.select_challenges([&"brak_duszy", &"bez_tlumu"])  # -> true
func select_challenges(challenge_ids: Array[StringName]) -> bool:
	if challenge_ids.size() > CHALLENGE_MAX_ACTIVE:
		return false
	_active_challenge_ids = challenge_ids.duplicate()
	return true


## Returns a copy of the currently active challenge ids, in selection order.
## Empty means no challenges active this era. Returns a duplicate, not the
## live internal array -- unlike CardContentDatabase's CARDS (a const table),
## _active_challenge_ids is mutable instance state guarded by
## CHALLENGE_MAX_ACTIVE, so callers must not be able to mutate it in place and
## silently bypass that cap.
func get_active_challenge_ids() -> Array[StringName]:
	return _active_challenge_ids.duplicate()


## Restores persisted state per the ADR-0003 boot protocol. A missing
## "_active_challenge_ids" key (or any save that predates this system)
## defaults safely to an empty array -- same default-on-missing-key pattern as
## every other Autoload in this project (PrestigeSystem.restore_state(),
## ADR-0012 §6 precedent). Order is preserved -- the input array's element
## order becomes the restored array's element order, unchanged.
##
## Example:
##   ChallengeSystem.restore_state(data.get("challenge", {}))
func restore_state(data: Dictionary) -> void:
	var ids_in: Array = data.get("_active_challenge_ids", [])
	_active_challenge_ids.clear()
	for id_str: String in ids_in:
		_active_challenge_ids.append(StringName(id_str))


## Story 006 (TR-pcs-007, ADR-0013's get_modifier() pseudocode -- implemented
## exactly as written, no deviation): returns the combined multiplicative
## modifier every active challenge applies to [param action_id] on
## [param axis] (one of &"reach_multiplier"/&"cringe_multiplier"/
## &"morale_multiplier", matching a catalogue entry's own "modifier_type"
## field). Pure function of _active_challenge_ids + the catalogue -- no side
## effects, no ResourceManager/other Autoload reads (Control Manifest
## guardrail, this story's Context section).
##
## Stacking (quick-spec §4): multiple active challenges targeting the same
## (action_id, axis) pair multiply together, not add or override -- two 0.5x
## Reach modifiers on the same action combine to 0.25x, matching AC-3's own
## worked example.
##
## The "all" sentinel (bez_tlumu's own catalogue entry): applies_to may be
## either an Array[StringName] of specific action ids, or the literal String
## "all" meaning every base action -- checked explicitly before the Array
## cast, since casting "all" (a String) to Array would be a type error, not a
## silent false.
##
## Returns exactly 1.0 (a true no-op multiply, not a missing-key error) when
## no active challenge targets this (action_id, axis) pair at all -- including
## when _active_challenge_ids is empty (no challenges active this era).
##
## Always clamped to at least CHALLENGE_MODIFIER_FLOOR via maxf() -- even a
## product that computes to exactly 0.0 (a hypothetically misconfigured
## catalogue entry) never reaches a caller as a true zero.
##
## Example:
##   ChallengeSystem.get_modifier(&"nagraj_vloga", &"reach_multiplier")  # -> 0.3 if brak_duszy active, else 1.0
##
## Deviation from ADR-0013's literal pseudocode (found+fixed 2026-07-20, same
## behavior/outcome, different implementation): the ADR's own text is
## `if applies_to != "all" and not (applies_to as Array).has(action_id):`,
## but Godot 4 GDScript throws a runtime error ("Invalid operands 'Array' and
## 'String' in operator '!='") when applies_to holds an Array and is compared
## against the String "all" with `!=` -- unlike Python/JS, GDScript's `!=`
## does not gracefully fall back to "different types, so not equal" for
## Array-vs-String. Rewritten as an explicit `is Array` type check instead,
## which sidesteps the illegal cross-type comparison entirely while producing
## the identical pass/skip decision for both applies_to shapes.
func get_modifier(action_id: StringName, axis: StringName) -> float:
	var product: float = 1.0
	for challenge_id: StringName in _active_challenge_ids:
		var entry: Dictionary = _CHALLENGE_CATALOGUE[challenge_id]
		if entry["modifier_type"] != axis:
			continue
		var applies_to: Variant = entry["applies_to"]
		if applies_to is Array and not (applies_to as Array).has(action_id):
			continue
		product *= entry["modifier_value"]
	return maxf(CHALLENGE_MODIFIER_FLOOR, product)


## Serializes persisted state for SaveSystem.save_now(). StringName ids are
## written out as plain String (JSON-serialization convention already
## established by ADR-0002/ADR-0010 and PrestigeSystem.serialize_state() --
## StringName is not a JSON type).
##
## Example:
##   var data: Dictionary = ChallengeSystem.serialize_state()
func serialize_state() -> Dictionary:
	var ids_out: Array[String] = []
	for id: StringName in _active_challenge_ids:
		ids_out.append(String(id))
	return {"_active_challenge_ids": ids_out}
