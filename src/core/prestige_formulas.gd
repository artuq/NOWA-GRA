## PrestigeFormulas is a stateless static utility class holding the
## Prestige/Checkpoint System's META_BONUS math: per-tier grant magnitude
## (Formula F1) and the one-time variety-completionist flat increment
## (Formula F1b).
##
## Implements TR-pcs-002 / ADR-0012 §3: pure static functions taking explicit
## arguments — no Autoload state, no `self`. Same shape as ResourceFormulas
## (ADR-0006, shared online/offline-consistency-by-construction precedent)
## and FeedbackMath (ADR-0011, stateless-by-design for testability).
## `PrestigeSystem` calls these functions and applies their results to its
## own owned state (`meta_bonus_totals`); these functions themselves never
## touch `HistoryFlagManager`, `SaveSystem`, or any Autoload.
##
## Story 003 scope: F1 (`grant_magnitude`, `tier_factor`) and F1b
## (`variety_bonus_increment`) only. F2's per-type stacking/cap
## (`apply_stacking_and_cap`) and F3a-d's consumption-side formulas are
## explicitly out of scope (Story 004 / Story 005) and are NOT implemented
## in this file yet.
##
## Stateless-only invariant: never add instance vars or @export fields to
## this class — PrestigeSystem's on_burnout_accepted() and any future
## caller (e.g. Team/Staff Management, per ADR-0012) call these statics
## independently, and any shared state would silently leak across unrelated
## contexts (ADR-0012 §3).
##
## Usage example:
##   var grant: float = PrestigeFormulas.grant_magnitude(&"META_REACH_MULT", 1, 1.0, true)
##   # -> 0.1071 (GDD F1's first-ever-burnout worked example)
class_name PrestigeFormulas
extends RefCounted

## Base grant per tier-point, before challenge scaling, per META_BONUS type
## (GDD F1's "BASE_INCREMENT[type] (proposed defaults)" table). Tuning knob,
## per-type — read fresh from design/registry/entities.yaml /
## design/gdd/prestige-checkpoint-system.md F1, never hand-tuned here without
## updating both sources in lockstep.
const BASE_INCREMENT: Dictionary[StringName, float] = {
	&"META_REACH_MULT": 0.02,
	&"META_SPONSOR_MULT": 0.025,
	&"META_HATERS_RESIST": 0.015,
	&"META_SPONSOR_FLOOR": 3.0,
}

## Hard per-type lifetime ceiling (GDD F2's "META_BONUS_MAX[type] (proposed
## defaults, deliberately non-uniform)" table). Used here only by
## grant_magnitude()'s first-burnout ceiling (4b-i) — the running-total clamp
## itself (F2, apply_stacking_and_cap()) is Story 004 scope.
const META_BONUS_MAX: Dictionary[StringName, float] = {
	&"META_REACH_MULT": 0.50,
	&"META_SPONSOR_MULT": 0.50,
	&"META_HATERS_RESIST": 0.40,
	&"META_SPONSOR_FLOOR": 100.0,
}

## Flat component blended into tier_factor()'s tier scaling (Core Rule 4a).
## Tuning knob, default 2 per entities.yaml, safe range [0, 4]. `0` reduces
## tier_factor() to the original pure-tier formula (variety-punishing —
## GDD's own caveat, do not set without another variety incentive in place).
const TIER_FLAT_BASE: int = 2

## Multiplies a player's first-ever accepted-burnout grant, per META_BONUS
## type independently (Core Rule 4b). Tuning knob, default 2.5.
const FIRST_BURNOUT_BONUS_MULT: float = 2.5

## Ceilings a first-ever grant (only) at this fraction of
## META_BONUS_MAX[type] (Core Rule 4b-i) — prevents FIRST_BURNOUT_BONUS_MULT
## from one-shotting a type's entire lifetime cap on high tier/challenge
## inputs. Tuning knob, default 0.5.
const FIRST_BURNOUT_GRANT_CAP_FRACTION: float = 0.5

## Dampens combined_meta_multiplier's contribution to raw_increment (square
## root at the locked default). Tuning knob, default 0.5, safe range
## [0.3, 0.5] — see entities.yaml note for why 0.5 is the mathematically
## safe ceiling (values above it risk overshooting a type's cap in one
## non-first grant).
const META_CHALLENGE_SCALING_EXPONENT: float = 0.5

## Multiplies BASE_INCREMENT[type] to produce each type's one-time
## completionist flat grant (F1b, Core Rule 4c). Tuning knob, default 2.0.
const VARIETY_BONUS_MULT: float = 2.0


## Returns the blended tier-scaling factor used by grant_magnitude(), per
## GDD Formula F1:
##
##   tier_factor(tier) = (tier_flat_base + tier) * 5 / (tier_flat_base + 5)
##
## [param tier_flat_base] is exposed as an explicit parameter (rather than
## always reading the TIER_FLAT_BASE constant internally) so this function
## stays independently testable at any tuning value, including the AC-6
## boundary case (tier_flat_base=0, which reduces this to the original pure
## `tier` value — tier_factor(N, 0) == float(N) for every tier).
## grant_magnitude() below calls this with the TIER_FLAT_BASE constant.
##
## The `5 / (tier_flat_base + 5)` normalization guarantees
## tier_factor(5, tier_flat_base) == 5.0 for every tier_flat_base value —
## Tier-5 output is unchanged from the pre-revision pure-tier formula
## regardless of how this knob is tuned (GDD F1 table note).
##
## Usage example:
##   PrestigeFormulas.tier_factor(1, 2)  # -> 2.142857... (GDD table: 2.143)
static func tier_factor(tier: int, tier_flat_base: int) -> float:
	return (float(tier_flat_base) + float(tier)) * 5.0 / (float(tier_flat_base) + 5.0)


## Returns the META_BONUS grant magnitude for one accepted burnout, per GDD
## Formula F1:
##
##   raw_increment[type] = BASE_INCREMENT[type] * tier_factor(tier, TIER_FLAT_BASE)
##       * (challenge_mult)^META_CHALLENGE_SCALING_EXPONENT * first_burnout_factor
##   bonus_increment[type] = raw_increment[type]  if not first-ever grant
##       else min(raw_increment[type], FIRST_BURNOUT_GRANT_CAP_FRACTION * META_BONUS_MAX[type])
##
## [param bonus_type] one of the four META_BONUS type keys (must exist in
## BASE_INCREMENT/META_BONUS_MAX — this function does not validate unknown
## keys, matching ResourceFormulas'/FeedbackMath's "trusts the caller's
## contract" precedent).
## [param tier] `ClassPathSystem.get_tier(active_path)` at the moment Choice
## A resolves — caller contract: only called when tier >= 1 (Core Rule 1;
## PrestigeSystem's on_burnout_accepted() only calls this when an active
## path exists).
## [param challenge_mult] `ChallengeSystem.get_combined_meta_multiplier()`;
## 1.0 if no challenges active.
## [param is_first_burnout] true only for the very first accepted-burnout
## grant on this specific type (Core Rule 4b — per-type flag, not global).
## Applies FIRST_BURNOUT_BONUS_MULT and the 4b-i ceiling clamp; false for
## every subsequent grant on that type, which is left fully unclamped here
## (subject only to F2's running-total cap, Story 004, applied by the
## caller on top of this function's return value).
##
## Performance: O(1) pure float arithmetic (one pow() call) — called once
## per accepted burnout (a rare event), same negligible-cost precedent as
## ResourceFormulas' per-call functions.
##
## Usage example:
##   PrestigeFormulas.grant_magnitude(&"META_REACH_MULT", 1, 1.0, true)  # -> 0.1071
static func grant_magnitude(bonus_type: StringName, tier: int, challenge_mult: float,
		is_first_burnout: bool) -> float:
	var raw: float = BASE_INCREMENT[bonus_type] * tier_factor(tier, TIER_FLAT_BASE) \
		* pow(challenge_mult, META_CHALLENGE_SCALING_EXPONENT)
	if is_first_burnout:
		raw *= FIRST_BURNOUT_BONUS_MULT
		raw = minf(raw, FIRST_BURNOUT_GRANT_CAP_FRACTION * META_BONUS_MAX[bonus_type])
	return raw


## Returns the one-time variety-completionist flat grant for a single
## META_BONUS type, per GDD Formula F1b:
##
##   variety_grant[type] = BASE_INCREMENT[type] * VARIETY_BONUS_MULT
##
## This is a per-type flat amount only — it does NOT decide *whether* the
## completionist bonus should fire this cycle (that cross-type "all four
## types nonzero for the first time" check, and the once-per-save
## variety_bonus_used flag, are PrestigeSystem's responsibility, since they
## require reading all four running totals — a cross-type check, not a
## per-grant formula; ADR-0012 §3 / this story's Implementation Notes).
## Equally, this function has no knowledge of the caller's current running
## total or that type's cap — a type already at META_BONUS_MAX[type] still
## gets a normal, non-special-cased return value from this function; F2's
## clamp (Story 004, apply_stacking_and_cap()) is solely responsible for
## absorbing it with no effect, and is applied by the caller on top of this
## function's return value, not inside it.
##
## Usage example:
##   PrestigeFormulas.variety_bonus_increment(&"META_REACH_MULT")  # -> 0.04
static func variety_bonus_increment(bonus_type: StringName) -> float:
	return BASE_INCREMENT[bonus_type] * VARIETY_BONUS_MULT
