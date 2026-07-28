## ResourceManager owns the five core game currencies and their mutation rules.
##
## Implements ADR-0001's direct-call contract: `apply_delta()` is the sole
## write path for resource mutations. Callers (e.g. ActionSystem,
## DecisionCardSystem) invoke it directly after they complete the action that
## owns the mutation; `resource_changed` is a notification-only signal for
## peer/UI listeners, never the write mechanism itself.
##
## Registered as a Godot Autoload singleton per ADR-0001's boot order
## (position 1 — first to initialize, nothing else depends on Autoloads
## above it).
##
## Initial values: all resources default to 0.0. This story (TR-res-001)
## scopes mutation/clamping only; actual starting-value semantics (e.g.
## Morale starting full) belong to a future restore_state()/boot story per
## ADR-0003 and are NOT decided here.
##
## Usage example:
##   ResourceManager.apply_delta({&"Reach": 25.0, &"Cringe": -10.0})
##   var reach: float = ResourceManager.get_resource(&"Reach")
extends Node

## Resource keys, per the validated vertical-slice prototype
## (prototypes/krol-cringeu-vertical-slice/scripts/autoload/resource_manager.gd).
## English keys are the binding decision for production code — design/gdd and
## design/registry/entities.yaml still show stale Polish-key examples
## (Zasięgi, Hatersi, Sponsorzy) pending a separate doc-sync task.
var _resources: Dictionary[StringName, float] = {
	&"Reach": 0.0,
	&"Cringe": 0.0,
	&"Haters": 0.0,
	&"Morale": 0.0,
	&"Sponsors": 0.0,
}

## Resource keys that are clamped to [0, 100] on every mutation.
## Reach/Haters/Sponsors are intentionally unbounded — see resource-system.md.
const _CLAMPED_KEYS: Array[StringName] = [&"Cringe", &"Morale"]

## Cost in Sponsors to activate the Sponsor Shield. Source: quick-spec
## sponsor-network-shield-2026-06-30.md (DDR-0001 #6).
const SHIELD_COST: int = 5

## Duration added to the shield timer per activation, in seconds. Additive
## stacking: activating while already active extends the remaining time.
const SHIELD_DURATION: float = 300.0

## Bonus added to Formula B's N_buffer while the shield is active. Effective
## buffer = M_BUFFER (3) + SHIELD_BUFFER_BONUS (5) = 8. Source: quick-spec.
const SHIELD_BUFFER_BONUS: int = 5

## Emitted once per key after apply_delta() commits that key's new value.
## Notification only — never the write mechanism itself (ADR-0001).
signal resource_changed(name: StringName, new_value: float, old_value: float)

## Emitted when the shield activates (is_active=true) and when it expires
## (is_active=false). remaining_seconds is the timer value at emission.
## HUD wires to this for the countdown indicator (separate UI story).
signal shield_changed(is_active: bool, remaining_seconds: float)

## Seconds remaining on the active shield. 0.0 = inactive. Ticked down in
## _process(); never goes negative. Persisted via serialize_state().
var _shield_remaining_seconds: float = 0.0

## Ticks the shield timer down by [param delta] seconds. Emits
## shield_changed(false, 0.0) exactly once on the frame the timer hits 0.
func _process(delta: float) -> void:
	if _shield_remaining_seconds <= 0.0:
		return
	_shield_remaining_seconds = maxf(0.0, _shield_remaining_seconds - delta)
	if _shield_remaining_seconds == 0.0:
		shield_changed.emit(false, 0.0)


## Spends SHIELD_COST Sponsors to add SHIELD_DURATION seconds to the shield
## timer. Returns true if the cost was paid; false if Sponsors < SHIELD_COST
## (no mutation on rejection). If the shield was already inactive and this
## activation succeeds, emits shield_changed(true, new_remaining). If already
## active, stacks duration (no signal — caller can read _shield_remaining_seconds
## directly for display).
##
## Example:
##   var ok: bool = ResourceManager.activate_sponsor_shield()
func activate_sponsor_shield() -> bool:
	if _resources.get(&"Sponsors", 0.0) < float(SHIELD_COST):
		return false
	var was_inactive: bool = _shield_remaining_seconds <= 0.0
	apply_delta({&"Sponsors": -float(SHIELD_COST)})
	_shield_remaining_seconds += SHIELD_DURATION
	if was_inactive:
		shield_changed.emit(true, _shield_remaining_seconds)
	return true


## Returns the effective N_buffer for Formula B (morale_drain_rate()). While
## the shield is active this is M_BUFFER + SHIELD_BUFFER_BONUS (= 8); when
## inactive it equals ResourceFormulas.M_BUFFER (= 3), the default constant.
## Offline Progress System and any live-drain caller use this instead of
## the raw M_BUFFER constant.
##
## Example:
##   var buf: int = ResourceManager.get_shield_effective_buffer()
func get_shield_effective_buffer() -> int:
	if _shield_remaining_seconds > 0.0:
		return ResourceFormulas.M_BUFFER + SHIELD_BUFFER_BONUS
	return ResourceFormulas.M_BUFFER


## Returns the shield timer's remaining seconds (0.0 = inactive). Read-only
## accessor for callers that need to snapshot shield state (e.g. OfflineProgressSystem)
## without coupling to the private field name.
func get_shield_remaining_seconds() -> float:
	return _shield_remaining_seconds


## Returns the current value of [param name], or 0.0 if the key is unknown.
##
## Example:
##   var morale: float = ResourceManager.get_resource(&"Morale")
func get_resource(name: StringName) -> float:
	return _resources.get(name, 0.0)

## Applies one or more resource deltas atomically (within this single call —
## no intermediate observable partial state, no async/deferred write path).
##
## For each key in [param deltas]: new_value = old_value + deltas[key].
## Cringe and Morale are clamped to [0, 100]; all other keys are unbounded.
## NOTE (tier-fill 2026-07-28): ekspert T5's Morale floor deliberately does
## NOT hook this clamp — a live-path floor here would make any Morale spend
## (ekspert's own invest() resource!) free once at the floor: deduct, clamp
## back up, affiliation still gained. The floor is an AMBIENT-drain shield
## ("cult immune to hate") and lives only in OfflineProgressSystem's drain
## loop, the sole ambient Morale-drain site in the game.
## Emits resource_changed once per key, after that key's value is committed.
##
## Example:
##   ResourceManager.apply_delta({&"Reach": 25.0, &"Cringe": -10.0, &"Morale": 5.0})
func apply_delta(deltas: Dictionary[StringName, float]) -> void:
	for key in deltas:
		var old_value: float = _resources.get(key, 0.0)
		var new_value: float = old_value + deltas[key]
		if key in _CLAMPED_KEYS:
			new_value = clamp(new_value, 0.0, 100.0)
		_resources[key] = new_value
		resource_changed.emit(key, new_value, old_value)
	if not deltas.is_empty():
		SaveSystem.mark_dirty()


## Returns this module's persisted state as a JSON-serializable `Dictionary`
## (plain `String` keys, per `JSON.stringify()`'s requirements — `StringName`
## is not a JSON type). Read by `SaveSystem.save_now()` (ADR-0002).
##
## Example:
##   var snapshot: Dictionary = ResourceManager.serialize_state()
func serialize_state() -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in _resources:
		result[String(key)] = _resources[key]
	result["shield_remaining_seconds"] = _shield_remaining_seconds
	return result


## Restores this module's state from [param data] (as produced by
## [method serialize_state]). Missing keys default safely — an empty
## [param data] (`{}`, the first-session case) leaves every resource at its
## existing default (`0.0`), per ADR-0003's `restore_state()` contract.
## Called by `SaveSystem.load_save()` at boot, before `ready`.
##
## Example:
##   ResourceManager.restore_state({"Reach": 25.0, "Cringe": 10.0})
func restore_state(data: Dictionary) -> void:
	for key: String in data:
		if key == "shield_remaining_seconds":
			_shield_remaining_seconds = float(data[key])
			continue
		_resources[StringName(key)] = float(data[key])
