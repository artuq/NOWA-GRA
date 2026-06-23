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

## Emitted once per key after apply_delta() commits that key's new value.
## Notification only — never the write mechanism itself (ADR-0001).
signal resource_changed(name: StringName, new_value: float, old_value: float)

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
