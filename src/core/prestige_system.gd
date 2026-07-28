## PrestigeSystem orchestrates the era-transition sequence: it reads Class
## Path state before it is cleared, triggers the reset, computes and grants
## a permanent META_BONUS, and (in later stories) sweeps era-local vs
## meta-persistent flags, then saves and signals.
##
## Implements TR-pcs-001 / ADR-0012 §1-2: registered as a new Core Autoload,
## below ClassPathSystem, DecisionCardSystem, SaveSystem, and
## HistoryFlagManager in Project Settings -> Autoload — PrestigeSystem
## depends on all four; none of them reference PrestigeSystem back
## (one-directional dependency discipline, same precedent ADR-0010 §1
## established for ClassPathSystem).
##
## Story 001 implemented the orchestration skeleton and the read-then-reset
## ordering guarantee. Story 003 filled in step 4: META_BONUS grant
## computation via PrestigeFormulas.grant_magnitude()/
## variety_bonus_increment(). Story 004 wires both grant call sites
## (_apply_grant()/_check_variety_bonus()) through PrestigeFormulas.
## apply_stacking_and_cap() — every grant now clamps at
## PrestigeFormulas.META_BONUS_MAX[bonus_type] (F2, Core Rule 1) instead of
## accumulating unbounded. The four first_burnout_bonus_used[type] flags and
## variety_bonus_used are tracked as HistoryFlagManager milestones (ADR-0012
## §1), same pattern ClassPathSystem uses for its own per-path milestones
## (class_path_system.gd's reset_era_state(), "class_path.{path}.best_tier.
## {N}" naming) — here: "prestige.first_burnout_used.{type}" and
## "prestige.variety_bonus_used". Story 006 adds on_burnout_deferred() —
## Choice B (Defer)'s own, much simpler entry point: a Morale cost via
## ResourceManager's existing clamp plus a "burnout_deferred_era_N"
## HistoryFlagManager milestone, deliberately calling none of Choice A's
## grant machinery. Story 007 (this revision) fills in step 5:
## _sweep_era_local_flags() (Core Rule 7, ADR-0012 §5) — resets the 5
## resources to era-start defaults (Final Burnout quick-spec §4.2) and
## clears the placeholder _deferred_this_era field — immediately followed by
## _apply_sponsors_era_start_override(), the first real call site for
## PrestigeFormulas.sponsors_era_start_override() (F3d, implemented in
## isolation by Story 005, wired in for the first time here). The two calls
## are deliberately kept as separate ResourceManager.apply_delta() calls, in
## that order, so the sweep's own Sponsors=0.0 default write and F3d's
## override write remain independently observable, in order, via
## ResourceManager.resource_changed (AC-3's ordering guarantee).
##
## burnout-challenge-system epic Story 007 (TR-pcs-007, ADR-0013, this
## revision) wires ChallengeSystem.get_combined_meta_multiplier() into step 4
## below, replacing the challenge_mult == 1.0 literal every prior revision of
## this method used (prestige-checkpoint Story 003 onward, back when
## ChallengeSystem did not exist yet). No other line of on_burnout_accepted()
## changes -- this is the epic's only touch to already-shipped PrestigeSystem
## code, per ADR-0013's own framing.
##
## burnout-challenge-system epic Story 008 (TR-pcs-007, ADR-0013 + ADR-0012
## §5, this revision) closes the gap Story 007 above left open:
## _sweep_era_local_flags() now clears ChallengeSystem._active_challenge_ids
## via ChallengeSystem.clear_active_challenges() -- see that method's own doc
## comment for the exact ordering guarantee relative to Story 007's
## challenge_mult read. This is the epic's LAST remaining touch to
## already-shipped PrestigeSystem code; no further stories in this epic
## modify this file.
##
## ADR-0017 (this revision, 2026-07-24 -- implementing an ADR Accepted
## 2026-07-22 that had no code yet): extracted step 4's inline grant-
## computation block into compute_next_grant(path_id, tier) -- a pure
## function, safe to call any number of times, used both for the real grant
## (on_burnout_accepted()) and for a pre-commit UI preview (Wypalenie card)
## without risking the two ever silently diverging. _apply_grant() is
## retired -- its cap math now lives inside compute_next_grant(), and
## on_burnout_accepted() applies the already-post-cap amount directly. A new
## _last_grant field (persisted) caches the most recent real grant's result
## for get_last_grant(), needed by the Challenge Selection screen's era-
## summary recap (design/ux/challenge-selection-screen.md) and by meta-bonus-
## visibility.md's consistency requirement.
##
## Usage example:
##   PrestigeSystem.on_burnout_accepted()  # called by BurnoutSystem's Choice A handler
##   PrestigeSystem.get_meta_bonus_total(&"META_REACH_MULT")  # -> 0.1071 after one grant
extends Node

## Fires only after the full synchronous on_burnout_accepted() sequence
## completes (ADR-0012 §2) — never mid-sequence, never via a deferred call.
signal era_transitioned

## Number of eras completed (transitions triggered by Choice A so far).
## Persisted via serialize_state()/restore_state() (ADR-0003 boot protocol).
var era_count: int = 0

## Permanent, additive-per-type META_BONUS running totals (ADR-0012 §1).
## Keys are the four META_BONUS type StringNames (PrestigeFormulas.
## BASE_INCREMENT's keys); a missing key means "never granted yet" (0.0),
## not an error — always read via get_meta_bonus_total(), never indexed
## directly, so callers get the 0.0 default for free. Each write routes
## through PrestigeFormulas.apply_stacking_and_cap() (Story 004, F2), so a
## value here is always clamped at PrestigeFormulas.META_BONUS_MAX[type] —
## never exceeds it. Persisted via serialize_state()/restore_state().
var meta_bonus_totals: Dictionary[StringName, float] = {}

## Maps each Class Path id to the single META_BONUS type it grants on
## burnout (GDD's meta_bonus_types table / entities.yaml's `active_path`
## field). Fixed at four entries, one per locked Class Path — not a tuning
## knob, not exposed as external config (the pairing is a design identity,
## not a balance number).
const _BONUS_TYPE_BY_PATH: Dictionary[StringName, StringName] = {
	&"pato_streamer": &"META_REACH_MULT",
	&"guru_celebryta": &"META_SPONSOR_MULT",
	&"ekspert_niszowy": &"META_HATERS_RESIST",
	&"biznesmen_contentu": &"META_SPONSOR_FLOOR",
}

## All four META_BONUS types, used by _check_variety_bonus()'s cross-type
## scan (F1b). Kept as a separate list (rather than deriving it from
## _BONUS_TYPE_BY_PATH.values() on every call) for clarity — same four keys
## as PrestigeFormulas.BASE_INCREMENT/META_BONUS_MAX.
const _ALL_BONUS_TYPES: Array[StringName] = [
	&"META_REACH_MULT", &"META_SPONSOR_MULT", &"META_HATERS_RESIST", &"META_SPONSOR_FLOOR",
]

## Story-001-only test-observability hook: the tier value captured in step 1
## of on_burnout_accepted(), before ClassPathSystem.reset_era_state() runs.
## Not part of ADR-0012's Key Interfaces — a real consumer (PrestigeFormulas
## .grant_magnitude()) is added by Story 003/004, at which point this field
## becomes redundant with that call's own argument and may be removed. Exists
## only so this story's tests can prove the read-before-reset ordering
## without a grant computation to spy on yet (AC-1/AC-3 in
## story-001-orchestration-core.md, both of which reference a spy on a value
## that doesn't exist until Story 003/004).
var _last_captured_tier: int = -1

## Story-007-only placeholder for BurnoutSystem's not-yet-implemented
## `_deferred_this_era` (Final Burnout quick-spec §4/6, final-burnout-2026-
## 07-01.md) — BurnoutSystem itself does not exist yet (only that quick-spec
## does), so PrestigeSystem temporarily owns this field as the minimal seam
## _sweep_era_local_flags() needs to have something concrete to clear (this
## story's AC-1). Not part of ADR-0012's Key Interfaces. Same
## test-observability-hook precedent as _last_captured_tier above — tests set
## this directly (matching this codebase's established convention of tests
## reaching into Autoload private fields, e.g. SaveSystem._autosave_
## suppressed) rather than via a dedicated setter. Expected to be removed or
## relocated to a real BurnoutSystem once that system is implemented; this
## field is not this story's design authority on BurnoutSystem's eventual
## shape.
var _deferred_this_era: bool = false

## Caches the most recent real grant computed by on_burnout_accepted() (ADR-
## 0017), queryable via get_last_grant(). Default matches "no burnout has
## ever been accepted yet" -- the same shape compute_next_grant() itself
## returns for a no-active-path call, so callers never need a separate
## first-session branch. Persisted via serialize_state()/restore_state() --
## if the app closes between era_transitioned firing and the Challenge
## Selection screen being confirmed, the recap must still be correct on the
## next boot.
var _last_grant: Dictionary = {"granted": false, "type": &"", "amount": 0.0}

## Era-start resource defaults (Final Burnout quick-spec §4.2, Core Rules ->
## "4. Choice A — Accept Burnout" step 2): the 5 values every resource is
## reset to on every accepted burnout, before F3d's Sponsors override is
## applied on top. Cringe=0/Haters=0/Reach=0/Sponsors=0 zero the era;
## Morale=100 is the one non-zero default (a full-Morale "fresh start", not a
## floor). Declared in this exact key order deliberately — Sponsors last —
## so _sweep_era_local_flags()'s single apply_delta() call emits Sponsors'
## resource_changed signal last among the 5, keeping it unambiguously
## distinct from, and strictly before, _apply_sponsors_era_start_override()'s
## own separate write (AC-3's ordering guarantee).
const _ERA_START_RESOURCE_DEFAULTS: Dictionary[StringName, float] = {
	&"Cringe": 0.0,
	&"Morale": 100.0,
	&"Haters": 0.0,
	&"Reach": 0.0,
	&"Sponsors": 0.0,
}


## Single entry point for "Choice A confirmed" (ADR-0012 §2). Performs the
## era-transition sequence synchronously, in order:
##   1. Read ClassPathSystem's active path + tier BEFORE any reset — this is
##      the exact ordering the GDD flags as bug-prone: reading after reset
##      would silently observe already-zeroed values
##   2. Suppress autosave for the duration of the transition (SaveSystem) —
##      Choice A's resolution is itself a card resolution, which would
##      otherwise be able to autosave mid-sequence
##   3. Reset ClassPathSystem's era-local state
##   4. META_BONUS grant computation (Story 003) + stacking/cap (Story 004):
##      if a path was active, compute this era's grant via
##      PrestigeFormulas.grant_magnitude() and apply it to meta_bonus_totals
##      through PrestigeFormulas.apply_stacking_and_cap() (F2's clamp), then
##      run the cross-type variety-completionist check (F1b), also clamped
##   5. Flag classification sweep (Core Rule 7, Story 007):
##      _sweep_era_local_flags() resets the 5 resources to era-start
##      defaults and clears _deferred_this_era, then
##      _apply_sponsors_era_start_override() applies F3d's Sponsors override
##      (Story 005's formula, wired in here) on top — deliberately AFTER the
##      sweep's own defaults, as two separate writes (AC-3's ordering
##      guarantee)
##   6. Increment era_count, then set the "burnout_accepted_era_N"
##      meta-persistent milestone (N = the post-increment era_count -- the
##      era that just completed) via HistoryFlagManager.set_milestone() --
##      same pattern Choice B's on_burnout_deferred() already uses for its
##      own "burnout_deferred_era_N" (Core Rule 7 AC-2, code-review fix)
##   7. Save, resume autosave, then fire era_transitioned — nothing above
##      this line may yield control before completing
##
## BINDING CONSTRAINT (ADR-0012 §2): zero `await`, zero `CONNECT_DEFERRED`,
## zero `call_deferred` anywhere in this method or anything it calls. This is
## not a style preference — a violation silently breaks the read-before-reset
## ordering guarantee this method exists to provide, with no compile error.
##
## Example:
##   PrestigeSystem.on_burnout_accepted()
func on_burnout_accepted() -> void:
	var path_id: StringName = ClassPathSystem.get_active_path()
	var tier: int = ClassPathSystem.get_tier(path_id) if path_id != &"" else 0
	_last_captured_tier = tier

	SaveSystem.suppress_autosave()

	ClassPathSystem.reset_era_state()
	# Staff is era-local too (team-staff-management.md Core Rule 2): hires are
	# part of what the burnout costs, not an exception to it.
	StaffSystem.reset_era_state()

	# Step 4 (Story 003; extracted into compute_next_grant() by ADR-0017,
	# this revision): META_BONUS grant computation (F1) + variety check
	# (F1b). path_id/tier are the values captured above, BEFORE reset_era_
	# state() -- compute_next_grant() is pure given these explicit inputs,
	# so passing them here (rather than letting it re-fetch internally) is
	# what keeps this call correct after the reset that already ran two
	# lines above (ADR-0017's Engine Specialist Validation finding).
	var grant_result: Dictionary = compute_next_grant(path_id, tier)
	_last_grant = grant_result
	if grant_result["granted"]:
		var bonus_type: StringName = grant_result["type"]
		# amount is ALREADY the post-F2-cap/4b-i-ceiling applied delta (see
		# compute_next_grant()'s own doc comment) -- a single addition, not
		# a second cap computation. Replaces the retired _apply_grant().
		meta_bonus_totals[bonus_type] = meta_bonus_totals.get(bonus_type, 0.0) + grant_result["amount"]
		if _first_burnout_pending(bonus_type):
			HistoryFlagManager.set_milestone(StringName("prestige.first_burnout_used." + String(bonus_type)))
	_check_variety_bonus()  # Core Rule 4c — fires at most once per save

	# Step 5 (Story 007): flag classification sweep (Core Rule 7), then F3d's
	# Sponsors override wired in immediately after — see this method's own
	# doc comment for why the ordering between these two calls is binding.
	_sweep_era_local_flags()
	_apply_sponsors_era_start_override()

	era_count += 1

	# Step 6b (code-review fix, BLOCKING finding, Core Rule 7 AC-2): the
	# "burnout_accepted_era_N" meta-persistent milestone, N = the
	# post-increment era_count (the era that just completed) -- same
	# HistoryFlagManager.set_milestone() pattern Choice B's
	# on_burnout_deferred() already uses for "burnout_deferred_era_N" above.
	# Placed after the increment (unlike Defer, where "current era" and
	# "completed era" are the same value) and before the save, so this
	# milestone is captured by the same save_now() call below.
	HistoryFlagManager.set_milestone(StringName("burnout_accepted_era_" + str(era_count)))

	SaveSystem.save_now()
	SaveSystem.resume_autosave()

	era_transitioned.emit()


## Single entry point for "Choice B (Defer) confirmed" (Story 006, GDD's
## Choice B — Defer, Morale Floor, No Grant). Deliberately NOT a branch
## inside on_burnout_accepted() — ADR-0012 §2 frames Choice A and Choice B as
## distinct paths, and Defer's body is intentionally much smaller: it never
## reads ClassPathSystem, never resets era-local state, and never touches
## meta_bonus_totals/era_count. The Morale-cost mechanic itself
## (BURNOUT_DEFER_MORALE_COST) is owned by BurnoutSystem's own quick-spec
## (final-burnout-2026-07-01.md) — this method accepts the cost as an
## explicit argument rather than importing or hardcoding that constant, so
## PrestigeSystem stays ignorant of BurnoutSystem's tuning (same
## one-directional-dependency discipline as ADR-0012 §1 — BurnoutSystem is
## the future caller, passing its own BURNOUT_DEFER_MORALE_COST).
##
## Performs, in order:
##   1. ResourceManager.apply_delta({&"Morale": -morale_cost}) — Morale is
##      already one of ResourceManager's _CLAMPED_KEYS (floor 0, ceiling
##      100), so this reuses the existing clamp mechanism rather than
##      reimplementing a floor here (GDD AC: "Morale clamps to 0, never
##      negative").
##   2. HistoryFlagManager.set_milestone() writes "burnout_deferred_era_N",
##      N = era_count (Defer does not transition eras — era_count is not
##      incremented here — so "the current era" is simply this field's
##      present value, unlike Choice A's "completed era" framing). Same
##      milestone mechanism as ClassPathSystem's "class_path.{path}.
##      best_tier.{N}" pattern (ADR-0010 §1) and this file's own
##      "prestige.first_burnout_used.{type}" flags — flat "burnout_deferred_
##      era_N" naming (no "prestige." prefix) matches the GDD's own AC
##      wording and final-burnout-2026-07-01.md §5's naming verbatim.
##
## Deliberately does NOT call ClassPathSystem.get_active_path()/get_tier(),
## does NOT call ClassPathSystem.reset_era_state(), does NOT call
## PrestigeFormulas.grant_magnitude()/apply_stacking_and_cap(), and does NOT
## touch meta_bonus_totals or era_count — Choice B grants nothing (GDD Edge
## Cases). tests/unit/prestige/prestige_defer_test.gd's static source-scan
## enforces this at the source level, not just via one test run's observed
## behavior.
##
## Sets _deferred_this_era = true (bug fix, found and fixed during
## burnout-challenge-system Story 003's implementation, 2026-07-19):
## final-burnout-2026-07-01.md §5 step 7 requires this write on every Defer,
## so a second same-era trigger can grey out Choice B (PrestigeSystem.
## has_deferred_this_era(), added by Story 003) — the original
## prestige-checkpoint Story 006/007 implementation declared and cleared this
## field (_sweep_era_local_flags() resets it to false on every accepted
## burnout) but never actually SET it true here, leaving the flag
## permanently false in real gameplay. This one-line addition is the fix;
## prestige_defer_test.gd's existing static source-scan (see that file's own
## header comment) already permits this token -- "_deferred_this_era" was
## never on its forbidden list, only ClassPathSystem/PrestigeFormulas'
## grant-machinery symbols are.
##
## Example:
##   PrestigeSystem.on_burnout_deferred(BurnoutSystem.BURNOUT_DEFER_MORALE_COST)
func on_burnout_deferred(morale_cost: float) -> void:
	ResourceManager.apply_delta({&"Morale": -morale_cost})
	_deferred_this_era = true
	HistoryFlagManager.set_milestone(StringName("burnout_deferred_era_" + str(era_count)))


## Returns true if [param bonus_type] has never received a first-burnout
## grant yet (Core Rule 4b — per-type flag, not global). Backed by a
## HistoryFlagManager milestone, same pattern ClassPathSystem uses for its
## own per-path milestones (ADR-0012 §1).
func _first_burnout_pending(bonus_type: StringName) -> bool:
	return not HistoryFlagManager.has_milestone(StringName("prestige.first_burnout_used." + String(bonus_type)))


## Pure preview/compute function (ADR-0017): given an explicit [param path_id]/
## [param tier] pair, returns exactly what a real grant would apply --
## {"granted": bool, "type": StringName, "amount": float} -- without mutating
## any state. [param path_id]/[param tier] are caller-supplied, NOT fetched
## internally (ClassPathSystem.get_active_path()/get_tier()), specifically so
## this stays correct whether called before ClassPathSystem.reset_era_state()
## (on_burnout_accepted()'s real grant, which captures path_id/tier first) or
## entirely independently of any reset (a pre-commit UI preview, e.g. the
## Wypalenie card, which reads live ClassPathSystem state itself). The caller
## owns capturing path_id/tier at the correct moment -- see this method's own
## Engine Specialist Validation note in ADR-0017 for why an earlier draft that
## fetched internally was wrong.
##
## "amount" is the ACTUAL applied delta -- current_total AFTER
## PrestigeFormulas.apply_stacking_and_cap() (F2's clamp, Core Rule 1) minus
## current_total BEFORE -- not the pre-cap PrestigeFormulas.grant_magnitude()
## raw output. A recap screen showing "amount" must match what actually landed
## in meta_bonus_totals, not an unclamped intermediate value.
##
## Returns {"granted": false, "type": &"", "amount": 0.0} for a no-active-path
## call ([param path_id] == &"") or an unrecognized path id -- distinguishes
## "nothing was granted" from "a grant computed to a small/zero number",
## per prestige-checkpoint-system.md line 254's locked requirement.
##
## challenge_mult/meta_bonus_totals ARE read internally (unlike path_id/tier)
## because reset_era_state() never touches either -- only ClassPathSystem's
## own affiliation state is cleared by that call, so no equivalent ordering
## hazard exists for these two reads.
##
## Example:
##   PrestigeSystem.compute_next_grant(ClassPathSystem.get_active_path(), ClassPathSystem.get_tier(path))
func compute_next_grant(path_id: StringName, tier: int) -> Dictionary:
	if path_id == &"":
		return {"granted": false, "type": &"", "amount": 0.0}
	var bonus_type: StringName = _BONUS_TYPE_BY_PATH.get(path_id, &"")
	if bonus_type == &"":
		return {"granted": false, "type": &"", "amount": 0.0}
	var challenge_mult: float = ChallengeSystem.get_combined_meta_multiplier()
	var is_first: bool = _first_burnout_pending(bonus_type)
	var raw_grant: float = PrestigeFormulas.grant_magnitude(bonus_type, tier, challenge_mult, is_first)
	var current_total: float = meta_bonus_totals.get(bonus_type, 0.0)
	var cap: float = PrestigeFormulas.META_BONUS_MAX[bonus_type]
	var post_cap_total: float = PrestigeFormulas.apply_stacking_and_cap(bonus_type, current_total, raw_grant, cap)
	return {"granted": true, "type": bonus_type, "amount": post_cap_total - current_total}


## Returns the cached result of the most recent real grant computed by
## on_burnout_accepted() (ADR-0017) -- {"granted": false, "type": &"",
## "amount": 0.0} before any burnout has ever been accepted (first-session
## default, same missing-key-default convention as every other peer Autoload
## in this project). Queryable any time after era_transitioned fires --
## needed by the Challenge Selection screen's era-summary recap
## (design/ux/challenge-selection-screen.md) so it shows the exact number the
## Wypalenie card previously previewed via compute_next_grant(), not an
## approximation.
##
## Example:
##   PrestigeSystem.get_last_grant()  # -> {"granted": true, "type": &"META_REACH_MULT", "amount": 0.0107}
func get_last_grant() -> Dictionary:
	return _last_grant


## Cross-type variety-completionist check (GDD Formula F1b, Core Rule 4c).
## Fires at most once per save: the moment all four META_BONUS_total[type]
## values are simultaneously nonzero (checked as a side-effect of every
## accepted-burnout grant, including the very grant that makes the fourth
## type nonzero for the first time — this method runs AFTER step 4's grant
## application in on_burnout_accepted(), never before), each of the four types
## additionally receives PrestigeFormulas.variety_bonus_increment(type), and
## the "prestige.variety_bonus_used" milestone is set so this never fires
## again. Same F2 clamp as compute_next_grant()'s own cap (ADR-0017): each type's flat
## variety increment is applied through PrestigeFormulas.
## apply_stacking_and_cap() too, so a type already at its cap when the
## completionist bonus fires absorbs its share with zero effect, same as any
## other grant (AC-11 — variety_bonus_increment() itself is cap-agnostic by
## design; this loop is what layers F2's clamp on top).
func _check_variety_bonus() -> void:
	if HistoryFlagManager.has_milestone(&"prestige.variety_bonus_used"):
		return
	for bonus_type: StringName in _ALL_BONUS_TYPES:
		if meta_bonus_totals.get(bonus_type, 0.0) <= 0.0:
			return
	for bonus_type: StringName in _ALL_BONUS_TYPES:
		var current_total: float = meta_bonus_totals.get(bonus_type, 0.0)
		var cap: float = PrestigeFormulas.META_BONUS_MAX[bonus_type]
		var increment: float = PrestigeFormulas.variety_bonus_increment(bonus_type)
		meta_bonus_totals[bonus_type] = PrestigeFormulas.apply_stacking_and_cap(bonus_type, current_total, increment, cap)
	HistoryFlagManager.set_milestone(&"prestige.variety_bonus_used")


## Core Rule 7 (ADR-0012 §5): clears every era-local flag, delegating the
## actual clear mechanics to their owning system's existing API — this
## method's only job is to know WHICH flags are era-local, never to
## reimplement how each one is stored/cleared.
##
## Covers exactly what's left after ClassPathSystem.reset_era_state()
## (already called earlier in on_burnout_accepted(), ADR-0010) clears its own
## era-local affiliation/tier/counters:
##   - the 5 resources -> _ERA_START_RESOURCE_DEFAULTS, via ResourceManager.
##     apply_delta() — ResourceManager has no absolute-set API by design
##     (apply_delta() is its sole write path, ADR-0001), so each target is
##     expressed as a delta from the resource's current value. All 5 deltas
##     are submitted in ONE apply_delta() call, in _ERA_START_RESOURCE_
##     DEFAULTS' declared key order (Sponsors last), so this call's Sponsors
##     resource_changed emission always completes, in full, before
##     _apply_sponsors_era_start_override()'s own separate call runs (that
##     ordering is guaranteed by plain sequential execution — two distinct
##     statements in on_burnout_accepted() — not by anything inside this
##     method itself).
##   - BurnoutSystem._deferred_this_era -> false, via the placeholder
##     _deferred_this_era field (see that field's own doc comment for why
##     PrestigeSystem temporarily owns it).
##   - ChallengeSystem._active_challenge_ids -> cleared, via
##     ChallengeSystem.clear_active_challenges() (burnout-challenge-system
##     epic Story 008, TR-pcs-007, ADR-0013 + ADR-0012 §5, this revision).
##     Placed AFTER the resource reset and _deferred_this_era clear, as the
##     last step of the sweep — no ordering dependency exists between it and
##     either of those, but it must run strictly after step 4's
##     ChallengeSystem.get_combined_meta_multiplier() read earlier in
##     on_burnout_accepted() (Story 007), which it already does by
##     construction: this sweep is called after step 4 completes, so the
##     multiplier is always consumed before this clear runs (this story's own
##     AC-3/AC-4 ordering regression check).
##
## Explicitly does NOT touch: Class Path affiliation/tier/counters (already
## cleared by reset_era_state(), not this sweep's job), or any meta-persistent flag
## (era_count, META_BONUS_totals, first_burnout_bonus_used[type],
## variety_bonus_used, burnout_accepted_era_N/burnout_deferred_era_N, Class
## Path's best_tier_reached/eras_spent_as milestones) — preserved by
## omission. There is no separate "preserve" call; the absence of a clear
## call IS the preservation mechanism (ADR-0012 §5). (burnout_accepted_era_N
## itself IS actively written -- by on_burnout_accepted() directly, after
## era_count += 1, not by this sweep -- see that method's own step 6 doc
## comment; this sweep's job is only to not clear it.)
##
## Idempotent by construction: a resource already sitting at its era-start
## default simply produces a zero delta (apply_delta() still emits
## resource_changed unconditionally for every key in the call, but the value
## doesn't change) — calling this twice in a row, or once on already-fresh
## state, never errors and never overshoots.
func _sweep_era_local_flags() -> void:
	var deltas: Dictionary[StringName, float] = {}
	for key: StringName in _ERA_START_RESOURCE_DEFAULTS:
		deltas[key] = _ERA_START_RESOURCE_DEFAULTS[key] - ResourceManager.get_resource(key)
	ResourceManager.apply_delta(deltas)

	_deferred_this_era = false

	ChallengeSystem.clear_active_challenges()


## Applies GDD Formula F3d's era-start Sponsors override on top of the
## sweep's own Sponsors=0.0 default (Core Rule 7 / AC-3): MUST run after
## _sweep_era_local_flags() in on_burnout_accepted(), as a separate
## ResourceManager.apply_delta() call — never merged into the sweep's own
## batch — so the two Sponsors writes stay independently observable, in
## order, via ResourceManager.resource_changed. Story 005 implemented
## PrestigeFormulas.sponsors_era_start_override() in isolation and explicitly
## deferred wiring its call site to this story (see that function's own doc
## comment) — this is that wiring, and only that; the formula itself is
## unmodified (Out of Scope).
##
## Reads meta_bonus_totals AFTER this era's own grant (step 4, already ran
## earlier in on_burnout_accepted()) — so if biznesmen_contentu was the
## active path this era, its own META_SPONSOR_FLOOR grant is already
## reflected in the total this override reads, matching F3d's intent (the
## override always reflects the CURRENT running total, not a stale
## pre-grant snapshot).
func _apply_sponsors_era_start_override() -> void:
	var floor_total: float = get_meta_bonus_total(&"META_SPONSOR_FLOOR")
	var override_value: float = PrestigeFormulas.sponsors_era_start_override(floor_total)
	var delta: float = override_value - ResourceManager.get_resource(&"Sponsors")
	ResourceManager.apply_delta({&"Sponsors": delta})


## Returns the number of eras completed so far.
func get_era_count() -> int:
	return era_count


## Returns [param bonus_type]'s current permanent running total, or `0.0` if
## it has never been granted yet (ADR-0012 Key Interfaces). Always safe to
## call with any of the four META_BONUS type StringNames, even before the
## first grant.
##
## Example:
##   PrestigeSystem.get_meta_bonus_total(&"META_REACH_MULT")  # -> 0.0 before any grant
func get_meta_bonus_total(bonus_type: StringName) -> float:
	return meta_bonus_totals.get(bonus_type, 0.0)


## Whether Choice B (Defer) has already been used this era. BurnoutSystem
## reads this to grey out the Defer option on a second same-era trigger
## (quick-spec final-burnout-2026-07-01.md §5) -- PrestigeSystem owns
## _deferred_this_era (Story 007, prestige-checkpoint epic), this is its only
## external read access. Added by burnout-challenge-system Story 003
## (TR-pcs-007), same minimal-getter pattern as get_era_count()/
## get_meta_bonus_total() above -- no signature change to
## on_burnout_accepted()/on_burnout_deferred().
func has_deferred_this_era() -> bool:
	return _deferred_this_era


## Restores persisted state per the ADR-0003 boot protocol, called by
## BootController after ClassPathSystem.restore_state() (no ordering
## dependency between the two at boot time). Story 003 scope adds
## meta_bonus_totals (Dictionary, String keys per the JSON-serialization
## convention ADR-0002/ADR-0010 already established — StringName is not a
## JSON type) to Story 001's era_count. The four first_burnout_bonus_used
## [type]/variety_bonus_used flags are HistoryFlagManager milestones (ADR-
## 0012 §1) and are restored through HistoryFlagManager's own existing
## restore path, not duplicated here. Missing keys default safely (`0` era
## count, empty totals dict — first-session case, `data == {}`).
##
## Example:
##   PrestigeSystem.restore_state(data.get("prestige", {}))
func restore_state(data: Dictionary) -> void:
	era_count = int(data.get("era_count", 0))
	meta_bonus_totals.clear()
	var totals_in: Dictionary = data.get("meta_bonus_totals", {})
	for key in totals_in:
		meta_bonus_totals[StringName(key)] = float(totals_in[key])
	# ADR-0017: _last_grant, StringName type re-encoded from plain String same
	# as every other StringName field in this method. Missing key (saves
	# predating this field) defaults to the same "nothing granted yet" shape
	# _last_grant itself already defaults to -- no separate first-session branch.
	var grant_in: Dictionary = data.get("_last_grant", {"granted": false, "type": "", "amount": 0.0})
	_last_grant = {
		"granted": bool(grant_in.get("granted", false)),
		"type": StringName(grant_in.get("type", "")),
		"amount": float(grant_in.get("amount", 0.0)),
	}


## Serializes persisted state for SaveSystem.save_now(). Story 003 scope
## adds meta_bonus_totals (plain String keys — see restore_state()'s doc
## comment) to Story 001's era_count. ADR-0017 (this revision) adds
## _last_grant, its "type" field re-encoded as plain String (StringName is
## not a JSON type, same convention as meta_bonus_totals' keys).
##
## Example:
##   var data: Dictionary = PrestigeSystem.serialize_state()
func serialize_state() -> Dictionary:
	var totals_out: Dictionary = {}
	for key: StringName in meta_bonus_totals:
		totals_out[String(key)] = meta_bonus_totals[key]
	var grant_out: Dictionary = {
		"granted": _last_grant["granted"],
		"type": String(_last_grant["type"]),
		"amount": _last_grant["amount"],
	}
	return {"era_count": era_count, "meta_bonus_totals": totals_out, "_last_grant": grant_out}
