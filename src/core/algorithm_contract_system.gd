## Owns one-shot Away Plans and persistent Creator Empire progression.
## Economy staging is side-effect-free; only commit_staged_return() mutates
## resources and persists the result (ADR-0021).
extends Node

signal contract_changed(contract_id: StringName)
signal ladder_changed(old_rung: int, new_rung: int)

enum State { UNARMED, ARMED, RETURN_PENDING, COMMITTING }

const DATA_PATH: String = "res://assets/data/algorithm_contracts.json"
const CONTRACT_REVISION: int = 1
const PATH_IDS: Array[StringName] = [
	&"pato_streamer", &"guru_celebryta", &"ekspert_niszowy", &"biznesmen_contentu",
]

var state: State = State.UNARMED
var armed_contract: Dictionary = {}
var business_remainder_units: int = 0
var contract_credits: int = 0
var stored_rung: int = 1
var staged_return: Dictionary = {}
var last_contract: Dictionary = {}
var open_away_plan_on_main: bool = false

var _contracts: Dictionary = {}
var _ladder: Array[Dictionary] = []
var _effects_applied: bool = false


func _ready() -> void:
	_load_definitions()
	if not ClassPathSystem.tier_unlocked.is_connected(_on_progress_gate_changed):
		ClassPathSystem.tier_unlocked.connect(_on_progress_gate_changed)
	if not PrestigeSystem.era_transitioned.is_connected(_on_era_changed):
		PrestigeSystem.era_transitioned.connect(_on_era_changed)


func _load_definitions() -> bool:
	_contracts.clear()
	_ladder.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary:
		push_error("Algorithm contract data is not a Dictionary.")
		return false
	for raw_contract: Variant in parsed.get("contracts", []):
		if not raw_contract is Dictionary or not _validate_contract(raw_contract):
			push_error("Invalid Algorithm Contract definition.")
			_contracts.clear()
			return false
		_contracts[StringName(raw_contract["id"])] = raw_contract.duplicate(true)
	var previous: Dictionary = {}
	for raw_gate: Variant in parsed.get("ladder", []):
		if not raw_gate is Dictionary or not _validate_gate(raw_gate, previous):
			push_error("Invalid Creator Empire ladder definition.")
			_contracts.clear()
			_ladder.clear()
			return false
		_ladder.append(raw_gate.duplicate(true))
		previous = raw_gate
	return _contracts.size() == 3 and _ladder.size() == 7


func _validate_contract(contract: Dictionary) -> bool:
	var id: String = String(contract.get("id", ""))
	if id not in ["drama", "business", "detox"] or int(contract.get("revision", 0)) != CONTRACT_REVISION:
		return false
	return _validate_terms(StringName(id), contract.get("terms", {}))


func _validate_terms(contract_id: StringName, terms: Dictionary) -> bool:
	match contract_id:
		&"drama":
			var value: float = float(terms.get("haters_multiplier", NAN))
			return is_finite(value) and value >= 1.25 and value <= 1.60
		&"business":
			var rate: float = float(terms.get("sponsors_per_hour", NAN))
			return is_finite(rate) and rate >= 0.75 and rate <= 2.0 and int(terms.get("units_per_sponsor", 0)) == 1000
		&"detox":
			var haters: float = float(terms.get("haters_per_hour", NAN))
			var morale: float = float(terms.get("morale_per_hour", NAN))
			return is_finite(haters) and is_finite(morale) and haters >= 6.0 and haters <= 15.0 and morale >= 8.0 and morale <= 15.0
	return false


func _validate_gate(gate: Dictionary, previous: Dictionary) -> bool:
	var rung: int = int(gate.get("rung", 0))
	if rung != _ladder.size() + 1 or String(gate.get("title_key", "")).is_empty():
		return false
	for key: String in ["eras", "mastery", "contracts"]:
		var value: int = int(gate.get(key, -1))
		if value < 0 or (not previous.is_empty() and value < int(previous.get(key, 0))):
			return false
	return true


func get_contract_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: StringName in [&"drama", &"business", &"detox"]:
		if _contracts.has(id):
			result.append(_contracts[id].duplicate(true))
	return result


func get_contract_definition(contract_id: StringName) -> Dictionary:
	return _contracts.get(contract_id, {}).duplicate(true)


func get_armed_contract_id() -> StringName:
	return StringName(armed_contract.get("id", ""))


func arm_contract(contract_id: StringName) -> bool:
	if state not in [State.UNARMED, State.ARMED] or not _contracts.has(contract_id):
		return false
	armed_contract = _contracts[contract_id].duplicate(true)
	state = State.ARMED
	contract_changed.emit(contract_id)
	SaveSystem.mark_dirty()
	return true


func cancel_contract() -> bool:
	if state != State.ARMED:
		return false
	armed_contract.clear()
	state = State.UNARMED
	contract_changed.emit(&"")
	SaveSystem.mark_dirty()
	return true


func stage_return(elapsed_seconds: int, context_override: Dictionary = {}) -> Dictionary:
	if state != State.ARMED or elapsed_seconds < OfflineProgressSystem.MIN_REPORT_THRESHOLD_SECONDS:
		return {}
	if not _validate_contract(armed_contract):
		armed_contract.clear()
		state = State.UNARMED
		return {}
	var context: Dictionary = context_override.duplicate(true) if not context_override.is_empty() else OfflineProgressSystem.capture_context()
	if not OfflineProgressSystem.is_valid_context(context):
		return {}
	var neutral: Dictionary = OfflineProgressSystem.simulate_from_context(context, elapsed_seconds)
	var chosen: Dictionary = OfflineProgressSystem.simulate_contract_from_context(
		context, elapsed_seconds, armed_contract, business_remainder_units
	)
	if not _valid_simulation(neutral) or not _valid_simulation(chosen):
		return {}
	var attribution: Dictionary = {}
	var deltas: Dictionary = {}
	for key: String in ["Reach", "Haters", "Morale", "Sponsors"]:
		attribution[key] = float(chosen["final"][key]) - float(neutral["final"][key])
		deltas[key] = float(chosen["final"][key]) - float(context[key])
	var before_rung: int = refresh_ladder()
	var predicted_rung: int = derive_rung(
		PrestigeSystem.get_era_count(), get_mastery_score(), contract_credits + 1,
		_ladder, before_rung
	)
	var crossed: Array[String] = []
	for rung_index: int in range(before_rung + 1, predicted_rung + 1):
		crossed.append(String(_ladder[rung_index - 1]["title_key"]))
	staged_return = {
		"contract_return": true,
		"contract": armed_contract.duplicate(true),
		"elapsed_seconds": maxi(0, elapsed_seconds),
		"counted_seconds": mini(maxi(0, elapsed_seconds), OfflineProgressSystem.MAX_OFFLINE_CAP_SECONDS),
		"capped": elapsed_seconds > OfflineProgressSystem.MAX_OFFLINE_CAP_SECONDS,
		"start": context.duplicate(true),
		"neutral": neutral,
		"chosen": chosen,
		"attribution": attribution,
		"resource_deltas": deltas,
		"business_remainder_before": business_remainder_units,
		"business_remainder_after": int(chosen.get("business_remainder_units", business_remainder_units)),
		"credits_before": contract_credits,
		"credits_after": contract_credits + 1,
		"rung_before": before_rung,
		"rung_after": predicted_rung,
		"crossed_title_keys": crossed,
	}
	_effects_applied = false
	state = State.RETURN_PENDING
	return staged_return.duplicate(true)


func _valid_simulation(result: Dictionary) -> bool:
	if result.is_empty() or not result.get("final", {}) is Dictionary:
		return false
	var final: Dictionary = result["final"]
	for key: String in ["Reach", "Cringe", "Haters", "Morale", "Sponsors"]:
		if not final.has(key) or not is_finite(float(final[key])):
			return false
	return true


func commit_staged_return(save_callable: Callable = Callable()) -> bool:
	if state == State.RETURN_PENDING:
		state = State.COMMITTING
		_apply_staged_effects_once()
	elif state != State.COMMITTING:
		return false
	var saved: bool = bool(save_callable.call()) if save_callable.is_valid() else SaveSystem.save_now()
	if saved:
		state = State.UNARMED
		staged_return["committed"] = true
		contract_changed.emit(&"")
	return saved


func _apply_staged_effects_once() -> void:
	if _effects_applied or staged_return.is_empty():
		return
	var typed_deltas: Dictionary[StringName, float] = {}
	for key: String in staged_return.get("resource_deltas", {}):
		typed_deltas[StringName(key)] = float(staged_return["resource_deltas"][key])
	ResourceManager.apply_delta(typed_deltas)
	ResourceManager.elapse_sponsor_shield(float(staged_return.get("elapsed_seconds", 0)))
	business_remainder_units = clampi(int(staged_return.get("business_remainder_after", business_remainder_units)), 0, 999)
	contract_credits = maxi(contract_credits, int(staged_return.get("credits_after", contract_credits)))
	var old_rung: int = stored_rung
	stored_rung = maxi(stored_rung, int(staged_return.get("rung_after", stored_rung)))
	last_contract = armed_contract.duplicate(true)
	armed_contract.clear()
	_effects_applied = true
	if stored_rung > old_rung:
		ladder_changed.emit(old_rung, stored_rung)


func repeat_last_contract() -> bool:
	if state != State.UNARMED or last_contract.is_empty():
		return false
	return arm_contract(StringName(last_contract.get("id", "")))


func clear_for_burnout() -> void:
	if state in [State.RETURN_PENDING, State.COMMITTING]:
		return
	armed_contract.clear()
	business_remainder_units = 0
	state = State.UNARMED
	contract_changed.emit(&"")


func reset_for_new_game() -> void:
	state = State.UNARMED
	armed_contract.clear()
	business_remainder_units = 0
	contract_credits = 0
	stored_rung = 1
	staged_return.clear()
	last_contract.clear()
	open_away_plan_on_main = false
	_effects_applied = false
	contract_changed.emit(&"")


func get_mastery_score() -> int:
	var total: int = 0
	for path_id: StringName in PATH_IDS:
		total += ClassPathSystem.get_lifetime_best_tier(path_id)
	return total


func refresh_ladder() -> int:
	if _ladder.is_empty():
		_load_definitions()
	var old_rung: int = stored_rung
	stored_rung = derive_rung(
		PrestigeSystem.get_era_count(), get_mastery_score(), contract_credits,
		_ladder, stored_rung
	)
	if stored_rung > old_rung:
		ladder_changed.emit(old_rung, stored_rung)
		SaveSystem.mark_dirty()
	return stored_rung


static func derive_rung(eras: int, mastery: int, credits: int, ladder: Array[Dictionary], minimum_rung: int = 1) -> int:
	var result: int = clampi(minimum_rung, 1, maxi(1, ladder.size()))
	for gate: Dictionary in ladder:
		if eras >= int(gate["eras"]) and mastery >= int(gate["mastery"]) and credits >= int(gate["contracts"]):
			result = maxi(result, int(gate["rung"]))
	return result


func get_ladder_status() -> Dictionary:
	refresh_ladder()
	var current: Dictionary = _ladder[stored_rung - 1].duplicate(true) if not _ladder.is_empty() else {}
	var next: Dictionary = _ladder[stored_rung].duplicate(true) if stored_rung < _ladder.size() else {}
	return {
		"rung": stored_rung,
		"current": current,
		"next": next,
		"eras": PrestigeSystem.get_era_count(),
		"mastery": get_mastery_score(),
		"contracts": contract_credits,
	}


func serialize_state() -> Dictionary:
	return {
		"armed_contract": armed_contract.duplicate(true),
		"business_remainder_units": business_remainder_units,
		"contract_credits": contract_credits,
		"stored_rung": stored_rung,
		"last_contract": last_contract.duplicate(true),
	}


func restore_state(data: Dictionary) -> void:
	if _contracts.is_empty():
		_load_definitions()
	business_remainder_units = clampi(int(data.get("business_remainder_units", 0)), 0, 999)
	contract_credits = maxi(0, int(data.get("contract_credits", 0)))
	stored_rung = clampi(int(data.get("stored_rung", 1)), 1, 7)
	last_contract = data.get("last_contract", {}).duplicate(true)
	var restored: Dictionary = data.get("armed_contract", {})
	armed_contract = restored.duplicate(true) if _validate_contract(restored) else {}
	state = State.ARMED if not armed_contract.is_empty() else State.UNARMED
	staged_return.clear()
	_effects_applied = false


func _on_progress_gate_changed(_path_id: StringName, _tier: int) -> void:
	refresh_ladder()


func _on_era_changed() -> void:
	refresh_ladder()
