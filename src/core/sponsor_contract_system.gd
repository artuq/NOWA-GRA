## Owns the one-shot Sponsor Career Contract: a small persisted state machine
## that remembers choices and schedules two controlled follow-up cards between
## ordinary action beats. It never applies card rewards itself; resolution
## stays exclusively in DecisionCardSystem.
extends Node

const CONFIG_PATH: String = "res://assets/data/sponsor_contract.json"

const STATE_NOT_STARTED: StringName = &"not_started"
const STATE_CAMPAIGN: StringName = &"campaign"
const STATE_FALLOUT_DUE: StringName = &"fallout_due"
const STATE_RECOVERY: StringName = &"recovery"
const STATE_FINALE_DUE: StringName = &"finale_due"
const STATE_COMPLETED: StringName = &"completed"
const STATE_CALLBACK_DUE: StringName = &"callback_due"
const STATE_CLOSED: StringName = &"closed"

const _VALID_STATES: Array[StringName] = [
	STATE_NOT_STARTED,
	STATE_CAMPAIGN,
	STATE_FALLOUT_DUE,
	STATE_RECOVERY,
	STATE_FINALE_DUE,
	STATE_COMPLETED,
	STATE_CALLBACK_DUE,
	STATE_CLOSED,
]
const _VALID_OPENING_CHOICES: Array[StringName] = [&"a", &"b"]
const _VALID_FINAL_CHOICES: Array[StringName] = [&"honest_report", &"sell_legend"]

## Emitted after every meaningful state/progress mutation. Presentation gets a
## duplicate snapshot and never reads this module's private fields directly.
signal contract_changed(snapshot: Dictionary)

var _config: Dictionary = {}
var _state: StringName = STATE_NOT_STARTED
var _actions_completed: int = 0
var _opening_choice: StringName = &""
var _fallout_choice: StringName = &""
var _final_choice: StringName = &""


func _init() -> void:
	configure(_load_config_file())


func _ready() -> void:
	ActionSystem.action_completed.connect(_on_action_completed)
	DecisionCardSystem.card_resolved.connect(_on_card_resolved)


## Replaces tuning/content ids from a validated Dictionary. This explicit seam
## keeps unit tests deterministic and makes thresholds data-driven.
func configure(config: Dictionary) -> bool:
	if not _is_valid_config(config):
		push_error("SponsorContractSystem: invalid config")
		return false
	_config = config.duplicate(true)
	return true


## Consumes one completed live action. Only active inter-card objectives count;
## extra actions while a story card is already due are ignored.
func process_action_completed() -> void:
	var threshold: int = _actions_required_for_state(_state)
	if threshold <= 0:
		return
	_actions_completed = mini(_actions_completed + 1, threshold)
	if _actions_completed >= threshold:
		_state = STATE_FALLOUT_DUE if _state == STATE_CAMPAIGN else STATE_FINALE_DUE
	_mark_changed()


## Consumes a stable card/option id pair. Player-facing labels and locale never
## participate in routing, so Polish transcreation cannot alter mechanics.
func process_card_resolved(card_id: StringName, option_id: StringName) -> void:
	if _state == STATE_NOT_STARTED and card_id == StringName(_config["opening_card_id"]):
		if option_id not in _VALID_OPENING_CHOICES:
			return
		_opening_choice = option_id
		_actions_completed = 0
		_state = STATE_CAMPAIGN
		_mark_changed()
		return

	if _state == STATE_FALLOUT_DUE and card_id == get_due_card_id():
		_fallout_choice = option_id
		_actions_completed = 0
		_state = STATE_RECOVERY
		_mark_changed()
		return

	if _state == STATE_FINALE_DUE and card_id == StringName(_config["finale_card_id"]):
		_final_choice = option_id
		_actions_completed = 0
		_state = STATE_COMPLETED
		HistoryFlagManager.set_milestone(&"contract.sponsor.completed")
		_mark_changed()
		return

	if _state == STATE_CALLBACK_DUE and card_id == get_due_card_id():
		_state = STATE_CLOSED
		_mark_changed()


## Arms a delayed narrative callback only after a real return of at least the
## configured duration. Offline time unlocks a decision; it never resolves it.
func process_offline_elapsed(elapsed_seconds: int) -> void:
	if _state != STATE_COMPLETED:
		return
	if elapsed_seconds < int(_config.get("callback_offline_seconds_required", 300)):
		return
	_state = STATE_CALLBACK_DUE
	_mark_changed()


## True only when DecisionCardSystem should select a controlled follow-up.
func has_due_card() -> bool:
	return _state in [STATE_FALLOUT_DUE, STATE_FINALE_DUE, STATE_CALLBACK_DUE]


## Returns the exact authored follow-up id, or an empty StringName otherwise.
func get_due_card_id() -> StringName:
	if _state == STATE_FALLOUT_DUE:
		return StringName(_config["fallout_cards"].get(String(_opening_choice), ""))
	if _state == STATE_FINALE_DUE:
		return StringName(_config["finale_card_id"])
	if _state == STATE_CALLBACK_DUE:
		return StringName(_config["callback_cards"].get(String(_final_choice), ""))
	return &""


## Locale-neutral UI/read model. Stage 1 is the opening decision already shown;
## active HUD progress therefore begins at stage 2 of 3.
func get_snapshot() -> Dictionary:
	return {
		"state": String(_state),
		"active": _state not in [STATE_NOT_STARTED, STATE_COMPLETED, STATE_CLOSED],
		"actions_completed": _actions_completed,
		"actions_required": _actions_required_for_state(_state),
		"due_card_id": get_due_card_id(),
		"stage_number": 2 if _state in [STATE_CAMPAIGN, STATE_FALLOUT_DUE] else (3 if _state in [STATE_RECOVERY, STATE_FINALE_DUE] else 4),
		"stage_total": 4,
		"opening_choice": String(_opening_choice),
		"fallout_choice": String(_fallout_choice),
		"final_choice": String(_final_choice),
	}


## Save block owned by this system. Choices are retained after completion as
## narrative memory for future cards and career receipts.
func serialize_state() -> Dictionary:
	return {
		"state": String(_state),
		"actions_completed": _actions_completed,
		"opening_choice": String(_opening_choice),
		"fallout_choice": String(_fallout_choice),
		"final_choice": String(_final_choice),
	}


## Restores and sanitizes one save block. Unknown/impossible state falls back
## to a fresh contract rather than scheduling a malformed card.
func restore_state(data: Dictionary) -> void:
	var restored_state: StringName = StringName(data.get("state", STATE_NOT_STARTED))
	var restored_opening: StringName = StringName(data.get("opening_choice", ""))
	var restored_final: StringName = StringName(data.get("final_choice", ""))
	if restored_state not in _VALID_STATES:
		_reset_fields()
		emit_changed()
		return
	if restored_state != STATE_NOT_STARTED and restored_opening not in _VALID_OPENING_CHOICES:
		_reset_fields()
		emit_changed()
		return
	if restored_state in [STATE_COMPLETED, STATE_CALLBACK_DUE, STATE_CLOSED] and restored_final not in _VALID_FINAL_CHOICES:
		_reset_fields()
		emit_changed()
		return

	_state = restored_state
	_opening_choice = restored_opening
	_fallout_choice = StringName(data.get("fallout_choice", ""))
	_final_choice = restored_final
	var threshold: int = _actions_required_for_state(_state)
	_actions_completed = clampi(int(data.get("actions_completed", 0)), 0, threshold) if threshold > 0 else 0
	emit_changed()


## Clears all career-specific progress for New Game.
func reset_for_new_game() -> void:
	_reset_fields()
	emit_changed()


func _on_action_completed(_action_id: StringName, _rewards: Dictionary) -> void:
	process_action_completed()


func _on_card_resolved(card_id: StringName, _path_tag: StringName, option_id: StringName) -> void:
	process_card_resolved(card_id, option_id)


func _actions_required_for_state(state_name: StringName) -> int:
	if state_name == STATE_CAMPAIGN:
		return int(_config.get("campaign_actions_required", 0))
	if state_name == STATE_RECOVERY:
		return int(_config.get("recovery_actions_required", 0))
	return 0


func _mark_changed() -> void:
	SaveSystem.mark_dirty()
	emit_changed()


func emit_changed() -> void:
	contract_changed.emit(get_snapshot().duplicate(true))


func _reset_fields() -> void:
	_state = STATE_NOT_STARTED
	_actions_completed = 0
	_opening_choice = &""
	_fallout_choice = &""
	_final_choice = &""


func _load_config_file() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("SponsorContractSystem: missing %s" % CONFIG_PATH)
		return {}
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("SponsorContractSystem: could not open %s" % CONFIG_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _is_valid_config(config: Dictionary) -> bool:
	if int(config.get("schema_version", 0)) != 1:
		return false
	if String(config.get("opening_card_id", "")).is_empty():
		return false
	if int(config.get("campaign_actions_required", 0)) <= 0:
		return false
	if int(config.get("recovery_actions_required", 0)) <= 0:
		return false
	if String(config.get("finale_card_id", "")).is_empty():
		return false
	if int(config.get("callback_offline_seconds_required", 0)) < 300:
		return false
	var fallout_cards: Variant = config.get("fallout_cards", {})
	var callback_cards: Variant = config.get("callback_cards", {})
	return (
		typeof(fallout_cards) == TYPE_DICTIONARY
		and not String(fallout_cards.get("a", "")).is_empty()
		and not String(fallout_cards.get("b", "")).is_empty()
		and typeof(callback_cards) == TYPE_DICTIONARY
		and not String(callback_cards.get("honest_report", "")).is_empty()
		and not String(callback_cards.get("sell_legend", "")).is_empty()
	)
