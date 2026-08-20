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
## (`variety_bonus_increment`). Story 004 adds F2's per-type stacking/cap
## (`apply_stacking_and_cap`). Story 005 adds F3a-d's consumption-side
## formulas — `final_reach`, `final_sponsors`, `haters_rate_final`,
## `sponsors_era_start_override` — the read-time multiplier applications
## consumed at action reward / card resolution / Haters-rate / era-start-reset
## points (ADR-0012 §3, `ResourceFormulas`-style stateless composition per
## control-manifest.md Core layer rules — these are read-time multiplier
## applications, not stored state mutations). Story 009 (this revision, TR-
## pcs-005, GDD "Misconfiguration Guard") adds `_clamp_grant()`, wrapping
## `grant_magnitude()`'s final return value: clamps a negative result to
## `0.0` and logs a `push_warning()` if `BASE_INCREMENT[bonus_type]` is
## misconfigured (`<= 0.0`) or the pre-clamp result would otherwise be
## negative — defensive only, degrades a bad balance edit gracefully instead
## of corrupting a permanent, never-reduced META_BONUS total (Core Rule 5).
## F1's math itself is unmodified by this revision (Out of Scope).
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


## Misconfiguration guard (Story 009, TR-pcs-005, GDD "Misconfiguration
## Guard"): clamps [param raw] to a non-negative value and logs a
## `push_warning()` if either (a) [param base_increment] itself is
## non-positive (`<= 0.0` — the config value grant_magnitude() actually
## multiplied by, i.e. `BASE_INCREMENT[bonus_type]`), or (b) [param raw] is
## negative even though [param base_increment] is positive (a defensive
## belt-and-braces branch — every other factor in F1's product (tier_factor(),
## pow(challenge_mult, ...), FIRST_BURNOUT_BONUS_MULT) is non-negative by
## construction, so this branch should be unreachable with any currently
## legal input, but is checked explicitly rather than assumed). At most one
## warning is logged per call (the two conditions are checked as if/elif, not
## independently) — a misconfigured base_increment and its resulting negative
## raw are the same root cause, not two separate problems worth double-
## reporting.
##
## This exists purely so a misconfigured `balance.json`/BASE_INCREMENT edit
## degrades gracefully — clamping a would-be-negative permanent META_BONUS
## contribution to `0.0` instead of silently corrupting the running total
## (Core Rule 5's never-reduced guarantee) — not expected to trigger with any
## of the four currently-tuned BASE_INCREMENT defaults (all positive, GDD F1
## table).
##
## [param base_increment] is accepted as an explicit argument (rather than
## re-reading `BASE_INCREMENT[bonus_type]` internally) purely so this guard
## stays independently unit-testable against a simulated misconfigured value:
## `BASE_INCREMENT` is a `const Dictionary`, and Godot 4.6.3's GDScript
## compiler rejects any assignment into a const collection's contents at
## parse time ("Cannot assign a new value to a constant", verified empirically
## — both from within this class and from an external caller), so there is no
## way to actually corrupt the real table at runtime to exercise this path.
## Same explicit-parameter-for-testability precedent as `tier_factor()`'s
## `tier_flat_base` parameter (Story 003's own doc comment: "exposed... so
## this function stays independently testable at any tuning value").
##
## grant_magnitude() below calls this with `BASE_INCREMENT[bonus_type]` as
## [param base_increment] — the real, currently-always-positive config value —
## and its own already-computed pre-clamp result as [param raw].
##
## Usage example:
##   PrestigeFormulas._clamp_grant(&"META_REACH_MULT", -0.05, -0.02)  # -> 0.0, warns
##   PrestigeFormulas._clamp_grant(&"META_REACH_MULT", 0.1071, 0.02)  # -> 0.1071, no warning
static func _clamp_grant(bonus_type: StringName, raw: float, base_increment: float) -> float:
	if base_increment <= 0.0:
		push_warning("PrestigeFormulas.grant_magnitude(): BASE_INCREMENT[%s] is misconfigured (%.4f, must be > 0.0) — grant clamped to 0.0" % [String(bonus_type), base_increment])
	elif raw < 0.0:
		push_warning("PrestigeFormulas.grant_magnitude(): computed grant for %s is negative (%.4f) — clamped to 0.0" % [String(bonus_type), raw])
	return maxf(0.0, raw)


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
## Story 009: the final return value is routed through `_clamp_grant()`
## (misconfiguration guard, TR-pcs-005) before being handed back to the
## caller — a no-op for every currently-tuned positive BASE_INCREMENT value,
## defensive-only for a hypothetical future misconfigured one. F1's math
## above this final wrap is unmodified (Out of Scope for that story).
##
## Performance: O(1) pure float arithmetic (one pow() call) — called once
## per accepted burnout (a rare event), same negligible-cost precedent as
## ResourceFormulas' per-call functions.
##
## Usage example:
##   PrestigeFormulas.grant_magnitude(&"META_REACH_MULT", 1, 1.0, true)  # -> 0.1071
static func grant_magnitude(bonus_type: StringName, tier: int, challenge_mult: float,
		is_first_burnout: bool) -> float:
	var base_increment: float = BASE_INCREMENT[bonus_type]
	var raw: float = base_increment * tier_factor(tier, TIER_FLAT_BASE) \
		* pow(challenge_mult, META_CHALLENGE_SCALING_EXPONENT)
	if is_first_burnout:
		raw *= FIRST_BURNOUT_BONUS_MULT
		raw = minf(raw, FIRST_BURNOUT_GRANT_CAP_FRACTION * META_BONUS_MAX[bonus_type])
	return _clamp_grant(bonus_type, raw, base_increment)


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


## Applies GDD Formula F2's per-type running-total stacking and hard cap to a
## single already-computed grant:
##
##   apply_stacking_and_cap(type, current_total, grant, cap) = min(current_total + grant, cap)
##
## Additive stacking, per type, clamped at [param cap] — any portion of
## [param grant] that would push the total past [param cap] is silently
## absorbed with no effect and no compensating grant elsewhere (Core Rule 1).
## A type already sitting exactly at [param cap] absorbs the entire grant
## (returns [param cap] unchanged) — this is the mechanism, by construction,
## that guarantees a "grant" can never softlock or reject an era transition:
## the caller (`PrestigeSystem`) always applies this function's result
## unconditionally, regardless of whether it changed anything.
##
## [param bonus_type] is accepted (rather than this function reading
## `META_BONUS_MAX[bonus_type]` internally) so the caller decides which cap
## applies — this keeps the function usable both for a normal per-type grant
## (caller passes `META_BONUS_MAX[bonus_type]`) and for any future test/tool
## that wants to probe an arbitrary cap value without touching the real
## table. This function itself never reads `META_BONUS_MAX` — [param
## bonus_type] exists purely for call-site clarity/documentation (matching
## every other `PrestigeFormulas` function's `bonus_type`-first signature)
## and is otherwise unused by the body.
##
## [param current_total] `PrestigeSystem.meta_bonus_totals.get(bonus_type,
## 0.0)` — the running total BEFORE this grant.
## [param grant] the already-computed grant magnitude for this single
## accepted burnout (`grant_magnitude()`'s return value, or
## `variety_bonus_increment()`'s — both call sites route through this same
## clamp, per ADR-0012 §3).
## [param cap] `PrestigeFormulas.META_BONUS_MAX[bonus_type]` — the type's
## hard lifetime ceiling (F2's "proposed defaults, deliberately non-uniform"
## table).
##
## Performance: O(1) pure float arithmetic — called once per accepted
## burnout (a rare event), same negligible-cost precedent as this class's
## other functions.
##
## Usage example:
##   PrestigeFormulas.apply_stacking_and_cap(&"META_REACH_MULT", 0.4944, 0.1010, 0.50)  # -> 0.50 (absorbs 0.0954)
static func apply_stacking_and_cap(bonus_type: StringName, current_total: float,
		grant: float, cap: float) -> float:
	return minf(current_total + grant, cap)


## Returns the final Reach grant for one completed action, per GDD Formula
## F3a:
##
##   final_reach = max(1, round(base * Mult(M) * class_path_multiplier
##       * challenge_modifier * (1 + META_REACH_MULT_total)))
##
## The `max(1, ...)` floor (added post-`/design-review`) guarantees a
## completed action never grants zero Reach, even when every multiplicative
## layer is at its lowest legal value simultaneously (AC-3's edge case: a
## raw product that rounds to 0 is floored to 1, not left at 0).
##
## [param base] the action's base Reach value (`ActionSystem`'s per-action
## constant).
## [param morale_mult] `ResourceFormulas.action_effectiveness_multiplier()`'s
## return value (`Mult(M)`) — the Morale-band multiplier, already computed
## by the caller.
## [param class_path_multiplier] `ClassPathSystem.get_active_multiplier(action_id)`
## (ADR-0010 §5) — 1.0 when no active path.
## [param challenge_modifier] `ChallengeSystem`'s per-action Reach modifier —
## 1.0 when no challenge active.
## [param meta_reach_mult_total] `PrestigeSystem.get_meta_bonus_total(&"META_REACH_MULT")`.
##
## Performance: O(1) pure float arithmetic — called once per completed
## action, same negligible-cost precedent as this class's other functions.
##
## Usage example:
##   PrestigeFormulas.final_reach(10.0, 1.00, 1.30, 1.0, 0.3873)  # -> 18
static func final_reach(base: float, morale_mult: float, class_path_multiplier: float,
		challenge_modifier: float, meta_reach_mult_total: float) -> int:
	var raw: float = base * morale_mult * class_path_multiplier * challenge_modifier \
		* (1.0 + meta_reach_mult_total)
	return maxi(1, roundi(raw))


## Returns the final Sponsors grant for one qualifying Decision Card's
## Sponsor roll, per GDD Formula F3b:
##
##   final_sponsors = round(base_sponsors_roll * class_path_sponsor_multiplier
##       * staff_sponsor_multiplier * (1 + META_SPONSOR_MULT_total))
##
## Unlike final_reach(), there is no floor rule here — a Sponsor roll
## legitimately can and does round to 0 (GDD F3b has no "never zero"
## guarantee for Sponsors, unlike Reach's F3a).
##
## [param base_sponsors_roll] the qualifying card's already-rolled base
## Sponsor amount (`DecisionCardSystem`'s `sponsorzy_per_qualifying_card`
## roll result).
## [param class_path_sponsor_multiplier] `ClassPathSystem.get_active_sponsor_multiplier()`
## (ADR-0010 §5a) — 1.0 when no active path.
## [param meta_sponsor_mult_total] `PrestigeSystem.get_meta_bonus_total(&"META_SPONSOR_MULT")`.
## [param staff_sponsor_multiplier] the era-local Sponsor Manager factor;
## defaults to 1.0 so the original three-argument F3b contract remains source
## compatible. Team/Staff Management composes at the same card-income point.
##
## Performance: O(1) pure float arithmetic — called once per qualifying
## card resolution, same negligible-cost precedent as this class's other
## functions.
##
## Usage example:
##   PrestigeFormulas.final_sponsors(3.0, 1.20, 0.50)  # -> 5
static func final_sponsors(base_sponsors_roll: float, class_path_sponsor_multiplier: float,
		meta_sponsor_mult_total: float, staff_sponsor_multiplier: float = 1.0) -> int:
	return roundi(
		base_sponsors_roll * class_path_sponsor_multiplier * staff_sponsor_multiplier
		* (1.0 + meta_sponsor_mult_total)
	)


## Returns the final Haters growth rate (per minute), per GDD Formula F3c:
##
##   H_rate_final = H_rate(C) * (1 - META_HATERS_RESIST_total)
##
## Deliberately the ONE F3 formula that applies identically online and
## offline (F3c locked scope, GDD's own explicit call-out) — contrast with
## Challenge action multipliers, which remain action-only. Both
## `LiveResourceTicker` and `OfflineProgressSystem.simulate_offline()` must
## apply this same resistance factor
## on top of `ResourceFormulas.haters_growth_rate(cringe)`'s result, so the
## two contexts can never silently diverge (same online/offline-consistency-
## by-construction precedent as ADR-0006's `ResourceFormulas`).
##
## The offline call site is wired in `OfflineProgressSystem`; live play uses
## the same factor through `LiveResourceTicker`. Do not approximate this
## time-based rate per action.
##
## [param base_rate] `ResourceFormulas.haters_growth_rate(cringe)` — `H_rate(C)`,
## already computed by the caller.
## [param meta_haters_resist_total] `PrestigeSystem.get_meta_bonus_total(&"META_HATERS_RESIST")`.
## `meta_haters_resist_total=0.0` is a no-op, returning [param base_rate]
## unchanged (META_HATERS_RESIST's cap of 0.40, per META_BONUS_MAX, keeps
## this always well short of the (1 - x) <= 0 degenerate case).
##
## Performance: O(1) pure float arithmetic — same negligible-cost precedent
## as this class's other functions; cheap even at the offline simulation
## loop's 1440-iteration worst case (ADR-0006).
##
## Usage example:
##   PrestigeFormulas.haters_rate_final(0.66, 0.30)  # -> 0.462
static func haters_rate_final(base_rate: float, meta_haters_resist_total: float) -> float:
	return base_rate * (1.0 - meta_haters_resist_total)


## Returns the era-start Sponsors override value, per GDD Formula F3d:
##
##   Sponsors_era_start = META_SPONSOR_FLOOR_total if META_SPONSOR_FLOOR_total > 0.0 else 0.0
##
## Story 005 implements ONLY this override function in isolation. The
## ordering guarantee between the era-transition flag sweep's default
## Sponsors=0 write and this override's write (the sweep must write its
## default FIRST, this override must write AFTER) is Story 007's own
## responsibility (this story's Out of Scope) — this function has no
## knowledge of when it is called relative to the sweep.
##
## [param meta_sponsor_floor_total] `PrestigeSystem.get_meta_bonus_total(&"META_SPONSOR_FLOOR")`.
## Always >= 0.0 by construction (F2's `apply_stacking_and_cap()` never
## produces a negative running total) — the `> 0.0` branch exists to make
## the "no override when the total is still exactly the untouched default"
## case explicit and self-documenting, not to guard against a negative
## input this function doesn't otherwise handle specially.
##
## Performance: O(1) — single comparison, same negligible-cost precedent as
## this class's other functions.
##
## Usage example:
##   PrestigeFormulas.sponsors_era_start_override(9.0)  # -> 9.0
##   PrestigeFormulas.sponsors_era_start_override(0.0)  # -> 0.0
static func sponsors_era_start_override(meta_sponsor_floor_total: float) -> float:
	return meta_sponsor_floor_total if meta_sponsor_floor_total > 0.0 else 0.0
