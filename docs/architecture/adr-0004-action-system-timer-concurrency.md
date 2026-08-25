# ADR-0004: Action System Timer and Single-Concurrency Enforcement

## Status
Accepted (2026-06-20; amended for the approved action queue and effective-duration read API, documentation sync 2026-08-05)

## Date
2026-06-19

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | Core (Gameplay timer) |
| **Knowledge Risk** | LOW — `Timer` node is a stable, pre-4.3 API; no documented 4.4-4.6 breaking change touches it |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload singleton architecture — defines `ActionSystem`'s `start_action()`/`action_completed` interface this ADR implements) |
| **Enables** | Action UI implementation (cannot build the Action Grid scene until the timer/progress contract is fixed) |
| **Blocks** | Action UI epic |
| **Ordering Note** | None beyond the above |

## Context

### Problem Statement
`action-system.md` specifies 3 actions with durations 4-9s and a single-concurrency rule (only one action runs at a time). This ADR fixes the concrete Godot mechanism for timing and enforcing that rule.

### Constraints
- Godot 4.6.3, GDScript, no threading
- Action UI needs per-frame progress updates (per `action-ui.md`'s requirement that the progress bar update every frame, not throttled)
- Must integrate with ADR-0001's `start_action(action_id) -> bool` / `action_completed` signal contract

### Requirements
- Only one action may run at once. A request while one is running must enqueue up to `QUEUE_CAP`, never interrupt or restart the running Timer; only an unknown id or full queue returns `false`.
- Progress must be queryable every frame for UI display without polling overhead
- The effective duration captured when the Timer is armed must be readable without exposing the private Timer or recalculating modifiers mid-action.

## Decision

Use a **single `Timer` node** (not `Autoload`-attached as a child, since Autoloads can have child nodes) owned by the `ActionSystem` Autoload, plus a `current_action_id: StringName` field that is empty (`&""`) when idle.

```gdscript
# ActionSystem (Autoload)
var current_action_id: StringName = &""
const QUEUE_CAP: int = 10
var _queue: Array[StringName] = []
var _timer: Timer

func _ready() -> void:
    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_action_timeout)
    add_child(_timer)

func start_action(action_id: StringName) -> bool:
    if not ACTION_DURATIONS.has(action_id):
        return false
    if current_action_id != &"":
        if _queue.size() >= QUEUE_CAP:
            return false
        _queue.append(action_id)
        queue_changed.emit(_queue.duplicate())
        return true
    current_action_id = action_id
    _timer.wait_time = ACTION_DURATIONS[action_id] * ClassPathSystem.get_action_duration_multiplier(action_id)
    _timer.start()
    action_started.emit(action_id)  # Timer is armed before synchronous listeners run
    return true

func get_progress() -> float:
    if current_action_id == &"" or _timer.wait_time <= 0.0:
        return 0.0  # guards idle/divide-by-zero; start_action arms before notifying or returning
    return 1.0 - (_timer.time_left / _timer.wait_time)

func get_current_duration() -> float:
    return 0.0 if current_action_id == &"" else _timer.wait_time

func get_queue_snapshot() -> Array[StringName]:
    return _queue.duplicate()  # ordered read-only snapshot for recreated UI

func _on_action_timeout() -> void:
    var completed_id := current_action_id
    var base_rewards := ACTION_REWARDS[completed_id]
    current_action_id = &""

    # Read current Morale, scale the Reach reward (Formula C), per action-system.md:
    # "reads the current Morale multiplier to scale the final Zasięgi (Reach) reward"
    var morale := ResourceManager.get_resource(&"Morale")
    var multiplier := ResourceFormulas.action_effectiveness_multiplier(morale)
    var scaled_reach := roundf(base_rewards[&"Reach"] * multiplier)  # round-half-away-from-zero (Godot roundf); rounding is the call site's job per Resource System Story 1-4, not ResourceFormulas

    var deltas: Dictionary[StringName, float] = {
        &"Reach": scaled_reach,
        &"Cringe": base_rewards[&"Cringe"],
        &"Morale": base_rewards[&"Morale"],
    }
    ResourceManager.apply_delta(deltas)  # direct call, ownership-clear write — ADR-0001 pattern; ResourceManager clamps Cringe/Morale to [0,100]

    action_completed.emit(completed_id, deltas)  # notification only, per ADR-0001; carries the FINAL applied deltas, not raw base rewards
    _try_dequeue()  # starts queue front only when idle and no suspension is active
```

> **Corrections:** On 2026-06-23 the reward sample was updated to apply the Morale multiplier and write through ResourceManager before notification. The approved `design/quick-specs/action-queue-auto-repeat-2026-06-30.md` subsequently superseded only the busy-request rejection rule: `current_action_id` still enforces one running action, while additional accepted requests wait in a bounded queue. The 2026-08-05 sync also records `get_current_duration()` so presentation reads the exact Timer duration after Class Path modifiers.

`get_progress()` is polled by Action UI every frame via `_process()` — this is cheap (a single division) and matches the existing requirement that the progress bar update every frame without a dedicated signal-per-frame mechanism, which `Timer` doesn't offer natively anyway.

### Architecture Diagram
```
ActionUI._process() -> ActionSystem.get_progress() + get_current_duration() [poll while active]
Button.pressed -> ActionSystem.start_action(id) -> Timer.start() if idle OR queue append if running
Timer.timeout -> ActionSystem._on_action_timeout() -> emits action_completed -> dequeues when unsuspended
```

### Key Interfaces
`start_action(action_id: StringName) -> bool` means “accepted,” either started or queued. `signal action_completed(action_id: StringName, rewards: Dictionary)` carries final applied deltas. `get_progress() -> float` and `get_current_duration() -> float` are the timing reads; the latter returns the effective Timer duration captured at start and `0.0` while idle. `get_queue_snapshot() -> Array[StringName]` returns an ordered typed copy for presentation reconstruction without exposing mutation. `current_action_id` and the queue remain ephemeral across app restarts. `_try_dequeue()` is valid only while idle; lifting a card/Morale suspend during an active action must not pop-and-reappend the head or rotate FIFO order.

## Alternatives Considered

### Alternative A: Per-action Timer nodes (one Timer per action type)
- **Description**: Create 3 separate `Timer` nodes, one per action, started/stopped independently.
- **Pros**: None meaningful for this use case.
- **Cons**: Single-concurrency enforcement still requires the same `current_action_id` check — multiple Timers add no capability, just more nodes to manage and a risk of two timers running simultaneously if the concurrency check is ever bypassed.
- **Rejection Reason**: Solves nothing a single Timer doesn't already solve; pure added complexity.

### Alternative B: Manual countdown in `_process(delta)`
- **Description**: Track `remaining_time` as a float, decrement it manually each frame, fire completion when it hits zero.
- **Pros**: Slightly more control over the exact completion-frame timing.
- **Cons**: Reinvents what `Timer` already does correctly (frame-accurate one-shot countdown with automatic `timeout` signal), with more code and more chances for an off-by-one-frame bug.
- **Rejection Reason**: No benefit over the built-in `Timer` node for this use case.

### Alternative C: Single Timer + state field — CHOSEN
Described above. Minimal code, uses Godot's built-in timer correctly, matches `action-system.md`'s single-concurrency requirement directly via the `current_action_id != &""` guard.

## Consequences

### Positive
- Minimal code — `Timer` node handles all the actual countdown logic
- Single-concurrency remains explicit: one Timer/current id runs while a bounded list stores future work.
- Queueing supports idle-session planning without restarting or partially rewarding the active action.

### Negative
- None significant at this scale

### Risks
- **Risk**: If the app is killed mid-action and relaunched, the in-progress action's elapsed time is lost (Timer state isn't naturally part of the save format).
  - **Mitigation**: Out of scope per Edge Cases below — `action-system.md` doesn't require resuming a mid-flight action across restarts; on relaunch, `current_action_id` simply resets to idle (`&""`), and the player can immediately start a new action. This is an accepted simplification, not an oversight.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| action-system.md | 3 actions, durations 4-9s | `ACTION_DURATIONS` dictionary keyed by action_id |
| action-system.md | Single-concurrency (only one action runs at a time) | `current_action_id != &""` guard in `start_action()` |
| action-ui.md | Progress bar updates every frame, not throttled | `get_progress()` is a cheap per-frame poll, no throttling needed |
| onboarding-tutorial.md | Reads `action_completed` event with action type to track variety-gate progress | `action_completed(action_id, rewards)` signal unchanged from ADR-0001, carries `action_id` |

## Performance Implications
- **CPU**: Negligible — one `Timer` node, one division per frame for `get_progress()`
- **Memory**: Negligible — one `Timer` node instance
- **Load Time**: None
- **Network**: N/A

## Migration Plan
N/A — first implementation of this system.

## Validation Criteria
- Attempt `start_action()` while running: confirm it enqueues until `QUEUE_CAP`, never restarts the Timer, and rejects only the request beyond cap.
- Let an action complete: confirm `action_completed` fires with the correct `action_id` and `rewards`, and `current_action_id` resets to `&""`
- Poll `get_progress()` at the start, middle, and end of an action: confirm values are 0.0, ~0.5, and 1.0 respectively (just before completion)
- Confirm `get_current_duration()` returns the modifier-adjusted Timer duration and a synchronous `action_started` listener sees it already armed.
- Lift card suspension before the active action ends: confirm the ordered queue snapshot is unchanged; recreate ActionGrid with a pre-populated queue and confirm its strip appears immediately.
- Kill the app mid-action and relaunch: confirm the system resets to idle, not an error state

## Related Decisions
- ADR-0001 (Autoload singleton architecture) — defines the interface this ADR implements
- ADR-0003 (Scene management/boot order) — `ActionSystem.restore_state()` resets `current_action_id` to idle on every launch (no mid-action resume), consistent with this ADR's accepted simplification
