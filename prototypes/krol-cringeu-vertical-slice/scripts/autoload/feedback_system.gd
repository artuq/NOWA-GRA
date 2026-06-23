# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the core fantasy within 3-5 min, unguided?
# Date: 2026-06-20
#
# Implements juice-feedback-system.md's magnitude() and payoff_duration() formulas.
# No audio implemented (no sound assets in this slice) — visual channels only
# (scale-pulse/shake on Decision Card events, flash on Action System events).
extends Node

const NORM_REF_CRINGE := 35.0
const NORM_REF_MORALE := 30.0
const Z_NORM_REF := 40.0
const PAYOFF_D_MIN := 1.5
const PAYOFF_D_MAX := 2.5
const PAYOFF_L_REF := 60.0

func magnitude(deltas: Dictionary) -> float:
	var contributions: Array[float] = []
	for key in deltas:
		var delta: float = abs(deltas[key])
		var contribution: float = 0.0
		if key == &"Cringe":
			contribution = delta / NORM_REF_CRINGE
		elif key == &"Morale":
			contribution = delta / NORM_REF_MORALE
		else:
			contribution = log(1.0 + delta) / log(1.0 + Z_NORM_REF)
		contributions.append(contribution)
	var max_contribution: float = 0.0
	for c in contributions:
		max_contribution = max(max_contribution, c)
	return clamp(max_contribution, 0.0, 1.0)

func payoff_duration(text_length: int) -> float:
	var raw: float = PAYOFF_D_MIN + (float(text_length) / PAYOFF_L_REF) * (PAYOFF_D_MAX - PAYOFF_D_MIN)
	return clamp(raw, PAYOFF_D_MIN, PAYOFF_D_MAX)
