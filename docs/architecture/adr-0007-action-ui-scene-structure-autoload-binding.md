# ADR-0007: Action UI Scene Structure and Autoload Binding Pattern

## Status
Proposed

## Date
2026-06-24

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | UI |
| **Knowledge Risk** | MEDIUM — Control node fundamentals (anchors, `_process()`, signal connections, `TouchScreenButton`/`Button` touch handling) are stable, well-covered training-data territory; the Modern editor theme and any UI-specific 4.4-4.6 rendering changes are post-cutoff and unverified for this specific use case |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None directly — this ADR uses only `Control`, `Button`, `ProgressBar`, `_process()`, and standard signal connection syntax, all stable since well before 4.4 |
| **Verification Required** | `Button` (not `TouchScreenButton`) confirmed correct by engine specialist review (2026-06-24) — plain `Button` receives synthesized touch events project-wide; `TouchScreenButton` is a legacy `Node2D`-based control that doesn't integrate with `Control` layout/theming and is discouraged here. Remaining open item: each slot button's `custom_minimum_size` must be verified to meet a real touch-target minimum once the scene exists — node type is settled, target *size* is not yet verified (see Validation Criteria) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload singleton architecture — direct-call/signal split this ADR applies at the UI layer), ADR-0004 (`ActionSystem.get_progress()` polling contract, already locked) |
| **Enables** | Action UI epic's stories (currently blocked pending this ADR) |
| **Blocks** | None |
| **Ordering Note** | This is the first Presentation-layer ADR in the project — no prior UI/Control-node precedent exists to extend, only the Core/Foundation Autoload patterns from ADR-0001/0004 to apply consistently |

## Context

### Problem Statement
`action-ui.md` specifies a 3-zone screen (Resource HUD, Action Grid, Running Action Overlay) consuming `ResourceManager`'s 5 resources and `ActionSystem`'s state/progress/completion signal. ADR-0001 already locked the general Autoload-consumption pattern (direct calls for ownership-clear writes, signals for multi-subscriber events) and ADR-0004 already locked that `ActionSystem.get_progress()` is polled every frame by Action UI specifically. What remains undecided is the Control-node **scene structure** itself: how many scripts, how they're organized relative to the 3 GDD zones, and how each zone's script obtains the Autoload data it needs to render.

### Constraints
- Godot 4.6.3, GDScript, Control nodes — first UI/scene work in this project, no existing precedent to extend
- Touch-only input per `technical-preferences.md`: large touch areas, no hover-only interactions
- The 3 zones have meaningfully different update cadences per the GDD: Resource HUD updates on resource change (event-driven), Action Grid updates on action start/lock-unlock (event-driven, infrequent), Running Action Overlay updates every frame while an action is active (`_process()`-driven, per ADR-0004's polling contract)
- Must not introduce a central EventBus or UI-internal message-passing layer — already a forbidden pattern in `docs/registry/architecture.yaml` (ADR-0001), and this project's scale (one screen, 3 zones, 2 Autoload dependencies) doesn't need one

### Requirements
- Each zone's script must read its own Autoload data directly — no relay layer
- The Running Action Overlay's `_process()`-driven polling must not also run when idle (wasted per-frame work for zones that don't need it)
- Button-tap-to-Autoload-call must be a single, traceable line per button (no indirection)

## Decision

**Alternative B — separate script per zone, no internal signal bus, no mediating layer.** Three sibling Control nodes under a single root `ActionScreen` (`res://scenes/action_screen/action_screen.tscn`), each with its own script, each calling Autoloads directly:

- `ResourceHud` (`resource_hud.gd`): connects to `ResourceManager.resource_changed` in `_ready()`, updates only the changed resource's label on each signal — never polls, never reads all 5 resources on every frame.
- `ActionGrid` (`action_grid.gd`): each of the 6 slot buttons' `pressed` signal connects directly to a handler that calls `ActionSystem.start_action(action_id)`. Connects to `ActionSystem.action_completed` to re-enable buttons and hide the overlay reference it holds (see below). Locked-slot buttons are `disabled = true` set once at `_ready()` (or on a future milestone-unlock event — out of scope until that event exists), never polled.
- `RunningActionOverlay` (`running_action_overlay.gd`): the only zone using `_process()`, and only while `ActionSystem.current_action_id != &""` (matching ADR-0004's existing "guards divide-by-zero when idle" contract on `get_progress()` — this ADR extends that same idle-guard idea to the UI's per-frame work, not just the formula). `_process()` is enabled/disabled via `set_process(bool)` toggled by the same `action_completed` signal `ActionGrid` already connects to (each zone owns its own connection — no relay between zones). **Control nodes process by default** — `_ready()` must explicitly call `set_process(not ActionSystem.current_action_id.is_empty())` once, checking the actual state at scene load, not just assuming idle. Without this, the overlay would poll needlessly every frame from scene entry until the first `action_completed` signal ever fires.

No zone calls another zone's methods or emits signals to another zone. Each zone is independently testable/replaceable; the *only* shared contract between zones is that they all read the same Autoloads, which is already locked by ADR-0001.

### Architecture Diagram
```
ActionScreen (Control, root)
  ├── ResourceHud (Control)
  │     └── connects: ResourceManager.resource_changed -> update one label
  ├── ActionGrid (Control)
  │     ├── 6x slot Button -> pressed -> ActionSystem.start_action(id)
  │     └── connects: ActionSystem.action_completed -> re-enable buttons
  └── RunningActionOverlay (Control)
        ├── connects: ActionSystem.action_completed -> set_process(false), hide()
        └── _process(): ActionSystem.get_progress() -> update bar fill (only while visible/processing)
```

### Key Interfaces
No new Autoload-level interfaces — this ADR only fixes how existing interfaces (`ResourceManager.get_resource()`/`resource_changed`, `ActionSystem.start_action()`/`get_progress()`/`action_completed`) are consumed from the Control-node side. New scene-local methods (e.g., `ResourceHud._on_resource_changed()`) are implementation detail, not part of any cross-system contract, and not registered in `docs/registry/architecture.yaml`.

## Alternatives Considered

### Alternative A: Single root Control script handling all 3 zones
- **Description**: One script (`action_screen.gd`) on the root node owns all rendering logic for all 3 zones directly.
- **Pros**: Fewest files; no question of how zones "find" each other since there's only one script.
- **Cons**: Mixes 3 genuinely different update cadences (event-driven HUD, event-driven Grid, per-frame Overlay) into one script's `_process()`/signal handlers — `_process()` would need an internal `if` guard for the Overlay-only work, every frame, even when nothing is running. Also makes the script grow with every future zone (Sponsors shop, Class Path indicator, etc.) rather than staying scoped to one GDD-defined zone.
- **Rejection Reason**: Conflates concerns that the GDD itself already separates into 3 zones with different lifecycles. `coding-standards.md`'s cyclomatic-complexity-under-10 guidance is also harder to hold once one script does everything.

### Alternative C: MVC-style mediating presenter script
- **Description**: A `ActionScreenPresenter` script sits between the Autoloads and 3 "dumb" view-only Control scripts, translating Autoload state into view-update calls.
- **Pros**: Maximizes testability of presentation logic independent of the scene tree (presenter could be unit-tested headlessly).
- **Cons**: Adds an entire layer and a new internal contract (presenter-to-view calls) for a 3-zone, 2-Autoload-dependency screen. This is exactly the kind of indirection ADR-0001 already rejected for the *backend* (Alternative A there, a central EventBus) for the same reason: solves a decoupling problem this project's scale doesn't have.
- **Rejection Reason**: Premature abstraction. If Action UI grows much more complex (e.g., once Juice/Feedback System and Main Navigation are added in Vertical Slice), revisit — but per-zone direct-call scripts are simpler and sufficient for the GDD's actual MVP scope.

## Consequences

### Positive
- Each zone's script is independently readable against its own slice of the GDD (Resource HUD's script only needs the Resource HUD section, etc.)
- No new indirection layer to learn or maintain — consistent with ADR-0001's existing direct-call philosophy, just applied one layer up
- `RunningActionOverlay`'s `set_process(false)`-while-idle guard keeps per-frame UI work at zero cost when no action is running, addressing the GDD's "every frame, not throttled" requirement only where it actually applies

### Negative
- If a future zone needs data from another zone (not from an Autoload), there's no established relay pattern yet — would need a new ADR or an explicit exception at that time
- Three separate scripts means three separate `_ready()` signal-connection blocks to keep correct, rather than one — slightly more boilerplate than Alternative A for this specific screen size

### Risks
- **Risk**: A future zone might be tempted to read Autoload state via another zone instead of the Autoload directly (e.g., `ActionGrid` reading `RunningActionOverlay`'s cached progress instead of calling `ActionSystem.get_progress()` itself), reintroducing cross-zone coupling this ADR explicitly avoids.
  - **Mitigation**: `docs/registry/architecture.yaml`'s existing forbidden-pattern entry ("Subscribing to a signal without a declared dependency in architecture.md's Module Ownership table") already covers this in spirit; `/code-review` should flag any new cross-zone script reference as a violation of this ADR specifically.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| action-ui.md | 3-zone layout (Resource HUD, Action Grid, Running Action Overlay) | One Control script per zone, matching the GDD's own zone boundaries exactly |
| action-ui.md | Progress bar updates every frame while running, not throttled | `RunningActionOverlay._process()`, enabled only while an action is active via `set_process(bool)` |
| action-ui.md | All 5 resources display simultaneously, react to changes | `ResourceHud` connects to `ResourceManager.resource_changed`, no polling |
| action-system.md (TR-aui-001) | `get_progress()` polled every frame by Action UI (already locked by ADR-0004) | `RunningActionOverlay` is the sole caller, confirming and scoping that contract to exactly one zone |

## Performance Implications
- **CPU**: `_process()` work is isolated to `RunningActionOverlay` and only while an action is active — zero per-frame UI cost while idle. `ResourceHud`'s signal-driven updates are O(1) per resource change, not per frame.
- **Memory**: Negligible — 3 small Control scripts, no new data structures.
- **Load Time**: Negligible — standard scene instantiation.
- **Network**: N/A.

## Migration Plan
N/A — first implementation, no prior Action UI code exists to migrate.

## Validation Criteria
- Confirm `RunningActionOverlay._process()` does not run (verify via a breakpoint or counter) while `ActionSystem.current_action_id == &""`, **including in the first frames immediately after scene load** (not just after the first `action_completed` signal) — `_ready()` must set the correct initial `set_process()` state explicitly, since Control nodes process by default
- Confirm tapping a locked slot button produces no Autoload call (no `start_action()` invocation) — `disabled = true` is sufficient, no additional guard needed in the handler
- Confirm `ResourceHud` does not call `ResourceManager.get_resource()` for all 5 keys on every `resource_changed` emission — only the changed key's label updates
- Confirm each of `ActionGrid`'s 6 slot buttons' `custom_minimum_size` meets a minimum touch-target size (commonly ~48x48dp-equivalent) per `technical-preferences.md`'s "large, touch-friendly" requirement — `Button` (not `TouchScreenButton`) is the correct node per engine specialist review (plain `Button` already receives synthesized touch events project-wide; `TouchScreenButton` is a legacy `Node2D`-based control that doesn't integrate with `Control` layout/theming), but target *size* is a real risk that must be verified, not assumed

## Related Decisions
- ADR-0001 (Autoload singleton architecture) — this ADR applies its direct-call/signal split at the Presentation layer for the first time
- ADR-0004 (Action System timer/concurrency) — `get_progress()`'s polling contract, scoped here to exactly one consuming zone
- `design/gdd/action-ui.md` — source GDD, including the 3-zone layout this ADR's scene structure mirrors exactly
