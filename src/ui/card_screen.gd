## CardScreen is the full-screen modal that surfaces DecisionCardSystem's cards
## in actual play (Card UI epic, ADR-0008). It appears when DecisionCardSystem
## emits card_presented (state -> PRESENTING), shows the card's content over a
## dimmed backdrop, blocks the Action UI zones beneath while shown, and on a
## resolved choice calls DecisionCardSystem.resolve_choice() then hides.
##
## Mounted as the TOP sibling under ActionScreen (drawn over the Resource HUD /
## Action Grid). Its root is a full-rect Control with mouse_filter = STOP, so
## while visible it is the topmost node under any touch and consumes it -- the
## zones beneath never receive it (hit-order consumption, not "blocking
## siblings"; ADR-0008). When idle it is visible = false, which means it
## receives no input at all and the Action UI beneath is fully interactive.
##
## Story 002 scope: the modal shell (appear/content/block/resolve). The swipe
## gesture that drives awaiting_swipe -> dragging -> resolving is Story 003 --
## the `dragging` state is declared here from the start so Story 003 only adds
## transitions. This story's resolution path is the public resolve(option_index)
## method, driven directly (by tests now, by the swipe gesture in Story 003).
##
## Performance: no _process() polling -- purely signal/event-driven; the
## entrance/exit visibility changes are instant here (entrance/exit tweens are
## a Story 003 polish concern, kept minimal in this shell).
class_name CardScreen
extends Control

## Preloaded (not the bare class_name) so this script parses in headless
## CLI/CI runs even before the editor regenerates the global class cache.
const FeedbackMath: GDScript = preload("res://src/ui/feedback_math.gd")

## Card UI lifecycle, per card-ui.md's State machine. `dragging` is declared
## now but only entered by Story 003's gesture handling.
enum State { HIDDEN, ENTERING, AWAITING_SWIPE, DRAGGING, RESOLVING }

var state: State = State.HIDDEN

## The card Dictionary currently shown, or {} when hidden. Received via the
## card_presented signal -- never read from DecisionCardSystem's private field.
var _card: Dictionary = {}

@onready var _situation_label: Label = %SituationLabel
@onready var _option_a_label: Label = %OptionALabel
@onready var _option_b_label: Label = %OptionBLabel
@onready var _card_node: Control = %Card

## Resolution-beat timing (GDD `resolving` state). The card holds on screen with
## the chosen option's flat `resolution_reaction` before dismissing, long enough
## to read. Duration is dynamic: a base, plus per-character reading time, plus a
## bonus for milestone-setting choices so a permanent narrative decision lands
## with a visibly heavier beat (GDD hard requirement). Tuning knobs (tests lower
## them for speed):
##   duration = resolution_beat_seconds
##            + reaction.length() * resolution_beat_per_char
##            + (resolution_beat_milestone_bonus if the option sets a milestone)
## Defaults give ~2.3s for a short reaction, ~3.5s for a long one, +1s on a
## milestone — within the 2-2.5s+ toast-readability guideline.
## Retuned 2026-07-06 (TR-juice-005): per_char = 1/60 so the text-driven part
## follows the juice GDD formula exactly — 1.5s floor at length 0, 2.5s at the
## 60-char reference, hard-clamped to [1.5, 2.5] for longer strings. The
## milestone bonus is added ON TOP of the clamped text part: card-ui.md's hard
## requirement ("a permanent decision lands with a visibly heavier beat")
## deliberately survives the juice GDD's pacing clamp, which targets text-length
## scaling only (its rationale: long localization strings must not break pacing).
var resolution_beat_seconds: float = 1.5
var resolution_beat_per_char: float = 1.0 / 60.0
var resolution_beat_milestone_bonus: float = 1.0
const RESOLUTION_BEAT_TEXT_MAX_SEC: float = 2.5

## Juice/Feedback Card channel (ADR-0011, Story 003): magnitude-scaled
## scale-pulse + visual-offset shake + audio stinger at resolution. All
## parameters come from FeedbackMath (abs-only — no valence coding, registry
## forbidden pattern). Tween handles stored for kill-before-restart and for
## the RESOLVING branch of _notification().
var _juice_pulse_tween: Tween
var _juice_shake_tween: Tween
## Magnitude of the most recent resolution — public-state-field convention
## (like `state`) so tests can assert the computed value directly.
var _last_juice_magnitude: float = 0.0
## One-shot stinger player. Streams arrive post-art-bible via /asset-spec;
## until then the explicit null-stream guard in _play_stinger() makes the
## silent no-op a code contract. # TODO: art-bible-pending
var _stinger_player: AudioStreamPlayer

## Swipe gesture state (Story 003). `-1` = no touch tracked. Only the first
## touch that starts a drag is tracked; events with a different index are
## ignored entirely (single-touch latch, ADR-0008 / GDD multi-touch rule).
var _tracked_index: int = -1
var _drag_start: Vector2 = Vector2.ZERO
## The card's resting position, captured lazily once layout has settled (on the
## first drag), so bounce-back and re-show return it to the right spot.
var _card_rest_position: Vector2 = Vector2.ZERO
var _rest_captured: bool = false
## Last horizontal drag velocity (px/s), from the most recent drag event --
## used by the commitment check at release (a fast short flick can confirm).
var _last_drag_velocity: float = 0.0
var _bounce_tween: Tween

func _ready() -> void:
	DecisionCardSystem.card_presented.connect(_on_card_presented)
	_stinger_player = AudioStreamPlayer.new()
	add_child(_stinger_player)
	# Idle until a card is presented -- invisible Controls receive no input, so
	# the Action UI beneath stays interactive.
	visible = false
	state = State.HIDDEN


func _on_card_presented(card: Dictionary) -> void:
	_card = card
	_populate(card)
	# Reset any leftover transform from a previous card's swipe -- including
	# scale, so an interrupted juice pulse can never leak into the next card
	# (ADR-0011 engine-specialist finding).
	if _rest_captured:
		_card_node.position = _card_rest_position
	_card_node.rotation_degrees = 0.0
	_card_node.scale = Vector2.ONE
	_reset_option_feedback()
	visible = true
	# Minimal entrance for the shell (a heavier entrance tween is deferred
	# polish): go straight to awaiting_swipe so the card is immediately swipeable.
	state = State.AWAITING_SWIPE


## Gesture handling (Story 003). Uses _input (not _gui_input) for robust
## full-screen touch capture, guarded by visibility/state so it only acts while
## a card is shown. The modal's STOP root still blocks the Action UI beneath via
## GUI hit-order independently of this raw-input path.
func _input(event: InputEvent) -> void:
	if state == State.HIDDEN or state == State.ENTERING or state == State.RESOLVING:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_on_touch_pressed(event)
		else:
			_on_touch_released(event)
	elif event is InputEventScreenDrag and event.index == _tracked_index and state == State.DRAGGING:
		_on_drag(event)


func _on_touch_pressed(event: InputEventScreenTouch) -> void:
	# Begin tracking only if no touch is currently tracked. A second
	# simultaneous finger (different index) is ignored entirely.
	if _tracked_index != -1:
		return
	# Touching the card again mid-bounce-back cancels the tween immediately and
	# resumes dragging (interruptible bounce-back, GDD Core Rules rule 7).
	if _bounce_tween != null and _bounce_tween.is_running():
		_bounce_tween.kill()
	if not _rest_captured:
		_card_rest_position = _card_node.position
		_rest_captured = true
	_card_node.pivot_offset = _card_node.size / 2.0
	_tracked_index = event.index
	_drag_start = event.position
	_last_drag_velocity = 0.0
	state = State.DRAGGING


func _on_drag(event: InputEventScreenDrag) -> void:
	var delta: Vector2 = event.position - _drag_start
	_card_node.position = _card_rest_position + delta
	var half_w: float = get_viewport_rect().size.x / 2.0
	_card_node.rotation_degrees = CardSwipeMath.rotation_degrees(delta.x, half_w)
	_last_drag_velocity = event.velocity.x
	_update_option_feedback(delta.x)


func _on_touch_released(event: InputEventScreenTouch) -> void:
	if event.index != _tracked_index or state != State.DRAGGING:
		return
	var drag_x: float = event.position.x - _drag_start.x
	var screen_width: float = get_viewport_rect().size.x
	_tracked_index = -1
	if CardSwipeMath.is_committed(drag_x, _last_drag_velocity, screen_width):
		# Drag right -> option_B (index 1); drag left -> option_A (index 0).
		var option_index: int = 1 if drag_x > 0.0 else 0
		resolve(option_index)
	else:
		_start_bounce_back()


## Tweens the card back to its rest position/rotation (ease-out, 150ms), matching
## the entrance timing. Stored + kill()-able so a re-touch can interrupt it.
func _start_bounce_back() -> void:
	if _bounce_tween != null and _bounce_tween.is_running():
		_bounce_tween.kill()
	_bounce_tween = create_tween().set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(_card_node, "position", _card_rest_position, 0.15)
	_bounce_tween.parallel().tween_property(_card_node, "rotation_degrees", 0.0, 0.15)
	_reset_option_feedback()
	state = State.AWAITING_SWIPE


## While dragging, the option label in the drag direction slightly enlarges and
## the other dims -- purely interactive "this will confirm" feedback, NOT moral
## colour coding (both labels keep an identical neutral base colour/style; only
## scale/opacity change, symmetrically by direction).
func _update_option_feedback(drag_x: float) -> void:
	if drag_x > 0.0:  # heading right -> option_B
		_set_option_emphasis(_option_b_label, true)
		_set_option_emphasis(_option_a_label, false)
	elif drag_x < 0.0:  # heading left -> option_A
		_set_option_emphasis(_option_a_label, true)
		_set_option_emphasis(_option_b_label, false)
	else:
		_reset_option_feedback()


func _set_option_emphasis(label: Label, active: bool) -> void:
	# Grow from the label's centre (not the default top-left pivot) so the scale
	# bump reads as the label swelling in place rather than drifting sideways.
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(1.2, 1.2) if active else Vector2(1.0, 1.0)
	# Dim the non-chosen option clearly (0.3 alpha) so the player is certain
	# which direction confirms which choice before lifting their finger.
	label.modulate = Color(1, 1, 1, 1) if active else Color(1, 1, 1, 0.3)


func _reset_option_feedback() -> void:
	_option_a_label.scale = Vector2.ONE
	_option_b_label.scale = Vector2.ONE
	_option_a_label.modulate = Color(1, 1, 1, 1)
	_option_b_label.modulate = Color(1, 1, 1, 1)


## Interruption (app backgrounded / focus lost). While DRAGGING: reset position
## and rotation to rest INSTANTLY (no tween), state back to awaiting_swipe, drop
## the tracked touch -- per GDD Core Rules rule 8 ("no partial state persisted").
## While RESOLVING: kill the juice pulse/shake tweens and restore scale/position
## so the next card presents clean (ADR-0011 -- makes the "no corrupt state on
## backgrounding" claim structural, not assumed). The resolution beat timer
## itself continues; only the visual effects are cut.
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_PAUSED and what != NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		return
	if state == State.RESOLVING:
		_kill_juice_tweens()
		_card_node.scale = Vector2.ONE
		if _rest_captured:
			_card_node.position = _card_rest_position
		return
	if state != State.DRAGGING:
		return
	if _bounce_tween != null and _bounce_tween.is_running():
		_bounce_tween.kill()
	if _rest_captured:
		_card_node.position = _card_rest_position
	_card_node.rotation_degrees = 0.0
	_reset_option_feedback()
	_tracked_index = -1
	state = State.AWAITING_SWIPE


## Fills the modal's labels from the card. Card content (`text`, option
## `label`s) is empty placeholder copy in CardContentDatabase (narrative
## authoring is a separate, unscheduled task), and the schema has no `category`
## field -- so this falls back to the card `id` as the title and neutral
## "Option A/B" labels with directional arrows when the real copy is empty.
## The category icon is a generic placeholder for the same reason (no category
## data exists yet) -- see docs/tech-debt-register.md.
func _populate(card: Dictionary) -> void:
	var text: String = card.get("text", "")
	_situation_label.text = text if not text.is_empty() else String(card.get("id", "???"))

	var options: Array = card.get("options", [])
	# Doubled guillemets «« »» (U+00AB/BB, Latin-1) instead of arrows ← →
	# (U+2190/92): OpenSans lacks the arrow glyphs, which rendered as hex boxes
	# on the web build (10-1 spike); doubled per user readability feedback.
	_option_a_label.text = "«« %s" % _option_label(options, 0, "Option A")
	_option_b_label.text = "%s »»" % _option_label(options, 1, "Option B")
	# Re-show prompts in case the previous card's resolution beat hid them.
	_option_a_label.visible = true
	_option_b_label.visible = true


func _option_label(options: Array, index: int, fallback: String) -> String:
	if index >= options.size():
		return fallback
	var label: String = options[index].get("label", "")
	return label if not label.is_empty() else fallback


## Resolves the player's choice ([param option_index]: 0 = option_A/left,
## 1 = option_B/right). This story's resolution seam -- Story 003's committed
## swipe calls this. Applies the choice via DecisionCardSystem (ownership-clear
## direct write, ADR-0001), then hides the modal and unblocks the Action UI.
## No-ops if not currently showing a card, mirroring resolve_choice()'s own
## guard against double-resolution.
func resolve(option_index: int) -> void:
	if state == State.HIDDEN or state == State.RESOLVING:
		return
	state = State.RESOLVING
	_tracked_index = -1
	_reset_option_feedback()
	# Snap the card back to centre/upright so the reaction text reads cleanly.
	if _bounce_tween != null and _bounce_tween.is_running():
		_bounce_tween.kill()
	if _rest_captured:
		_card_node.position = _card_rest_position
	_card_node.rotation_degrees = 0.0
	# Read the chosen option's reaction + milestone flag BEFORE the system
	# consumes the card.
	var reaction: String = _reaction_for(option_index)
	var has_milestone: bool = _option_sets_milestone(option_index)
	# Juice Card channel (ADR-0011 §3): magnitude from the chosen option's
	# deltas, computed locally while the card is still in hand -- no signal
	# or payload changes anywhere. Pivot set here defensively: a direct
	# resolve() call (tests, future accessibility path) must pulse from the
	# card's centre even when no drag preceded it.
	_card_node.pivot_offset = _card_node.size / 2.0
	_last_juice_magnitude = _juice_magnitude_for(option_index)
	_play_juice_effects(_last_juice_magnitude)
	# Apply effects (resources before flags, per the system) — the HUD updates
	# live underneath while the reaction is shown.
	DecisionCardSystem.resolve_choice(option_index)
	# Resolution beat: swap the situation text for the algorithm's flat reaction
	# and hide the option prompts, hold (longer for longer text / milestones),
	# then dismiss. state stays RESOLVING so the _input guard blocks any swipe
	# and resolve() can't re-enter mid-beat.
	_situation_label.text = reaction
	_option_a_label.visible = false
	_option_b_label.visible = false
	await get_tree().create_timer(_resolution_beat_duration(reaction, has_milestone)).timeout
	_card = {}
	visible = false
	state = State.HIDDEN


## Returns the chosen option's `resolution_reaction`, or a neutral fallback when
## a card has none authored yet (per the GDD, some cards' reactions are still an
## open question). The fallback stays factual/non-judgmental (anti-pillar rule).
func _reaction_for(option_index: int) -> String:
	var options: Array = _card.get("options", [])
	if option_index >= options.size():
		return "The algorithm notes your choice and moves on."
	var reaction: String = options[option_index].get("resolution_reaction", "")
	return reaction if not reaction.is_empty() else "The algorithm notes your choice and moves on."


## True if the chosen option permanently changes the narrative (sets a history
## milestone) — earns the heavier/longer resolution beat (GDD requirement).
func _option_sets_milestone(option_index: int) -> bool:
	var options: Array = _card.get("options", [])
	if option_index >= options.size():
		return false
	return options[option_index].has("milestone_to_set")


## Resolution-beat hold in seconds: the text-driven part (base + per-char
## reading time) hard-clamped to [resolution_beat_seconds,
## RESOLUTION_BEAT_TEXT_MAX_SEC] per the juice GDD's payoff formula
## (TR-juice-005 -- long localization strings must not break pacing), plus
## card-ui.md's milestone bonus ON TOP of the clamp (a permanent decision's
## heavier beat is a deliberate design weight, not a text-length artifact).
func _resolution_beat_duration(reaction: String, has_milestone: bool) -> float:
	var text_part: float = resolution_beat_seconds + reaction.length() * resolution_beat_per_char
	var duration: float = clampf(text_part, resolution_beat_seconds, RESOLUTION_BEAT_TEXT_MAX_SEC)
	if has_milestone:
		duration += resolution_beat_milestone_bonus
	return duration


## Magnitude of the chosen option's resource deltas, per FeedbackMath.
## Returns 0.0 for an out-of-range index or a card with no deltas.
func _juice_magnitude_for(option_index: int) -> float:
	var options: Array = _card.get("options", [])
	if option_index >= options.size():
		return 0.0
	return FeedbackMath.magnitude(options[option_index].get("resource_deltas", {}))


## Plays the Card channel's sensory set for magnitude [param m]: scale-pulse
## (always -- lowest tier still plays, TR-juice-004), shake (only at m >= 0.3,
## amplitude/duration from FeedbackMath), and the stinger. Same parameters for
## a triumph and a disaster at equal magnitude -- FeedbackMath is sign-blind.
func _play_juice_effects(m: float) -> void:
	_kill_juice_tweens()
	# Scale-pulse: up to pulse_scale(m) and back to ONE in one chain.
	_juice_pulse_tween = create_tween()
	_juice_pulse_tween.tween_property(_card_node, "scale", Vector2.ONE * FeedbackMath.pulse_scale(m), 0.08)
	_juice_pulse_tween.tween_property(_card_node, "scale", Vector2.ONE, 0.12)
	# Shake: visual offset around the rest position; structurally absent below
	# the mid tier (amplitude 0). Uses the captured rest position when known,
	# else the card's current position (direct-resolve path before any drag).
	var amplitude: float = FeedbackMath.shake_amplitude_px(m)
	if amplitude <= 0.0:
		# Keep the field an honest signal: null means "no shake this resolve"
		# (a stale dead-tween reference would break that invariant on a
		# long-lived instance -- code-review finding, 2026-07-06).
		_juice_shake_tween = null
	else:
		var rest: Vector2 = _card_rest_position if _rest_captured else _card_node.position
		var duration: float = FeedbackMath.shake_duration_sec(m)
		_juice_shake_tween = create_tween()
		_juice_shake_tween.tween_property(_card_node, "position", rest + Vector2(amplitude, 0.0), duration * 0.25)
		_juice_shake_tween.tween_property(_card_node, "position", rest - Vector2(amplitude * 0.6, 0.0), duration * 0.25)
		_juice_shake_tween.tween_property(_card_node, "position", rest + Vector2(amplitude * 0.3, 0.0), duration * 0.25)
		_juice_shake_tween.tween_property(_card_node, "position", rest, duration * 0.25)
	_play_stinger(m)


func _kill_juice_tweens() -> void:
	if _juice_pulse_tween != null and _juice_pulse_tween.is_running():
		_juice_pulse_tween.kill()
	if _juice_shake_tween != null and _juice_shake_tween.is_running():
		_juice_shake_tween.kill()


## Stinger playback stub: parameters are computed (and test-assertable via
## FeedbackMath) but no streams exist until the art bible + /asset-spec deliver
## them. The explicit null-stream guard is mandatory (ADR-0011): null-stream
## play() behavior on 4.6.3 is unverified, so the silent no-op is a code
## contract, not an assumed engine default.
func _play_stinger(m: float) -> void:
	var params: Dictionary = FeedbackMath.stinger_params(m)
	# Layer mixing (params["layers"] streams, tail, saturation) lands with the
	# assets. # TODO: art-bible-pending
	if _stinger_player.stream != null:
		_stinger_player.play()
	else:
		# Structurally silent until assets exist -- params computed above so
		# the pipeline is exercised end-to-end even before audio lands.
		pass
