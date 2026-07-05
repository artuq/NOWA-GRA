## ActionSystem owns the select-and-wait action loop's timing and
## single-concurrency enforcement.
##
## Implements ADR-0004's mechanism: a single child `Timer` node (one_shot)
## plus a `current_action_id: StringName` field that is `&""` when idle.
## `start_action()` is the sole write path for `current_action_id` (ADR-0001
## direct-call ownership) — when idle it starts immediately; when running it
## enqueues the action instead (Story 003). Returns `false` only for unknown
## action_id or a full queue (QUEUE_CAP reached).
##
## Registered as a Godot Autoload singleton per the Control Manifest's boot
## order (after `ResourceManager`, ADR-0001/ADR-0003).
##
## On resolution (Story 002 / TR-act-001, ADR-0004's 2026-06-23 correction):
## `_on_action_timeout()` reads the current Morale via
## `ResourceManager.get_resource(&"Morale")`, scales the base Reach reward by
## `ResourceFormulas.action_effectiveness_multiplier()` (round-half-away-from-
## zero via `roundf`), writes the final Reach/Cringe/Morale deltas in one
## atomic `ResourceManager.apply_delta()` call (ADR-0001 direct-call
## ownership), then emits `action_completed` carrying those same final,
## post-scaling deltas — never the raw `ACTION_REWARDS` base values.
##
## Queue (Story 003): actions are held in `_queue: Array[StringName]` (max
## QUEUE_CAP). Auto-dequeue is suppressed when a DecisionCard is presented
## (`_suspended_by_card`) or when Morale is in the Critical band
## (`_suspended_by_morale`). Both conditions are tracked independently so
## either can lift without accidentally un-suspending the other.
##
## Usage example:
##   if ActionSystem.start_action(&"nagraj_vloga"):
##       # action accepted (started or queued)
##   var progress: float = ActionSystem.get_progress()  # 0.0..1.0, safe to poll every frame
extends Node

## Per-action durations in seconds, keyed by action_id.
## Source: design/gdd/action-system.md Reward table (Nagraj vloga 6s /
## Zrób dramę 9s / Przeproś w internecie 4s).
const ACTION_DURATIONS: Dictionary[StringName, float] = {
	&"nagraj_vloga": 6.0,
	&"zrob_drame": 9.0,
	&"przeprosiny": 4.0,
	# Milestone/counter-gated unlocks (slots 4-6) -- see
	# design/quick-specs/milestone-gated-action-slots-2026-06-30.md (DDR-0001 #3).
	# Unlock conditions live in ActionGrid (ActionUnlocks), not this reward table.
	&"nagraj_kolaba": 12.0,
	&"udziel_wywiadu": 15.0,
	&"wydaj_kurs": 20.0,
}

## Per-action base reward deltas, keyed by action_id. `Reach` is scaled by
## the Morale effectiveness multiplier at resolution time (see
## `_on_action_timeout()`); `Cringe` and `Morale` are applied flat, unscaled.
## Source: design/gdd/action-system.md Reward table (Nagraj vloga +5/+2/0 /
## Zrób dramę +10/+20/-3 / Przeproś w internecie +6/-15/+5).
##
## TECH DEBT: this and `ACTION_DURATIONS` are typed const lookups (acceptable
## for this story — mirrors `ResourceManager`'s `_CLAMPED_KEYS` precedent per
## coding-standards.md). Both are candidates for extraction to an external
## `.tres` data resource once balance tuning begins, so designers can retune
## without touching code.
const ACTION_REWARDS: Dictionary[StringName, Dictionary] = {
	&"nagraj_vloga": {&"Reach": 5.0, &"Cringe": 2.0, &"Morale": 0.0},
	&"zrob_drame": {&"Reach": 10.0, &"Cringe": 20.0, &"Morale": -3.0},
	&"przeprosiny": {&"Reach": 6.0, &"Cringe": -15.0, &"Morale": 5.0},
	# Gated unlocks (slots 4-6) -- higher reward than the base 3, each self-balanced
	# by a Cringe cost feeding the Cringe->Haters->Morale chain. No Sponsors delta
	# (that faucet stays on sponsor/brand cards). Source: the quick spec above.
	&"nagraj_kolaba": {&"Reach": 16.0, &"Cringe": 8.0, &"Morale": -2.0},
	&"udziel_wywiadu": {&"Reach": 24.0, &"Cringe": 4.0, &"Morale": 3.0},
	&"wydaj_kurs": {&"Reach": 40.0, &"Cringe": 18.0, &"Morale": -5.0},
}

## English UI display names, keyed by action_id. The game's UI language is
## English (user decision, 2026-06-25); action_id keys themselves stay as-is
## (internal identifiers, not player-facing). Moved here from ActionGrid
## (Action UI epic, Story 003) so it's accessible to any Action UI zone
## without cross-zone coupling (ADR-0007) -- RunningActionOverlay needed this
## too and previously fell back to displaying the raw action_id, a real bug
## found via user playtesting.
const ACTION_DISPLAY_NAMES: Dictionary[StringName, String] = {
	&"nagraj_vloga": "Record a Vlog",
	&"zrob_drame": "Make Drama",
	&"przeprosiny": "Apologize Online",
	&"nagraj_kolaba": "Record a Collab",
	&"udziel_wywiadu": "Give an Interview",
	&"wydaj_kurs": "Launch a Course",
}

## Maximum number of actions that can sit in the queue at once. When the queue
## reaches this size, `start_action()` returns `false` and action buttons in
## ActionGrid are disabled with a "Queue full" tooltip.
const QUEUE_CAP: int = 10

## The currently running action's id, or `&""` when idle. This is the sole
## state field gating concurrency — `start_action()` is the only writer.
var current_action_id: StringName = &""

## Ordered list of queued action ids, front = next to run. Ephemeral:
## not persisted (Story 003 Out of Scope; ADR-0001 governs save state).
var _queue: Array[StringName] = []

## True while a DecisionCard is being presented. Prevents `_try_dequeue()`
## from auto-starting the next queued action until the card is resolved.
## Tracked separately from `_suspended_by_morale` so either condition can
## lift independently without accidentally clearing the other.
var _suspended_by_card: bool = false

## True while Morale is in the Critical band [0, ResourceFormulas.E_LOW_THRESHOLD).
## Prevents `_try_dequeue()` from auto-starting the next queued action.
## Tracked separately from `_suspended_by_card` (same rationale above).
var _suspended_by_morale: bool = false

## True for the duration of `_on_action_timeout()`'s own resolution work.
## `ResourceManager.apply_delta()` emits `resource_changed` synchronously,
## which can reentrantly lift a suspend flag and call `_try_dequeue()` before
## `_on_action_timeout()` has emitted `action_completed` for the action that
## just finished -- this guard makes `_try_dequeue()` a no-op during that
## window so the trailing `_try_dequeue()` call below picks it up afterward,
## preserving `action_completed` -> `action_started` emission order.
var _resolving: bool = false

var _timer: Timer

## Emitted after `_on_action_timeout()` writes the resolved deltas via
## `ResourceManager.apply_delta()` (ADR-0001 direct-call pattern,
## notification-only signal). `rewards` carries the FINAL applied deltas
## (post Morale-multiplier scaling), not the raw `ACTION_REWARDS` base
## values — per ADR-0004's 2026-06-23 correction.
signal action_completed(action_id: StringName, rewards: Dictionary[StringName, float])

## Emitted by `start_action()` immediately after a successful start (i.e.,
## exactly when it is about to return `true`) — never emitted on a rejected
## start (already running, or unknown action_id). Added for Action UI's
## RunningActionOverlay (Story 004) to react to "an action just started"
## without polling or cross-zone coupling — a one-line addition to
## ActionSystem's existing public surface, not a new architectural decision
## (ADR-0007 already governs how Action UI consumes ActionSystem's signals).
signal action_started(action_id: StringName)

## Emitted after every queue mutation (enqueue, dequeue, or clear). [param
## snapshot] is a duplicate of the queue at emission time — safe to hold
## without risking aliasing. ActionGrid connects to this to rebuild the
## queue bar and update the cap-disable state on action buttons.
signal queue_changed(snapshot: Array[StringName])

## Emitted when the combined suspend state changes (either `_suspended_by_card`
## or `_suspended_by_morale` flips and alters the effective combined value).
## ActionGrid connects to this to dim/undim the queue bar and hide/show the
## Clear button during card presentation.
signal queue_suspended_changed(is_suspended: bool)


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_action_timeout)
	add_child(_timer)
	DecisionCardSystem.card_presented.connect(_on_card_presented)
	DecisionCardSystem.card_resolved.connect(_on_card_resolved)
	ResourceManager.resource_changed.connect(_on_resource_changed)


## Named (non-lambda) handlers for the DecisionCardSystem subscriptions above —
## named so tests can explicitly disconnect them from a fresh instance in
## `after_test()` (lambdas cannot be disconnected without holding the exact
## Callable reference, which `_ready()` does not expose).
func _on_card_presented(_card: Dictionary) -> void:
	_set_card_suspended(true)


func _on_card_resolved(_card_id: StringName, _path_tag: StringName, _option: StringName) -> void:
	_set_card_suspended(false)


## Attempts to start or queue [param action_id].
##
## - If idle and [param action_id] is a known key: starts immediately, emits
##   `action_started`, returns `true`.
## - If running and queue is not full: appends to queue, emits `queue_changed`,
##   returns `true`.
## - If running and queue is full (size >= QUEUE_CAP): returns `false` with no
##   mutation.
## - If [param action_id] is not in `ACTION_DURATIONS`: returns `false` with no
##   mutation (unknown id — never crashes on a missing key).
##
## Example:
##   ActionSystem.start_action(&"zrob_drame")  # true if idle or queue not full
func start_action(action_id: StringName) -> bool:
	if not ACTION_DURATIONS.has(action_id):
		return false  # unknown action_id: reject, no mutation, no crash
	if current_action_id != &"":
		# Action already running — enqueue instead of reject.
		if _queue.size() >= QUEUE_CAP:
			return false  # queue full: reject
		_queue.append(action_id)
		queue_changed.emit(_queue.duplicate())
		return true
	# Idle: start immediately.
	current_action_id = action_id
	action_started.emit(action_id)
	_timer.wait_time = ACTION_DURATIONS[action_id]
	_timer.start()
	return true


## Returns the running action's completion fraction in `[0.0, 1.0]`. Returns
## exactly `0.0` when idle or when `wait_time <= 0.0` (divide-by-zero guard) —
## safe to poll every frame from `_process()` (ADR-0004).
##
## Example:
##   var fraction: float = ActionSystem.get_progress()
func get_progress() -> float:
	if current_action_id == &"" or _timer.wait_time <= 0.0:
		return 0.0
	return 1.0 - (_timer.time_left / _timer.wait_time)


## Returns the current number of actions in the queue. Read-only accessor —
## callers must not mutate `_queue` directly. ActionGrid uses this to determine
## whether to disable action buttons at the QUEUE_CAP limit.
func get_queue_size() -> int:
	return _queue.size()


## Empties the queue without affecting the currently running action. Safe to
## call at any time, including when idle or suspended. Emits `queue_changed`
## with an empty snapshot so the queue bar UI updates immediately.
func clear_queue() -> void:
	_queue.clear()
	queue_changed.emit([])


## Resolves the completed action: reads the current Morale, scales the base
## Reach reward by `ResourceFormulas.action_effectiveness_multiplier()`
## (round-half-away-from-zero via `roundf`), writes the final Reach/Cringe/
## Morale deltas in one atomic `ResourceManager.apply_delta()` call, then
## emits `action_completed` with those same final, post-scaling deltas. After
## emitting, attempts to dequeue the next action via `_try_dequeue()`.
## Per ADR-0004 (2026-06-23 correction) + ADR-0001's direct-call pattern.
## No-ops if there is no active action (guards against a direct/duplicate
## call when `current_action_id == &""` — the Timer itself never triggers
## this case, since it only fires after `start_action()` sets a valid id).
func _on_action_timeout() -> void:
	if current_action_id == &"":
		return
	var completed_id: StringName = current_action_id
	current_action_id = &""
	_resolving = true
	var base_rewards: Dictionary = ACTION_REWARDS[completed_id]
	var morale: float = ResourceManager.get_resource(&"Morale")
	var multiplier: float = ResourceFormulas.action_effectiveness_multiplier(morale)
	var scaled_reach: float = roundf(base_rewards[&"Reach"] * multiplier)
	# Class path tier bonus (ADR-0010 pull model): 1.0 when no active path.
	var path_bonus: float = ClassPathSystem.get_active_multiplier(completed_id)
	scaled_reach = roundf(scaled_reach * path_bonus)
	var deltas: Dictionary[StringName, float] = {
		&"Reach": scaled_reach,
		&"Cringe": base_rewards[&"Cringe"],
		&"Morale": base_rewards[&"Morale"],
	}
	ResourceManager.apply_delta(deltas)
	action_completed.emit(completed_id, deltas)
	_resolving = false
	_try_dequeue()


## Pops the front of the queue and starts it, if conditions allow. No-ops when:
## - either suspend flag is set (`_suspended_by_card` or `_suspended_by_morale`)
## - the queue is empty
## Called automatically after every action completes, and after every suspend
## lift (`_set_card_suspended(false)` / `_set_morale_suspended(false)`).
func _try_dequeue() -> void:
	if _resolving or _suspended_by_card or _suspended_by_morale or _queue.is_empty():
		return
	var next: StringName = _queue.pop_front()
	queue_changed.emit(_queue.duplicate())
	start_action(next)


## Sets the card-based suspend flag. Emits `queue_suspended_changed` only when
## the combined effective suspend state actually changes (not on every call).
## If lifting card suspension also clears the combined state, calls
## `_try_dequeue()` to auto-start the next queued action.
func _set_card_suspended(value: bool) -> void:
	if _suspended_by_card == value:
		return
	var combined_before: bool = _suspended_by_card or _suspended_by_morale
	_suspended_by_card = value
	var combined_after: bool = _suspended_by_card or _suspended_by_morale
	if combined_after != combined_before:
		queue_suspended_changed.emit(combined_after)
	if not combined_after:
		_try_dequeue()


## Sets the morale-based suspend flag. Emits `queue_suspended_changed` only
## when the combined effective suspend state actually changes. If lifting morale
## suspension also clears the combined state, calls `_try_dequeue()`.
func _set_morale_suspended(value: bool) -> void:
	if _suspended_by_morale == value:
		return
	var combined_before: bool = _suspended_by_card or _suspended_by_morale
	_suspended_by_morale = value
	var combined_after: bool = _suspended_by_card or _suspended_by_morale
	if combined_after != combined_before:
		queue_suspended_changed.emit(combined_after)
	if not combined_after:
		_try_dequeue()


## Reacts to every ResourceManager resource change. Only Morale changes are
## handled: if Morale drops below `ResourceFormulas.E_LOW_THRESHOLD` (15.0,
## the Critical band boundary), the queue is suspended. If Morale rises back
## to or above that threshold, the morale suspend is lifted (which may
## auto-start the next queued action via `_set_morale_suspended`).
func _on_resource_changed(name: StringName, new_value: float, _old: float) -> void:
	if name == &"Morale":
		_set_morale_suspended(new_value < ResourceFormulas.E_LOW_THRESHOLD)
