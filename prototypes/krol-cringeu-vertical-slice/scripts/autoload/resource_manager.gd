# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the core fantasy within 3-5 min, unguided?
# Date: 2026-06-20
#
# Implements ADR-0001's ResourceManager contract: owns the 5 currencies, clamps
# Cringe/Morale to [0,100] internally. Slice scope: in-memory only, no save/load.
extends Node

var _resources: Dictionary = {
	&"Reach": 0.0,
	&"Cringe": 0.0,
	&"Haters": 0.0,
	&"Morale": 70.0,
	&"Sponsors": 0.0,
}

signal resource_changed(name: StringName, new_value: float, old_value: float)

func get_resource(name: StringName) -> float:
	return _resources.get(name, 0.0)

func apply_delta(deltas: Dictionary) -> void:
	for key in deltas:
		var old_value: float = _resources.get(key, 0.0)
		var new_value: float = old_value + deltas[key]
		if key == &"Cringe" or key == &"Morale":
			new_value = clamp(new_value, 0.0, 100.0)
		_resources[key] = new_value
		resource_changed.emit(key, new_value, old_value)

func get_morale_band() -> String:
	var m := get_resource(&"Morale")
	if m >= 70.0:
		return "High"
	elif m >= 40.0:
		return "Normal"
	elif m >= 15.0:
		return "Low"
	else:
		return "Critical"
