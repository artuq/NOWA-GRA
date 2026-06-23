# Control Manifest

> **Engine**: Godot 4.6.3
> **Last Updated**: 2026-06-20
> **Manifest Version**: 2026-06-20
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
technical preferences, and engine reference docs. For the reasoning behind each
rule, see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: scene management, event architecture, save/load, engine initialisation*

### Required Patterns

- **Implement every Core/Foundation module as a Godot Autoload singleton** — source: ADR-0001
- **Use direct method calls when the caller is the sole trigger of a state mutation it owns** (e.g., `ActionSystem` calling `ResourceManager.apply_delta()`) — source: ADR-0001
- **Use Godot signals when multiple unrelated modules subscribe to the same event** (e.g., `ActionSystem.action_completed` heard by both `OnboardingGate` and `DecisionCardSystem`) — source: ADR-0001
- **Declare all signals with static types** (e.g., `signal action_completed(action_id: String, payload: Dictionary)`) — source: ADR-0001
- **Register Autoloads in this exact order** (top-to-bottom = ready-order): `ResourceManager`, `HistoryFlagManager`, `CardContentDatabase`, `SaveSystem`, `ActionSystem`, `OfflineProgressSystem`, `OnboardingGate`, `DecisionCardSystem` — a subscriber connecting in `_ready()` must be registered below its emitter or the connection silently never fires — source: ADR-0001
- **Save format is JSON**, written via `JSON.stringify()` to `user://save.tmp`, then atomically renamed to `user://save.json` via `DirAccess.rename_absolute()` — check the returned `Error`, retain the `.tmp` file and log on failure rather than silently losing it — source: ADR-0002
- **Every save payload includes a `schema_version` field**, increment-only; on load, a version mismatch or JSON parse failure falls back to first-session defaults — never crash — source: ADR-0002
- **Use a dedicated Boot scene** (`res://scenes/boot/boot.tscn`) as the Project Main Scene; `BootController` runs: `SaveSystem.load_save()` → `restore_state(data)` on each module in the ADR-0001 Autoload order → `OfflineProgressSystem.simulate_offline()` → conditional transition to Offline Report Screen or Main scene — source: ADR-0003
- **Every module owning persisted state implements `restore_state(data: Dictionary) -> void`**, called by `BootController`; missing keys must default safely (first-session case, `data == {}`) — source: ADR-0003
- **Use `Time.get_unix_time_from_system()`**, never `OS.get_unix_time()` (removed in Godot 4) — source: ADR-0003 (engine compatibility note)

### Forbidden Approaches

- **Never introduce a central `EventBus` autoload** (string-keyed event dispatch) — loses GDScript's static-typing safety and solves a decoupling problem this project's scale doesn't have — source: ADR-0001
- **Never connect to a signal without a declared dependency in `architecture.md`'s Module Ownership table** — update that table first if a new dependency is needed — source: ADR-0001
- **Never use `ConfigFile` or binary `ResourceSaver`/`.tres` for save data** — `ConfigFile`'s flat key-value model doesn't fit this project's nested state; binary format isn't debuggable and complicates schema migration — source: ADR-0002
- **Never embed one-time boot/launch sequencing logic inside the main gameplay scene's `_ready()`** — couples launch-only logic to an ongoing-gameplay scene that doesn't conceptually own it — source: ADR-0003

### Performance Guardrails

- None with a specific numeric budget — both Autoload pattern and save I/O are confirmed negligible-cost (sub-frame) at this project's scale — source: ADR-0001, ADR-0002

---

## Core Layer Rules

*Applies to: core gameplay loop, main player systems (Action System, Decision Card System, Offline Progress System)*

### Required Patterns

- **Action timing uses a single `Timer` node** (child of the `ActionSystem` Autoload, `one_shot = true`), guarded by a `current_action_id: StringName` field for single-concurrency (`start_action()` returns `false` if one is already running) — source: ADR-0004
- **`get_progress()` must guard divide-by-zero**: return `0.0` if `current_action_id == &""` or `wait_time <= 0.0` — source: ADR-0004
- **Decision Card cooldown is a plain `int` counter**, decremented on `ActionSystem.action_completed` — counts completed actions, not elapsed time — source: ADR-0005
- **Each Autoload owning gameplay RNG instantiates its own `RandomNumberGenerator` member** (never the global `randf()`/`randi()` functions) — source: ADR-0005
- **Expose a `set_seed(s: int) -> void` test-only hook on any module with gameplay RNG**, satisfying the project's "no random seeds" test-determinism rule — source: ADR-0005, `coding-standards.md`
- **`force_cooldown_zero()` on `DecisionCardSystem` is called only by `OnboardingGate`**, at the Phase 1→2 transition — direct, ownership-clear call, not a signal — source: ADR-0005
- **Offline/online resource formulas (`haters_growth_rate`, `morale_drain_rate`, `action_effectiveness_multiplier`, `passive_zasiegi_income`) live in one stateless static utility class** (`ResourceFormulas`, `res://src/core/resource_formulas.gd`), called by both `ActionSystem` (live play) and `OfflineProgressSystem` (offline simulation) — guarantees the two contexts can never silently diverge — source: ADR-0006
- **`simulate_offline()` is a single synchronous `while` loop**, max 1440 iterations (60s steps, 24h cap, per `offline-progress-system.md`) — no threading, no `async`/`await` — source: ADR-0006

### Forbidden Approaches

- **Never use per-action `Timer` nodes or manual countdown in `_process()`** for Action System timing — the single shared `Timer` + state guard is sufficient and simpler — source: ADR-0004
- **Never implement Decision Card cooldown as a `Timer`** — the GDD's unit is completed actions, not elapsed time; a Timer would require lossy time-translation — source: ADR-0005
- **Never add instance vars or `@export` fields to `ResourceFormulas`** — it must stay stateless; both call sites (live play, offline simulation) call its static functions independently, and any shared state would silently leak across unrelated contexts — source: ADR-0006
- **Never use `async`/`await`/coroutines for the offline simulation loop** — confirmed cheap even at the 1440-iteration worst case; adding async machinery would be premature optimization contradicting `architecture.md` Principle 1 (no threading anywhere) — source: ADR-0006

### Performance Guardrails

- **`simulate_offline()`**: confirmed sub-millisecond even at the 1440-iteration (24h) worst case — no async/threading required — source: ADR-0006

---

## Feature Layer Rules

*No Accepted ADRs cover Feature-layer systems yet (Class Path System, Team/Staff Management, Prestige/Checkpoint System are Vertical Slice/Alpha tier, undesigned as of this manifest version).*

---

## Presentation Layer Rules

*No Accepted ADRs cover Presentation-layer systems yet. Per `architecture.md`'s own backlog, Card UI and Offline Report Screen ADRs are deliberately deferred to implementation — straightforward Control-node patterns, low architectural risk, fully specified at the GDD level. Implement directly against `card-ui.md` / `offline-report-screen.md` / `juice-feedback-system.md` without a governing ADR.*

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `PlayerController` |
| Variables | snake_case | `move_speed` |
| Signals/Events | snake_case, past tense | `health_changed` |
| Files | snake_case matching class | `player_controller.gd` |
| Scenes/Prefabs | PascalCase matching root node | `PlayerController.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH` |

### Performance Budgets

| Target | Value |
|--------|-------|
| Framerate | 60fps |
| Frame budget | 16.6ms |
| Draw calls | ≤100 per frame (mobile budget — revisit after first profiling pass) |
| Memory ceiling | Not yet configured — set after first profiling pass on target Android hardware |

### Approved Libraries / Addons

- None approved yet — `technical-preferences.md` has no entries as of this manifest version.

### Forbidden APIs (Godot 4.6.3)

- `OS.get_unix_time()` — removed in Godot 4 (moved to the `Time` singleton); use `Time.get_unix_time_from_system()` — source: `docs/engine-reference/godot/breaking-changes.md`, ADR-0003
- `SkeletonIK3D` — deprecated since 4.4; not applicable to this 2D project, listed for completeness — source: `docs/engine-reference/godot/deprecated-apis.md`
- `object_cast_to` / `classdb_get_class_tag` (GDExtension) — deprecated since 4.6; not applicable unless/until native GDExtension code is added — source: `docs/engine-reference/godot/deprecated-apis.md`

### Cross-Cutting Constraints

- **No threading anywhere** — every system in this project's MVP scope (including the worst-case offline simulation) is cheap enough to run synchronously on the main thread; do not introduce threads pre-emptively — source: `architecture.md` Principle 1
- **Data-driven content, hardcoded mechanics** — card content lives in `Resource`/JSON files; the formulas/thresholds operating on that content live in code — source: `architecture.md` Principle 3, `coding-standards.md`
- **Feedback intensity scales with magnitude only, never with moral valence** — no red/green or "good/bad" color coding anywhere in UI or audio feedback; same effect family for a win and a loss of equal magnitude — source: `juice-feedback-system.md` (locked anti-pillar across Action UI, Card UI, Offline Report Screen, Juice/Feedback System)
