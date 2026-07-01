## OfflineProgressSystem owns the stepped offline-time simulation: re-derives
## Hatersi growth, Morale drain, and passive Reach/Zasięgi income for an
## elapsed offline duration, using the same ResourceFormulas static functions
## consumed by live play (ActionSystem), guaranteeing the two contexts can
## never diverge (ADR-0006, TR-off-001).
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
	var capped: bool = elapsed_seconds > MAX_OFFLINE_CAP_SECONDS
	var remaining: int = min(elapsed_seconds, MAX_OFFLINE_CAP_SECONDS)

	var cringe_fixed: float = ResourceManager.get_resource(&"Cringe")
	var h: float = ResourceManager.get_resource(&"Haters")
	var m: float = ResourceManager.get_resource(&"Morale")
	var z_gained: float = 0.0

	# Sponsor Shield: if active at sim start, first N seconds use the elevated
	# buffer (shield segment), remainder uses the base M_BUFFER. This is a
	# 2-segment approximation — per quick-spec sponsor-network-shield-2026-06-30.md
	# (DDR-0001 #6). Shield state is read once at sim start (snapshot), not
	# per-tick — avoids branching inside the 1440-iteration worst-case loop.
	var shield_seconds: int = clampi(int(ResourceManager.get_shield_remaining_seconds()), 0, remaining)
	var segments: Array[Dictionary] = [
		{"seconds": shield_seconds, "buffer": ResourceManager.get_shield_effective_buffer()},
		{"seconds": remaining - shield_seconds, "buffer": ResourceFormulas.M_BUFFER},
	]

	for seg: Dictionary in segments:
		var seg_remaining: int = seg["seconds"]
		var effective_buffer: int = seg["buffer"]
		while seg_remaining > 0:
			var dt: int = min(OFFLINE_STEP_SECONDS, seg_remaining)
			var dt_minutes: float = dt / 60.0

			var h_rate: float = ResourceFormulas.haters_growth_rate(cringe_fixed)
			h += h_rate * dt_minutes

			var m_drain: float = ResourceFormulas.morale_drain_rate(int(h), effective_buffer)
			m = max(0.0, m - m_drain * dt_minutes)

			var mult: float = ResourceFormulas.action_effectiveness_multiplier(m)
			z_gained += ResourceFormulas.passive_zasiegi_income(h, mult, float(dt))

			seg_remaining -= dt

	var result: Dictionary = {
		"final_H": h,
		"final_M": m,
		"total_Z_gained": z_gained,
		"capped": capped,
	}
	last_simulation_result = result
	return result
