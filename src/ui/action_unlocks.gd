## ActionUnlocks is a stateless static utility holding the unlock conditions for
## the 3 milestone/counter-gated Action Grid slots (slots 4-6), per
## design/quick-specs/milestone-gated-action-slots-2026-06-30.md (DDR-0001 #3).
##
## The unlock predicate is a pure function of the player's decision-history
## inputs (risky/safe choice counts + two milestone booleans), so it's headlessly
## unit-testable against the spec's exact thresholds without HistoryFlagManager or
## a scene tree -- same precedent as CardSwipeMath / OfflineReportFormatting.
## ActionGrid is the only caller; it reads the real HistoryFlagManager and feeds
## the results in.
##
## Stateless-only invariant: never add instance vars. The "which slot maps to
## which action_id / button index" wiring lives in ActionGrid, not here -- this
## class owns only the gate logic.
##
## DDR-0001 constraint: every slot is unlockable via EITHER a risky-path OR a
## safe-path condition, so the deliberately-un-punished clean-path player is
## never locked out of action-economy growth (resource-system.md Edge Cases).
class_name ActionUnlocks
extends RefCounted

## The 3 gated action ids, in slot order (Action Grid slots 4, 5, 6 = the 3
## reserved locked slots after the base 3). Index here aligns with the bool
## array returned by [method unlocked_slots].
const GATED_ACTION_IDS: Array[StringName] = [&"nagraj_kolaba", &"udziel_wywiadu", &"wydaj_kurs"]

## Slot 4 (Collab) unlocks at this many risky OR safe choices. GDD tuning knob.
const SLOT_4_COUNTER_THRESHOLD: int = 3
## Slot 5 (Interview) -- escalating threshold. GDD tuning knob.
const SLOT_5_COUNTER_THRESHOLD: int = 6
## Slot 6 (Course) gates on a named defining moment from either path -- the two
## existing milestone-bearing cards, one risky, one safe.
const SLOT_6_MILESTONE_RISKY: StringName = &"card.staged_drama.chosen_risky"
const SLOT_6_MILESTONE_SAFE: StringName = &"card.cancel_threat.apologized"

## Returns a 3-element Array[bool] -- whether gated slot 4, 5, 6 (in that order)
## is unlocked, given the player's decision history. Pure: no Autoload/scene
## access. [param risky_count]/[param safe_count] are the History Flag pattern
## counters; [param has_slot6_risky]/[param has_slot6_safe] are the two slot-6
## milestone booleans. Each slot uses an OR across the two paths.
##
## Usage example:
##   ActionUnlocks.unlocked_slots(3, 0, false, false)  # -> [true, false, false]
static func unlocked_slots(risky_count: int, safe_count: int, has_slot6_risky: bool, has_slot6_safe: bool) -> Array[bool]:
	var result: Array[bool] = [
		risky_count >= SLOT_4_COUNTER_THRESHOLD or safe_count >= SLOT_4_COUNTER_THRESHOLD,
		risky_count >= SLOT_5_COUNTER_THRESHOLD or safe_count >= SLOT_5_COUNTER_THRESHOLD,
		has_slot6_risky or has_slot6_safe,
	]
	return result
