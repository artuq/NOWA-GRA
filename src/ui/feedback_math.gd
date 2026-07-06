## FeedbackMath owns the Juice/Feedback System's display math: the event
## magnitude formula and the per-tier effect parameter functions (pulse scale,
## shake amplitude/duration, stinger layer params).
##
## Implements TR-juice-001/003/004 / ADR-0011: a stateless static utility
## (same shape as ResourceFormulas, ADR-0006 — never add instance vars or
## @export fields; both UI call sites, ResourceHud and CardScreen, call these
## statics independently and any shared state would leak across contexts).
##
## The no-valence-coding guarantee (TR-juice-003, registry forbidden pattern)
## is structural: every function reads absf(delta) or a magnitude scalar —
## the SIGN of a resource delta cannot influence any output, by construction.
## Intensity encodes "how much happened," never "was it good or bad."
##
## Usage example:
##   var m: float = FeedbackMath.magnitude({&"Cringe": 20.0, &"Reach": 10.0})
##   var target: float = FeedbackMath.pulse_scale(m)
class_name FeedbackMath
extends RefCounted

## Log-normalization reference for unbounded resources (Reach, Sponsors,
## Haters). GDD Tuning Knob: start 40, safe range 20-80.
## ponytail: const, not external balance data — same extraction-later posture
## as ActionSystem.ACTION_REWARDS.
const Z_NORM_REF: float = 40.0

## Linear-ratio normalization for bounded resources: the delta size that
## counts as "maxed out" (contribution 1.0). Cringe tracks CardContentDatabase's
## card delta ceiling (35); Morale tracks Resource System's band gap (30).
## Keep in sync if those source values ever change (GDD Knob interaction note).
const BOUNDED_NORM_REFS: Dictionary[StringName, float] = {
	&"Cringe": 35.0,
	&"Morale": 30.0,
}

## Magnitude tier boundaries (GDD: low [0, 0.3), mid [0.3, 0.7), high [0.7, 1]).
const TIER_MID: float = 0.3
const TIER_HIGH: float = 0.7

## Card scale-pulse targets per tier edge (GDD Visual Requirements:
## ~102-105% low, up to ~110-115% high). Piecewise-linear and continuous
## across tier boundaries — monotonically non-decreasing in m.
const PULSE_LOW_MIN: float = 1.02
const PULSE_LOW_MAX: float = 1.05
const PULSE_MID_MAX: float = 1.10
const PULSE_HIGH_MAX: float = 1.15

## Shake amplitude (px) per tier edge. Retuned 2026-07-06 after the first
## feel-test: the GDD's placeholder range (2-4px mid, 8px cap) was fully
## masked by the simultaneous scale-pulse — invisible on video review at any
## playback speed (QA verdict: As Designed / Needs Tweak). Bumped to 6-12px
## per QA recommendation; on touch-only Android with a finger covering part
## of the card, feedback must over-communicate. Revisit in polish if too
## aggressive — easier to dial down than to ship an effect nobody registers.
const SHAKE_MID_MIN_PX: float = 6.0
const SHAKE_MID_MAX_PX: float = 8.0
const SHAKE_HIGH_MAX_PX: float = 12.0

## Shake duration (seconds) per tier edge (same 2026-07-06 retune: 0.10-0.25s
## was too brief to register alongside the pulse; now 0.3-0.4s).
const SHAKE_MID_MIN_SEC: float = 0.30
const SHAKE_MID_MAX_SEC: float = 0.35
const SHAKE_HIGH_MAX_SEC: float = 0.40

## Stinger tail bounds (GDD Audio: ~80ms dry at magnitude 0 scaling to
## ~600-900ms textured tail at magnitude 1 — 0.9 chosen as the ceiling).
const STINGER_TAIL_MIN_SEC: float = 0.08
const STINGER_TAIL_MAX_SEC: float = 0.9


## Returns the event feedback magnitude [0.0, 1.0] for [param deltas]
## (resource StringName -> signed float delta), per the GDD formula:
## max over resources of contribution(r), hard-clamped.
## Bounded resources (Cringe, Morale) use linear ratio |delta|/norm_ref;
## every other key (Reach, Sponsors, Haters, and any future resource) uses
## log compression log(1+|delta|)/log(1+Z_NORM_REF) — unknown keys never
## crash, they are simply treated as unbounded.
## Reads absf(delta) only — sign-invariant by construction (TR-juice-003).
##
## Example:
##   FeedbackMath.magnitude({&"Cringe": 20.0, &"Morale": -3.0, &"Reach": 10.0})  # -> 0.646
static func magnitude(deltas: Dictionary) -> float:
	var best: float = 0.0
	for key in deltas:
		var contribution: float
		var size: float = absf(float(deltas[key]))
		if BOUNDED_NORM_REFS.has(key):
			contribution = size / BOUNDED_NORM_REFS[key]
		else:
			contribution = log(1.0 + size) / log(1.0 + Z_NORM_REF)
		best = maxf(best, contribution)
	return clampf(best, 0.0, 1.0)


## Returns the card scale-pulse target for magnitude [param m]: piecewise-
## linear from 1.02 (m=0) through 1.05 (m=0.3) and 1.10 (m=0.7) to 1.15 (m=1).
## Always >= PULSE_LOW_MIN — a zero-magnitude event still pulses (TR-juice-004).
static func pulse_scale(m: float) -> float:
	var mc: float = clampf(m, 0.0, 1.0)
	if mc < TIER_MID:
		return lerpf(PULSE_LOW_MIN, PULSE_LOW_MAX, mc / TIER_MID)
	if mc < TIER_HIGH:
		return lerpf(PULSE_LOW_MAX, PULSE_MID_MAX, (mc - TIER_MID) / (TIER_HIGH - TIER_MID))
	return lerpf(PULSE_MID_MAX, PULSE_HIGH_MAX, (mc - TIER_HIGH) / (1.0 - TIER_HIGH))


## Returns the shake amplitude in pixels for magnitude [param m]: exactly 0
## below the mid tier (low-magnitude card resolutions pulse only, GDD rule),
## 2-4px through the mid tier, up to a hard cap in the high tier.
static func shake_amplitude_px(m: float) -> float:
	var mc: float = clampf(m, 0.0, 1.0)
	if mc < TIER_MID:
		return 0.0
	if mc < TIER_HIGH:
		return lerpf(SHAKE_MID_MIN_PX, SHAKE_MID_MAX_PX, (mc - TIER_MID) / (TIER_HIGH - TIER_MID))
	return lerpf(SHAKE_MID_MAX_PX, SHAKE_HIGH_MAX_PX, (mc - TIER_HIGH) / (1.0 - TIER_HIGH))


## Returns the shake duration in seconds for magnitude [param m]: 0 below the
## mid tier (no shake at all), <=0.15s mid, capped at 0.25s high.
static func shake_duration_sec(m: float) -> float:
	var mc: float = clampf(m, 0.0, 1.0)
	if mc < TIER_MID:
		return 0.0
	if mc < TIER_HIGH:
		return lerpf(SHAKE_MID_MIN_SEC, SHAKE_MID_MAX_SEC, (mc - TIER_MID) / (TIER_HIGH - TIER_MID))
	return lerpf(SHAKE_MID_MAX_SEC, SHAKE_HIGH_MAX_SEC, (mc - TIER_HIGH) / (1.0 - TIER_HIGH))


## Returns the audio stinger parameters for magnitude [param m]:
## `layers` (1 dry transient low / 2 mid / 3 full stack high — GDD layer
## density), `tail_sec` (decay length, linear 0.08..0.9), and `saturation`
## (transient soft-clip amount, equal to clamped m). All parameters scale
## with magnitude only — never pitch, never harmony (no-valence rule).
##
## Example:
##   FeedbackMath.stinger_params(0.0)  # -> {layers: 1, tail_sec: 0.08, saturation: 0.0}
static func stinger_params(m: float) -> Dictionary:
	var mc: float = clampf(m, 0.0, 1.0)
	var layers: int = 1
	if mc >= TIER_HIGH:
		layers = 3
	elif mc >= TIER_MID:
		layers = 2
	return {
		"layers": layers,
		"tail_sec": lerpf(STINGER_TAIL_MIN_SEC, STINGER_TAIL_MAX_SEC, mc),
		"saturation": mc,
	}
