## ActionScreen-scoped ambient resource ticker.
##
## Frame deltas are accumulated into fixed one-second logical steps. The node
## exists only as a direct child of ActionScreen, so boot, offline report, start,
## and challenge-selection scenes cannot accidentally accrue live resources.
## A frame hitch may execute several logical steps, but their resource changes
## are committed as one ambient batch to avoid signal and save-write spam.
class_name LiveResourceTicker
extends Node

## Explicit preload keeps headless first-run parsing independent of the editor's
## global class cache after adding ResourceSimulationStep.
const ResourceSimulationStepScript: GDScript = preload(
	"res://src/core/resource_simulation_step.gd"
)

## Logical integration step for active play. Balance formulas remain owned by
## ResourceFormulas/ResourceSimulationStep; this is only cadence.
const LIVE_STEP_SECONDS: float = 1.0
const _ACCUMULATOR_EPSILON: float = 0.0000001

var _accumulator_seconds: float = 0.0


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_accumulator_seconds += delta
	var complete_steps: int = 0
	while _accumulator_seconds + _ACCUMULATOR_EPSILON >= LIVE_STEP_SECONDS:
		_accumulator_seconds -= LIVE_STEP_SECONDS
		complete_steps += 1
	if absf(_accumulator_seconds) <= _ACCUMULATOR_EPSILON:
		_accumulator_seconds = 0.0
	if complete_steps > 0:
		_advance_complete_steps(complete_steps)


## Advances [param step_count] complete live quanta and commits one atomic
## ambient resource batch. Public only as a deterministic test seam; normal
## gameplay reaches it through [_process].
func _advance_complete_steps(step_count: int) -> void:
	if step_count <= 0:
		return
	var cringe: float = ResourceManager.get_resource(&"Cringe")
	var starting_haters: float = ResourceManager.get_resource(&"Haters")
	var starting_morale: float = ResourceManager.get_resource(&"Morale")
	var haters: float = starting_haters
	var morale: float = starting_morale
	var reach_gained: float = 0.0

	for _step_index: int in step_count:
		var step: Dictionary = ResourceSimulationStepScript.compute(
			cringe,
			haters,
			morale,
			LIVE_STEP_SECONDS,
			ResourceManager.get_shield_effective_buffer(),
			ClassPathSystem.get_haters_growth_multiplier() * StaffSystem.get_haters_multiplier(),
			PrestigeSystem.get_meta_bonus_total(&"META_HATERS_RESIST"),
			ClassPathSystem.get_morale_drain_multiplier(),
			ClassPathSystem.get_morale_floor(),
			1.0  # Staff Assistant is deliberately offline-only.
		)
		haters = float(step["final_H"])
		morale = float(step["final_M"])
		reach_gained += float(step["reach_gained"])

	var deltas: Dictionary[StringName, float] = {
		&"Reach": reach_gained,
		&"Haters": haters - starting_haters,
		&"Morale": morale - starting_morale,
	}
	ResourceManager.apply_ambient_delta(deltas)
