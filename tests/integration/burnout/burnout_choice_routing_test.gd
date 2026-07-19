## Integration tests for BurnoutSystem._ready()/_on_card_resolved() (Burnout &
## Challenge System, Story burnout-challenge-system/003, TR-pcs-007,
## ADR-0013's Decision section, story-readiness-corrected 2026-07-19). Covers
## all 5 Acceptance Criteria from story-003-choice-routing.md: AC-1 (Accept
## routes to PrestigeSystem.on_burnout_accepted()), AC-2 (Defer routes to
## PrestigeSystem.on_burnout_deferred()), AC-3 (any other card is ignored),
## AC-4 (PrestigeSystem.has_deferred_this_era() getter exists and reflects
## live/era-reset state), AC-5 (the two _OPTION_LABEL_* consts exactly match
## CardContentDatabase's real final_burnout entry -- a label-drift regression
## test).
##
## Testing technique for _ready()'s new DecisionCardSystem.card_resolved.
## connect() wiring (docs/tech-debt-register.md, Story 001 entry, flagged this
## exact gap: prior BurnoutSystem suites never add_child()'d their instances
## since there was no _ready() to exercise):
##   - Every test in this suite add_child()s a fresh BurnoutSystem instance in
##     before_test() -- _ready() runs synchronously as part of add_child()
##     (the parent, this test suite node, is already inside the SceneTree),
##     so the real DecisionCardSystem.card_resolved connection is established
##     for every single test here, not skipped.
##   - Immediately after add_child(), _bs.set_process(false) disables Story
##     001/002's inherited _process() trigger-timer logic -- this suite never
##     drives or asserts on that behavior (see burnout_trigger_timer_test.gd/
##     burnout_card_injection_test.gd for that coverage), and leaving
##     _process() live risks a stray real frame elapsing between this suite's
##     synchronous tests (GdUnit4's async runner may process a frame between
##     test functions) reading the REAL ResourceManager Cringe value and
##     force-injecting a card on the real DecisionCardSystem Autoload as an
##     unrelated side effect. set_process(false) does not touch _ready() --
##     that has already run by the time this line executes.
##   - Most tests below call _bs._on_card_resolved(...) DIRECTLY -- isolated,
##     deterministic coverage of the routing logic itself, same "drive the
##     handler directly" precedent as burnout_trigger_timer_test.gd/
##     burnout_card_injection_test.gd.
##   - test_ready_wiring_real_signal_emission_routes_through_to_prestige_system()
##     below is the dedicated, unambiguous proof the REAL signal connection
##     fires: it emits DecisionCardSystem.card_resolved directly (never
##     calling _bs._on_card_resolved() itself) and observes PrestigeSystem.
##     era_count/era_transitioned change -- nothing else listens to
##     card_resolved and calls into PrestigeSystem, so this can only happen if
##     _ready()'s connection is real and live.
##
## PrestigeSystem/ResourceManager/HistoryFlagManager/ClassPathSystem/
## SaveSystem are real Autoload singletons with no dependency-injection seam
## (ADR-0001) -- same "real Autoload, manual snapshot/restore" technique
## prestige_grant_wiring_test.gd/prestige_defer_test.gd already established.
## "Spy on PrestigeSystem.on_burnout_accepted()/on_burnout_deferred()" is not
## achievable via GdUnit4 (singleton spying is explicitly refused, see
## prestige_defer_test.gd's own header comment) -- this suite substitutes
## real, unambiguous behavioral side effects instead: era_count incrementing
## / era_transitioned firing exactly once for Accept, a Morale delta of
## exactly BURNOUT_DEFER_MORALE_COST plus a burnout_deferred_era_N milestone
## for Defer, and neither for an ignored card.
##
## KNOWN GAP FOUND AND FIXED DURING THIS STORY'S IMPLEMENTATION (2026-07-19):
## prestige-checkpoint Story 006/007's shipped on_burnout_deferred() declared
## and cleared _deferred_this_era but never actually set it true on Defer --
## final-burnout-2026-07-01.md §5 step 7 requires it. Confirmed against the
## source quick-spec and fixed as a one-line addition to
## src/core/prestige_system.gd's on_burnout_deferred() in this same change
## (in scope as a bug fix, not a deviation -- see that method's own updated
## doc comment). AC-4's tests below exercise the REAL, now-fixed
## on_burnout_deferred() end to end, per the story's own QA Test Cases
## wording ("real call, not mocked").
extends GdUnitTestSuite

const BurnoutSystemScript: GDScript = preload("res://src/core/burnout_system.gd")

var _bs: Node

var _era_count_snapshot: int
var _meta_totals_snapshot: Dictionary
var _deferred_this_era_snapshot: bool
var _morale_snapshot: float


func before_test() -> void:
	_era_count_snapshot = PrestigeSystem.era_count
	_meta_totals_snapshot = PrestigeSystem.meta_bonus_totals.duplicate()
	_deferred_this_era_snapshot = PrestigeSystem._deferred_this_era
	_morale_snapshot = ResourceManager.get_resource(&"Morale")

	ClassPathSystem.reset_era_state()
	SaveSystem._debounce_timer.stop()
	SaveSystem._autosave_suppressed = false

	_bs = BurnoutSystemScript.new()
	add_child(_bs)
	# _ready() already ran synchronously above (this suite node is already
	# inside the SceneTree) -- the real DecisionCardSystem.card_resolved
	# connection is live. Disabling _process() here only stops Story 001/002's
	# inherited per-frame trigger-timer logic from firing on a stray frame
	# between this suite's tests; see this file's header comment.
	_bs.set_process(false)


func after_test() -> void:
	if is_instance_valid(_bs):
		# queue_free() alone is not enough here: it defers the actual free (and
		# therefore the automatic signal disconnection that comes with it) to
		# an idle frame that may not have happened yet by the time the NEXT
		# test's before_test() runs a fresh add_child() -- confirmed by a real
		# failure during this suite's own development, where a later test's
		# real DecisionCardSystem.card_resolved.emit() call was independently
		# handled by multiple still-connected instances from earlier tests,
		# inflating a single expected on_burnout_accepted() call into three.
		# Disconnecting explicitly here guarantees the real signal never
		# reaches a torn-down test instance, regardless of GdUnit4's own
		# inter-test frame timing.
		if DecisionCardSystem.card_resolved.is_connected(_bs._on_card_resolved):
			DecisionCardSystem.card_resolved.disconnect(_bs._on_card_resolved)
		_bs.queue_free()

	PrestigeSystem.restore_state({
		"era_count": _era_count_snapshot,
		"meta_bonus_totals": _meta_totals_snapshot,
	})
	PrestigeSystem._deferred_this_era = _deferred_this_era_snapshot

	var morale_delta: float = _morale_snapshot - ResourceManager.get_resource(&"Morale")
	ResourceManager.apply_delta({&"Morale": morale_delta})

	ClassPathSystem.reset_era_state()
	SaveSystem._debounce_timer.stop()
	SaveSystem._autosave_suppressed = false


## Connects a spy to PrestigeSystem.era_transitioned, runs [param action], and
## returns how many times it fired -- on_burnout_accepted() is the only
## caller of era_transitioned.emit(), so this is this suite's real-behavior
## substitute for a call-count spy on a singleton (see this file's header
## comment).
func _count_era_transitions(action: Callable) -> int:
	var emissions: Array = []
	var spy: Callable = func() -> void: emissions.append(true)
	PrestigeSystem.era_transitioned.connect(spy)
	action.call()
	PrestigeSystem.era_transitioned.disconnect(spy)
	return emissions.size()


# --- AC-1: Accept routes to PrestigeSystem.on_burnout_accepted(), _card_pending cleared ---

func test_ac1_accept_clears_card_pending_and_calls_on_burnout_accepted_exactly_once() -> void:
	_bs._card_pending = true
	var era_before: int = PrestigeSystem.era_count

	var transition_count: int = _count_era_transitions(
		func() -> void:
			_bs._on_card_resolved(BurnoutSystemScript.BURNOUT_CARD_ID, &"", BurnoutSystemScript._OPTION_LABEL_ACCEPT)
	)

	assert_bool(_bs._card_pending).override_failure_message(
		"_card_pending must be cleared to false when the Accept branch runs"
	).is_false()
	assert_int(transition_count).override_failure_message(
		"exactly one era_transitioned emission means PrestigeSystem.on_burnout_accepted() was called exactly once -- it is the only source of that signal"
	).is_equal(1)
	assert_int(PrestigeSystem.era_count).override_failure_message(
		"on_burnout_accepted() must have actually run (era_count incremented), not just emitted the signal"
	).is_equal(era_before + 1)


## Ordering guarantee (AC-1's own wording: "in that order, same frame, same
## call stack"): _card_pending must already be false by the time
## on_burnout_accepted() reaches era_transitioned.emit() -- the only way this
## can be observed given _on_card_resolved()'s single-threaded, sequential
## body is to probe _card_pending from inside a callback connected to
## era_transitioned itself, proving the write happened strictly before the
## call that ends with this emission.
func test_ac1_card_pending_already_false_by_the_time_era_transitioned_fires() -> void:
	_bs._card_pending = true
	var observed: Array = []
	var probe: Callable = func() -> void: observed.append(_bs._card_pending)
	PrestigeSystem.era_transitioned.connect(probe)

	_bs._on_card_resolved(BurnoutSystemScript.BURNOUT_CARD_ID, &"", BurnoutSystemScript._OPTION_LABEL_ACCEPT)

	PrestigeSystem.era_transitioned.disconnect(probe)
	assert_array(observed).has_size(1)
	assert_bool(observed[0]).override_failure_message(
		"_card_pending must already be false by the time on_burnout_accepted() finishes and fires era_transitioned"
	).is_false()


# --- AC-2: Defer routes to PrestigeSystem.on_burnout_deferred(BURNOUT_DEFER_MORALE_COST) ---

func test_ac2_defer_clears_card_pending_and_calls_on_burnout_deferred_with_correct_cost() -> void:
	ResourceManager.apply_delta({&"Morale": 80.0 - ResourceManager.get_resource(&"Morale")})
	_bs._card_pending = true
	var era_before: int = PrestigeSystem.era_count
	var morale_before: float = ResourceManager.get_resource(&"Morale")

	var transition_count: int = _count_era_transitions(
		func() -> void:
			_bs._on_card_resolved(BurnoutSystemScript.BURNOUT_CARD_ID, &"", BurnoutSystemScript._OPTION_LABEL_DEFER)
	)

	assert_bool(_bs._card_pending).override_failure_message(
		"_card_pending must be cleared to false when the Defer branch runs"
	).is_false()
	assert_int(transition_count).override_failure_message(
		"Defer must never call on_burnout_accepted() -- era_transitioned must not fire"
	).is_equal(0)
	assert_int(PrestigeSystem.era_count).override_failure_message(
		"Defer must never transition eras"
	).is_equal(era_before)
	assert_float(ResourceManager.get_resource(&"Morale")).override_failure_message(
		"on_burnout_deferred() must be called with exactly BURNOUT_DEFER_MORALE_COST"
	).is_equal_approx(morale_before - BurnoutSystemScript.BURNOUT_DEFER_MORALE_COST, 0.0001)
	assert_bool(HistoryFlagManager.has_milestone(StringName("burnout_deferred_era_" + str(era_before)))).override_failure_message(
		"the real on_burnout_deferred() must have run its own milestone write, not just clamped Morale"
	).is_true()


# --- AC-3: any other card is ignored -- no PrestigeSystem call, _card_pending untouched ---

func test_ac3_other_card_id_takes_no_action() -> void:
	_bs._card_pending = true
	var era_before: int = PrestigeSystem.era_count
	var morale_before: float = ResourceManager.get_resource(&"Morale")

	var transition_count: int = _count_era_transitions(
		func() -> void:
			_bs._on_card_resolved(&"hater_callout", &"", &"Some Other Label")
	)

	assert_bool(_bs._card_pending).override_failure_message(
		"_card_pending must remain untouched for a card_id != BURNOUT_CARD_ID"
	).is_true()
	assert_int(transition_count).is_equal(0)
	assert_int(PrestigeSystem.era_count).is_equal(era_before)
	assert_float(ResourceManager.get_resource(&"Morale")).is_equal_approx(morale_before, 0.0001)


## Companion case: _card_pending starting false must also stay false (not
## flipped true) for an ignored card -- proves "untouched", not just "stays
## whatever true value it happened to have".
func test_ac3_other_card_id_leaves_card_pending_false_when_it_started_false() -> void:
	_bs._card_pending = false

	_bs._on_card_resolved(&"staged_drama", &"", &"Whatever")

	assert_bool(_bs._card_pending).is_false()


# --- AC-4: PrestigeSystem.has_deferred_this_era() getter exists, reflects real state ---

## Exercises the REAL, now-fixed on_burnout_deferred() (see this file's
## header comment -- prestige-checkpoint Story 006/007's on_burnout_deferred()
## was missing the _deferred_this_era = true write required by
## final-burnout-2026-07-01.md §5 step 7; fixed in the same change as this
## story). Matches the story's own QA Test Cases wording exactly: "real call,
## not mocked".
func test_ac4_real_on_burnout_deferred_call_sets_has_deferred_this_era_true() -> void:
	PrestigeSystem._deferred_this_era = false

	PrestigeSystem.on_burnout_deferred(10.0)

	assert_bool(PrestigeSystem.has_deferred_this_era()).override_failure_message(
		"a real on_burnout_deferred() call must set _deferred_this_era = true, readable via has_deferred_this_era()"
	).is_true()


## Story 006/007's own era-reset semantics: _sweep_era_local_flags() (run
## inside on_burnout_accepted()) clears _deferred_this_era back to false --
## has_deferred_this_era() must reflect that live, not a value cached at
## Defer time.
func test_ac4_has_deferred_this_era_resets_to_false_after_a_subsequent_accepted_era() -> void:
	PrestigeSystem.on_burnout_deferred(10.0)
	assert_bool(PrestigeSystem.has_deferred_this_era()).is_true()

	PrestigeSystem.on_burnout_accepted()

	assert_bool(PrestigeSystem.has_deferred_this_era()).override_failure_message(
		"has_deferred_this_era() must return false again after a subsequent accepted era resets _deferred_this_era -- not a stale cached value"
	).is_false()


## Routing-level companion to the two tests above: BurnoutSystem's own Defer
## branch (not a direct PrestigeSystem call) must also result in
## has_deferred_this_era() becoming readable as true -- proves the getter is
## useful from BurnoutSystem's actual call path, not just PrestigeSystem's
## own API in isolation.
func test_ac4_has_deferred_this_era_reflects_burnout_system_routed_defer() -> void:
	PrestigeSystem._deferred_this_era = false
	_bs._card_pending = true

	_bs._on_card_resolved(BurnoutSystemScript.BURNOUT_CARD_ID, &"", BurnoutSystemScript._OPTION_LABEL_DEFER)

	assert_bool(PrestigeSystem.has_deferred_this_era()).override_failure_message(
		"has_deferred_this_era() must return true after BurnoutSystem routes a Defer through to the real on_burnout_deferred()"
	).is_true()


# --- AC-5: label-drift regression test -- consts must match the real CardContentDatabase entry ---

func test_ac5_option_label_consts_match_real_card_content_database_entry() -> void:
	var card: Dictionary = CardContentDatabase.get_card(BurnoutSystemScript.BURNOUT_CARD_ID)
	assert_bool(card.is_empty()).is_false()
	assert_array(card["options"]).has_size(2)

	var labels: Array = []
	for option: Dictionary in card["options"]:
		labels.append(option["label"])

	assert_bool(labels.has(String(BurnoutSystemScript._OPTION_LABEL_ACCEPT))).override_failure_message(
		"BurnoutSystem._OPTION_LABEL_ACCEPT ('%s') must exactly match one of final_burnout's real option labels %s -- a drift here silently no-ops the Accept branch" %
		[BurnoutSystemScript._OPTION_LABEL_ACCEPT, labels]
	).is_true()
	assert_bool(labels.has(String(BurnoutSystemScript._OPTION_LABEL_DEFER))).override_failure_message(
		"BurnoutSystem._OPTION_LABEL_DEFER ('%s') must exactly match one of final_burnout's real option labels %s -- a drift here silently no-ops the Defer branch" %
		[BurnoutSystemScript._OPTION_LABEL_DEFER, labels]
	).is_true()


## Companion to AC-5: an unrecognized third value must push_error(), not
## silently fall into either branch (story-readiness-time correction --
## explicit if/elif/else, not ADR-0013's original simplified if/else). Also
## confirms _card_pending still clears and neither PrestigeSystem entry point
## fires on a drifted/garbage label.
func test_unrecognized_option_chosen_pushes_error_and_calls_neither_prestige_entry_point() -> void:
	_bs._card_pending = true
	var era_before: int = PrestigeSystem.era_count
	var morale_before: float = ResourceManager.get_resource(&"Morale")

	var probe: Callable = func() -> void:
		_bs._on_card_resolved(BurnoutSystemScript.BURNOUT_CARD_ID, &"", &"Some Drifted Label")
	assert_error(probe).is_push_error(any_string())

	assert_bool(_bs._card_pending).override_failure_message(
		"_card_pending must still clear even on an unrecognized option_chosen -- the card DID resolve, it just couldn't be routed"
	).is_false()
	assert_int(PrestigeSystem.era_count).is_equal(era_before)
	assert_float(ResourceManager.get_resource(&"Morale")).is_equal_approx(morale_before, 0.0001)


# --- _ready() wiring proof: the REAL DecisionCardSystem.card_resolved signal, not a direct call ---

## Unambiguous proof _ready() really connects _on_card_resolved() to the REAL
## DecisionCardSystem.card_resolved signal IN PRODUCTION: drives the REAL
## BurnoutSystem Autoload singleton, not the fresh add_child()'d _bs test
## instance used by every other test in this suite.
##
## Deliberately NOT using _bs here (found during this suite's own
## development, via a real test failure): BurnoutSystem is itself a
## registered Autoload (project.godot), so its own genuine _ready() already
## connected it to the real DecisionCardSystem.card_resolved signal at engine
## boot, fully independently of this suite's fresh _bs instances. Emitting
## the real signal with a fresh _bs ALSO connected means the real Autoload's
## listener reacts too -- two independent, real _on_card_resolved() calls
## both routing to the real PrestigeSystem.on_burnout_accepted(), inflating a
## single expected era_transitioned emission into two. Driving the real
## Autoload singleton directly sidesteps that double-count entirely, and is
## arguably the more faithful proof of this AC anyway: it demonstrates the
## actual production object's _ready() wiring, not a synthetic double's.
func test_ready_wiring_real_signal_emission_routes_through_to_prestige_system() -> void:
	# before_test() unconditionally add_child()s a fresh _bs for every test in
	# this suite (including this one) -- that instance is unused here (this
	# test drives the real Autoload instead, see this function's own doc
	# comment) but its _ready() has still connected it to the same real
	# signal, so it must be disconnected here too or it would independently
	# react to the emission below, inflating the expected count of 1 to 2.
	DecisionCardSystem.card_resolved.disconnect(_bs._on_card_resolved)

	var card_pending_snapshot: bool = BurnoutSystem._card_pending
	BurnoutSystem._card_pending = true
	var era_before: int = PrestigeSystem.era_count

	var transition_count: int = _count_era_transitions(
		func() -> void:
			DecisionCardSystem.card_resolved.emit(BurnoutSystemScript.BURNOUT_CARD_ID, &"", BurnoutSystemScript._OPTION_LABEL_ACCEPT)
	)

	assert_int(transition_count).override_failure_message(
		"_ready()'s DecisionCardSystem.card_resolved.connect(_on_card_resolved) must route a REAL signal emission through to PrestigeSystem.on_burnout_accepted() -- zero emissions means the connection never fired"
	).is_equal(1)
	assert_int(PrestigeSystem.era_count).is_equal(era_before + 1)
	assert_bool(BurnoutSystem._card_pending).override_failure_message(
		"the REAL BurnoutSystem Autoload's own _card_pending must clear via its real _on_card_resolved(), not this suite's synthetic _bs instance"
	).is_false()

	BurnoutSystem._card_pending = card_pending_snapshot


## Low-blast-radius companion: a real signal emission for a non-Wypalenie card
## must reach the real connection and correctly no-op (proven together with
## the test above, which proves the connection positively fires for the
## Wypalenie card) -- confirms the same real wiring doesn't over-fire for
## every card_resolved emission, only the one it owns.
func test_ready_wiring_real_signal_emission_ignores_non_burnout_card() -> void:
	_bs._card_pending = true
	var era_before: int = PrestigeSystem.era_count
	var morale_before: float = ResourceManager.get_resource(&"Morale")

	DecisionCardSystem.card_resolved.emit(&"hater_callout", &"", &"Some Label")

	assert_bool(_bs._card_pending).is_true()
	assert_int(PrestigeSystem.era_count).is_equal(era_before)
	assert_float(ResourceManager.get_resource(&"Morale")).is_equal_approx(morale_before, 0.0001)
