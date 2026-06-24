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

	while remaining > 0:
		var dt: int = min(OFFLINE_STEP_SECONDS, remaining)
		var dt_minutes: float = dt / 60.0

		# Fixed order per offline-progress-system.md Core Rules: H, then M,
		# then Mult, then Z. Never reorder -- Z depends on the post-update H
		# and the multiplier computed from the post-update M, not the
		# step's starting values.
		var h_rate: float = ResourceFormulas.haters_growth_rate(cringe_fixed)
		h += h_rate * dt_minutes

		# morale_drain_rate() takes an int (Hatersi count is a whole-number
		# variable per resource-system.md's Formula B), but h accumulates as
		# a float across steps. Truncating via int() rather than rounding --
		# h only ever grows, so this is equivalent to floor(h), consistent
		# with "count of Haters" semantics (a partial Hater doesn't drain
		# Morale yet). No existing live-play call site to match against this
		# story (ActionSystem doesn't call ResourceFormulas yet -- that
		# migration is separate scope, see story's Out of Scope).
		var m_drain: float = ResourceFormulas.morale_drain_rate(int(h))
		m = max(0.0, m - m_drain * dt_minutes)

		var mult: float = ResourceFormulas.action_effectiveness_multiplier(m)
		# ADR-0006's Decision pseudocode predates ResourceFormulas.
		# passive_zasiegi_income() (added by Resource System Story 005) and
		# inlines the Z_PER_HATER multiplication directly -- using the real,
		# already-tested function here instead keeps this loop free of any
		# duplicated formula math, consistent with ADR-0006's own stated goal
		# of a single shared implementation.
		z_gained += ResourceFormulas.passive_zasiegi_income(h, mult, float(dt))

		remaining -= dt

	var result: Dictionary = {
		"final_H": h,
		"final_M": m,
		"total_Z_gained": z_gained,
		"capped": capped,
	}
	last_simulation_result = result
	return result
