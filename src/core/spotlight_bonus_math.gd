## Pure reward math for Skill Challenge card mini-games. Narrative and
## progression effects are deliberately outside this helper.
class_name SpotlightBonusMath
extends RefCounted


## Computes a score-scaled reward between inclusive minimum and maximum values.
## Invalid inputs safely return zero; score is clamped to `[0,1]`.
static func curved_reward(reward_min: float, reward_max: float, score: float, exponent: float) -> int:
	if not is_finite(reward_min) or not is_finite(reward_max):
		return 0
	if not is_finite(score) or not is_finite(exponent):
		return 0
	if reward_min < 0.0 or reward_max < reward_min or exponent <= 0.0:
		return 0
	var safe_score: float = clampf(score, 0.0, 1.0)
	var curved: float = pow(safe_score, exponent)
	return maxi(0, roundi(reward_min + (reward_max - reward_min) * curved))
