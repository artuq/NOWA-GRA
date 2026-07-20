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

## The 5 designed challenges (design/quick-specs/challenge-era-runs-2026-07-01.md,
## "Challenge Catalogue (5 Designed Examples)" section), field values
## reproduced verbatim from that section's per-challenge tables -- not
## approximated. `applies_to` is either an Array[StringName] of affected
## action ids, or the literal String "all" (bez_tlumu only, per its own table
## row) meaning every base action -- callers reading this field must handle
## both shapes; Story 006 (modifier application) owns interpreting it, this
## story only stores it faithfully.
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
		"applies_to": [&"przepros_w_internecie"],
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
		"applies_to": [&"przepros_w_internecie"],
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
