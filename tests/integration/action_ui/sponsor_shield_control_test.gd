## Package 2 integration contract for the compact Sponsor Shield control on
## ActionScreen. The control is a reactive command surface: ResourceManager
## owns Sponsors, shield duration, stacking, and shield_changed; UI only
## renders state and forwards an activation request.
extends GdUnitTestSuite

const SHIELD_SCENE: String = "res://scenes/action_screen/sponsor_shield_control.tscn"

var _sponsors_before: float = 0.0
var _shield_before: float = 0.0
var _resource_manager_was_processing: bool = false
var _locale_snapshot: String = ""


func before_test() -> void:
	_locale_snapshot = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_sponsors_before = ResourceManager.get_resource(&"Sponsors")
	_shield_before = ResourceManager.get_shield_remaining_seconds()
	_resource_manager_was_processing = ResourceManager.is_processing()
	# Keep exact countdown and signal payloads deterministic in headless tests.
	ResourceManager.set_process(false)
	ResourceManager._shield_remaining_seconds = 0.0
	_set_sponsors(0.0)
	SaveSystem._debounce_timer.stop()


func after_test() -> void:
	TranslationServer.set_locale(_locale_snapshot)
	ResourceManager._shield_remaining_seconds = _shield_before
	_set_sponsors(_sponsors_before)
	ResourceManager.set_process(_resource_manager_was_processing)
	SaveSystem._debounce_timer.stop()


func _set_sponsors(value: float) -> void:
	ResourceManager.apply_delta({&"Sponsors": value - ResourceManager.get_resource(&"Sponsors")})


func _control() -> Control:
	var runner: GdUnitSceneRunner = scene_runner(SHIELD_SCENE)
	return runner.scene() as Control


## Restored inactive state is rendered during _ready(), before any subsequent
## resource or shield signal. The fixed cost remains visible at all times.
func test_ready_renders_restored_inactive_state_and_visible_cost() -> void:
	_set_sponsors(float(ResourceManager.SHIELD_COST))
	var control: Control = _control()
	var status: Label = control.find_child("ShieldStatusLabel", true, false) as Label
	var cost: Label = control.find_child("ShieldCostLabel", true, false) as Label
	var button: Button = control.find_child("ShieldActionButton", true, false) as Button

	assert_str(status.text.to_lower()).contains("inactive")
	assert_str(cost.text).contains("%d Sponsors" % ResourceManager.SHIELD_COST)
	assert_bool(cost.visible).is_true()
	assert_str(button.text).contains("Activate")
	assert_bool(button.disabled).is_false()


## Countdown uses ceiling (never advertises expiry early) and a stable
## H:MM:SS layout, including durations above one hour. It refreshes while the
## control is alive rather than relying on an activation-only signal.
func test_ready_restores_active_countdown_and_process_refreshes_with_ceil() -> void:
	ResourceManager._shield_remaining_seconds = 3660.01
	var control: Control = _control()
	var status: Label = control.find_child("ShieldStatusLabel", true, false) as Label

	assert_str(status.text).contains("1:01:01")
	ResourceManager._shield_remaining_seconds = 59.01
	control._process(0.0)
	assert_str(status.text).contains("0:01:00")


## An unaffordable activation stays discoverable: the control is visible and
## disabled, while a separate explanation gives the exact missing amount.
func test_insufficient_sponsors_disables_button_and_shows_shortfall() -> void:
	_set_sponsors(float(ResourceManager.SHIELD_COST - 2))
	var control: Control = _control()
	var button: Button = control.find_child("ShieldActionButton", true, false) as Button
	var shortfall: Label = control.find_child("ShieldShortfallLabel", true, false) as Label

	assert_bool(button.visible).is_true()
	assert_bool(button.disabled).is_true()
	assert_bool(shortfall.visible).is_true()
	assert_str(shortfall.text).contains("2 more Sponsors")


func test_control_refreshes_after_polish_language_change() -> void:
	_set_sponsors(float(ResourceManager.SHIELD_COST - 2))
	var control: Control = _control()
	TranslationServer.set_locale("pl_PL")
	SettingsSystem.language_changed.emit(&"pl", &"pl_PL")
	await get_tree().process_frame

	assert_str((control.find_child("ShieldStatusLabel", true, false) as Label).text).contains("Tarcza wyłączona")
	assert_str((control.find_child("ShieldCostLabel", true, false) as Label).text).contains("Koszt")
	assert_str((control.find_child("ShieldShortfallLabel", true, false) as Label).text).contains("Brakuje 2 Sponsorów")
	assert_str((control.find_child("ShieldActionButton", true, false) as Button).text).contains("Włącz")

	TranslationServer.set_locale("en")
	SettingsSystem.language_changed.emit(&"en", &"en")
	await get_tree().process_frame
	assert_str((control.find_child("ShieldStatusLabel", true, false) as Label).text).contains("Shield inactive")
	assert_str((control.find_child("ShieldShortfallLabel", true, false) as Label).text).contains("2 more Sponsors")


## Both a first purchase and an extension go through the button, spend the
## fixed cost, and publish shield_changed. Emitting after EVERY successful
## purchase keeps all reactive UI correct when duration stacks.
func test_purchase_and_extension_spend_cost_and_emit_each_time() -> void:
	_set_sponsors(float(ResourceManager.SHIELD_COST * 3))
	var control: Control = _control()
	var button: Button = control.find_child("ShieldActionButton", true, false) as Button
	var emissions: Array[Array] = []
	var on_shield_changed := func(is_active: bool, remaining: float) -> void:
		emissions.append([is_active, remaining])
	ResourceManager.shield_changed.connect(on_shield_changed)

	button.pressed.emit()
	button.pressed.emit()

	ResourceManager.shield_changed.disconnect(on_shield_changed)
	assert_float(ResourceManager.get_resource(&"Sponsors")).is_equal_approx(
		float(ResourceManager.SHIELD_COST), 0.0001
	)
	assert_float(ResourceManager.get_shield_remaining_seconds()).is_equal_approx(
		ResourceManager.SHIELD_DURATION * 2.0, 0.0001
	)
	assert_array(emissions).has_size(2)
	assert_bool(emissions[0][0]).is_true()
	assert_bool(emissions[1][0]).is_true()
	assert_float(emissions[0][1]).is_equal_approx(ResourceManager.SHIELD_DURATION, 0.0001)
	assert_float(emissions[1][1]).is_equal_approx(ResourceManager.SHIELD_DURATION * 2.0, 0.0001)
	assert_str(button.text).contains("Add")


## Mobile accessibility baseline: the primary command target is at least
## 44 logical pixels high, independent of its current enabled state.
func test_action_button_has_minimum_44_pixel_touch_target() -> void:
	var control: Control = _control()
	var button: Button = control.find_child("ShieldActionButton", true, false) as Button

	assert_float(button.custom_minimum_size.y).is_greater_equal(44.0)


## The feature is shipped as part of normal play, not as an orphan scene.
func test_action_screen_instantiates_sponsor_shield_control() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_screen.tscn")
	var root: Node = runner.scene()

	assert_object(root.find_child("SponsorShieldControl", true, false)).is_not_null()


## Wrapped resource pills and the shield occupy consecutive container rows,
## preventing the overlap seen on narrow portrait layouts.
func test_resource_stats_do_not_overlap_sponsor_shield() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/resource_hud.tscn")
	var hud: Control = runner.scene() as Control
	var stats: Control = hud.get_node("HBoxContainer") as Control
	var shield: Control = hud.get_node("SponsorShieldControl") as Control
	await get_tree().process_frame

	assert_float(shield.position.y).is_greater_equal(stats.position.y + stats.size.y)
