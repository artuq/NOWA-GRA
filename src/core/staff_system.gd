## StaffSystem owns the player's hired team: era-local `staff_count` per role
## (Troll / Assistant / Sponsor Manager) and the pull-model multipliers those
## counts produce (design/gdd/team-staff-management.md).
##
## Three roles, three different effects (Core Rule 1 — game-concept.md's
## "trolle/asystenci/sponsorzy"):
## - Troll — multiplies the Haters growth RATE (satire: paid troll accounts
##   manufacture controversy). Composes into F3c alongside META_HATERS_RESIST.
## - Assistant — multiplies OFFLINE progress rate only (Pillar 4). Has no
##   effect during live play, by design (Core Rule 6).
## - Sponsor Manager — multiplies the Sponsors AMOUNT a qualifying card
##   grants (Core Rule 1's explicit scope lock: never the card's draw weight,
##   which would be a runaway feedback loop).
##
## Era-local (Core Rule 2): every count resets to zero on an accepted
## Wypalenie, exactly like Class Path affiliation — staff is part of what the
## burnout costs, not an exception to it. META_BONUS remains the only state
## that survives.
##
## Pull model throughout (ADR-0010's established direction): this module never
## calls into its consumers. DecisionCardSystem reads
## get_sponsor_multiplier() at card resolution, OfflineProgressSystem reads
## get_offline_rate_multiplier() inside simulate_offline(), and both
## OfflineProgressSystem and LiveResourceTicker read get_haters_multiplier().
## PrestigeSystem calls reset_era_state() during its
## era sweep.
##
## Usage example:
##   if StaffSystem.hire(&"troll"):
##       print(StaffSystem.get_staff_count(&"troll"))
extends Node

## The three hireable roles, in fixed display order.
const ROLES: Array[StringName] = [&"troll", &"assistant", &"sponsor_manager"]

## F1 asymptotic ceilings — the multiplier approaches but never reaches these
## (GDD Formula 1 Defaults). Tuning knobs.
const MAX_MULTIPLIER: Dictionary[StringName, float] = {
	&"troll": 2.5,
	&"assistant": 2.0,
	&"sponsor_manager": 2.0,
}

## F1 half-points: hire count at which the multiplier reaches half its total
## bonus range (GDD Formula 1 Defaults). Tuning knobs.
const STAFF_HALF_POINT: Dictionary[StringName, float] = {
	&"troll": 4.0,
	&"assistant": 5.0,
	&"sponsor_manager": 4.0,
}

## F2 first-hire costs in Sponsors (GDD Formula 2 Defaults). Tuning knobs.
const HIRE_BASE_COST: Dictionary[StringName, float] = {
	&"troll": 4.0,
	&"assistant": 5.0,
	&"sponsor_manager": 6.0,
}

## F2 per-hire geometric growth (GDD Formula 2 Defaults). sponsor_manager
## grows fastest, deliberately dampening its own income loop (Core Rule 1).
const HIRE_COST_GROWTH: Dictionary[StringName, float] = {
	&"troll": 1.6,
	&"assistant": 1.6,
	&"sponsor_manager": 1.7,
}

## Emitted after a successful hire, with the role and its new count. UI-only
## notification (same contract as ClassPathSystem.tier_unlocked) — no consumer
## is required to react.
signal staff_hired(role: StringName, new_count: int)

## Emitted when era reset clears every count (accepted Wypalenie).
signal staff_reset()

## Era-local hire counts. Absent key = 0 (see get_staff_count).
var _staff_count: Dictionary[StringName, int] = {}


## F1 — staff effect multiplier: `1.0 + (MAX - 1.0) * n / (n + HALF)`.
## Rectangular hyperbola: exactly 1.0 at n=0, hits the midpoint of its bonus
## range at n == STAFF_HALF_POINT, converges on (never reaches) MAX.
## Static + fully argument-driven so tests and balance passes can evaluate the
## curve without touching live state.
static func staff_multiplier(role: StringName, n: int) -> float:
	var ceiling: float = MAX_MULTIPLIER.get(role, 1.0)
	var half_point: float = STAFF_HALF_POINT.get(role, 1.0)
	if n <= 0 or ceiling <= 1.0:
		return 1.0
	return 1.0 + (ceiling - 1.0) * (float(n) / (float(n) + half_point))


## F2 — cost of hiring the (n+1)-th member of [param role]:
## `BASE * GROWTH^n`, returned as an int via the GDD's LOCKED ceil() rule
## (Sponsors is an integer currency elsewhere; never round down — that would
## let a player underpay on a rounding edge).
static func hire_cost(role: StringName, n: int) -> int:
	var base: float = HIRE_BASE_COST.get(role, 0.0)
	var growth: float = HIRE_COST_GROWTH.get(role, 1.0)
	if base <= 0.0:
		return 0
	return int(ceil(base * pow(growth, float(max(n, 0)))))


## Current era-local count for [param role], 0 if never hired. Pure read.
func get_staff_count(role: StringName) -> int:
	return _staff_count.get(role, 0)


## Sponsors cost of the NEXT hire for [param role] (the (n+1)-th). Pure read —
## the UI renders this and the affordability gate below uses it.
func get_next_hire_cost(role: StringName) -> int:
	return hire_cost(role, get_staff_count(role))


## Whether the player can currently afford the next hire of [param role].
## Pure read; hire() re-checks independently (never trusts a stale UI state).
func can_hire(role: StringName) -> bool:
	if not MAX_MULTIPLIER.has(role):
		return false
	return ResourceManager.get_resource(&"Sponsors") >= float(get_next_hire_cost(role))


## Hires one member of [param role]: deducts the F2 cost in Sponsors and
## increments the era-local count. Instant, no duration (Core Rule 7).
## Returns false with NO side effects for an unknown role or insufficient
## Sponsors — same reject-cleanly contract as ClassPathSystem.invest().
##
## Example:
##   if StaffSystem.hire(&"assistant"):
##       ...
func hire(role: StringName) -> bool:
	if not MAX_MULTIPLIER.has(role):
		return false
	var cost: int = get_next_hire_cost(role)
	if ResourceManager.get_resource(&"Sponsors") < float(cost):
		return false
	var deltas: Dictionary[StringName, float] = {&"Sponsors": -float(cost)}
	ResourceManager.apply_delta(deltas)
	_staff_count[role] = get_staff_count(role) + 1
	staff_hired.emit(role, _staff_count[role])
	return true


## Troll multiplier for the Haters growth rate (F3:
## `H_rate_final = H_rate(C) * staff_multiplier(troll, n) * (1 - META_HATERS_RESIST)`).
## Consumed by both OfflineProgressSystem and LiveResourceTicker so the Troll
## affects ambient Haters growth consistently online and offline.
func get_haters_multiplier() -> float:
	return staff_multiplier(&"troll", get_staff_count(&"troll"))


## Assistant multiplier on offline progress rate (Core Rule 6 — offline only,
## deliberately no live-play effect). Consumed inside simulate_offline().
func get_offline_rate_multiplier() -> float:
	return staff_multiplier(&"assistant", get_staff_count(&"assistant"))


## Sponsor Manager multiplier on the Sponsors AMOUNT a qualifying card grants
## (F3b). Scope-locked by Core Rule 1: never applied to card draw weight.
func get_sponsor_multiplier() -> float:
	return staff_multiplier(&"sponsor_manager", get_staff_count(&"sponsor_manager"))


## Clears every era-local count (accepted Wypalenie). Called by
## PrestigeSystem's era sweep, mirroring ClassPathSystem.reset_era_state().
## Emits staff_reset only when something actually changed.
func reset_era_state() -> void:
	if _staff_count.is_empty():
		return
	_staff_count.clear()
	staff_reset.emit()


## Restores persisted counts from [param data] (the "staff" sub-dict, or {} on
## a first session / a save predating this module) — ADR-0003's restore_state
## contract: missing keys default to zero state, never crashes.
func restore_state(data: Dictionary) -> void:
	_staff_count.clear()
	var counts: Dictionary = data.get("staff_count", {})
	for key: String in counts:
		_staff_count[StringName(key)] = int(counts[key])


## JSON-serializable state (plain String keys — StringName is not a JSON
## type), matching every peer module's convention. Read by SaveSystem.
func serialize_state() -> Dictionary:
	var out: Dictionary = {}
	for role: StringName in _staff_count:
		out[String(role)] = _staff_count[role]
	return {"staff_count": out}
