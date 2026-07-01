## ResourceFormulas is a stateless static utility class holding the Resource
## System's shared math formulas (Cringe -> Hatersi growth, Morale drain,
## action effectiveness, passive Zasięgi income).
##
## Implements ADR-0006's shared-formula contract: both live play
## (ActionSystem) and offline simulation (OfflineProgressSystem) call these
## same static functions, guaranteeing the two contexts can never silently
## diverge (TR-res-001).
##
## Stateless-only invariant: never add instance vars or @export fields to
## this class — both call sites call its static functions independently,
## and any shared state would silently leak across unrelated contexts
## (ADR-0006, control-manifest.md Core layer rules).
##
## Usage example:
##   var rate: float = ResourceFormulas.haters_growth_rate(cringe)
##   hatersi += rate * delta_minutes
class_name ResourceFormulas
extends RefCounted

## Hatersi growth rate at Cringe = 0 (the floor). Per-minute units.
const H_BASE: float = 0.02

## Exponent shaping the Hatersi growth curve against normalized Cringe.
##
## TUNING CONSTRAINT (found during code review): this must stay a whole
## number. haters_growth_rate()'s "always finite, never NaN" guarantee for
## out-of-contract negative input relies on pow(negative_base, H_EXP)
## resolving via x*x-style integer-exponent math. A non-integer H_EXP (e.g.
## 2.5) would produce NaN for negative Cringe inputs. Safe range per
## resource-system.md tuning knobs is [1.5, 2.5] for the *intended* curve
## shape — if tuning ever moves this to a non-integer value, re-verify
## test_out_of_contract_negative_cringe_returns_finite_value() still passes.
const H_EXP: float = 2.0

## Additional Hatersi growth rate added at Cringe = 100 (the ceiling), on
## top of H_BASE. Per-minute units.
const H_MAX_ADD: float = 1.0

## Returns the Hatersi passive growth rate (per minute) for a given Cringe
## value, per resource-system.md's Formula A:
##
##   H_rate(C) = H_base + (C / 100)^H_exp * H_max_add
##
## [param cringe] is expected to already be clamped to [0, 100] by the
## caller (ResourceManager clamps Cringe on every mutation per TR-res-001).
## This function does NOT re-clamp or validate its input — it trusts the
## caller's contract. If that contract is ever violated (cringe < 0 or
## cringe > 100), this function still returns a finite float; it never
## produces NaN or Infinity, since the only floating-point operation here is
## a single pow() call on a value that exponentiates safely outside [0,1]
## (negative bases work fine here as well, since H_EXP is a whole number).
##
## There is no hard cap on the returned rate or on any caller's accumulated
## Hatersi count — the GDD explicitly states the rate climbing without
## bound as Cringe approaches/exceeds 100 is an intended pressure peak, not
## a bug to fix.
##
## Performance: O(1) pure float arithmetic (one pow() call) — negligible
## even at the offline simulation loop's 1440-iteration worst case
## (ADR-0006). No profiling required at this scale.
##
## Usage example:
##   var rate: float = ResourceFormulas.haters_growth_rate(50.0)  # -> 0.27
static func haters_growth_rate(cringe: float) -> float:
	# NOTE: `pow()` is a builtin math function whose return value must be
	# explicitly typed `float` — `:=` type inference on a `pow()` result has
	# silently degraded to Variant in this project before. Always use an
	# explicit `var result: float = ...` here, never `:=`.
	var normalized: float = cringe / 100.0
	var curve: float = pow(normalized, H_EXP)
	var result: float = H_BASE + curve * H_MAX_ADD
	return result


## Hatersi count below which Morale drain is fully suppressed (the "buffer"
## zone). This is a hard cliff at the boundary (max(0, N - N_buffer)), not a
## gradual ramp — N=N_buffer drains exactly 0, same as N=0.
const M_BUFFER: int = 3

## Morale drain rate (per minute) contributed by each Hatersi beyond
## M_BUFFER, before the M_DRAIN_EXP curve is applied.
const M_DRAIN_PER_HATER: float = 0.15

## Exponent shaping the Morale drain curve against Hatersi count beyond the
## buffer. Fractional exponent (1.3) is safe here because max(0, ...) inside
## morale_drain_rate() guarantees a non-negative base before pow() is ever
## called — see that function's doc comment for the full NaN-safety
## argument (unlike H_EXP above, this constant has no whole-number
## constraint).
const M_DRAIN_EXP: float = 1.3

## Returns the Morale drain rate (per minute) for a given Hatersi count,
## per resource-system.md's Formula B:
##
##   M_drain(N) = M_drain_per_hater * max(0, N - N_buffer)^M_drain_exp
##
## The first M_BUFFER Hatersi drain nothing — this is the max(0, ...) clamp
## inside the formula itself (the buffer mechanism), not a defensive guard.
## This function returns a *rate*, not a time-integrated delta: the caller
## computes ΔMorale = -morale_drain_rate(N) * Δt / 60 and is responsible for
## flooring the result at the current Morale value before calling
## ResourceManager.apply_delta() — that clamp (Story 001) is the floor
## enforcement, not this function. This function never floors against
## current Morale and always returns its full, unclamped value, even when N
## is large enough that the implied drain would exceed current Morale.
##
## [param effective_buffer] overrides the default M_BUFFER when a caller
## (e.g. the Sponsor Shield via ResourceManager.get_shield_effective_buffer())
## needs an elevated buffer. Defaults to M_BUFFER so all existing call sites
## that omit the argument are unaffected.
##
## NaN-safety: M_DRAIN_EXP is a fractional exponent (1.3), which would be
## unsafe (NaN) on a negative base via pow() — but max(0, N - N_buffer)
## guarantees the base passed to pow() is always >= 0 regardless of what N
## is (even an out-of-contract negative Hatersi count), so this formula is
## safe by construction without requiring M_DRAIN_EXP to stay a whole
## number (contrast with H_EXP's whole-number constraint above).
##
## Performance: O(1) pure float arithmetic (one max() + one pow()) —
## negligible even at the offline simulation loop's 1440-iteration worst
## case (ADR-0006). No profiling required at this scale.
##
## Usage example:
##   var rate: float = ResourceFormulas.morale_drain_rate(10)  # -> ~1.882
##   var rate_shielded: float = ResourceFormulas.morale_drain_rate(10, 8)  # elevated buffer
static func morale_drain_rate(hatersi_count: int, effective_buffer: int = M_BUFFER) -> float:
	# NOTE: `pow()`/`max()` builtin results must be explicitly typed `float`
	# here — `:=` type inference on these calls has silently degraded to
	# Variant in this project before (see haters_growth_rate() above).
	# Always use explicit `var result: float = ...`, never `:=`.
	var excess: float = max(0.0, float(hatersi_count) - float(effective_buffer))
	var curve: float = pow(excess, M_DRAIN_EXP)
	var result: float = M_DRAIN_PER_HATER * curve
	return result


## Morale value at/above which the action effectiveness multiplier is Full
## (1.00x) — the top of the highest band, per resource-system.md's Formula C.
const E_FULL_THRESHOLD: float = 70.0

## Morale value at/above which the multiplier is at least High (0.90x).
const E_HIGH_THRESHOLD: float = 40.0

## Morale value at/above which the multiplier is at least Low (0.75x).
const E_LOW_THRESHOLD: float = 15.0

## Multiplier applied when Morale is in the Full band [70, 100].
const E_MULT_FULL: float = 1.0

## Multiplier applied when Morale is in the High band [40, 70).
const E_MULT_HIGH: float = 0.9

## Multiplier applied when Morale is in the Low band [15, 40).
const E_MULT_LOW: float = 0.75

## Multiplier applied when Morale is in the Critical band [0, 15).
const E_MULT_CRITICAL: float = 0.5

## Returns the action effectiveness multiplier for a given Morale value, per
## resource-system.md's Formula C:
##
##   Mult(M) = 1.00  if 70 <= M <= 100
##           = 0.90  if 40 <= M < 70
##           = 0.75  if 15 <= M < 40
##           = 0.50  if  0 <= M < 15
##
## This is a discrete lookup, not an interpolated curve — legible math is
## the explicit design intent (story-004). Boundaries use the
## inclusive-lower convention: `>=` for each band's lower bound, `<` for its
## upper bound, so a boundary value (e.g. M=70 or M=40) always belongs to
## the higher band.
##
## [param morale] is expected to already be clamped to [0, 100] by the
## caller (ResourceManager clamps Morale on every mutation per TR-res-001).
## This function does NOT re-clamp or validate its input.
##
## Rounding of the *final reward* (not the multiplier itself) uses
## round-half-up, and is the call site's responsibility (Action System /
## Offline Progress System) — this function's job is the multiplier lookup
## only (story-004 scope boundary).
##
## Performance: O(1) discrete branch lookup (no math library calls) —
## negligible relative to the offline simulation loop's confirmed
## sub-millisecond budget even at its 1440-iteration worst case (ADR-0006).
## No profiling required at this scale.
##
## Usage example:
##   var mult: float = ResourceFormulas.action_effectiveness_multiplier(35.0)  # -> 0.75
static func action_effectiveness_multiplier(morale: float) -> float:
	if morale >= E_FULL_THRESHOLD:
		return E_MULT_FULL
	elif morale >= E_HIGH_THRESHOLD:
		return E_MULT_HIGH
	elif morale >= E_LOW_THRESHOLD:
		return E_MULT_LOW
	else:
		return E_MULT_CRITICAL


## Returns the display band label for a Morale value, per resource-system.md's
## Formula C bands — the single source of truth shared by the Resource HUD and
## the Offline Report Screen (both need the same band name, so the boundary
## numbers live here once, never duplicated at a UI call site). Same
## inclusive-lower band boundaries as [method action_effectiveness_multiplier].
##
## Usage example:
##   ResourceFormulas.morale_band_label(35.0)  # -> "Low"
static func morale_band_label(morale: float) -> String:
	if morale >= E_FULL_THRESHOLD:
		return "High"
	elif morale >= E_HIGH_THRESHOLD:
		return "Normal"
	elif morale >= E_LOW_THRESHOLD:
		return "Low"
	else:
		return "Critical"


## Passive Zasięgi/Reach income generated per Hatersi, per minute, before the
## Morale multiplier is applied. Locked tuning constant, per
## resource-system.md's Formula D.
const Z_PER_HATER: float = 0.2

## Returns the passive Zasięgi income accrued over [param elapsed_seconds] of
## idle time (no player action), per resource-system.md's Formula D:
##
##   Z_passive(N, Δt) = N * Z_per_hater * Mult(M) * (Δt / 60)
##
## [param hatersi_count] is the current Hatersi count (N).
## [param morale_mult] is the *already-computed* action effectiveness
## multiplier (Mult(M)) -- the caller is responsible for obtaining this via
## action_effectiveness_multiplier() (Story 004) beforehand. This function
## deliberately takes it as a parameter rather than recomputing it, so it
## stays a pure arithmetic combination of its three inputs with zero
## cross-calls to other formulas in this file (story-005 scope boundary,
## ADR-0006's "no hidden cross-calls" requirement).
## [param elapsed_seconds] is the idle duration in seconds (Δt).
##
## **Signature is locked**: this exact parameter order/types
## (hatersi_count: float, morale_mult: float, elapsed_seconds: float) -> float
## is the contract the future Offline Progress System's simulate_offline()
## loop depends on (ADR-0006) -- do not reorder or retype the parameters
## without updating that call site in lockstep.
##
## This function does NOT clamp or validate any of its inputs -- it trusts
## the caller's contract, consistent with the other formulas in this file.
##
## Performance: O(1) pure float arithmetic (no branches, no math library
## calls) -- negligible relative to the offline simulation loop's confirmed
## sub-millisecond budget even at its 1440-iteration worst case (ADR-0006).
## No profiling required at this scale.
##
## Usage example:
##   var mult: float = ResourceFormulas.action_effectiveness_multiplier(80.0)  # -> 1.0
##   var z: float = ResourceFormulas.passive_zasiegi_income(10.0, mult, 600.0)  # -> 20.0
static func passive_zasiegi_income(hatersi_count: float, morale_mult: float, elapsed_seconds: float) -> float:
	var dt_minutes: float = elapsed_seconds / 60.0
	var result: float = hatersi_count * Z_PER_HATER * morale_mult * dt_minutes
	return result
