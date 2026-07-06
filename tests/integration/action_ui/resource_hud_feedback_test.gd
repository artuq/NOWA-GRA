## Integration tests for ResourceHud's Juice Action channel (Juice/Feedback
## Story 002, TR-juice-002/004, ADR-0011 §2). Covers the 6 QA test cases
## embedded in the story: count-up + flash on action_completed with no shake,
## start-value derivation from the payload, sign-invariant presentation,
## zero-magnitude flash, tween pile-up guard, and the self_modulate-not-
## modulate rule (number legibility).
##
## Emits ActionSystem.action_completed directly (synthetic rewards) — deltas
## are NOT applied to ResourceManager except where a test explicitly needs the
## resource_changed interplay; those snapshot/restore per save_core_test.gd's
## established pattern.
extends GdUnitTestSuite

const ResourceHudScript: GDScript = preload("res://src/ui/resource_hud.gd")

var _resource_snapshot: Dictionary[StringName, float] = {}


func before_test() -> void:
	_resource_snapshot[&"Reach"] = ResourceManager.get_resource(&"Reach")
	_resource_snapshot[&"Cringe"] = ResourceManager.get_resource(&"Cringe")


func after_test() -> void:
	var restore: Dictionary[StringName, float] = {}
	for key: StringName in _resource_snapshot:
		restore[key] = _resource_snapshot[key] - ResourceManager.get_resource(key)
	ResourceManager.apply_delta(restore)
	SaveSystem._debounce_timer.stop()


func _hud() -> Control:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/resource_hud.tscn")
	return runner.scene() as Control


## AC-1: action event -> count-up + flash, no shake (position unchanged).
func test_action_completed_starts_countup_and_flash_no_shake() -> void:
	var hud: Control = _hud()
	var pill: Control = hud.find_child("ReachPill", true, false) as Control
	await get_tree().process_frame  # let the container layout settle first

	ActionSystem.action_completed.emit(&"nagraj_vloga", {&"Reach": 5.0})
	await get_tree().process_frame

	assert_bool(hud._countup_tweens.has(&"Reach")).is_true()
	assert_bool((hud._countup_tweens[&"Reach"] as Tween).is_running()).is_true()
	assert_bool(hud._flash_tweens.has(&"Reach")).is_true()
	# "No shake" is STRUCTURAL in this channel: ResourceHud has no shake tween
	# member at all (unlike CardScreen's _juice_shake_tween). Note: pill layout
	# position may legitimately reflow as the count-up changes text width —
	# position equality is NOT the right assertion in a container.
	assert_bool("_juice_shake_tween" in hud).is_false()

	# After the fixed durations elapse: label shows the end value, chrome settled.
	await get_tree().create_timer(0.9).timeout
	var end_value: float = ResourceManager.get_resource(&"Reach")
	var label: Label = hud.find_child("ReachValueLabel", true, false) as Label
	assert_str(label.text).is_equal("Reach: %s" % ActionUIFormatting.format_number(end_value))
	assert_that(pill.self_modulate).is_equal(Color.WHITE)


## AC-2: count-up derives start = end - reward and animates upward; the
## resource_changed snap is suppressed while the count-up owns the label.
func test_countup_start_derivation_and_snap_suppression() -> void:
	var hud: Control = _hud()

	ActionSystem.action_completed.emit(&"nagraj_vloga", {&"Reach": 50.0})
	await get_tree().create_timer(0.15).timeout  # mid-tween

	var end_value: float = ResourceManager.get_resource(&"Reach")
	var displayed: float = hud._displayed_countup_values.get(&"Reach", -1.0)
	assert_float(displayed).is_greater_equal(end_value - 50.0)
	assert_float(displayed).is_less(end_value)  # still counting up, not snapped

	# A resource_changed mid-count-up must NOT snap the label (guard active).
	ResourceManager.apply_delta({&"Reach": 100.0})
	await get_tree().process_frame
	var displayed_after: float = hud._displayed_countup_values.get(&"Reach", -1.0)
	assert_float(displayed_after).is_less(end_value + 1.0)  # not snapped to end+100


## AC-3: opposite-sign events at equal magnitude produce identical
## presentation parameters (single flash token, fixed durations).
func test_sign_invariant_presentation() -> void:
	var hud: Control = _hud()

	ActionSystem.action_completed.emit(&"zrob_drame", {&"Cringe": 20.0})
	await get_tree().process_frame
	assert_bool((hud._flash_tweens[&"Cringe"] as Tween).is_running()).is_true()
	await get_tree().create_timer(0.9).timeout

	ActionSystem.action_completed.emit(&"przeprosiny", {&"Cringe": -20.0})
	await get_tree().process_frame
	assert_bool((hud._flash_tweens[&"Cringe"] as Tween).is_running()).is_true()
	# Structural single-token guarantee: one FLASH_COLOR const drives both —
	# there is no second color constant to select by sign anywhere in the node.
	assert_that(ResourceHudScript.FLASH_COLOR).is_equal(Color(1.35, 1.35, 1.35, 1.0))
	await get_tree().create_timer(0.9).timeout


## AC-4: zero-magnitude event still flashes (never silently skipped).
func test_zero_delta_still_flashes() -> void:
	var hud: Control = _hud()

	ActionSystem.action_completed.emit(&"nagraj_vloga", {&"Reach": 0.0})
	await get_tree().process_frame

	assert_bool(hud._flash_tweens.has(&"Reach")).is_true()
	assert_bool((hud._flash_tweens[&"Reach"] as Tween).is_running()).is_true()
	await get_tree().create_timer(0.9).timeout


## AC-5: a second event mid-count-up kills the previous tween and continues
## from the displayed value — exactly one live tween per resource, final
## label equals the second event's end value.
func test_tween_pileup_guard() -> void:
	var hud: Control = _hud()

	ActionSystem.action_completed.emit(&"nagraj_vloga", {&"Reach": 40.0})
	await get_tree().create_timer(0.1).timeout
	var first_tween: Tween = hud._countup_tweens[&"Reach"]

	ActionSystem.action_completed.emit(&"nagraj_vloga", {&"Reach": 10.0})
	await get_tree().process_frame

	var second_tween: Tween = hud._countup_tweens[&"Reach"]
	assert_bool(first_tween.is_running()).is_false()  # killed
	assert_bool(second_tween.is_running()).is_true()
	assert_object(second_tween).is_not_same(first_tween)

	await get_tree().create_timer(0.9).timeout
	var end_value: float = ResourceManager.get_resource(&"Reach")
	var label: Label = hud.find_child("ReachValueLabel", true, false) as Label
	assert_str(label.text).is_equal("Reach: %s" % ActionUIFormatting.format_number(end_value))


## Gap closure (code review 2026-07-06): a real action payload rewards THREE
## resources at once — independent count-ups for numeric resources, flash for
## all, and NO count-up for Morale (band label would flicker through
## thresholds mid-tween; Morale is flash-only by design).
func test_multi_resource_event_countups_and_morale_flash_only() -> void:
	var hud: Control = _hud()

	ActionSystem.action_completed.emit(&"zrob_drame", {&"Reach": 10.0, &"Cringe": 20.0, &"Morale": -3.0})
	await get_tree().process_frame

	assert_bool(hud._countup_tweens.has(&"Reach")).is_true()
	assert_bool(hud._countup_tweens.has(&"Cringe")).is_true()
	assert_bool(hud._countup_tweens.has(&"Morale")).is_false()  # flash-only
	assert_bool(hud._flash_tweens.has(&"Reach")).is_true()
	assert_bool(hud._flash_tweens.has(&"Cringe")).is_true()
	assert_bool(hud._flash_tweens.has(&"Morale")).is_true()
	# Morale label stays a clean band string throughout.
	var morale_label: Label = hud.find_child("MoraleValueLabel", true, false) as Label
	assert_bool(morale_label.text.begins_with("Morale: ")).is_true()
	await get_tree().create_timer(0.9).timeout


## Gap closure: count-up start uses the TRUE pre-change value cached from
## resource_changed — when ResourceManager clamps (Cringe 95 + 20 -> 100),
## the count-up starts at 95, not the fictitious payload-derived 80.
func test_clamped_cringe_countup_starts_from_true_old_value() -> void:
	var hud: Control = _hud()
	ResourceManager.apply_delta({&"Cringe": 95.0 - ResourceManager.get_resource(&"Cringe")})
	await get_tree().process_frame

	ResourceManager.apply_delta({&"Cringe": 20.0})  # clamps to 100, old_value = 95
	ActionSystem.action_completed.emit(&"zrob_drame", {&"Cringe": 20.0})
	await get_tree().create_timer(0.05).timeout  # early in the tween

	var displayed: float = hud._displayed_countup_values.get(&"Cringe", -1.0)
	assert_float(displayed).is_greater_equal(95.0)  # true start, not 80
	assert_float(displayed).is_less_equal(100.0)
	await get_tree().create_timer(0.9).timeout


## Gap closure: an unknown resource key must be safe — no pill exists for it
## (flash guard returns) and the label update no-ops. No crash, no error.
func test_unknown_resource_key_is_safe() -> void:
	var hud: Control = _hud()

	ActionSystem.action_completed.emit(&"nagraj_vloga", {&"FutureUnknownResource": 5.0})
	await get_tree().process_frame

	assert_bool(hud._flash_tweens.has(&"FutureUnknownResource")).is_false()  # null-pill guard held
	await get_tree().create_timer(0.9).timeout


## AC-6: the flash animates the pill's self_modulate only — pill modulate and
## the child value Label stay untouched (number legibility, engine-specialist
## finding folded into ADR-0011).
func test_flash_uses_self_modulate_not_modulate() -> void:
	var hud: Control = _hud()
	var pill: Control = hud.find_child("ReachPill", true, false) as Control
	var label: Label = hud.find_child("ReachValueLabel", true, false) as Label

	ActionSystem.action_completed.emit(&"nagraj_vloga", {&"Reach": 5.0})
	await get_tree().create_timer(0.08).timeout  # mid-flash (peak ~0.072s)

	assert_that(pill.self_modulate).is_not_equal(Color.WHITE)
	assert_that(pill.modulate).is_equal(Color.WHITE)
	assert_that(label.modulate).is_equal(Color.WHITE)
	assert_that(label.self_modulate).is_equal(Color.WHITE)
	await get_tree().create_timer(0.9).timeout
