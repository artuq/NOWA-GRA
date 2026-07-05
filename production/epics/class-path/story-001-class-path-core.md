# Story 001: Class Path Core

> **Epic**: Class Path System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (3–4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-07-05

## Context

**GDD**: `design/quick-specs/class-path-system-2026-07-01.md`
**Requirements**: `TR-cps-001`, `TR-cps-002`, `TR-cps-003`, `TR-cps-004`, `TR-cps-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Class Path System Architecture — Autoload, Signal Contract, and Multiplier Application
**ADR Decision Summary**: ClassPathSystem is a Core Autoload (#9 in boot order) owning affiliation floats and tier state. DecisionCardSystem gains an additive `card_resolved` signal (same precedent as `card_presented`). ActionSystem applies tier multipliers via a pull-model `get_active_multiplier(action_id)` call. `restore_state(data)` per ADR-0003. `reset_era_state()` API defined; BurnoutSystem wiring deferred to Alpha.

**Secondary ADRs**: ADR-0001 (Autoload pattern), ADR-0003 (`restore_state` boot protocol)

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: All APIs (Autoload, signal, Dictionary) are pre-4.3 stable. No post-cutoff APIs used.

**Control Manifest Rules (Core layer)**:
- Required: Autoload singleton; signals for multi-subscriber events; direct calls for ownership-clear writes; `restore_state(data: Dictionary) -> void` implemented; per-instance `RandomNumberGenerator` if RNG is used; no threading
- Forbidden: central EventBus; connecting to signals without declared dependency in `architecture.md` Module Ownership table
- Guardrail: no numeric performance budget for Autoloads — confirmed negligible at this project's scale

**Note — Manifest Version**: control-manifest.md covers ADRs 0001–0006 (v2026-06-20). ADR-0010 post-dates the manifest. The manifest's Core and Foundation rules above fully apply; ADR-0010-specific implementation rules are embedded in `## Implementation Notes` below.

---

## Acceptance Criteria

*From `design/quick-specs/class-path-system-2026-07-01.md`, MVP scope (2 paths, Tier 1–2, card contribution only):*

### Prerequisite changes (part of this story's migration plan)
- [ ] `"path_tag": ""` field added to all 12 card entries in card data JSON (neutral cards = `""`, pato_streamer/guru_celebryta cards = their path id)
- [ ] `card_resolved(card_id: StringName, path_tag: StringName, option_chosen: StringName)` signal added to `DecisionCardSystem.resolve_choice()` — emitted after `HistoryFlagManager.increment_counter()` (additive, no existing logic changed)

### ClassPathSystem affiliation
- [ ] **GIVEN** a card resolves with `path_tag = "pato_streamer"`, **WHEN** `DecisionCardSystem.resolve_choice()` completes, **THEN** `HistoryFlagManager.get_counter("pato_streamer_choices_count")` increments by 1
- [ ] **GIVEN** `pato_streamer_choices_count = 5`, **WHEN** `ClassPathSystem.get_affiliation("pato_streamer")` is called (default `CARD_AFFILIATION_PER_CHOICE = 4.0`), **THEN** returns `20.0`
- [ ] **GIVEN** card contribution exceeds `CARD_CONTRIBUTION_MAX (60.0)`, **THEN** `get_affiliation()` returns `60.0` (capped)

### Tier progression
- [ ] **GIVEN** pato_streamer affiliation crosses `20.0`, **THEN** `ClassPathSystem.get_tier("pato_streamer")` == 1 and `tier_unlocked("pato_streamer", 1)` signal emitted exactly once
- [ ] **GIVEN** affiliation crosses `40.0`, **THEN** `get_tier()` == 2 and `tier_unlocked` emitted with `tier=2`
- [ ] Tier is monotonically non-decreasing — `get_tier()` never returns a value lower than a previously observed value

### Active path
- [ ] **GIVEN** only `pato_streamer` is at Tier 1+, **WHEN** `ClassPathSystem.get_active_path()` called, **THEN** returns `"pato_streamer"`
- [ ] **GIVEN** all paths at Tier 0, **WHEN** `get_active_path()` called, **THEN** returns `""` (no active path)

### Multipliers (MVP: T1 only for 2 paths)
- [ ] **GIVEN** pato_streamer active at Tier 1, **WHEN** `get_active_multiplier(&"zrob_drame")` called, **THEN** returns `1.3`
- [ ] **GIVEN** guru_celebryta active at Tier 1, **WHEN** ActionSystem triggers sponsor income multiplier lookup, **THEN** `get_active_multiplier` returns the correct T1 multiplier (`1.2` for sponsor income context)
- [ ] **GIVEN** no active path (all Tier 0), **WHEN** `get_active_multiplier(any_id)` called, **THEN** returns `1.0`

### Offline exclusion
- [ ] **GIVEN** `PATH_MULTIPLIER_OFFLINE = false` (default), **WHEN** offline simulation runs, **THEN** result identical to no-active-path baseline (`get_active_multiplier` NOT called by OfflineProgressSystem)

### Era reset
- [ ] **GIVEN** pato_streamer at Tier 2 (affiliation 45.0), **WHEN** `ClassPathSystem.reset_era_state()` called, **THEN** `get_affiliation("pato_streamer")` == `0.0`, `get_tier("pato_streamer")` == 0, `HistoryFlagManager.get_counter("pato_streamer_choices_count")` == 0
- [ ] **GIVEN** player reached Tier 2 before reset, **WHEN** era reset runs, **THEN** `HistoryFlagManager.has_milestone("class_path.pato_streamer.best_tier.2")` == `true` (meta flag preserved)

### Save / Load
- [ ] **GIVEN** affiliation state, **WHEN** `restore_state(data)` called with previously saved data, **THEN** `get_affiliation()` and `get_tier()` return saved values; missing keys default to `0.0` / `0` (first-session safety)

---

## Implementation Notes

*From ADR-0010 (primary), ADR-0001, ADR-0003:*

### Step 0: Prerequisite changes to existing systems

**Card data JSON** — add `"path_tag"` field to every card entry:
```json
{ "id": "nagraj_kolaba", "path_tag": "pato_streamer", ... }
{ "id": "udziel_wywiadu", "path_tag": "guru_celebryta", ... }
{ "id": "some_neutral_card", "path_tag": "", ... }
```
Neutral cards use `""`. This is additive — no existing code breaks.

**`src/core/decision_card_system.gd`** — add signal and emission (additive only, do NOT change existing logic):
```gdscript
signal card_resolved(card_id: StringName, path_tag: StringName, option_chosen: StringName)

# Inside resolve_choice(), AFTER the existing HistoryFlagManager.increment_counter call:
card_resolved.emit(resolved_card_id, resolved_card.get("path_tag", &""), chosen_option)
```
Confirm exact variable names by reading `decision_card_system.gd` before editing.

### Step 1: Create `src/core/class_path_system.gd`

Register as Autoload #9 in Project Settings → Autoload (below DecisionCardSystem).

```gdscript
extends Node

signal tier_unlocked(path_id: StringName, tier: int)
signal active_path_changed(path_id: StringName)

const TIER_THRESHOLDS: Array[float] = [0.0, 20.0, 40.0, 60.0, 80.0, 100.0]

var _affiliation: Dictionary = {}   # StringName -> float
var _current_tier: Dictionary = {}  # StringName -> int
var _active_path: StringName = &""

func _ready() -> void:
    DecisionCardSystem.card_resolved.connect(_on_card_resolved)

func _on_card_resolved(card_id: StringName, path_tag: StringName, _option: StringName) -> void:
    if path_tag == &"":
        return
    _recalculate_affiliation(path_tag)
    _check_tier_progression(path_tag)
    _update_active_path()
```

### Step 2: Affiliation formula (MVP — card contribution only)

```gdscript
func _recalculate_affiliation(path_id: StringName) -> void:
    var count: int = HistoryFlagManager.get_counter(path_id + "_choices_count")
    var per_choice: float = BalanceData.get_value("CARD_AFFILIATION_PER_CHOICE")  # default 4.0
    var cap: float = BalanceData.get_value("CARD_CONTRIBUTION_MAX")  # default 60.0
    _affiliation[path_id] = minf(count * per_choice, cap)
```

### Step 3: Tier progression

```gdscript
func _check_tier_progression(path_id: StringName) -> void:
    var affil: float = _affiliation.get(path_id, 0.0)
    var old_tier: int = _current_tier.get(path_id, 0)
    var new_tier: int = old_tier
    for t in range(old_tier + 1, TIER_THRESHOLDS.size()):
        if affil >= TIER_THRESHOLDS[t]:
            new_tier = t
        else:
            break
    if new_tier > old_tier:
        _current_tier[path_id] = new_tier
        tier_unlocked.emit(path_id, new_tier)
```

### Step 4: Active path resolution

```gdscript
func _update_active_path() -> void:
    var best_path: StringName = &""
    var best_affil: float = 0.0
    for path_id: StringName in _affiliation:
        if _current_tier.get(path_id, 0) >= 1:
            var a: float = _affiliation[path_id]
            if a > best_affil:
                best_affil = a
                best_path = path_id
    if best_path != _active_path:
        _active_path = best_path
        active_path_changed.emit(_active_path)
```

### Step 5: Multiplier table + get_active_multiplier

Read tier multipliers from `balance.json` under `class_path.{path_id}.tier_{n}.{action_id}` or equivalent flat structure. For MVP, hard-code the table from balance.json at `_ready()`:
```gdscript
func get_active_multiplier(action_id: StringName) -> float:
    if _active_path.is_empty():
        return 1.0
    var tier: int = _current_tier.get(_active_path, 0)
    # _path_multiplier_table populated from balance.json in _ready()
    return _path_multiplier_table.get(_active_path, {}).get(tier, {}).get(action_id, 1.0)
```

### Step 6: ActionSystem wiring

In `ActionSystem._resolve_action()` (or equivalent reward resolution method), after applying `Mult(M)` and before calling `ResourceManager.apply_delta()`:
```gdscript
var path_bonus: float = ClassPathSystem.get_active_multiplier(action_id)
reward_reach = roundi(reward_reach * path_bonus)
```
Read `action_system.gd` to find the exact reward resolution call site before editing.

### Step 7: restore_state / reset_era_state

```gdscript
func restore_state(data: Dictionary) -> void:
    _affiliation = data.get("affiliation", {})
    _current_tier = data.get("current_tier", {})
    _active_path = data.get("active_path", &"")

func reset_era_state() -> void:
    for path_id: StringName in _affiliation:
        # Write meta flags before clearing
        var tier: int = _current_tier.get(path_id, 0)
        for t in range(1, tier + 1):
            HistoryFlagManager.set_milestone("class_path." + path_id + ".best_tier." + str(t))
        if _active_path == path_id:
            HistoryFlagManager.set_milestone("class_path." + path_id + ".era_completed")
        HistoryFlagManager.reset_counter(path_id + "_choices_count")  # era-local counter
    _affiliation.clear()
    _current_tier.clear()
    _active_path = &""
    active_path_changed.emit(&"")
```

---

## Out of Scope

*Do NOT implement in this story:*

- Story 002 (Class Path HUD): HUD indicator widget and visual display
- Active investment mechanic (Invest button, resource spend → affiliation) — Vertical Slice scope
- Tier 3–5 and signature cards — Alpha scope
- Class Path Panel (full path screen) — Alpha scope
- BurnoutSystem wiring for `era_transitioned` — Alpha scope (ADR-0010 deferred)
- 4-path registration (Ekspert Niszowy, Biznesmen Contentu) — Vertical Slice scope

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-8-2026-07-01.md`, section 8-2.*

- **AC-1**: Card resolution increments path counter
  - Given: `pato_streamer_choices_count = 0`
  - When: card resolves with `path_tag = "pato_streamer"`
  - Then: `HistoryFlagManager.get_counter("pato_streamer_choices_count")` == 1
  - Edge cases: card with `path_tag = ""` → no counter changes; unknown path tag → no counter changes

- **AC-2**: `get_affiliation()` formula returns correct value
  - Given: `pato_streamer_choices_count = 5`, `CARD_AFFILIATION_PER_CHOICE = 4.0`
  - When: `ClassPathSystem.get_affiliation("pato_streamer")`
  - Then: returns `20.0`
  - Edge cases: count = 0 → `0.0`; count = 1 → `4.0`

- **AC-3**: Card contribution cap
  - Given: `pato_streamer_choices_count = 50` (200.0 > cap 60.0)
  - When: `get_affiliation("pato_streamer")`
  - Then: returns `60.0`
  - Edge cases: count = 15 → exactly `60.0` (boundary); count = 14 → `56.0`; count = 16 → `60.0`

- **AC-4**: Tier 1 unlock at 20.0
  - Given: affiliation crosses `20.0`
  - When: ClassPathSystem evaluates tier
  - Then: `get_tier("pato_streamer")` == 1; `tier_unlocked("pato_streamer", 1)` signal emitted
  - Edge cases: affiliation == `20.0` → Tier 1 (inclusive); affiliation == `19.99` → Tier 0

- **AC-5**: Tier 2 unlock at 40.0
  - Given: affiliation crosses `40.0`
  - Then: `get_tier("pato_streamer")` == 2; signal emitted with `tier=2`
  - Edge cases: affiliation == `39.99` → Tier 1 (not 2)

- **AC-6**: Tier monotonicity
  - Given: pato_streamer at Tier 1
  - When: `get_tier("pato_streamer")` queried multiple times
  - Then: always returns ≥ 1; no code path can set tier below current value

- **AC-7**: Active path — single path at Tier 1+
  - Given: pato_streamer at Tier 1; guru_celebryta at Tier 0
  - When: `ClassPathSystem.get_active_path()`
  - Then: returns `"pato_streamer"`

- **AC-8**: No active path before Tier 1
  - Given: all paths at Tier 0
  - When: `get_active_path()`
  - Then: returns `""` or null-equivalent

- **AC-9**: T1 pato_streamer multiplier
  - Given: pato_streamer active at Tier 1
  - When: `get_active_multiplier(&"zrob_drame")`
  - Then: returns `1.3`
  - Edge cases: same at Tier 0 → `1.0`

- **AC-10**: T1 guru_celebryta multiplier
  - Given: guru_celebryta active at Tier 1
  - When: `get_active_multiplier` called for sponsor income context
  - Then: returns `1.2`
  - Edge cases: pato_streamer active instead → guru multiplier NOT applied → `1.0`

- **AC-11**: Offline exclusion
  - Given: pato_streamer active at Tier 2; `PATH_MULTIPLIER_OFFLINE = false`
  - When: offline simulation runs
  - Then: result identical to no-active-path baseline; `get_active_multiplier` not called by OfflineProgressSystem

- **AC-12**: Era reset
  - Given: pato_streamer at Tier 2 (affiliation 45.0); guru at Tier 0 (affiliation 10.0)
  - When: `reset_era_state()` called
  - Then: `get_affiliation("pato_streamer")` == `0.0`; `get_tier("pato_streamer")` == 0; `get_counter("pato_streamer_choices_count")` == 0

- **AC-13**: Meta flags survive era reset
  - Given: player reached Tier 2 on pato_streamer before reset
  - When: era reset runs
  - Then: `HistoryFlagManager.has_milestone("class_path.pato_streamer.best_tier.2")` == `true`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/class-path/class_path_core_test.gd` — must exist and all tests pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (ClassPathSystem is new; DecisionCardSystem changes are additive — no story dependency)
- Unlocks: Story 002 (Class Path HUD Indicator — requires ClassPathSystem signals to exist)

## Completion Notes
**Completed**: 2026-07-05
**Criteria**: 16/16 passing (all auto-verified; AC-11 offline exclusion verified structurally — zero ClassPathSystem references in OfflineProgressSystem)
**Deviations**: 2 advisory — (1) `const` balance values instead of Implementation Notes' `BalanceData.get_value()` (BalanceData doesn't exist; accepted at story-readiness, matches ACTION_REWARDS convention); (2) `ActionSystem._on_card_resolved` widened to 3 ignored params (Godot rejects narrower handlers on multi-param signals)
**Test Evidence**: Logic: tests/unit/class-path/class_path_core_test.gd (30 tests PASSED) + tests/integration/decision_card_system/card_resolution_test.gd (+2 AC-1 producer-side tests PASSED)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (godot-gdscript-specialist + qa-tester); all 4 suggestions applied and re-tested (typed _MULTIPLIER_TABLE, emit-on-change guard in reset_era_state, T2 multiplier tests, AC-1 integration tests)
