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
const SpotlightMinigameConfigScript: GDScript = preload(
	"res://src/core/spotlight_minigame_config.gd"
)

## Card UI lifecycle, per card-ui.md's State machine. `dragging` is declared
## now but only entered by Story 003's gesture handling.
enum State { HIDDEN, ENTERING, AWAITING_SWIPE, DRAGGING, SPOTLIGHT, RESOLVING }

var state: State = State.HIDDEN

## The card Dictionary currently shown, or {} when hidden. Received via the
## card_presented signal -- never read from DecisionCardSystem's private field.
var _card: Dictionary = {}

@onready var _situation_label: Label = %SituationLabel
@onready var _option_a_label: Label = %OptionALabel
@onready var _option_b_label: Label = %OptionBLabel
@onready var _card_node: Control = %Card
@onready var _feed_sprint: FeedSprint = %FeedSprint
@onready var _comment_moderation: CommentModeration = %CommentModeration
@onready var _brief_puzzle: BriefPuzzle = %BriefPuzzle

var _pending_spotlight_option: int = -1
var _active_spotlight: Control

## Resolution-beat timing (GDD `resolving` state). Every option owns a stable
## short/medium/long pacing class, so translating or rewriting its reaction can
## never change gameplay tempo. Milestone choices receive the existing extra
## beat so permanent decisions still land with more weight.
var resolution_beat_seconds: float = 1.5
## Deprecated test-tuning seam retained for compatibility. Setting this to zero
## disables the class offset, which keeps existing fast integration tests fast;
## production duration never reads the localized string length.
var resolution_beat_per_char: float = 1.0 / 60.0
var resolution_beat_milestone_bonus: float = 1.0
const RESOLUTION_BEAT_PACING_SECONDS: Dictionary = {
	"short": 1.5,
	"medium": 2.0,
	"long": 2.5,
}

## Juice/Feedback Card channel (ADR-0011, Story 003): magnitude-scaled
## scale-pulse + visual-offset shake at resolution. All parameters come from
## FeedbackMath (abs-only — no valence coding, registry forbidden pattern).
## Tween handles stored for kill-before-restart and for the RESOLVING branch
## of _notification().
var _juice_pulse_tween: Tween
var _juice_shake_tween: Tween
## Magnitude of the most recent resolution — public-state-field convention
## (like `state`) so tests can assert the computed value directly.
var _last_juice_magnitude: float = 0.0

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
	_situation_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_option_a_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_option_b_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	DecisionCardSystem.card_presented.connect(_on_card_presented)
	SettingsSystem.language_changed.connect(_on_language_changed)
	_feed_sprint.finished.connect(_on_spotlight_finished.bind(_feed_sprint))
	_comment_moderation.finished.connect(_on_spotlight_finished.bind(_comment_moderation))
	_brief_puzzle.finished.connect(_on_spotlight_finished.bind(_brief_puzzle))
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
	_card_node.visible = true
	_pending_spotlight_option = -1
	_reset_option_feedback()
	visible = true
	# Minimal entrance for the shell (a heavier entrance tween is deferred
	# polish): go straight to awaiting_swipe so the card is immediately swipeable.
	state = State.AWAITING_SWIPE


func _on_language_changed(_preference: StringName, _locale: StringName) -> void:
	# Settings cannot normally be opened over this modal, but keeping an open
	# card reactive makes programmatic/device-locale changes deterministic too.
	# Do not overwrite the authored reaction once resolution has begun.
	if not _card.is_empty() and state in [State.AWAITING_SWIPE, State.DRAGGING]:
		_populate(_card)


## Gesture handling (Story 003). Uses _input (not _gui_input) for robust
## full-screen touch capture, guarded by visibility/state so it only acts while
## a card is shown. The modal's STOP root still blocks the Action UI beneath via
## GUI hit-order independently of this raw-input path.
func _input(event: InputEvent) -> void:
	if state == State.HIDDEN or state == State.ENTERING or state == State.SPOTLIGHT or state == State.RESOLVING:
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
	var text: String = _localized_field(card, "text_key", "text")
	_situation_label.text = text if not text.is_empty() else String(card.get("id", "???"))
	# Meta-loop telegraph (playtest 12-3 fix, ADR-0017's preview API): the
	# Wypalenie card itself states what accepting banks, computed from the
	# live projected grant — the same number get_last_grant() will later
	# report on the Challenge Selection recap. Data lives in game systems,
	# not card copy — the static text stays untouched for every other card.
	if StringName(String(card.get("id", ""))) == BurnoutSystem.BURNOUT_CARD_ID:
		_situation_label.text += "\n\n%s" % _burnout_stake_line()

	var options: Array = card.get("options", [])
	# Doubled guillemets «« »» (U+00AB/BB, Latin-1) instead of arrows ← →
	# (U+2190/92): OpenSans lacks the arrow glyphs, which rendered as hex boxes
	# on the web build (10-1 spike); doubled per user readability feedback.
	_option_a_label.text = "«« %s" % _option_label(options, 0, tr("CARD_OPTION_A"))
	_option_b_label.text = "%s »»" % _option_label(options, 1, tr("CARD_OPTION_B"))
	# Re-show prompts in case the previous card's resolution beat hid them.
	_option_a_label.visible = true
	_option_b_label.visible = true


func _option_label(options: Array, index: int, fallback: String) -> String:
	if index >= options.size():
		return fallback
	var label: String = _localized_field(options[index], "label_key", "label")
	return label if not label.is_empty() else fallback


func _localized_field(source: Dictionary, key_field: String, fallback_field: String) -> String:
	var key: String = String(source.get(key_field, ""))
	if not key.is_empty():
		var localized: String = tr(key)
		# Godot returns the key itself when no translation exists. Never expose
		# that implementation detail to a player: use the authored English field.
		if localized != key:
			return localized
	return String(source.get(fallback_field, ""))


func _localized_reward_resource(resource_id: StringName) -> String:
	var keys: Dictionary[StringName, StringName] = {
		&"Reach": &"RESOURCE_REACH_REWARD",
		&"Cringe": &"RESOURCE_CRINGE_REWARD",
		&"Haters": &"RESOURCE_HATERS_REWARD",
		&"Morale": &"RESOURCE_MORALE_REWARD",
		&"Sponsors": &"RESOURCE_SPONSORS_REWARD",
	}
	var key: StringName = keys.get(resource_id, &"")
	return tr(key) if key != &"" else String(resource_id)


## The Wypalenie card's stake line — mirrors BurnoutWarningIndicator's
## telegraph phrasing (same nouns, same percent formatting; kept as a small
## deliberate duplication rather than a shared static — both are simple
## presentation formatters over the same compute_next_grant() source).
func _burnout_stake_line() -> String:
	var path_id: StringName = ClassPathSystem.get_active_path()
	if path_id == &"":
		return tr("CARD_BURNOUT_NO_PATH")
	var tier: int = ClassPathSystem.get_tier(path_id)
	var grant: Dictionary = PrestigeSystem.compute_next_grant(path_id, tier)
	if not grant["granted"] or grant["amount"] <= 0.0:
		return tr("CARD_BURNOUT_CAP_REACHED")
	var nouns: Dictionary[StringName, String] = {
		&"META_REACH_MULT": tr("RESOURCE_REACH"),
		&"META_SPONSOR_MULT": tr("RESOURCE_SPONSOR_INCOME"),
		&"META_HATERS_RESIST": tr("RESOURCE_HATERS_RESISTANCE"),
		&"META_SPONSOR_FLOOR": tr("RESOURCE_ERA_START_SPONSORS"),
	}
	var noun: String = nouns.get(grant["type"], String(grant["type"]))
	if grant["type"] == &"META_SPONSOR_FLOOR":
		return tr("CARD_BURNOUT_BANK_FLAT") % [int(roundf(grant["amount"])), noun]
	var pct: float = snappedf(grant["amount"] * 100.0, 0.1)
	var pct_text: String = str(int(roundf(pct))) if is_equal_approx(pct, roundf(pct)) else ("%.1f" % pct)
	return tr("CARD_BURNOUT_BANK_PERCENT") % [pct_text, noun]


## Resolves the player's choice ([param option_index]: 0 = option_A/left,
## 1 = option_B/right). This story's resolution seam -- Story 003's committed
## swipe calls this. Applies the choice via DecisionCardSystem (ownership-clear
## direct write, ADR-0001), then hides the modal and unblocks the Action UI.
## No-ops if not currently showing a card, mirroring resolve_choice()'s own
## guard against double-resolution.
func resolve(option_index: int) -> void:
	if state == State.HIDDEN or state == State.SPOTLIGHT or state == State.RESOLVING:
		return
	if _option_starts_spotlight(option_index):
		_begin_spotlight(option_index)
		return
	_complete_resolution(option_index, 0.0)


func _begin_spotlight(option_index: int) -> void:
	var minigame_id: StringName = StringName(_card.get("spotlight_minigame", ""))
	var config: Dictionary = SpotlightMinigameConfigScript.load_config(minigame_id)
	_pending_spotlight_option = option_index
	state = State.SPOTLIGHT
	_tracked_index = -1
	_card_node.visible = false
	_active_spotlight = _spotlight_for(minigame_id)
	if _active_spotlight == null or not bool(_active_spotlight.call(&"start", config)):
		var skip_option: int = int(_card.get("spotlight_skip_option", 1))
		_pending_spotlight_option = -1
		_card_node.visible = true
		_complete_resolution(skip_option, 0.0)


func _spotlight_for(minigame_id: StringName) -> Control:
	if minigame_id == &"feed_sprint":
		return _feed_sprint
	if minigame_id == &"comment_moderation":
		return _comment_moderation
	if minigame_id == &"brief_puzzle":
		return _brief_puzzle
	return null


func _on_spotlight_finished(score: float, abandoned: bool, source: Control) -> void:
	if source != _active_spotlight or state != State.SPOTLIGHT or _pending_spotlight_option < 0:
		return
	var option_index: int = int(_card.get("spotlight_skip_option", 1)) if abandoned else _pending_spotlight_option
	_pending_spotlight_option = -1
	_active_spotlight = null
	_card_node.visible = true
	_complete_resolution(option_index, score)


func _complete_resolution(option_index: int, spotlight_score: float) -> void:
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
	var reaction_pacing: String = _reaction_pacing_for(option_index)
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
	DecisionCardSystem.resolve_choice(option_index, spotlight_score)
	if not DecisionCardSystem.last_spotlight_reward.is_empty():
		var reward_parts: Array[String] = []
		for resource_id: StringName in DecisionCardSystem.last_spotlight_reward:
			reward_parts.append("+%d %s" % [
				int(roundf(DecisionCardSystem.last_spotlight_reward[resource_id])),
				_localized_reward_resource(resource_id),
			])
		reaction += "\n" + (tr("CARD_SPOTLIGHT_COMPLETE") % ", ".join(reward_parts))
	# Resolution beat: swap the situation text for the algorithm's flat reaction
	# and hide the option prompts, hold for its authored pacing class (plus the
	# milestone emphasis), then dismiss. state stays RESOLVING so the input guard
	# blocks any swipe
	# and resolve() can't re-enter mid-beat.
	_situation_label.text = reaction
	_option_a_label.visible = false
	_option_b_label.visible = false
	await get_tree().create_timer(_resolution_beat_duration(reaction_pacing, has_milestone)).timeout
	# The resolve_choice() above can END THIS SCENE: accepting the Wypalenie
	# card runs PrestigeSystem.on_burnout_accepted() -> era_transitioned ->
	# ActionScreen's change_scene_to_file() (ADR-0018), which frees this node
	# (and its whole scene) at the end of that frame — while this coroutine is
	# still parked on the beat timer above. Resuming then would touch a freed
	# instance ("previously freed instance" errors, and in the editor a hard
	# stop). Nothing below needs to run in that case: the scene is gone.
	# Found 2026-07-28 chasing the reported era-transition failure.
	if not is_inside_tree():
		return
	_card = {}
	visible = false
	state = State.HIDDEN


## Returns the chosen option's `resolution_reaction`, or a neutral fallback when
## a card has none authored yet (per the GDD, some cards' reactions are still an
## open question). The fallback stays factual/non-judgmental (anti-pillar rule).
func _reaction_for(option_index: int) -> String:
	var options: Array = _card.get("options", [])
	if option_index >= options.size():
		return tr("CARD_REACTION_FALLBACK")
	var reaction: String = _localized_field(options[option_index], "reaction_key", "resolution_reaction")
	return reaction if not reaction.is_empty() else tr("CARD_REACTION_FALLBACK")


func _reaction_pacing_for(option_index: int) -> String:
	var options: Array = _card.get("options", [])
	if option_index < 0 or option_index >= options.size():
		return "medium"
	var pacing: String = String(options[option_index].get("reaction_pacing", "medium"))
	return pacing if RESOLUTION_BEAT_PACING_SECONDS.has(pacing) else "medium"


func _option_starts_spotlight(option_index: int) -> bool:
	var options: Array = _card.get("options", [])
	if option_index < 0 or option_index >= options.size():
		return false
	return bool(options[option_index].get("starts_spotlight", false))


## True if the chosen option permanently changes the narrative (sets a history
## milestone) — earns the heavier/longer resolution beat (GDD requirement).
func _option_sets_milestone(option_index: int) -> bool:
	var options: Array = _card.get("options", [])
	if option_index >= options.size():
		return false
	return options[option_index].has("milestone_to_set")


## Resolution-beat hold in seconds. The class is authored with the option and
## remains identical in every locale. The deprecated multiplier is only a test
## seam; no display copy participates in this calculation.
func _resolution_beat_duration(pacing: String, has_milestone: bool) -> float:
	var pacing_offset: float = float(RESOLUTION_BEAT_PACING_SECONDS.get(pacing, RESOLUTION_BEAT_PACING_SECONDS["medium"])) - 1.5
	var legacy_scale: float = clampf(resolution_beat_per_char / (1.0 / 60.0), 0.0, 1.0)
	var duration: float = resolution_beat_seconds + pacing_offset * legacy_scale
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
## (always -- lowest tier still plays, TR-juice-004) and shake (only at
## m >= 0.3, amplitude/duration from FeedbackMath). Same parameters for
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
	# Reduce-motion (art-bible.md Section 7 MANDATE): read directly from the
	# SettingsSystem Autoload -- FeedbackMath stays stateless (ADR-0011), the
	# flag is passed in here, never read internally by FeedbackMath itself.
	var amplitude: float = FeedbackMath.shake_amplitude_px(m, SettingsSystem.reduce_motion)
	if amplitude <= 0.0:
		# Keep the field an honest signal: null means "no shake this resolve"
		# (a stale dead-tween reference would break that invariant on a
		# long-lived instance -- code-review finding, 2026-07-06).
		_juice_shake_tween = null
	else:
		var rest: Vector2 = _card_rest_position if _rest_captured else _card_node.position
		var duration: float = FeedbackMath.shake_duration_sec(m, SettingsSystem.reduce_motion)
		_juice_shake_tween = create_tween()
		_juice_shake_tween.tween_property(_card_node, "position", rest + Vector2(amplitude, 0.0), duration * 0.25)
		_juice_shake_tween.tween_property(_card_node, "position", rest - Vector2(amplitude * 0.6, 0.0), duration * 0.25)
		_juice_shake_tween.tween_property(_card_node, "position", rest + Vector2(amplitude * 0.3, 0.0), duration * 0.25)
		_juice_shake_tween.tween_property(_card_node, "position", rest, duration * 0.25)


func _kill_juice_tweens() -> void:
	if _juice_pulse_tween != null and _juice_pulse_tween.is_running():
		_juice_pulse_tween.kill()
	if _juice_shake_tween != null and _juice_shake_tween.is_running():
		_juice_shake_tween.kill()
