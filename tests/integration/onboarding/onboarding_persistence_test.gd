## Interaction tests for OnboardingGate's persistence (Story 003, Onboarding/
## Tutorial epic): serialize_state()/restore_state(), the SaveSystem.save_now()
## payload, and BootController wiring. Uses a fresh OnboardingGateScript
## instance for serialize/restore round-trips (no Autoload-state isolation
## needed there) and the real Autoloads for the SaveSystem/BootController
## integration points.
extends GdUnitTestSuite

const OnboardingGateScript: GDScript = preload("res://src/core/onboarding_gate.gd")
const SaveSystemScript: GDScript = preload("res://src/core/save_system.gd")

const VLOG: StringName = &"nagraj_vloga"
const DRAMA: StringName = &"zrob_drame"
const APOLOGY: StringName = &"przeprosiny"

var _onboarding_phase_snapshot: int
var _completed_types_snapshot: Dictionary
var _skill_challenge_intro_snapshot: bool
var _seen_skill_challenges_snapshot: Dictionary[StringName, bool]
var _seen_showcase_cards_snapshot: Dictionary[StringName, bool]

func before_test() -> void:
	_onboarding_phase_snapshot = OnboardingGate.phase
	_completed_types_snapshot = OnboardingGate._completed_types.duplicate()
	_skill_challenge_intro_snapshot = OnboardingGate._skill_challenge_intro_seen
	_seen_skill_challenges_snapshot = OnboardingGate._seen_skill_challenges.duplicate()
	_seen_showcase_cards_snapshot = OnboardingGate._seen_showcase_cards.duplicate()

func after_test() -> void:
	OnboardingGate.phase = _onboarding_phase_snapshot
	OnboardingGate._completed_types = _completed_types_snapshot
	OnboardingGate._skill_challenge_intro_seen = _skill_challenge_intro_snapshot
	OnboardingGate._seen_skill_challenges = _seen_skill_challenges_snapshot
	OnboardingGate._seen_showcase_cards = _seen_showcase_cards_snapshot
	SaveSystem._debounce_timer.stop()

## AC: mid-phase save/restore -- 1 of 3 types completed, captured and restored,
## stays PURE_ACTION with exactly that one type marked.
func test_mid_phase_one_type_round_trips() -> void:
	var gate: Node = OnboardingGateScript.new()
	gate.on_action_completed(VLOG)
	var snapshot: Dictionary = gate.serialize_state()

	var restored: Node = OnboardingGateScript.new()
	restored.restore_state(snapshot)

	assert_int(restored.phase).is_equal(OnboardingGateScript.Phase.PURE_ACTION)
	assert_bool(restored._completed_types.has(VLOG)).is_true()
	assert_bool(restored._completed_types.has(DRAMA)).is_false()
	assert_bool(restored._completed_types.has(APOLOGY)).is_false()
	gate.free()
	restored.free()

## AC: mid-phase save/restore -- 2 of 3 types completed, both restored.
func test_mid_phase_two_types_round_trips() -> void:
	var gate: Node = OnboardingGateScript.new()
	gate.on_action_completed(VLOG)
	gate.on_action_completed(DRAMA)
	var snapshot: Dictionary = gate.serialize_state()

	var restored: Node = OnboardingGateScript.new()
	restored.restore_state(snapshot)

	assert_int(restored.phase).is_equal(OnboardingGateScript.Phase.PURE_ACTION)
	assert_bool(restored._completed_types.has(VLOG)).is_true()
	assert_bool(restored._completed_types.has(DRAMA)).is_true()
	assert_bool(restored._completed_types.has(APOLOGY)).is_false()
	gate.free()
	restored.free()

## AC: phase_first_card_pending survives restore, and the next action after
## restore still transitions to phase_normal correctly.
func test_first_card_pending_survives_restore() -> void:
	var gate: Node = OnboardingGateScript.new()
	gate.on_action_completed(VLOG)
	gate.on_action_completed(DRAMA)
	gate.on_action_completed(APOLOGY)  # -> FIRST_CARD_PENDING
	var snapshot: Dictionary = gate.serialize_state()

	var restored: Node = OnboardingGateScript.new()
	restored.restore_state(snapshot)
	assert_int(restored.phase).is_equal(OnboardingGateScript.Phase.FIRST_CARD_PENDING)

	restored.on_action_completed(VLOG)  # the next completed action
	assert_int(restored.phase).is_equal(OnboardingGateScript.Phase.NORMAL)
	gate.free()
	restored.free()

## AC (gap closed, flagged by code review): a corrupted/hand-edited save with
## an out-of-enum phase value falls back to PURE_ACTION, never crashes and
## never silently no-ops as an invalid enum value -- matching SaveSystem's own
## "corruption -> first-session defaults" contract.
func test_corrupted_out_of_range_phase_falls_back_to_pure_action() -> void:
	var gate: Node = OnboardingGateScript.new()

	gate.restore_state({"phase": 99, "completed_types": []})
	assert_int(gate.phase).is_equal(OnboardingGateScript.Phase.PURE_ACTION)

	gate.restore_state({"phase": -1, "completed_types": []})
	assert_int(gate.phase).is_equal(OnboardingGateScript.Phase.PURE_ACTION)
	gate.free()

## AC (revised by first-card-hook-onboarding-2026-07-06): fresh install /
## no save data -- restore_state({}) enters the HOOK state: FIRST_CARD_PENDING
## with the card cooldown pre-zeroed (deferred), so the first card lands right
## after action #1. PURE_ACTION is no longer the fresh-session entry point.
func test_empty_restore_enters_first_card_hook() -> void:
	var gate: Node = OnboardingGateScript.new()
	gate.restore_state({})

	assert_int(gate.phase).is_equal(OnboardingGateScript.Phase.FIRST_CARD_PENDING)
	assert_bool(gate._completed_types.is_empty()).is_true()
	assert_bool(gate.is_card_suppressed()).is_false()  # cards live from action #1
	assert_bool(gate.should_show_skill_challenge_intro()).is_true()
	gate.free()
	# Consume the deferred force_cooldown_zero aimed at the real Autoload,
	# then restore its cooldown so later suites see the default state.
	await get_tree().process_frame
	DecisionCardSystem._actions_until_check = DecisionCardSystem.COOLDOWN_ACTIONS


func test_skill_challenge_intro_flag_round_trips_and_old_save_defaults_unseen() -> void:
	var gate: Node = OnboardingGateScript.new()
	gate.restore_state({"phase": OnboardingGateScript.Phase.NORMAL, "completed_types": []})
	assert_bool(gate.should_show_skill_challenge_intro()).is_true()

	gate.mark_skill_challenge_intro_seen()
	var restored: Node = OnboardingGateScript.new()
	restored.restore_state(gate.serialize_state())
	assert_bool(restored.should_show_skill_challenge_intro()).is_false()
	gate.free()
	restored.free()


func test_showcase_progress_round_trips_and_old_save_migrates_seen_minigames() -> void:
	var gate: Node = OnboardingGateScript.new()
	gate.mark_showcase_card_seen(&"feed_sprint_challenge")
	gate.mark_showcase_card_seen(&"brand_deal_choice")
	var restored: Node = OnboardingGateScript.new()
	restored.restore_state(gate.serialize_state())
	assert_bool(restored.has_seen_showcase_card(&"feed_sprint_challenge")).is_true()
	assert_bool(restored.has_seen_showcase_card(&"brand_deal_choice")).is_true()
	assert_bool(restored.has_seen_showcase_card(&"comment_moderation_challenge")).is_false()

	var migrated: Node = OnboardingGateScript.new()
	migrated.restore_state({
		"phase": OnboardingGateScript.Phase.NORMAL,
		"skill_challenge_intro_seen": true,
		"seen_skill_challenges": ["feed_sprint_challenge"],
	})
	assert_bool(migrated.has_seen_showcase_card(&"feed_sprint_challenge")).is_true()
	assert_bool(migrated.has_seen_showcase_card(&"brand_deal_choice")).is_false()
	gate.free()
	restored.free()
	migrated.free()


## AC (first-card hook, end-to-end contract): after a fresh restore, the very
## first completed action triggers the card pool check -- the cooldown was
## pre-zeroed by the deferred call.
func test_fresh_session_first_action_triggers_card_check() -> void:
	var gate: Node = OnboardingGateScript.new()
	gate.restore_state({})
	await get_tree().process_frame  # deferred force_cooldown_zero lands on the Autoload

	assert_int(DecisionCardSystem._actions_until_check).is_equal(0)

	gate.free()
	DecisionCardSystem._actions_until_check = DecisionCardSystem.COOLDOWN_ACTIONS

## AC: SaveSystem.save_now()'s payload contains an "onboarding" key matching
## OnboardingGate.serialize_state()'s shape.
func test_save_now_payload_contains_onboarding_key() -> void:
	OnboardingGate.phase = OnboardingGate.Phase.FIRST_CARD_PENDING
	OnboardingGate._completed_types = {VLOG: true, DRAMA: true, APOLOGY: true}

	var had_save_file: bool = FileAccess.file_exists(SaveSystemScript.SAVE_PATH)
	var backup: String = ""
	if had_save_file:
		var f: FileAccess = FileAccess.open(SaveSystemScript.SAVE_PATH, FileAccess.READ)
		backup = f.get_as_text()
		f.close()

	SaveSystem.save_now()
	var f2: FileAccess = FileAccess.open(SaveSystemScript.SAVE_PATH, FileAccess.READ)
	var written: Dictionary = JSON.parse_string(f2.get_as_text())
	f2.close()

	assert_bool(written.has("onboarding")).is_true()
	# JSON.parse_string deserializes numbers as float, not int -- cast before
	# comparing (the round-trip through restore_state()'s own `as Phase` cast
	# handles this correctly for real boot; this test asserts the raw JSON shape).
	assert_int(int(written["onboarding"]["phase"])).is_equal(OnboardingGate.Phase.FIRST_CARD_PENDING)

	# Restore the real save file to its prior state (or remove it if it didn't
	# exist), matching save_core_test.gd's established backup/restore pattern.
	if had_save_file:
		var restore_f: FileAccess = FileAccess.open(SaveSystemScript.SAVE_PATH, FileAccess.WRITE)
		restore_f.store_string(backup)
		restore_f.close()
	else:
		DirAccess.remove_absolute(SaveSystemScript.SAVE_PATH)

## AC: BootController wiring -- boot_with() calls OnboardingGate.restore_state()
## with the "onboarding" sub-dict from the save Dictionary.
func test_boot_controller_restores_onboarding_phase() -> void:
	var bc: Node = preload("res://src/core/boot_controller.gd").new()
	add_child(bc)
	var data: Dictionary = {
		"onboarding": {"phase": OnboardingGate.Phase.FIRST_CARD_PENDING, "completed_types": ["nagraj_vloga", "zrob_drame", "przeprosiny"]},
	}

	bc.boot_with(data, 0)

	assert_int(OnboardingGate.phase).is_equal(OnboardingGate.Phase.FIRST_CARD_PENDING)
	assert_bool(OnboardingGate._completed_types.has(VLOG)).is_true()
	bc.queue_free()

## AC (revised by first-card-hook 2026-07-06): BootController wiring -- a save
## Dictionary with no "onboarding" key (older save format / first session)
## enters the first-card HOOK state (FIRST_CARD_PENDING), no crash.
func test_boot_controller_handles_missing_onboarding_key() -> void:
	var bc: Node = preload("res://src/core/boot_controller.gd").new()
	add_child(bc)

	bc.boot_with({}, 0)  # no "onboarding" key at all

	assert_int(OnboardingGate.phase).is_equal(OnboardingGate.Phase.FIRST_CARD_PENDING)
	assert_bool(OnboardingGate._completed_types.is_empty()).is_true()
	bc.queue_free()
	# Consume the deferred cooldown-zero + restore the Autoload's default.
	await get_tree().process_frame
	DecisionCardSystem._actions_until_check = DecisionCardSystem.COOLDOWN_ACTIONS

## AC: mark_dirty wiring on phase change -- a real variety-advancing call
## marks the real SaveSystem dirty; a repeat-type call (no real mutation) and
## any call in NORMAL (terminal) do not.
func test_mark_dirty_only_on_real_mutation() -> void:
	var gate: Node = OnboardingGateScript.new()
	SaveSystem._debounce_timer.stop()

	gate.on_action_completed(VLOG)  # genuine new type -> marks dirty
	assert_bool(SaveSystem._debounce_timer.is_stopped()).is_false()
	SaveSystem._debounce_timer.stop()

	gate.on_action_completed(VLOG)  # repeat -> no real mutation, no mark
	assert_bool(SaveSystem._debounce_timer.is_stopped()).is_true()

	gate.on_action_completed(DRAMA)
	gate.on_action_completed(APOLOGY)  # -> FIRST_CARD_PENDING, marks dirty
	SaveSystem._debounce_timer.stop()
	gate.on_action_completed(VLOG)  # -> NORMAL, marks dirty
	assert_bool(SaveSystem._debounce_timer.is_stopped()).is_false()
	SaveSystem._debounce_timer.stop()

	gate.on_action_completed(DRAMA)  # NORMAL is terminal -> no mark
	assert_bool(SaveSystem._debounce_timer.is_stopped()).is_true()
	gate.free()
