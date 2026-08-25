## Stateless transition shared by live and offline ambient resource progress.
##
## The sequencing is part of the gameplay contract: Haters grow first,
## Morale drains from the post-growth Haters value, the effectiveness band is
## selected from post-drain Morale, and passive Reach uses both updated values.
## This class owns no state and never reads Autoloads, so each caller must pass
## its context explicitly (ADR-0006, live-resource-loop quick spec 2026-08-05).
class_name ResourceSimulationStep
extends RefCounted


## Advances one ambient simulation interval and returns
## `{final_H, final_M, reach_gained}` as unrounded floats.
##
## [param morale_floor] protects only against ambient drain. If Morale already
## starts below the configured floor, the effective floor becomes the starting
## value for this step, preventing both further drain and a free heal.
static func compute(
		cringe: float,
		haters: float,
		morale: float,
		elapsed_seconds: float,
		effective_buffer: int = ResourceFormulas.M_BUFFER,
		haters_multiplier: float = 1.0,
		meta_haters_resist: float = 0.0,
		morale_drain_multiplier: float = 1.0,
		morale_floor: float = 0.0,
		passive_income_multiplier: float = 1.0) -> Dictionary:
	var dt_seconds: float = maxf(0.0, elapsed_seconds)
	if dt_seconds == 0.0:
		return {
			"final_H": haters,
			"final_M": morale,
			"reach_gained": 0.0,
		}

	var dt_minutes: float = dt_seconds / 60.0
	var base_haters_rate: float = ResourceFormulas.haters_growth_rate(cringe)
	var final_haters_rate: float = PrestigeFormulas.haters_rate_final(
		base_haters_rate, meta_haters_resist
	) * haters_multiplier
	var final_haters: float = haters + final_haters_rate * dt_minutes

	var drain_rate: float = ResourceFormulas.morale_drain_rate(
		int(final_haters), effective_buffer
	) * morale_drain_multiplier
	var effective_floor: float = maxf(0.0, minf(morale_floor, morale))
	var final_morale: float = maxf(
		effective_floor, morale - drain_rate * dt_minutes
	)

	var morale_multiplier: float = ResourceFormulas.action_effectiveness_multiplier(final_morale)
	var reach_gained: float = ResourceFormulas.passive_zasiegi_income(
		final_haters, morale_multiplier, dt_seconds
	) * passive_income_multiplier

	return {
		"final_H": final_haters,
		"final_M": final_morale,
		"reach_gained": reach_gained,
	}
