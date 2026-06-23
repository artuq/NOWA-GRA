# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the core fantasy within 3-5 min, unguided?
# Date: 2026-06-20
#
# Builds the entire UI procedurally (no hand-authored .tscn hierarchy) for speed
# and robustness. Implements: Resource HUD, Action Grid (3 buttons, no locked
# slots — unlock_threshold values don't exist yet per action-ui.md's flagged gap,
# out of scope for this slice), Running Action Overlay (progress bar), and the
# Card UI full-screen modal (swipe-to-commit, per ADR/card-ui.md formulas).
extends Control

const COMMIT_THRESHOLD_RATIO := 0.30
const FLICK_VELOCITY_THRESHOLD := 800.0
const MAX_TILT_DEGREES := 12.0

var _resource_labels: Dictionary = {}
var _action_buttons: Dictionary = {}
var _progress_bar: ProgressBar
var _progress_label: Label
var _overlay_panel: Panel

var _card_panel: PanelContainer
var _card_text_label: Label
var _card_option_a_label: Label
var _card_option_b_label: Label
var _dragging := false
var _drag_start_x := 0.0
var _drag_current_x := 0.0
var _drag_start_time := 0
var _bounce_tween: Tween
var _framing_panel: Panel

func _ready() -> void:
	_build_resource_hud()
	_build_action_grid()
	_build_running_overlay()
	_build_card_modal()
	_build_framing_screen()

	ResourceManager.resource_changed.connect(_on_resource_changed)
	ActionSystem.action_completed.connect(_on_action_completed)
	DecisionCardSystem.card_presented.connect(_on_card_presented)
	DecisionCardSystem.card_resolved.connect(_on_card_resolved)

	for key in [&"Reach", &"Cringe", &"Haters", &"Morale", &"Sponsors"]:
		_update_resource_label(key, ResourceManager.get_resource(key))

func _build_framing_screen() -> void:
	# Fictional framing beat shown once at session start — added after a playtest
	# found players had no context for why they were clicking ("I didn't know why
	# I was clicking this"). NOT a tutorial (Pillar 3 forbids lecture-style
	# explanations) — one line, dismissed by a single tap, never shown again this
	# session. Line chosen by narrative-director: "Everyone's watching. Act
	# accordingly — or don't." (encodes "Consequences Have Weight" without
	# moralizing — the "or don't" deflates any judgment).
	_framing_panel = Panel.new()
	_framing_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_framing_panel.z_index = 200
	# Explicit opaque background — Panel's default theme stylebox in a project
	# with no Theme resource assigned can render as effectively transparent,
	# letting the Action Grid show through underneath instead of being blocked.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.97)
	_framing_panel.add_theme_stylebox_override("panel", style)
	add_child(_framing_panel)

	# CenterContainer recomputes its child's centered position continuously as the
	# child's size changes — avoids the one-shot anchors_preset(CENTER) timing bug
	# (computing the centering offset against a not-yet-sized child).
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_framing_panel.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var label := Label.new()
	label.text = "Everyone's watching.\nAct accordingly — or don't."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(label)

	var hint := Label.new()
	hint.text = "(tap to begin)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(hint)

	_framing_panel.gui_input.connect(_on_framing_dismissed)

func _on_framing_dismissed(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.pressed if event is InputEventScreenTouch else event.is_pressed()
		if pressed:
			var t := create_tween()
			t.tween_property(_framing_panel, "modulate:a", 0.0, 0.25)
			t.tween_callback(_framing_panel.queue_free)

func _process(_delta: float) -> void:
	var running := ActionSystem.current_action_id != &""
	_overlay_panel.visible = running
	# Action Grid is blocked while an action runs OR while the card modal is
	# visible (Card UI's "blocks background interactions" requirement).
	var blocked := running or _card_panel.visible
	for id in _action_buttons:
		var btn: Button = _action_buttons[id]
		btn.disabled = blocked
		# disabled alone doesn't stop a Button (default filter STOP) from
		# claiming the click in the input-dispatch search — while blocked,
		# also set IGNORE so input bubbles past it to Main._gui_input
		# (needed for the card swipe area, which overlaps the grid visually).
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE if blocked else Control.MOUSE_FILTER_STOP
	if running:
		_progress_bar.value = ActionSystem.get_progress() * 100.0
		_progress_label.text = "%s — %.1fs" % [
			ActionSystem.ACTION_LABELS[ActionSystem.current_action_id],
			(1.0 - ActionSystem.get_progress()) * ActionSystem.ACTION_DURATIONS[ActionSystem.current_action_id]
		]

func _build_resource_hud() -> void:
	var hud := HBoxContainer.new()
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.position = Vector2(10, 10)
	add_child(hud)
	for key in [&"Reach", &"Cringe", &"Haters", &"Morale", &"Sponsors"]:
		var lbl := Label.new()
		lbl.text = "%s: 0" % key
		lbl.custom_minimum_size = Vector2(130, 0)
		hud.add_child(lbl)
		_resource_labels[key] = lbl

func _build_action_grid() -> void:
	var grid := VBoxContainer.new()
	grid.position = Vector2(40, 100)
	grid.custom_minimum_size = Vector2(640, 0)
	add_child(grid)
	for id in [&"record_vlog", &"start_drama", &"apologize"]:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(640, 90)
		var duration: float = ActionSystem.ACTION_DURATIONS[id]
		var rewards: Dictionary = ActionSystem.ACTION_REWARDS[id]
		btn.text = "%s\n%ss — +%sR, %+dC, %+dM" % [
			ActionSystem.ACTION_LABELS[id], duration,
			rewards[&"Reach"], rewards[&"Cringe"], rewards[&"Morale"]
		]
		btn.pressed.connect(_on_action_button_pressed.bind(id))
		grid.add_child(btn)
		_action_buttons[id] = btn

func _build_running_overlay() -> void:
	_overlay_panel = Panel.new()
	_overlay_panel.position = Vector2(40, 420)
	_overlay_panel.custom_minimum_size = Vector2(640, 100)
	_overlay_panel.visible = false
	_overlay_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_panel.add_child(vbox)

	_progress_label = Label.new()
	_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_progress_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(620, 30)
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_progress_bar)

func _on_action_button_pressed(id: StringName) -> void:
	ActionSystem.start_action(id)

func _on_action_completed(_id: StringName, rewards: Dictionary) -> void:
	# Action System channel: count-up handled by _update_resource_label (text only,
	# no shake) + a light flash. magnitude is computed but only drives flash/popup
	# intensity (not duration — duration is fixed per juice-feedback-system.md
	# Core Rules rule 2).
	var mag: float = FeedbackSystem.magnitude(rewards)
	ResourceManager.apply_delta(rewards)
	_flash_changed_labels(rewards, mag)
	_spawn_delta_popups(rewards, mag)

func _flash_changed_labels(deltas: Dictionary, _mag: float) -> void:
	for key in deltas:
		var lbl: Label = _resource_labels.get(key)
		if lbl == null:
			continue
		lbl.modulate = Color(1.4, 1.4, 1.0)  # one neutral "activity" token, never valence-coded
		var t := create_tween()
		t.tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.18)

func _spawn_delta_popups(deltas: Dictionary, mag: float) -> void:
	# Floating "+3 Reach" style popup — the flash alone was too subtle to register
	# as a reward ("I do it and forget it"). Size/lift/pop scale with magnitude
	# (no red/green — per the locked no-valence-coding rule; intensity only).
	#
	# All popups from ONE event are stacked in a single centered column (not
	# spawned above their individual HUD labels) — anchoring each at its own
	# narrow label caused adjacent popups to visually overlap/merge whenever
	# 2+ resources changed in the same event and font size grew with magnitude.
	# A vertically-stacked column guarantees separation regardless of font size.
	var visible_mag: float = max(mag, 0.3)
	var popup_width: float = 240.0
	var anchor_x: float = (get_viewport_rect().size.x - popup_width) / 2.0
	var anchor_y: float = 70.0
	var line_height: float = 38.0
	var stack_index: int = 0

	for key in deltas:
		var delta: float = deltas[key]
		if is_zero_approx(delta):
			continue
		var popup := Label.new()
		var sign_str: String = "+" if delta > 0 else ""
		popup.text = "%s%s %s" % [sign_str, str(delta).pad_decimals(0), key]
		popup.custom_minimum_size = Vector2(popup_width, 0)
		popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var font_size: int = int(lerp(22.0, 40.0, visible_mag))
		popup.add_theme_font_size_override("font_size", font_size)
		popup.modulate = Color(1, 1, 1, 1)
		popup.z_index = 100
		add_child(popup)
		popup.global_position = Vector2(anchor_x, anchor_y + stack_index * line_height)
		popup.pivot_offset = Vector2(popup_width / 2.0, font_size / 2.0)
		popup.scale = Vector2(0.4, 0.4)
		stack_index += 1

		var lift: float = lerp(30.0, 90.0, visible_mag)
		var pop_scale: float = lerp(1.1, 1.6, visible_mag)
		var t := create_tween()
		t.tween_property(popup, "scale", Vector2(pop_scale, pop_scale), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.parallel().tween_property(popup, "position:y", popup.position.y - lift, 0.9).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(popup, "modulate:a", 0.0, 0.6).set_delay(0.4)
		t.tween_callback(popup.queue_free)

func _on_resource_changed(res_name: StringName, new_value: float, _old: float) -> void:
	_update_resource_label(res_name, new_value)

func _update_resource_label(res_name: StringName, value: float) -> void:
	var lbl: Label = _resource_labels.get(res_name)
	if lbl == null:
		return
	if res_name == &"Morale":
		lbl.text = "Morale: %s (%.0f%%)" % [ResourceManager.get_morale_band(), value]
	else:
		lbl.text = "%s: %.0f" % [res_name, value]

# --- Card UI (full-screen blocking modal, swipe-to-commit) ---

func _build_card_modal() -> void:
	# mouse_filter = IGNORE on the panel and every descendant: this card has no
	# individually-clickable children, the whole card is one drag surface, and
	# the drag/release handling lives on Main's _gui_input. Without IGNORE here,
	# the PanelContainer (default filter STOP) swallows every touch/click before
	# it reaches Main, and the swipe gesture never fires.
	_card_panel = PanelContainer.new()
	_card_panel.position = Vector2(60, 300)
	_card_panel.size = Vector2(600, 500)
	_card_panel.custom_minimum_size = Vector2(600, 500)
	_card_panel.pivot_offset = Vector2(300, 250)  # center pivot — without this,
	# scale tweens grow from the top-left corner and the "pulse" looks like a
	# corner-stretch rather than a centered pop.
	_card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_panel.visible = false
	add_child(_card_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_panel.add_child(vbox)

	_card_text_label = Label.new()
	_card_text_label.custom_minimum_size = Vector2(560, 250)
	_card_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_card_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_card_text_label)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hbox)

	_card_option_a_label = Label.new()
	_card_option_a_label.custom_minimum_size = Vector2(270, 0)
	_card_option_a_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_card_option_a_label)

	_card_option_b_label = Label.new()
	_card_option_b_label.custom_minimum_size = Vector2(270, 0)
	_card_option_b_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_card_option_b_label)

func _on_card_presented(card) -> void:
	_card_text_label.text = card.text
	_card_option_a_label.text = "<- %s" % card.option_a_label
	_card_option_b_label.text = "%s ->" % card.option_b_label
	_card_option_a_label.modulate = Color(1, 1, 1, 1)
	_card_option_b_label.modulate = Color(1, 1, 1, 1)
	_card_panel.position = Vector2(60, 300)
	_card_panel.rotation_degrees = 0.0
	_card_panel.scale = Vector2.ONE
	_card_panel.visible = true

func _on_card_resolved(_card_id: StringName, _option: StringName, reaction: String, mag: float, effects: Dictionary) -> void:
	# Resolution payoff (juice-feedback-system.md Core Rules rule 5): replace the
	# card's question text with the reaction, play scale-pulse/shake scaled by
	# magnitude (no audio — no sound assets in this slice), spawn delta popups on
	# the HUD (same mechanism as Action System, see _spawn_delta_popups), then dismiss.
	_card_text_label.text = reaction
	_card_option_a_label.text = ""
	_card_option_b_label.text = ""
	# Brief highlight on the swapped-in text itself — the swap was reported as
	# "completely static," easy to miss even with the panel pulse/shake.
	_card_text_label.modulate = Color(1.3, 1.3, 1.1)
	var text_t := create_tween()
	text_t.tween_property(_card_text_label, "modulate", Color(1, 1, 1, 1), 0.4)
	_spawn_delta_popups(effects, mag)
	await _play_resolution_juice(mag)
	var duration: float = FeedbackSystem.payoff_duration(reaction.length())
	await get_tree().create_timer(duration).timeout
	DecisionCardSystem.dismiss_card()
	_card_panel.visible = false

func _play_resolution_juice(mag: float) -> void:
	# Same effect family across the full magnitude range — only amplitude/duration
	# scale, never effect type or color (no-valence-coding rule, AC's primary criterion).
	# Floor at 0.35 so even a low-magnitude resolution is clearly visible, not just
	# "technically present" — this was reported as completely invisible before;
	# floor + bigger multipliers + centered pivot (see _build_card_modal) fix that.
	var visible_mag: float = max(mag, 0.35)
	var pulse_scale: float = 1.0 + lerp(0.06, 0.22, visible_mag)
	var shake_amplitude: float = lerp(3.0, 14.0, visible_mag)
	var base_pos: Vector2 = _card_panel.position

	print("[FeedbackSystem] resolution juice: mag=%.3f pulse_scale=%.3f shake_amplitude=%.1f" % [mag, pulse_scale, shake_amplitude])

	var t := create_tween()
	t.tween_property(_card_panel, "scale", Vector2(pulse_scale, pulse_scale), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(_card_panel, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_IN)

	var shake_t := create_tween()
	var shakes := 5
	for i in shakes:
		var offset := Vector2(randf_range(-shake_amplitude, shake_amplitude), randf_range(-shake_amplitude, shake_amplitude))
		shake_t.tween_property(_card_panel, "position", base_pos + offset, 0.035)
	shake_t.tween_property(_card_panel, "position", base_pos, 0.035)
	await shake_t.finished

func _gui_input(event: InputEvent) -> void:
	# Handles both touch (Android) and mouse (editor/desktop testing) input.
	if not _card_panel.visible:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.pressed if event is InputEventScreenTouch else event.is_pressed()
		var pos: Vector2 = event.position
		if pressed:
			_dragging = true
			_drag_start_x = pos.x
			_drag_current_x = pos.x
			_drag_start_time = Time.get_ticks_msec()
			if _bounce_tween and _bounce_tween.is_running():
				_bounce_tween.kill()
		else:
			if _dragging:
				_on_drag_released()
			_dragging = false
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and _dragging:
		_drag_current_x = event.position.x
		_update_card_drag_visual()

func _update_card_drag_visual() -> void:
	var drag_x := _drag_current_x - _drag_start_x
	var half_width := get_viewport_rect().size.x / 2.0
	var rotation_deg: float = clamp(drag_x / half_width, -1.0, 1.0) * MAX_TILT_DEGREES
	_card_panel.position.x = 60 + drag_x
	_card_panel.rotation_degrees = rotation_deg
	if drag_x > 0:
		_card_option_b_label.modulate = Color(1, 1, 1, 1)
		_card_option_a_label.modulate = Color(1, 1, 1, 0.5)
	elif drag_x < 0:
		_card_option_a_label.modulate = Color(1, 1, 1, 1)
		_card_option_b_label.modulate = Color(1, 1, 1, 0.5)

func _on_drag_released() -> void:
	var drag_x: float = _drag_current_x - _drag_start_x
	var elapsed_sec: float = max(0.001, (Time.get_ticks_msec() - _drag_start_time) / 1000.0)
	var velocity: float = drag_x / elapsed_sec
	var screen_width: float = get_viewport_rect().size.x
	var is_committed: bool = (abs(drag_x) >= COMMIT_THRESHOLD_RATIO * screen_width) \
		or (abs(velocity) >= FLICK_VELOCITY_THRESHOLD)

	if is_committed:
		var option: StringName = &"option_b" if drag_x > 0 else &"option_a"
		_card_panel.position = Vector2(60, 300)
		_card_panel.rotation_degrees = 0.0
		DecisionCardSystem.resolve_choice(option)
		# _on_card_resolved (connected to DecisionCardSystem.card_resolved) handles
		# the resolution payoff display and eventual dismissal — not done here.
	else:
		_bounce_back()

func _bounce_back() -> void:
	_bounce_tween = create_tween()
	_bounce_tween.set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(_card_panel, "position:x", 60.0, 0.15)
	_bounce_tween.parallel().tween_property(_card_panel, "rotation_degrees", 0.0, 0.15)
