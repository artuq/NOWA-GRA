# ADR-0010: Class Path System Architecture — Autoload, Signal Contract, and Multiplier Application

## Status
Accepted (2026-07-01, following independent /architecture-review in a separate session — verdict PASS, no conflicts, clear to move Proposed→Accepted)

## Date
2026-07-01

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | Core |
| **Knowledge Risk** | LOW — pure GDScript, `Dictionary`, `float`, signals; no post-4.3 engine API used |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None — all patterns used here (Autoload, signal, Dictionary) are pre-4.3 stable |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload pattern, all Core modules); ADR-0003 (restore_state boot protocol); ADR-0005 (HistoryFlagManager.increment_counter — confirmed API); ADR-0008 (DecisionCardSystem signal architecture — this ADR adds a second signal) |
| **Enables** | Story 8-2 (Class Path Core implementation); Story 8-3 (Class Path HUD) |
| **Blocks** | Stories 8-2 and 8-3 cannot begin until this ADR is Accepted |
| **Ordering Note** | ClassPathSystem must appear BELOW DecisionCardSystem in the Autoload boot list (Project Settings → Autoload), since it connects to `DecisionCardSystem.card_resolved` in `_ready()`. BurnoutSystem (Alpha) will similarly be registered BELOW ClassPathSystem when implemented. |

## Context

### Problem Statement
`class-path-system-2026-07-01.md` (quick-spec, approved 2026-07-01) defines ClassPathSystem as a new Core module owning four-path influencer affiliation state. Three integration questions must be resolved before implementation can begin: (1) how ClassPathSystem learns when a card with a path tag is resolved, (2) how ActionSystem applies path-tier multipliers without the coupling direction being inverted, and (3) how era reset is coordinated before BurnoutSystem (Alpha) exists.

### Constraints
- GDScript-only, Godot 4.6.3, no threading (ADR-0001)
- DecisionCardSystem is Complete and test-covered — any addition must be additive (precedent from ADR-0008: `card_presented` was added without breaking the Complete backend)
- ClassPathSystem must NOT depend on ActionSystem — multiplier coupling must be pull-only from ActionSystem's side
- ADR-0003: all modules with persisted state must implement `restore_state(data: Dictionary)`
- ADR-0001 boot order rule: a subscriber module must be registered BELOW its signal emitter in the Autoload list

### Requirements
- Affiliation counter increments driven by card resolution with minimal coupling change to DecisionCardSystem
- Tier unlock signal emitted exactly once when threshold is crossed (not on every affiliation read)
- ActionSystem applies multiplier without knowing ClassPathSystem's internal tier state
- Era reset safe to call without BurnoutSystem existing (MVP tolerance)
- Save/load round-trip for affiliation floats and tier ints

## Decision

### 1. ClassPathSystem as Core Autoload

`ClassPathSystem` is registered as a Godot Autoload singleton, consistent with ADR-0001. It owns:
- `_affiliation: Dictionary` — per-path affiliation [0.0, 100.0], keyed by path `StringName`
- `_current_tier: Dictionary` — per-path tier [0–5], keyed by path `StringName`
- `_active_path: StringName` — empty string = no active path

Boot order addition (below existing 8 Autoloads, in Project Settings → Autoload):
```
9. ClassPathSystem   ← connects to DecisionCardSystem.card_resolved in _ready()
```

### 2. DecisionCardSystem gains `card_resolved` signal (additive)

Same precedent as ADR-0008's `card_presented` addition and ADR-0007's `action_started` addition. One additive emission at the end of `resolve_choice()`, after `HistoryFlagManager.increment_counter()` has run:

```gdscript
signal card_resolved(card_id: StringName, path_tag: StringName, option_chosen: StringName)
```

`path_tag` is read from the resolved card's Dictionary field (see Decision §3). Empty string (`""`) for neutral cards. DecisionCardSystem emits this signal regardless of whether `path_tag` is empty — ClassPathSystem ignores empty-tag events internally. Card UI is unaffected — it already hides after `resolve_choice()` returns; the new signal fires after the existing logic.

### 3. `path_tag` field in CardContentDatabase card schema

Each card in the card data JSON gains a `"path_tag"` field:
```json
{ "id": "nagraj_kolaba", "path_tag": "pato_streamer", ... }
{ "id": "cancel_threat", "path_tag": "",              ... }
```
This is additive — existing card code reading other fields is unaffected. All 12 existing card entries require a `"path_tag"` field added (neutral cards use `""`). No save migration needed — `path_tag` is read from CardContentDatabase at runtime, not from save files.

### 4. ClassPathSystem card_resolved handler and tier progression

ClassPathSystem connects in `_ready()`:
```gdscript
func _ready() -> void:
    DecisionCardSystem.card_resolved.connect(_on_card_resolved)
```

Handler:
```gdscript
func _on_card_resolved(card_id: StringName, path_tag: StringName, _option: StringName) -> void:
    if path_tag == &"":
        return
    # Counter already incremented by DecisionCardSystem before this signal fired.
    _recalculate_affiliation(path_tag)
    _check_tier_progression(path_tag)
    _update_active_path()
```

`_recalculate_affiliation()` reads `HistoryFlagManager.get_counter(path_tag + "_choices_count")` and applies the cap formula from the quick-spec. `_check_tier_progression()` emits `tier_unlocked` only when `_current_tier[path_tag]` advances — guaranteeing the signal fires exactly once per tier crossing, not on every read.

### 5. Multiplier application — pull model

ActionSystem calls `ClassPathSystem.get_active_multiplier(action_id: StringName) -> float` at reward resolution, immediately after the Morale band multiplier (`Mult(M)`, existing), before calling `ResourceManager.apply_delta()`. ClassPathSystem returns the tier bonus for the active path if the action is affected; otherwise returns `1.0`.

```gdscript
# In ClassPathSystem
func get_active_multiplier(action_id: StringName) -> float:
    if _active_path.is_empty():
        return 1.0
    return _path_multiplier_table.get(_active_path, {}).get(action_id, 1.0)
```

`_path_multiplier_table` is a `Dictionary` populated from `assets/data/balance.json` under the `class_path` key at `_ready()`. No dependency ClassPathSystem → ActionSystem is introduced.

### 5a. Sponsor multiplier application — pull model, card-resolution scoped *(added 2026-07-13, `/propagate-design-change` on `prestige-checkpoint-system.md`'s `/design-review`)*

`guru_celebryta`/`biznesmen_contentu`'s Sponsor tier bonuses (per the quick-spec's Tier Bonuses table) have no resolution hook, since Sponsors are granted at Decision Card resolution (`sponsorzy_per_qualifying_card` roll), not via §5's `action_id`-keyed reward path. Same pull-model precedent as §5, additive:

```gdscript
func get_active_sponsor_multiplier() -> float:
    if _active_path.is_empty():
        return 1.0
    return _sponsor_multiplier_table.get(_active_path, 1.0)
```

`_sponsor_multiplier_table` is a `Dictionary` populated from `assets/data/balance.json` under the same `class_path` key as `_path_multiplier_table` (§5), keyed by path only (no `action_id` — Sponsor grants aren't per-action). Called by `DecisionCardSystem` at the point it resolves a qualifying card's Sponsor roll, immediately before writing the delta via `ResourceManager.apply_delta()` — mirrors §5's "immediately after Morale multiplier, before `apply_delta()`" ordering, adapted to the card-resolution call site instead of action-completion. No new dependency direction: `DecisionCardSystem` already depends on `ClassPathSystem` indirectly via the `card_resolved` signal chain (§2/§4); this adds one pull-query call, same shape as ActionSystem's existing one.

### 6. Era reset — deferred wiring

`ClassPathSystem.reset_era_state() -> void` is the public API. For MVP (no BurnoutSystem): called manually via debug console or test helper. For Alpha: BurnoutSystem registers ClassPathSystem as a listener to its `era_transitioned` signal in BurnoutSystem's `_ready()` — not here. This ADR defines the API contract only.

Meta flags (`class_path.{path_id}.best_tier.{N}`, `class_path.{path_id}.era_completed`) are written to HistoryFlagManager milestones during `reset_era_state()` before clearing affiliation. They survive era resets because HistoryFlagManager milestones are monotonic.

### 7. Save / Load

`ClassPathSystem.restore_state(data: Dictionary) -> void` — called by BootController in ADR-0003's init sequence, below DecisionCardSystem's restore_state. Persists and restores: `affiliation` Dictionary, `current_tier` Dictionary. Meta flags are the canonical long-term record; ClassPathSystem's transient copy is reconstructed from the save on restore.

### Architecture Diagram

```
DecisionCardSystem.card_resolved ─────────→ ClassPathSystem._on_card_resolved()
  (card_id, path_tag, option)   (subscribes)      │
                                                   ├─ reads HistoryFlagManager.get_counter()
                                                   ├─ emits tier_unlocked(path_id, tier)
                                                   └─ emits active_path_changed(path_id)

ActionSystem._resolve_reward()  ─────────→ ClassPathSystem.get_active_multiplier(action_id)
  (pull: asks for float)                           (returns 1.0 if no active path)

BootController._ready()         ─────────→ ClassPathSystem.restore_state(data)
BurnoutSystem (Alpha only)      ─────────→ ClassPathSystem.reset_era_state()  [deferred]

ClassPathUI / HUD               ──(reads)→ ClassPathSystem signals + query methods
```

### Key Interfaces

```gdscript
# Signals (ClassPathSystem emits)
signal tier_unlocked(path_id: StringName, tier: int)
signal active_path_changed(path_id: StringName)  # "" = no active path

# Signal added to DecisionCardSystem (§2 above)
# signal card_resolved(card_id: StringName, path_tag: StringName, option_chosen: StringName)

# Queries (pure reads — UI and ActionSystem call these freely)
func get_affiliation(path_id: StringName) -> float
func get_tier(path_id: StringName) -> int
func get_active_path() -> StringName
func get_active_multiplier(action_id: StringName) -> float  # 1.0 when no active path
func get_active_sponsor_multiplier() -> float  # 1.0 when no active path (added 2026-07-13, §5a)

# Commands
func invest(path_id: StringName, resource_id: StringName, amount: float) -> bool
func restore_state(data: Dictionary) -> void
func reset_era_state() -> void  # MVP: debug-only; Alpha: wired to BurnoutSystem.era_transitioned
```

## Alternatives Considered

### Alternative A: Lazy evaluation — no `card_resolved` signal
ClassPathSystem computes affiliation on every `get_affiliation()` call by reading HistoryFlagManager counters directly. Tier unlock emitted as side effect of the getter.
- **Pros**: No change to DecisionCardSystem.
- **Cons**: Signals emitted from getters create implicit side effects invisible at call sites — a caller reading `get_affiliation()` for UI display would unexpectedly emit `tier_unlocked`. Breaks Godot's unidirectional signal flow. Tier unlock timing becomes non-deterministic (fires whenever UI first reads after threshold, not at resolution moment).
- **Rejection Reason**: Side-effecting getters violate Godot signal conventions and make tier_unlocked untestable in isolation.

### Alternative B: Push multipliers via ActionSystem.action_completed
ClassPathSystem subscribes to `ActionSystem.action_completed` and modifies the reward payload before ResourceManager sees it.
- **Pros**: ClassPathSystem intercepts rewards centrally.
- **Cons**: Creates ClassPathSystem → ActionSystem coupling (circular risk). Intercepting ActionSystem's reward chain violates ActionSystem's single-owner principle (ADR-0001). If multipliers ever depend on action state still being "live," ordering becomes fragile.
- **Rejection Reason**: Pull model keeps ActionSystem fully ignorant of ClassPathSystem's existence; easier to disable/mock in tests.

### Alternative C: ClassPathSystem wraps ResourceManager.apply_delta()
All action rewards flow through a ClassPathSystem-aware `apply_delta_with_path_bonus()`.
- **Pros**: Single point for all resource mutations with bonus application.
- **Cons**: ClassPathSystem becomes a mandatory critical-path dependency. A ClassPathSystem bug breaks all reward delivery. Violates ResourceManager's sole ownership of resource state.
- **Rejection Reason**: Creates a god-object critical path from a system that should be an optional enhancement layer.

## Consequences

### Positive
- ClassPathSystem is fully isolated: nothing depends on it except the UI and ActionSystem's single multiplier query
- Adding more paths or tier effects requires only data changes in `_path_multiplier_table` — no structural code change
- Tier progression detection is deterministic: fires exactly when the card resolves, not deferred to next UI read
- Consistent with all 9 existing ADRs' patterns — no new architectural pattern introduced

### Negative
- DecisionCardSystem gains a second signal — minor complexity increase to a Complete system (mitigated: same additive pattern as ADR-0008's `card_presented`)
- `path_tag` field in card data requires all 12 existing card entries to be updated (all neutral cards get `""`)
- `get_active_multiplier()` called on every action completion — O(1) Dictionary lookup, negligible, but a new per-action call site

### Risks
- **BurnoutSystem wiring deferred**: BurnoutSystem must explicitly connect to `ClassPathSystem.reset_era_state` when implemented. Mitigation: BurnoutSystem's epic file will document this dependency when created.
- **`card_resolved` signal order**: signal fires after HistoryFlagManager.increment_counter but within the same frame as `resolve_choice()`. If any future subscriber expects counter-not-yet-incremented state, ordering will matter. Mitigation: document that ClassPathSystem and all future `card_resolved` subscribers must assume the counter IS already incremented.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `class-path-system-2026-07-01.md` | ClassPathSystem owns affiliation floats, tier state, active path resolution, investment logic, signals | ClassPathSystem Autoload with full API surface specified |
| `class-path-system-2026-07-01.md` | Card resolution automatically increments path-tagged pattern counters via HistoryFlagManager | DecisionCardSystem increments counter in `resolve_choice()`; `card_resolved` signal triggers ClassPathSystem re-evaluation |
| `class-path-system-2026-07-01.md` | ActionSystem queries `get_active_multiplier(action_id)` on action completion | Pull model: ActionSystem calls ClassPathSystem.get_active_multiplier(); ClassPathSystem never touches ActionSystem |
| `class-path-system-2026-07-01.md` | BurnoutSystem emits `era_transitioned` → ClassPathSystem.reset_era_state() | API defined; BurnoutSystem wiring deferred to BurnoutSystem's ADR (Alpha) |
| `class-path-system-2026-07-01.md` | SaveSystem: ClassPathSystem state added to serialize/restore cycle | restore_state(data: Dictionary) per ADR-0003 pattern |

## Performance Implications
- **CPU**: O(1) per action completion (Dictionary lookup for multiplier). O(4 paths) per card resolution (tier check). Negligible on any mobile hardware.
- **Memory**: 4 floats + 4 ints + 1 StringName + multiplier table (small, static). Negligible.
- **Load Time**: restore_state() does 4 Dictionary reads. Negligible.
- **Network**: N/A

## Migration Plan
1. Add `"path_tag": ""` to all 12 existing card entries in card data JSON (additive, no save migration)
2. Add `card_resolved` signal emission at end of `DecisionCardSystem.resolve_choice()` (additive)
3. Register ClassPathSystem as Autoload #9 in Project Settings → Autoload
4. Implement `src/core/class_path_system.gd` per the Key Interfaces above
5. Modify ActionSystem reward resolution to call `ClassPathSystem.get_active_multiplier()` and multiply result

## Validation Criteria
- Unit test: `get_affiliation("pato_streamer")` returns correct value after HistoryFlagManager counter increment
- Unit test: `tier_unlocked` signal fires exactly once when affiliation crosses 20.0
- Unit test: `get_active_multiplier("zrob_drame")` returns 1.30 when pato_streamer at Tier 1, 1.0 otherwise
- Integration test: card resolution → counter increment → `card_resolved` signal → affiliation change → tier unlock chain
- Integration test: `restore_state()` after `reset_era_state()` produces correct zero state

## Related Decisions
- ADR-0001: Autoload singleton architecture (pattern basis for this decision)
- ADR-0003: Boot order and `restore_state()` protocol
- ADR-0005: HistoryFlagManager counter API consumed here
- ADR-0008: DecisionCardSystem signal architecture (precedent for additive `card_resolved` signal)
- `design/quick-specs/class-path-system-2026-07-01.md`: full path definitions, formulas, tuning knobs
