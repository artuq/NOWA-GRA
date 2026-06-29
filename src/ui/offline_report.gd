## OfflineReportScreen is the standalone full-screen scene shown once at cold
## start when the player has been away >= MIN_REPORT_THRESHOLD_SECONDS — the
## "what did I miss?" reward moment (Pillar 4). It reads the offline simulation
## result from OfflineProgressSystem.last_simulation_result (populated by
## BootController, ADR-0003/0009), renders a hero Reach number + secondary stats
## in a dry, factual, no-judgment tone, and dismisses (tap anywhere OR the
## "Continue!" button) via a scene swap to the main scene.
##
## Not a modal (contrast Card UI / ADR-0008): at boot there is no gameplay scene
## beneath to preserve, so a full scene swap is the lifecycle (ADR-0009). The
## root is a full-rect Button — tap-anywhere dismiss — with the report content as
## its children and an explicit "Continue!" Button affordance.
##
## No _process(): the screen is static and fully event-driven.
class_name OfflineReportScreen
extends Button

## Emitted right before the scene swap, carrying the target path -- a test seam
## so tests can count real dismiss side effects instead of only inspecting the
## _dismissing guard bool (code-review finding, 2026-06-29).
signal scene_swap_requested(path: String)

## Scene swapped to on dismiss. A var (not a const) so tests can point it at a
## harmless existing scene; production keeps the default (built by Story 003).
var main_scene_path: String = "res://scenes/main/main.tscn"

## Latches on the first dismiss so rapid multi-taps (button + background, mixed)
## fire the scene swap exactly once (GDD multi-tap edge case). A pure UI concern,
## so it lives on the screen, not on any Autoload.
var _dismissing: bool = false

@onready var _hero_number_label: Label = %HeroNumberLabel
@onready var _haters_label: Label = %HatersLabel
@onready var _morale_label: Label = %MoraleLabel
@onready var _duration_label: Label = %DurationLabel
@onready var _capped_label: Label = %CappedLabel
@onready var _continue_button: Button = %ContinueButton

func _ready() -> void:
	_render(OfflineProgressSystem.last_simulation_result)
	# Tap anywhere (root Button) OR the explicit affordance both dismiss once.
	pressed.connect(_dismiss)
	_continue_button.pressed.connect(_dismiss)


## Fills the report from the transient simulation payload. Missing keys fall back
## to safe neutral values (e.g. no baseline -> zero delta) so the screen never
## errors — BootController is the contract owner for the full payload.
func _render(r: Dictionary) -> void:
	var total_z: float = r.get("total_Z_gained", 0.0)
	_hero_number_label.text = "+%s" % ActionUIFormatting.format_number(total_z)

	# ΔHatersi: final_H - h0, shown signed and never hidden (GDD: "+0" if equal).
	var final_h: float = r.get("final_H", 0.0)
	var h0: float = r.get("h0", final_h)
	_haters_label.text = "Haters: %+d" % int(roundf(final_h - h0))

	# Morale: current band, with a "(was X)" indicator only if the band shifted.
	var final_m: float = r.get("final_M", 0.0)
	var m0: float = r.get("m0", final_m)
	var current_band: String = ResourceFormulas.morale_band_label(final_m)
	var initial_band: String = ResourceFormulas.morale_band_label(m0)
	if current_band != initial_band:
		_morale_label.text = "Morale: %s (was %s)" % [current_band, initial_band]
	else:
		_morale_label.text = "Morale: %s" % current_band

	var elapsed: int = int(r.get("elapsed_seconds", 0))
	_duration_label.text = "You were away for %s." % OfflineReportFormatting.format_duration(elapsed)

	# Capped message only when the break exceeded the 24h cap.
	_capped_label.visible = bool(r.get("capped", false))


## Single-fire dismiss → swap to the main gameplay scene. The latch makes every
## tap after the first a no-op for the rest of this screen's life.
func _dismiss() -> void:
	if _dismissing:
		return
	_dismissing = true
	scene_swap_requested.emit(main_scene_path)
	get_tree().change_scene_to_file(main_scene_path)
