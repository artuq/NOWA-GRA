# ADR-0001: Autoload Singleton Architecture vs Event Bus

## Status
Accepted (2026-06-20, following independent /architecture-review — verdict CONCERNS overall but no conflicts or blockers against this ADR specifically)

## Date
2026-06-19

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | Core |
| **Knowledge Risk** | LOW — Autoload singletons and signals are stable, pre-4.3 patterns; none of the documented 4.4-4.6 breaking changes touch this domain |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (first ADR) |
| **Enables** | ADR-0002 (Save file format), ADR-0003 (Scene management/boot order), all Core-layer ADRs (Action System, Decision Card weighting, Offline simulation) |
| **Blocks** | All Foundation/Core/Feature epics — no module can be implemented until its communication pattern is fixed |
| **Ordering Note** | Must be Accepted before any other ADR in this project, since every later ADR's "Key Interfaces" section assumes this pattern |

## Context

### Problem Statement
`Król Cringe'u` has 7 Core/Foundation modules (ResourceManager, HistoryFlagManager, ActionSystem, SaveSystem, OfflineProgressSystem, CardContentDatabase, DecisionCardSystem) that must communicate without tight coupling, while still being simple enough for a solo developer to maintain. The master architecture document (`docs/architecture/architecture.md`) already proposes a specific pattern (Autoload singletons, signals for peer/notification relationships, direct calls for ownership-clear writes) as Principle 2 and 4 — this ADR formalizes that proposal as a binding decision with full rationale and rejected alternatives.

### Constraints
- Solo developer — must minimize boilerplate and indirection that has no payoff at this project's scale (11 MVP systems, no plans for hot-reloadable modding or massive system count)
- GDScript only, Godot 4.6.3
- No threading anywhere (confirmed safe per Offline Progress System's bounded 1440-iteration cap)
- Must support the data flows already specified in `architecture.md` (action completion, card resolution, save/load, init order)

### Requirements
- Every module's public contract must be easy to trace from a call site to its implementation (no "what listens to this event?" archaeology)
- State ownership must be unambiguous — exactly one module owns each piece of game state
- Must not block the 6 ADRs required by `architecture.md`'s ADR backlog (this is ADR #1 in that ordering)

## Decision

Use **Godot Autoload singletons** for every Core and Foundation module (`ResourceManager`, `HistoryFlagManager`, `ActionSystem`, `SaveSystem`, `OfflineProgressSystem`, `CardContentDatabase`, `DecisionCardSystem`), with two communication patterns chosen per relationship type — not a single uniform mechanism:

1. **Direct method calls** when the caller is the sole intended trigger of a state mutation and owns the causal relationship (e.g., `ActionSystem` calling `ResourceManager.apply_delta()` after an action completes — there is exactly one place this call originates).
2. **Godot signals** when multiple unrelated modules need to react to an event without the emitter knowing or caring who's listening (e.g., `ActionSystem.action_completed` is heard by both `OnboardingGate` and `DecisionCardSystem`, neither of which `ActionSystem` should need to know about).

No central `EventBus` autoload is introduced. Each module emits its own signals; subscribers connect directly to the specific autoload they depend on.

### Architecture Diagram
(See `architecture.md`'s Module Ownership dependency diagram — this ADR is the formalization of that diagram's communication edges.)

```
Direct call (ownership-clear):     ActionSystem -> ResourceManager.apply_delta()
Signal (peer/multi-subscriber):    ActionSystem.action_completed -> [OnboardingGate, DecisionCardSystem]
```

### Key Interfaces
Each Autoload module is registered in Project Settings → Autoload, accessible globally by its singleton name (e.g., `ResourceManager.get_resource("Zasiegi")`). Signal connections are made in `_ready()` of the subscribing autoload or scene, e.g.:
```gdscript
# In DecisionCardSystem._ready()
ActionSystem.action_completed.connect(_on_action_completed)
```
No module connects to a signal it does not have a direct dependency on per `architecture.md`'s Module Ownership table — connecting "just in case" is not permitted; if a new dependency is needed, update that table first.

**Signal declaration (typed, locked per coding standard):**
```gdscript
signal action_completed(action_id: String, payload: Dictionary)
```

**Canonical Autoload boot order** (Project Settings → Autoload, top to bottom — earlier entries are ready first):
1. `ResourceManager`
2. `HistoryFlagManager`
3. `CardContentDatabase`
4. `SaveSystem`
5. `ActionSystem`
6. `OfflineProgressSystem`
7. `OnboardingGate`
8. `DecisionCardSystem`

Rule: a module that connects to another module's signal in `_ready()` must be registered *below* the emitter in this list — Autoloads initialize top-to-bottom, and a subscriber registered above its emitter will silently miss the connection (no error, the signal simply doesn't exist yet). `DecisionCardSystem` and `OnboardingGate` both subscribe to `ActionSystem.action_completed`, hence their position below it.

**`_ready()` timing safety:** no module may emit a signal before all 8 Autoloads have completed `_ready()` (e.g., no "replay missed events at boot" logic) — confirmed safe per the Data Flow #4 init order in `architecture.md`, where `OfflineProgressSystem.simulate_offline()` runs as an explicit call after load, not as a signal emission during boot.

## Alternatives Considered

### Alternative A: Central EventBus autoload
- **Description**: A single `EventBus` autoload that all modules publish to and subscribe from, using string-keyed events (`EventBus.emit("action_completed", data)`).
- **Pros**: Maximum decoupling — modules never reference each other by name. Easy to add new listeners without touching the emitter.
- **Cons**: String-keyed events lose compile-time/static-typing safety (GDScript's typed signals are stronger). Harder to trace "who handles this event" — requires grepping string literals across the codebase. Adds an indirection layer with no payoff at this project's scale (7 modules, fully known dependency graph, no plugin/mod system planned).
- **Rejection Reason**: Solves a decoupling problem this project doesn't have. The dependency graph in `architecture.md` is small, fully known at design time, and rarely changes — a central bus optimizes for a scale and uncertainty this MVP doesn't carry.

### Alternative B: Pure direct calls everywhere (no signals)
- **Description**: Every module calls every dependent module's methods directly; no signals used.
- **Pros**: Maximally traceable — every interaction is a visible function call.
- **Cons**: Breaks down the moment a single event has multiple unrelated subscribers (e.g., `action_completed` is consumed by both `OnboardingGate` and `DecisionCardSystem` — `ActionSystem` would need to know about and call both, coupling it to consumers it shouldn't need to know about).
- **Rejection Reason**: Forces emitters to enumerate their own subscribers, which inverts ownership — `ActionSystem` shouldn't need to know that `OnboardingGate` exists.

### Alternative C: Hybrid (signals for multi-subscriber events, direct calls for ownership-clear writes) — CHOSEN
Described above. Matches the data flows already specified in `architecture.md` without introducing new infrastructure.

## Consequences

### Positive
- Zero new infrastructure to build or maintain (no EventBus class, no string-event registry)
- Every signal connection is statically discoverable via Godot's typed signal system and a project-wide grep for `.connect(`
- Matches `architecture.md`'s already-approved data flows exactly — no architectural drift between this ADR and the master document

### Negative
- If the module count grows significantly past this MVP's 7 modules (e.g., Alpha-tier Team/Staff Management, Prestige/Checkpoint System), the "everyone connects directly to what they need" pattern may need revisiting — acceptable trade-off, deferred to a future ADR if it becomes a real problem
- Adding a new subscriber to an existing signal requires editing that subscriber's `_ready()` — slightly more code than a bus's "subscribe centrally" pattern, but this is the traceability win, not a cost

### Risks
- **Risk**: A future contributor (if this stops being solo dev) might reach for a global EventBus out of habit, fragmenting the pattern.
  - **Mitigation**: This ADR is the documented stance; `docs/registry/architecture.yaml` will record "no central EventBus" as a forbidden-pattern entry.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| action-system.md | `action_completed` event consumed by Onboarding/Tutorial and Decision Card System | Signal pattern — `ActionSystem` emits once, both subscribe independently |
| resource-system.md | Resource mutations must be traceable to their trigger | Direct call pattern — `apply_delta()` callers are explicit, no event indirection |
| onboarding-tutorial.md | Gates Decision Card System without Decision Card System needing to know Onboarding exists | Onboarding subscribes to `ActionSystem.action_completed`; `DecisionCardSystem.present_next_card()` checks `OnboardingGate.is_card_suppressed()` directly (ownership-clear read) |
| save-persistence-system.md | `mark_dirty()` triggered by mutations across multiple Core modules | Direct call — each mutating module calls `SaveSystem.mark_dirty()` after its own state change |

## Performance Implications
- **CPU**: Negligible — signals and direct calls in GDScript have effectively identical overhead at this project's event frequency (a handful of events per action/card resolution, not per-frame)
- **Memory**: None — no new data structures introduced
- **Load Time**: None
- **Network**: N/A (single-player, no networking)

## Migration Plan
N/A — no existing code to migrate. This is the initial architecture for `src/`.

## Validation Criteria
- Every Core/Foundation module is implemented as a Godot Autoload (verify via Project Settings → Autoload list matching the 7 modules)
- No `EventBus` or equivalent central dispatcher class exists anywhere in `src/`
- Every `.connect()` call has a corresponding entry in `architecture.md`'s Module Ownership "Consumes" column

## Related Decisions
- `docs/architecture/architecture.md` — Architecture Principles 2 and 4 (this ADR formalizes those principles)
- ADR-0002 (Save file format) — depends on this ADR's `mark_dirty()` direct-call pattern
- ADR-0003 (Scene management/boot order) — depends on this ADR's module-as-Autoload pattern
