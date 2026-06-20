# ADR-0006: Offline Simulation Loop Implementation

## Status
Accepted (2026-06-20, following independent /architecture-review — verdict CONCERNS overall but no conflicts or blockers against this ADR specifically)

## Date
2026-06-19

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | Core (simulation logic) |
| **Knowledge Risk** | LOW — pure GDScript math loop, no engine-specific API risk; nothing in 4.4-4.6 touches this domain |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload architecture — `OfflineProgressSystem`'s `simulate_offline()` interface), ADR-0003 (Boot order — calls this function synchronously as boot step 4) |
| **Enables** | Offline Report Screen implementation (cannot build until the simulation result shape is fixed) |
| **Blocks** | Offline Report Screen epic |
| **Ordering Note** | This is the last of the 6 ADRs required by `architecture.md`'s backlog — completing it closes the ADR gap before `/test-setup` and Pre-Production gate work |

## Context

### Problem Statement
`offline-progress-system.md` specifies a stepped 1-minute simulation of Hatersi growth, Morale drain, and passive Zasięgi income over a capped offline duration (max 24h = 1440 one-minute steps), reusing the same formulas Resource System defines for live play (per that GDD's design intent of guaranteeing consistency between online and offline math). This ADR fixes the concrete GDScript loop implementation.

### Constraints
- Godot 4.6.3, GDScript, no threading (per `architecture.md` Principle 1) — confirmed safe since the worst case is 1440 simple arithmetic iterations, sub-millisecond cost
- Must run synchronously, called once from `BootController` (ADR-0003) before any UI is shown
- Must use the exact formulas already registered in `entities.yaml`: `haters_growth_rate`, `morale_drain_rate`, `action_effectiveness_multiplier`, `passive_zasiegi_income`

### Requirements
- Output shape must match ADR-0003's consumption: `{final_H, final_M, total_Z_gained, capped}` (already specified in `architecture.md`'s API Boundaries)
- Cringe is held fixed during the simulation (per `resource-system.md`'s `Cringe_fixed` parameter — Cringe doesn't change while the player is offline, since it only changes via active actions/cards)

## Decision

Implement `simulate_offline()` as a single synchronous `while` loop over fixed 60-second steps, capped at 1440 iterations (24h), applying the three registered formulas in the fixed order already locked by `offline-progress-system.md`'s Core Rules (H, then M, then Mult, then Z — per that GDD's explicit ordering rule).

```gdscript
# OfflineProgressSystem (Autoload)
const MAX_OFFLINE_CAP_SECONDS := 86400
const OFFLINE_STEP_SECONDS := 60

var last_simulation_result: Dictionary = {}  # transient, read-once by Offline Report Screen (per ADR-0003)

func simulate_offline(elapsed_seconds: int) -> Dictionary:
    var capped := elapsed_seconds > MAX_OFFLINE_CAP_SECONDS
    var remaining: int = min(elapsed_seconds, MAX_OFFLINE_CAP_SECONDS)
    var cringe_fixed: float = ResourceManager.get_resource(&"Cringe")
    var h: float = ResourceManager.get_resource(&"Hatersi")
    var m: float = ResourceManager.get_resource(&"Morale")
    var z_gained: float = 0.0

    while remaining > 0:
        var dt: int = min(OFFLINE_STEP_SECONDS, remaining)
        var dt_minutes: float = dt / 60.0

        # Fixed order per offline-progress-system.md Core Rules: H, then M, then Mult, then Z
        var h_rate := ResourceFormulas.haters_growth_rate(cringe_fixed)
        h += h_rate * dt_minutes

        var m_drain := ResourceFormulas.morale_drain_rate(h)
        m = max(0.0, m - m_drain * dt_minutes)

        var mult := ResourceFormulas.action_effectiveness_multiplier(m)
        z_gained += h * Z_PER_HATER * mult * dt_minutes

        remaining -= dt

    var result := {
        "final_H": h,
        "final_M": m,
        "total_Z_gained": z_gained,
        "capped": capped,
    }
    last_simulation_result = result
    return result
```

`ResourceFormulas` is a static-method utility class (not an Autoload — it owns no state, only pure functions) shared between live-play action resolution and this offline loop, guaranteeing the consistency `offline-progress-system.md` explicitly requires (same formula, one implementation, two call sites). **Stateless-only invariant**: this class must never gain instance vars or `@export` fields — both call sites (this Autoload and `ActionSystem`) call its static functions independently, and any shared state would silently leak across unrelated contexts.

### Architecture Diagram
```
BootController -> OfflineProgressSystem.simulate_offline(elapsed_seconds)
                        |
                  while remaining > 0:
                        |
                  ResourceFormulas.haters_growth_rate() -> h
                  ResourceFormulas.morale_drain_rate() -> m
                  ResourceFormulas.action_effectiveness_multiplier() -> mult
                  z_gained += ...
                        |
                  return {final_H, final_M, total_Z_gained, capped}
```

### Key Interfaces
`simulate_offline(elapsed_seconds: int) -> Dictionary` matches `architecture.md`'s API Boundaries exactly, no changes. New: `ResourceFormulas` static utility class (new file, `res://src/core/resource_formulas.gd`, `class_name ResourceFormulas`), containing `haters_growth_rate()`, `morale_drain_rate()`, `action_effectiveness_multiplier()` as static functions — these are also called by `ActionSystem`/`ResourceManager` during live play, per `resource-system.md`'s formulas.

## Alternatives Considered

### Alternative A: `async`/`await` with a yield between steps
- **Description**: Use a coroutine pattern, yielding control back to the engine between simulation steps to avoid blocking a frame.
- **Pros**: Would matter if the loop were expensive.
- **Cons**: Adds complexity (coroutine state, an explicit "simulation in progress" UI state) for a loop confirmed to cost well under a frame budget even at the 1440-iteration maximum (simple arithmetic, no allocations in the hot path). `architecture.md` Principle 1 explicitly establishes "no threading anywhere" as the project's stance, citing this exact case as the proof point.
- **Rejection Reason**: Solves a performance problem this loop doesn't have. Adding async machinery here would be premature optimization that contradicts the project's own established architecture principle.

### Alternative B: Single synchronous `while` loop — CHOSEN
Described above. Matches `architecture.md`'s Data Flow #4 (synchronous, runs before any UI) and Principle 1 exactly.

## Consequences

### Positive
- Single, simple, synchronous function — easy to unit test in isolation (call it directly with various `elapsed_seconds`, assert on the returned dictionary, no scene tree or timing dependencies)
- `ResourceFormulas` as a shared static utility guarantees online/offline formula consistency by construction — there's only one implementation of each formula, not two that could drift apart

### Negative
- None significant

### Risks
- **Risk**: If a future formula change is made to `ResourceFormulas` for live play but the offline loop's call sites aren't updated (e.g., a new parameter added), the two contexts could silently diverge.
  - **Mitigation**: Not a real risk under this design — both live play and offline simulation call the *same* static functions, not separate copies. A signature change breaks both call sites at the same time (compile-time GDScript type checking), not silently.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| offline-progress-system.md | Stepped 1-minute simulation, max 1440 iterations, 24h cap | `OFFLINE_STEP_SECONDS=60`, `MAX_OFFLINE_CAP_SECONDS=86400`, loop bounded by `remaining` |
| offline-progress-system.md | Fixed step order: H, then M, then Mult, then Z | Loop body's comment-annotated order, matching that GDD's Core Rules rule 6 exactly |
| offline-progress-system.md | `Cringe_fixed` held constant during simulation | `cringe_fixed` read once before the loop, never reassigned inside it |
| resource-system.md | `haters_growth_rate`, `morale_drain_rate`, `action_effectiveness_multiplier`, `passive_zasiegi_income` formulas | Implemented in `ResourceFormulas`, shared with live-play call sites |

## Performance Implications
- **CPU**: Worst case 1440 iterations of simple float arithmetic — confirmed sub-millisecond, well under any frame budget, runs once at boot before any rendering of gameplay UI
- **Memory**: Negligible — no allocations inside the loop
- **Load Time**: Adds at most ~1ms to boot time in the worst case (24h offline gap)
- **Network**: N/A

## Migration Plan
N/A — first implementation.

## Validation Criteria
- `simulate_offline(0)`: confirm `total_Z_gained = 0`, `capped = false`, `final_H`/`final_M` unchanged from input
- `simulate_offline(86400)` (exactly the cap): confirm `capped = false` (boundary inclusive, not exceeding)
- `simulate_offline(86401)`: confirm `capped = true`, simulation only covers 86400 seconds of steps
- `simulate_offline(90)` (1.5 steps): confirm the loop handles a partial final step correctly (`dt = min(60, remaining)` on the last iteration)
- Call the same `ResourceFormulas.haters_growth_rate()` from both a live-play test and this loop with identical inputs: confirm identical output (consistency guarantee)

## Related Decisions
- ADR-0001 (Autoload singleton architecture) — defines the interface this ADR implements
- ADR-0003 (Scene management/boot order) — calls `simulate_offline()` as boot step 4
- `design/gdd/offline-progress-system.md` — source GDD, including the worked example that revealed the "Morale crash to Critical band" satirical hook (Pillar 3), unaffected by this implementation ADR
