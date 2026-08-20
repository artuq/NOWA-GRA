## OfflineProgressSystem owns the stepped offline-time simulation: re-derives
## Hatersi growth, Morale drain, and passive Reach/Zasięgi income for an
## elapsed offline duration, using the same ResourceSimulationStep consumed by
## active play's LiveResourceTicker so sequencing and modifier composition
## cannot drift between contexts (ADR-0006, TR-off-001).
##
## Implements ADR-0006: a single synchronous `while` loop over fixed
## 60-second steps, capped at 1440 iterations (24h = MAX_OFFLINE_CAP_SECONDS).
## No threading -- the worst case (1440 simple arithmetic iterations) is
## sub-millisecond, confirmed in ADR-0006's Performance Implications.
##
## Step order is fixed and never reordered: Hatersi, then Morale, then the
## effectiveness multiplier, then Zasięgi -- per offline-progress-system.md's
## Core Rules and ADR-0006's Decision.
##
## Registered as a Godot Autoload singleton per ADR-0001's boot order, after
## ResourceManager (this system reads ResourceManager's current state at the
## start of each simulate_offline() call).
##
## Scope note (TR-off-002, launch-time boot wiring, is explicitly NOT this
## story's scope -- BootController/Main scene/Offline Report Screen don't
## exist yet; see story-001-stepped-offline-simulation.md's Out of Scope).
## This Autoload currently has no caller in production code; it is exercised
## directly by tests until a future Boot epic wires it in.
##
## Re-entrancy note: the GDD's acceptance criteria included a guard against
## "a second app-start event firing before simulate_offline() completes" --
## dropped from this story's scope (see story's Implementation Notes) since
## ADR-0003's boot model makes this structurally unreachable: BootController's
## _ready() can only fire once per process, and this loop is synchronous and
## sub-millisecond, leaving no window for a second invocation to race against.
##
## Usage example:
##   var result: Dictionary = OfflineProgressSystem.simulate_offline(86400)
##   # result == {"final_H": ..., "final_M": ..., "total_Z_gained": ..., "capped": false}
extends Node

## Explicit preload keeps headless first-run parsing independent of the editor's
## global class cache after adding ResourceSimulationStep.
const ResourceSimulationStepScript: GDScript = preload(
	"res://src/core/resource_simulation_step.gd"
)

## Maximum offline duration simulated, in seconds (24 hours). Elapsed time
## beyond this is discarded, not rolled over to a future call.
const MAX_OFFLINE_CAP_SECONDS: int = 86400

## Minimum elapsed time (seconds) for the Offline Report Screen to appear,
## per offline-report-screen.md's threshold gate (GDD tuning knob: 300s/5min,
## safe range 60-900). Below this, BootController routes straight to the main
## scene with no report -- a short app-switch isn't worth an anticlimactic
## "+2 Reach" interruption. The gate check itself runs in BootController
## (ADR-0009 §5); this constant is just the tuning-knob home, mirroring
## MAX_OFFLINE_CAP_SECONDS above.
const MIN_REPORT_THRESHOLD_SECONDS: int = 300

## Fixed simulation step size, in seconds. The final step of a run may be
## shorter than this (a partial step) when the remaining duration doesn't
## divide evenly.
const OFFLINE_STEP_SECONDS: int = 60

## The most recent simulate_offline() result. Transient -- never serialized
## by SaveSystem, read-once by a future Offline Report Screen (ADR-0003).
var last_simulation_result: Dictionary = {}

## Simulates [param elapsed_seconds] of offline time in fixed 60-second steps,
## capped at MAX_OFFLINE_CAP_SECONDS (24h), per ADR-0006's Decision.
##
## Reads Cringe, Haters, and Morale from ResourceManager once, at the start
## of the call -- Cringe is held fixed for the entire simulation (per
## resource-system.md's Cringe_fixed parameter: Cringe only changes via
## active actions/cards, never while offline). Haters and Morale evolve
## step-by-step inside the loop using the already-locked formulas in
## ResourceFormulas (Resource System epic, Complete) -- this function does
## not duplicate that math, it only sequences it.
##
## Each step applies, in this fixed order (never reordered): Hatersi growth,
## then Morale drain (floored at 0), then the effectiveness multiplier looked
## up from the *post-update* Morale, then Zasięgi/Reach income accrued using
## the *post-update* Hatersi and the multiplier just computed.
##
## This function does not write back to ResourceManager -- it returns the
## simulation result for the caller (a future BootController) to apply.
## Returning rather than writing keeps this function a pure, easily-testable
## simulation: call it directly with any elapsed_seconds and assert on the
## returned Dictionary, no scene tree or ResourceManager-mutation side
## effects to set up or tear down between test cases.
##
## Returns a Dictionary shaped {final_H: float, final_M: float,
## total_Z_gained: float, capped: bool} -- the exact shape ADR-0003's
## BootController integration expects.
##
## Usage example:
##   var result: Dictionary = OfflineProgressSystem.simulate_offline(86400)
##   var final_haters: float = result["final_H"]
func simulate_offline(elapsed_seconds: int) -> Dictionary:
	var result: Dictionary = simulate_from_context(capture_context(), elapsed_seconds)
	last_simulation_result = result
	return result


func capture_context() -> Dictionary:
	var morale: float = ResourceManager.get_resource(&"Morale")
	return {
		"Reach": ResourceManager.get_resource(&"Reach"),
		"Cringe": ResourceManager.get_resource(&"Cringe"),
		"Haters": ResourceManager.get_resource(&"Haters"),
		"Morale": morale,
		"Sponsors": ResourceManager.get_resource(&"Sponsors"),
		"shield_seconds": maxi(0, int(ResourceManager.get_shield_remaining_seconds())),
		"shield_buffer": ResourceManager.get_shield_effective_buffer(),
		"base_buffer": ResourceFormulas.M_BUFFER,
		"haters_multiplier": ClassPathSystem.get_haters_growth_multiplier() * StaffSystem.get_haters_multiplier(),
		"meta_haters_resist": PrestigeSystem.get_meta_bonus_total(&"META_HATERS_RESIST"),
		"assistant_multiplier": StaffSystem.get_offline_rate_multiplier(),
		"morale_drain_multiplier": ClassPathSystem.get_morale_drain_multiplier(),
		"morale_floor": maxf(0.0, minf(ClassPathSystem.get_morale_floor(), morale)),
		"sponsor_income_multiplier": ClassPathSystem.get_sponsor_income_multiplier(),
		"meta_sponsor_bonus": PrestigeSystem.get_meta_bonus_total(&"META_SPONSOR_MULT"),
	}


func is_valid_context(context: Dictionary) -> bool:
	for key: String in ["Reach", "Cringe", "Haters", "Morale", "Sponsors", "shield_seconds", "shield_buffer", "base_buffer", "haters_multiplier", "meta_haters_resist", "assistant_multiplier", "morale_drain_multiplier", "morale_floor", "sponsor_income_multiplier", "meta_sponsor_bonus"]:
		if not context.has(key) or not is_finite(float(context[key])):
			return false
	return float(context["Reach"]) >= 0.0 and float(context["Haters"]) >= 0.0 \
		and float(context["Sponsors"]) >= 0.0 and float(context["Morale"]) >= 0.0


func simulate_from_context(context: Dictionary, elapsed_seconds: int) -> Dictionary:
	if not is_valid_context(context):
		return {}
	var safe_elapsed: int = maxi(0, elapsed_seconds)
	var capped: bool = safe_elapsed > MAX_OFFLINE_CAP_SECONDS
	var remaining: int = mini(safe_elapsed, MAX_OFFLINE_CAP_SECONDS)
	var cringe_fixed: float = float(context["Cringe"])
	var h: float = float(context["Haters"])
	var m: float = float(context["Morale"])
	var z_gained: float = 0.0

	# Sponsor Shield: if active at sim start, first N seconds use the elevated
	# buffer (shield segment), remainder uses the base M_BUFFER. This is a
	# 2-segment approximation — per quick-spec sponsor-network-shield-2026-06-30.md
	# (DDR-0001 #6). Shield state is read once at sim start (snapshot), not
	# per-tick — avoids branching inside the 1440-iteration worst-case loop.
	var shield_seconds: int = clampi(int(context["shield_seconds"]), 0, remaining)
	var segments: Array[Dictionary] = [
		{"seconds": shield_seconds, "buffer": int(context["shield_buffer"])},
		{"seconds": remaining - shield_seconds, "buffer": int(context["base_buffer"])},
	]

	# Class path tier effects (tier-fill 2026-07-28, ADR-0010 pull model),
	# snapshotted ONCE at sim start like the shield above — Pillar 4: the
	# active path's ambient bonuses (ekspert T1 drain ×0.8, ekspert T5
	# haters ×0.5 + Morale floor 40) apply offline exactly as they do live,
	# same online+offline precedent as META_HATERS_RESIST (prestige GDD,
	# locked 2026-07-12). All three default to neutral with no active path,
	# leaving the sim byte-identical to its pre-tier-fill behavior.
	# Staff effects (team-staff-management.md, snapshotted once like the rest):
	# Troll multiplies the Haters growth rate (F3), Assistant multiplies the
	# offline income rate (Core Rule 6 — offline only, no live-play effect).
	var haters_mult: float = float(context["haters_multiplier"])
	# F3c is permanent and cannot change during an offline window, so snapshot
	# it once alongside the other pull-model factors. The governing helper is
	# shared with the live tick to preserve online/offline parity.
	var meta_haters_resist: float = float(context["meta_haters_resist"])
	var assistant_mult: float = float(context["assistant_multiplier"])
	var drain_mult: float = float(context["morale_drain_multiplier"])
	# min(floor, starting m): the floor blocks drain from crossing it but
	# never lifts a Morale that already sits below it (no free Morale from
	# going offline) — same semantics as ResourceManager.apply_delta's clamp.
	var morale_floor: float = float(context["morale_floor"])

	for seg: Dictionary in segments:
		var seg_remaining: int = seg["seconds"]
		var effective_buffer: int = seg["buffer"]
		while seg_remaining > 0:
			var dt: int = min(OFFLINE_STEP_SECONDS, seg_remaining)
			var step: Dictionary = ResourceSimulationStepScript.compute(
				cringe_fixed,
				h,
				m,
				float(dt),
				effective_buffer,
				haters_mult,
				meta_haters_resist,
				drain_mult,
				morale_floor,
				assistant_mult
			)
			h = float(step["final_H"])
			m = float(step["final_M"])
			z_gained += float(step["reach_gained"])

			seg_remaining -= dt

	var result: Dictionary = {
		"final_H": h,
		"final_M": m,
		"total_Z_gained": z_gained,
		"capped": capped,
		"counted_seconds": remaining,
		"final": {
			"Reach": float(context["Reach"]) + z_gained,
			"Cringe": float(context["Cringe"]),
			"Haters": h,
			"Morale": m,
			"Sponsors": float(context["Sponsors"]),
		},
	}
	return result


func simulate_contract_from_context(context: Dictionary, elapsed_seconds: int, contract: Dictionary, remainder_units: int = 0) -> Dictionary:
	if not is_valid_context(context):
		return {}
	var contract_id: StringName = StringName(contract.get("id", ""))
	var terms: Dictionary = contract.get("terms", {})
	match contract_id:
		&"drama":
			var drama_context: Dictionary = context.duplicate(true)
			drama_context["haters_multiplier"] = float(context["haters_multiplier"]) * float(terms.get("haters_multiplier", 1.5))
			return simulate_from_context(drama_context, elapsed_seconds)
		&"business":
			return _simulate_business(context, elapsed_seconds, terms, remainder_units)
		&"detox":
			return _simulate_detox(context, elapsed_seconds, terms)
	return {}


func _simulate_business(context: Dictionary, elapsed_seconds: int, terms: Dictionary, remainder_units: int) -> Dictionary:
	var safe_elapsed: int = maxi(0, elapsed_seconds)
	var counted: int = mini(safe_elapsed, MAX_OFFLINE_CAP_SECONDS)
	var business_context: Dictionary = context.duplicate(true)
	business_context["haters_multiplier"] = 0.0
	business_context["assistant_multiplier"] = 0.0
	var result: Dictionary = simulate_from_context(business_context, safe_elapsed)
	var unit_scale: int = int(terms.get("units_per_sponsor", 1000))
	var raw_units: int = clampi(remainder_units, 0, unit_scale - 1)
	var generated: float = float(terms.get("sponsors_per_hour", 1.5)) * float(unit_scale) * float(counted) / 3600.0
	generated *= float(context["sponsor_income_multiplier"]) * (1.0 + float(context["meta_sponsor_bonus"]))
	raw_units += int(floor(generated))
	var gained: int = raw_units / unit_scale
	result["final"]["Reach"] = float(context["Reach"])
	result["final"]["Haters"] = float(context["Haters"])
	result["final"]["Sponsors"] = float(context["Sponsors"]) + float(gained)
	result["final_H"] = float(context["Haters"])
	result["total_Z_gained"] = 0.0
	result["business_remainder_units"] = raw_units % unit_scale
	return result


func _simulate_detox(context: Dictionary, elapsed_seconds: int, terms: Dictionary) -> Dictionary:
	var safe_elapsed: int = maxi(0, elapsed_seconds)
	var counted: int = mini(safe_elapsed, MAX_OFFLINE_CAP_SECONDS)
	var hours: float = float(counted) / 3600.0
	var final_haters: float = maxf(0.0, float(context["Haters"]) - float(terms.get("haters_per_hour", 10.0)) * hours)
	var final_morale: float = minf(100.0, float(context["Morale"]) + float(terms.get("morale_per_hour", 12.0)) * hours)
	return {
		"final_H": final_haters,
		"final_M": final_morale,
		"total_Z_gained": 0.0,
		"capped": safe_elapsed > MAX_OFFLINE_CAP_SECONDS,
		"counted_seconds": counted,
		"final": {
			"Reach": float(context["Reach"]),
			"Cringe": float(context["Cringe"]),
			"Haters": final_haters,
			"Morale": final_morale,
			"Sponsors": float(context["Sponsors"]),
		},
	}
