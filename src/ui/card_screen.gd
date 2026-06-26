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

## Resolution-beat hold (seconds): after a choice commits, the card stays on
## screen with the chosen option's flat `resolution_reaction` text before it
## dismisses — the algorithm's cold comment on the choice (GDD `resolving`
## state; beat duration is a data-driven tuning knob). Lowered by tests for speed.
var resolution_beat_seconds: float = 1.5

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
	# Idle until a card is presented -- invisible Controls receive no input, so
	# the Action UI beneath stays interactive.
	visible = false
	state = State.HIDDEN


func _on_card_presented(card: Dictionary) -> void:
	_card = card
	_populate(card)
	# Reset any leftover transform from a previous card's swipe.
	if _rest_captured:
		_card_node.position = _card_rest_position
	_card_node.rotation_degrees = 0.0
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


## Interruption (app backgrounded / focus lost) while dragging: reset position
## and rotation to rest INSTANTLY (no tween), state back to awaiting_swipe, drop
## the tracked touch -- per GDD Core Rules rule 8 ("no partial state persisted").
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_PAUSED and what != NOTIFICATION_WM_WINDOW_FOCUS_OUT:
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
	_option_a_label.text = "← %s" % _option_label(options, 0, "Option A")
	_option_b_label.text = "%s →" % _option_label(options, 1, "Option B")
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
	# Read the chosen option's reaction BEFORE the system consumes the card.
	var reaction: String = _reaction_for(option_index)
	# Apply effects (resources before flags, per the system) — the HUD updates
	# live underneath while the reaction is shown.
	DecisionCardSystem.resolve_choice(option_index)
	# Resolution beat: swap the situation text for the algorithm's flat reaction
	# and hide the option prompts, hold, then dismiss. state stays RESOLVING so
	# the _input guard blocks any swipe and resolve() can't re-enter mid-beat.
	_situation_label.text = reaction
	_option_a_label.visible = false
	_option_b_label.visible = false
	await get_tree().create_timer(resolution_beat_seconds).timeout
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
