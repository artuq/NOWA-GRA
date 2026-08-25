## Integration tests for BurnoutSystem._try_inject_burnout_card() (Burnout &
## Challenge System, Story burnout-challenge-system/002, TR-pcs-007,
## ADR-0013). Covers all 4 Acceptance Criteria from
## story-002-card-injection-guard-rails.md: AC-1 (successful injection),
## AC-2 (deferred injection while DecisionCardSystem is mid-cycle on a normal
## card, no clobbering, retry succeeds once back at COOLDOWN), AC-3 (a failed
## injection is loud -- push_error(), never a silent soft-lock), AC-4
## (regression: once the Burnout Card is PRESENTING, no normal card can
## displace it -- inject_priority_card()'s already-shipped guarantee). Also
## covers this story's own BLOCKING Validation Criterion: CardContentDatabase
## must resolve BurnoutSystem.BURNOUT_CARD_ID to a real, non-empty entry.
##
## BurnoutSystem is normally an Autoload singleton, but for test isolation a
## fresh instance is created directly from the script and never added to the
## scene tree (same technique tests/unit/burnout/burnout_trigger_timer_test.gd
## already established for Story 001) -- _try_inject_burnout_card() is called
## directly, not via the engine's _process() loop.
##
## Unlike burnout_trigger_timer_test.gd, this suite CANNOT isolate
## DecisionCardSystem the same way inject_priority_card_test.gd does (a fresh
## DecisionCardSystemScript.new() instance) -- ADR-0013's own
## _try_inject_burnout_card() pseudocode calls DecisionCardSystem/
## CardContentDatabase by their global Autoload names, not an injected
## reference (matching BurnoutSystem's existing ResourceManager-by-global-name
## precedent from Story 001). So this suite drives the REAL DecisionCardSystem
## Autoload directly, snapshotting and restoring its state/_priority_card_pending/
## _presented_card/_actions_until_check around every test, same "real Autoload,
## manual snapshot/restore" technique prestige_grant_wiring_test.gd already
## established for PrestigeSystem/ClassPathSystem.
extends GdUnitTestSuite

const BurnoutSystemScript: GDScript = preload("res://src/core/burnout_system.gd")

var _bs: Node

var _dcs_state_snapshot: int
var _dcs_priority_pending_snapshot: bool
var _dcs_presented_card_snapshot: Dictionary
var _dcs_actions_until_check_snapshot: int
var _onboarding_phase_snapshot: int


func before_test() -> void:
	_bs = BurnoutSystemScript.new()

	_dcs_state_snapshot = DecisionCardSystem.state
	_dcs_priority_pending_snapshot = DecisionCardSystem._priority_card_pending
	_dcs_presented_card_snapshot = DecisionCardSystem._presented_card.duplicate()
	_dcs_actions_until_check_snapshot = DecisionCardSystem._actions_until_check

	# Real DecisionCardSystem must start every test from a clean COOLDOWN
	# state, regardless of what an earlier suite left behind -- same
	# leakage-tolerant precondition prestige_grant_wiring_test.gd's
	# before_test() establishes for its own Autoloads.
	DecisionCardSystem.state = DecisionCardSystem.State.COOLDOWN
	DecisionCardSystem._priority_card_pending = false
	DecisionCardSystem._presented_card = {}

	# AC-4's real ActionSystem.action_completed emission must not be silently
	# swallowed by OnboardingGate's Phase 1 suppression -- same precedent
	# inject_priority_card_test.gd already established.
	_onboarding_phase_snapshot = OnboardingGate.phase
	OnboardingGate.phase = OnboardingGate.Phase.NORMAL


func after_test() -> void:
	if is_instance_valid(_bs):
		_bs.free()

	DecisionCardSystem.state = _dcs_state_snapshot
	DecisionCardSystem._priority_card_pending = _dcs_priority_pending_snapshot
	DecisionCardSystem._presented_card = _dcs_presented_card_snapshot
	DecisionCardSystem._actions_until_check = _dcs_actions_until_check_snapshot

	OnboardingGate.phase = _onboarding_phase_snapshot


# --- Validation Criterion (ADR-0013, BLOCKING): BURNOUT_CARD_ID must resolve
# to a real CardContentDatabase entry -- the exact silent-soft-lock class
# this story's AC-3 guards against at the call level, guarded here at the
# content-config level. ---

func test_burnout_card_id_resolves_to_a_real_non_empty_card_entry() -> void:
	var card: Dictionary = CardContentDatabase.get_card(BurnoutSystemScript.BURNOUT_CARD_ID)

	assert_bool(card.is_empty()).override_failure_message(
		"BurnoutSystem.BURNOUT_CARD_ID (%s) must resolve to a real CardContentDatabase entry -- " %
		BurnoutSystemScript.BURNOUT_CARD_ID +
		"a mismatch here makes inject_priority_card() return false every time, permanently latching the trigger"
	).is_false()
	assert_str(card["id"]).is_equal("final_burnout")
	assert_array(card["options"]).has_size(2)


# --- AC-1: successful injection ---

func test_ac1_successful_injection_sets_card_pending_and_resets_timer() -> void:
	assert_int(DecisionCardSystem.state).is_equal(DecisionCardSystem.State.COOLDOWN)
	_bs._cringe_sustained_seconds = 300.0
	_bs._card_pending = false

	_bs._try_inject_burnout_card()

	assert_int(DecisionCardSystem.state).override_failure_message(
		"a successful injection must advance DecisionCardSystem to PRESENTING"
	).is_equal(DecisionCardSystem.State.PRESENTING)
	assert_str(DecisionCardSystem._presented_card["id"]).is_equal("final_burnout")
	assert_bool(_bs._card_pending).override_failure_message(
		"_card_pending must be set true only on a successful injection"
	).is_true()
	assert_float(_bs._cringe_sustained_seconds).override_failure_message(
		"the trigger timer must reset to 0.0 only on a successful injection"
	).is_equal_approx(0.0, 0.0001)


# --- AC-2: deferred injection while DecisionCardSystem is mid-cycle, no clobbering ---

func test_ac2_deferred_while_checking_no_clobbering() -> void:
	_assert_deferred_for_state(DecisionCardSystem.State.CHECKING)


func test_ac2_deferred_while_presenting_no_clobbering() -> void:
	_assert_deferred_for_state(DecisionCardSystem.State.PRESENTING)


func test_ac2_deferred_while_resolving_no_clobbering() -> void:
	_assert_deferred_for_state(DecisionCardSystem.State.RESOLVING)


func _assert_deferred_for_state(mid_cycle_state: int) -> void:
	DecisionCardSystem.state = mid_cycle_state
	# A normal card is "in flight" -- present so a clobber would be observable.
	DecisionCardSystem._presented_card = {"id": "hater_callout"}
	_bs._cringe_sustained_seconds = 300.0
	_bs._card_pending = false

	_bs._try_inject_burnout_card()

	assert_bool(_bs._card_pending).override_failure_message(
		"injection must be skipped (not just failed) while DecisionCardSystem is mid-cycle -- state %s" % mid_cycle_state
	).is_false()
	assert_float(_bs._cringe_sustained_seconds).override_failure_message(
		"_cringe_sustained_seconds must NOT reset when injection is deferred -- the trigger condition must stay latched"
	).is_equal_approx(300.0, 0.0001)
	assert_int(DecisionCardSystem.state).override_failure_message(
		"the in-progress normal card's state must be untouched by a deferred injection attempt"
	).is_equal(mid_cycle_state)
	assert_str(DecisionCardSystem._presented_card["id"]).override_failure_message(
		"the in-progress normal card must remain sole -- a deferred injection must never clobber it"
	).is_equal("hater_callout")


## Companion to the 3 deferred-state tests above: once DecisionCardSystem
## returns to COOLDOWN, the very next attempt (same BurnoutSystem instance,
## same still-latched timer) succeeds -- confirms this is a genuine retry,
## not a permanent skip.
func test_ac2_retry_succeeds_once_state_returns_to_cooldown() -> void:
	DecisionCardSystem.state = DecisionCardSystem.State.PRESENTING
	DecisionCardSystem._presented_card = {"id": "hater_callout"}
	_bs._cringe_sustained_seconds = 300.0
	_bs._card_pending = false

	_bs._try_inject_burnout_card()
	assert_bool(_bs._card_pending).is_false()

	# The normal card resolves -- DecisionCardSystem returns to COOLDOWN.
	DecisionCardSystem.state = DecisionCardSystem.State.COOLDOWN
	DecisionCardSystem._presented_card = {}

	_bs._try_inject_burnout_card()

	assert_bool(_bs._card_pending).override_failure_message(
		"a retry once state is back to COOLDOWN must succeed -- the earlier defer must not have permanently blocked injection"
	).is_true()
	assert_int(DecisionCardSystem.state).is_equal(DecisionCardSystem.State.PRESENTING)
	assert_str(DecisionCardSystem._presented_card["id"]).is_equal("final_burnout")


# --- AC-3: failed injection is loud, not silent ---

## Forces the real "a priority card is already pending elsewhere" failure
## path inject_priority_card() itself guards (decision_card_system.gd:274) --
## injects a real other card first (hater_callout) via the actual
## DecisionCardSystem API, leaving _priority_card_pending true, then forces
## state back to COOLDOWN so _try_inject_burnout_card()'s own first guard
## passes and the call actually reaches inject_priority_card(), which then
## fails via ITS OWN already-shipped guard.
##
## NOTE (corrected during code review, 2026-07-17): state==COOLDOWN with
## _priority_card_pending==true is NOT reachable via any real gameplay path
## today -- inject_priority_card() only ever sets _priority_card_pending=true
## in the same synchronous call that sets state=PRESENTING, and only clears
## it in the same synchronous call (resolve_choice()) that sets
## state=COOLDOWN; no yield point exists between either pair, and GDScript is
## single-threaded, so the two fields can never observably disagree this way
## on their own. The `DecisionCardSystem.state = COOLDOWN` line below is a
## manufactured precondition, not a mock -- inject_priority_card() itself is
## still real and unmocked -- but it does not model a scenario
## _try_inject_burnout_card() can hit in production, since its own first
## guard (state != COOLDOWN -> return) already excludes every real case where
## a priority card could be pending. This test exercises
## inject_priority_card()'s general-purpose "already pending" guard as
## defensive/forward-looking coverage (documented as usable by future forced-
## card callers, ADR-0012 §4), not a scenario BurnoutSystem itself can
## currently trigger.
func test_ac3_failed_injection_logs_push_error_and_does_not_soft_lock() -> void:
	var other_injected: bool = DecisionCardSystem.inject_priority_card(&"hater_callout")
	assert_bool(other_injected).is_true()
	assert_bool(DecisionCardSystem._priority_card_pending).is_true()
	# Force the state guard open so the call under test actually reaches
	# inject_priority_card() instead of deferring at the state check.
	DecisionCardSystem.state = DecisionCardSystem.State.COOLDOWN

	_bs._cringe_sustained_seconds = 300.0
	_bs._card_pending = false

	var probe: Callable = func() -> void:
		_bs._try_inject_burnout_card()
	assert_error(probe).is_push_error(any_string())

	assert_bool(_bs._card_pending).override_failure_message(
		"_card_pending must stay false on a failed injection -- this is the exact soft-lock this AC guards against"
	).is_false()
	assert_float(_bs._cringe_sustained_seconds).override_failure_message(
		"_cringe_sustained_seconds must NOT reset on a failed injection -- a retry must remain possible next call"
	).is_equal_approx(300.0, 0.0001)

	# Retry is genuinely possible: once the other pending card is cleared, a
	# subsequent attempt succeeds -- proves this AC's "retries next frame"
	# contract, not just that the false-branch code ran once.
	DecisionCardSystem._priority_card_pending = false
	DecisionCardSystem._presented_card = {}
	_bs._try_inject_burnout_card()
	assert_bool(_bs._card_pending).override_failure_message(
		"once the blocking condition clears, a subsequent attempt must succeed -- no permanent soft-lock"
	).is_true()


# --- AC-4: regression -- Burnout Card presented blocks normal presentation
# via DecisionCardSystem's existing state machine (no new suspension
# mechanism added by this story). Same technique
# inject_priority_card_test.gd::test_priority_card_pending_blocks_normal_pool_presentation()
# already established. ---

func test_ac4_presented_burnout_card_blocks_normal_card_presentation() -> void:
	_bs._cringe_sustained_seconds = 300.0
	_bs._card_pending = false
	_bs._try_inject_burnout_card()
	assert_int(DecisionCardSystem.state).is_equal(DecisionCardSystem.State.PRESENTING)
	assert_str(DecisionCardSystem._presented_card["id"]).is_equal("final_burnout")

	# Well more than the 2-action cooldown threshold -- if presentation were
	# NOT blocked, a normal _check_pool() cycle would already have swapped
	# the Burnout Card out.
	ActionSystem.action_completed.emit(&"test_action", {})
	ActionSystem.action_completed.emit(&"test_action", {})
	ActionSystem.action_completed.emit(&"test_action", {})

	assert_int(DecisionCardSystem.state).override_failure_message(
		"a presented Burnout Card must remain sole -- no normal card may swap in until it resolves"
	).is_equal(DecisionCardSystem.State.PRESENTING)
	assert_str(DecisionCardSystem._presented_card["id"]).is_equal("final_burnout")


# --- Defensive coverage: _try_inject_burnout_card()'s own safety under a
# hypothetical re-entrant call, closing a gap flagged during code review.
# _process()'s call site already guards on `not _card_pending` before ever
# calling this function -- this test proves the function is ALSO safe if
# that external guarantee were ever violated by a future refactor, rather
# than relying purely on cross-invariant reasoning (state==PRESENTING
# whenever _card_pending==true, per the trace in the AC-3 comment above). ---

func test_reentrant_call_while_already_pending_is_a_harmless_no_op() -> void:
	_bs._cringe_sustained_seconds = 300.0
	_bs._card_pending = false
	_bs._try_inject_burnout_card()
	assert_bool(_bs._card_pending).is_true()
	assert_int(DecisionCardSystem.state).is_equal(DecisionCardSystem.State.PRESENTING)

	# Call again directly (bypassing _process()'s `not _card_pending` guard)
	# -- state is PRESENTING, so the function's own COOLDOWN guard must defer,
	# not attempt a second injection.
	_bs._try_inject_burnout_card()

	assert_bool(_bs._card_pending).override_failure_message(
		"a re-entrant call while already pending must remain a no-op, not corrupt state"
	).is_true()
	assert_str(DecisionCardSystem._presented_card["id"]).override_failure_message(
		"a re-entrant call must never inject a second time or swap the presented card"
	).is_equal("final_burnout")


# --- Content contract: the Wypalenie card's two options must carry NO
# resource_deltas/counter_increments -- Story 003 routes the real Choice A/B
# consequences through PrestigeSystem.on_burnout_accepted()/
# on_burnout_deferred(); any nonzero value on the card itself would apply on
# top of Story 003's effects (DecisionCardSystem.resolve_choice() applies
# resource_deltas unconditionally before card_resolved fires). Documented in
# card_content_database.gd's own comment; enforced here so a future edit
# violating it fails loud instead of silently double-applying. ---

func test_final_burnout_card_options_carry_no_resource_deltas_or_counters() -> void:
	var card: Dictionary = CardContentDatabase.get_card(BurnoutSystemScript.BURNOUT_CARD_ID)
	for option: Dictionary in card["options"]:
		assert_dict(option["resource_deltas"]).override_failure_message(
			"Wypalenie card option '%s' must have empty resource_deltas -- Story 003 owns the real effects via PrestigeSystem; a nonzero value here would double-apply" % option.get("label", "?")
		).is_empty()
		assert_dict(option["counter_increments"]).override_failure_message(
			"Wypalenie card option '%s' must have empty counter_increments -- same double-apply risk as resource_deltas" % option.get("label", "?")
		).is_empty()
