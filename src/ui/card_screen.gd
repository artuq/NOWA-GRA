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

func _ready() -> void:
	DecisionCardSystem.card_presented.connect(_on_card_presented)
	# Idle until a card is presented -- invisible Controls receive no input, so
	# the Action UI beneath stays interactive.
	visible = false
	state = State.HIDDEN


func _on_card_presented(card: Dictionary) -> void:
	_card = card
	_populate(card)
	visible = true
	# Minimal entrance for the shell (Story 003 replaces this with a tween):
	# go straight to awaiting_swipe so the card is immediately interactable.
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
	DecisionCardSystem.resolve_choice(option_index)
	_card = {}
	visible = false
	state = State.HIDDEN
