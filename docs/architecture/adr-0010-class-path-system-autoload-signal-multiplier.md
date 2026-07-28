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

### 8. Investment Contribution — gated command, replacing the `invest()` stub *(added 2026-07-13, `/architecture-decision` extension for class-path-system.md's VS/Alpha delta)*

Per GDD Core Rule 4a and F2, `invest()` becomes a live command gated on prior card-choice history: investment is only accepted when the path's F1 card-contribution term is `> 0`. The current stub's unconditional `return false` becomes the defensive rejection branch for a gate violation, not a permanent no-op.

```gdscript
func invest(path_id: StringName, resource_id: StringName, amount: float) -> bool:
    if _card_contribution.get(path_id, 0.0) <= 0.0:  # gate — Core Rule 4a
        return false
    if not ResourceManager.can_afford(resource_id, amount):
        return false
    var rate: float = _investment_rate_table.get(path_id, 0.0)
    ResourceManager.apply_delta(resource_id, -amount)
    _investment_contribution[path_id] = _investment_contribution.get(path_id, 0.0) + amount * rate
    _recalculate_total_affiliation(path_id)  # F3 clamp, then _check_tier_progression + _update_active_path
    return true
```

**Required internal refactor**: `_recalculate_affiliation()` currently conflates F1 (card) and F2 (investment) into one `_affiliation[path_id]` float. Core Rule 4a's gate reads the F1 term alone, so the two contributions must be tracked separately (`_card_contribution`, `_investment_contribution`) and summed+clamped into `_affiliation` by a new `_recalculate_total_affiliation()` (F3), called from both the `card_resolved` handler and `invest()`. This is a structural change to existing MVP code, not a purely additive one — flag as MEDIUM implementation risk in the story (see Risks below).

`_investment_rate_table` is per-path (`INVESTMENT_AFFILIATION_RATE[path]` per GDD F2), sourced from `assets/data/balance.json` under `class_path.investment_rate`, same data-source pattern as `_path_multiplier_table` (§5).

### 9. Tie-Break Resolution (F5) — fixes BUG-003 *(added 2026-07-13)*

Shipped `_update_active_path()` uses a strict `>` comparison with no margin check — this is BUG-003 (`production/qa/bugs/BUG-003-class-path-no-tiebreak-logic.md`, S3): two paths within `PATH_AFFILIATION_TIE_BREAK_MARGIN` of each other silently resolve to whichever iterates first in the `_affiliation` Dictionary, instead of GDD F5's "no active path, Ambiguous" state.

Fix — track the top two candidates and compare their gap:

```gdscript
func _update_active_path() -> void:
    var best_path: StringName = &""
    var best_affil: float = -1.0
    var second_affil: float = -1.0
    for path_id: StringName in _affiliation:
        if _current_tier.get(path_id, 0) >= 1:
            var a: float = _affiliation[path_id]
            if a > best_affil:
                second_affil = best_affil
                best_affil = a
                best_path = path_id
            elif a > second_affil:
                second_affil = a
    var resolved: StringName = best_path
    if second_affil >= 0.0 and (best_affil - second_affil) < PATH_AFFILIATION_TIE_BREAK_MARGIN:
        resolved = &""  # ambiguous — GDD F5
    if resolved != _active_path:
        _active_path = resolved
        active_path_changed.emit(_active_path)
```

`PATH_AFFILIATION_TIE_BREAK_MARGIN` (5.0 default) stays a GDScript `const` in `class_path_system.gd`, matching where `CARD_AFFILIATION_PER_CHOICE`/`CARD_CONTRIBUTION_MAX` already live — not `balance.json` (those two are also file consts, not data-file values). GDD UI Requirements needs the numeric gap surfaced when ambiguous — new query `get_ambiguous_gap() -> float` returns `best_affil - second_affil` when ambiguous, `-1.0` otherwise.

**Behavioural change**: `active_path_changed("")` can now fire when it previously wouldn't have (any two paths landing within the margin after previously having a resolved winner). This is intentional per F5, but is a new emission case for existing subscribers (HUD) to handle — already covered by GDD UI Requirements' "Ambiguous" state, not a new UI requirement.

### 10. Signature Card Wiring (Tier 5) — pull-model trigger condition, not pool mutation *(added 2026-07-13)*

`DecisionCardSystem._trigger_condition_met(condition: String)` is presently a single-case switch (`"always"` only — the GDD Open Question on trigger-condition grammar was explicitly deferred to VS+, per its own code comment). Rather than adding a push-based pool-mutation API to DecisionCardSystem (which would require a new dependency direction, contradicting §5/§5a's established pull-model precedent), signature cards use an additive trigger-condition grammar entry:

```gdscript
func _trigger_condition_met(condition: String) -> bool:
    if condition == "always":
        return true
    if condition.begins_with("class_path_tier:"):
        var parts := condition.split(":")  # "class_path_tier:{path_id}:{min_tier}"
        return ClassPathSystem.get_tier(StringName(parts[1])) >= int(parts[2])
    return false
```

Each path's Tier-5 signature card (`design/gdd/class-path-system.md` Tier Bonuses table: `viral_moment` / `brand_deal_of_the_century` / `kult_niszowy` / `ipo_influencera`) is added to `CardContentDatabase` with `trigger_condition = "class_path_tier:{path_id}:5"`. No pool-mutation call, no new signal consumer — `_build_eligible_pool()` already re-evaluates `trigger_condition` on every pool build (§`_build_eligible_pool`, existing code), so the card becomes eligible the moment tier 5 is reached and ineligible again after era reset drops the tier back to 0, with zero new wiring. `signature_card_unlocked`/`signature_card_removed` (GDD Signals table) remain UI-only notification signals — DecisionCardSystem does not subscribe to them.

### 11. 4-Path Registration Expansion (Tiers 3-5) *(added 2026-07-13)*

`_MULTIPLIER_TABLE` and the path-registration dictionaries currently cover 2 paths × Tiers 1-2 only (`class_path_system.gd`'s MVP-scope header comment). Expansion to 4 paths × Tiers 1-5 is pure data growth within the existing `_MULTIPLIER_TABLE` / `balance.json` structure (§5) — no new API surface. `TIER_THRESHOLDS` is already a 6-element array (`_check_tier_progression()`'s `range(old_tier + 1, TIER_THRESHOLDS.size())` already generalizes past 2 tiers) and needs no structural change, only its 5 real threshold values populated per GDD Tuning Knobs if not already present.

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

ClassPathUI (Invest button)     ─────────→ ClassPathSystem.invest(path, resource, amount)  [§8]
DecisionCardSystem._build_eligible_pool() ─────────→ ClassPathSystem.get_tier(path_id)  [§10, pull, trigger_condition]
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
func get_ambiguous_gap() -> float  # best - second when ambiguous, -1.0 otherwise (added 2026-07-13, §9)

# Commands
func invest(path_id: StringName, resource_id: StringName, amount: float) -> bool
# ^ gated on card_contribution[path] > 0 (Core Rule 4a) — implemented 2026-07-13, §8
func restore_state(data: Dictionary) -> void
func reset_era_state() -> void  # MVP: debug-only; Alpha: wired to BurnoutSystem.era_transitioned

# DecisionCardSystem — additive trigger_condition grammar entry (§10)
# _trigger_condition_met() gains: "class_path_tier:{path_id}:{min_tier}"
```

### §12 — Tier Effect Table + pull-model effect getters (2026-07-28, tier-bonus fill)

Extends §5/§11 for the non-Reach tier bonuses (the playtest-12-3 "hollow ladder"
fix, `design/reference/class-path-tier-bonus-table-draft.md`). Same architecture,
more getters — no new Autoload, no new signal, no push:

- `_TIER_EFFECT_TABLE` (const, same in-file sourcing as `_MULTIPLIER_TABLE`):
  path → tier → {secondary_yield, duration_mult, reach_all_mult,
  cringe_gain_mult, sponsor_income_mult, morale_cost_mult, morale_drain_mult,
  haters_growth_mult, morale_floor}. **Resolution is cumulative**: highest
  defining tier ≤ current wins per key — and `get_active_multiplier()` itself
  now resolves cumulatively too (fixing the latent hollow-tier-drops-T2 bug).
- New pure-read getters, all active-path-gated with neutral defaults:
  `get_secondary_yield(action_id)`, `get_action_duration_multiplier(action_id)`,
  `get_cringe_gain_multiplier()`, `get_sponsor_income_multiplier()`,
  `get_morale_cost_multiplier()`, `get_morale_drain_multiplier()`,
  `get_haters_growth_multiplier()`, `get_morale_floor()`, plus the
  presentation feed `get_tier_effect_data(path_id, tier)` (raw, per-tier,
  not active-gated — ClassPathPanel legibility).
- Consumers (pull model, §5's direction): ActionSystem (timer arming ×
  duration mult; resolution: cringe/morale scaling + secondary-yield merge),
  DecisionCardSystem (positive Sponsors card deltas × sponsor income),
  OfflineProgressSystem (drain/haters mults + Morale floor, snapshotted once
  at sim start like the shield). **ResourceManager deliberately NOT a
  consumer**: a live Morale-floor clamp in `apply_delta()` would make Morale
  spends (ekspert's own invest resource) free at the floor — the floor is an
  ambient-drain shield only (documented on both sides).

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
- **§8 `_recalculate_affiliation()` refactor**: splitting the F1/F2-conflated float into two tracked terms touches existing MVP code (not purely additive) — regression risk against the 2-path MVP's existing behaviour. Mitigation: story requires the existing `class_path_core_test.gd` suite (25 tests) to stay green after the split, plus new F1/F2-isolation test cases.
- **§9 tie-break behavioural change**: `active_path_changed("")` can now fire in a case it never did before (see §9). Mitigation: already covered by GDD F5 / UI Requirements' Ambiguous state — flag in the story as a "new emission path for an existing signal," not a new signal.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `class-path-system-2026-07-01.md` | ClassPathSystem owns affiliation floats, tier state, active path resolution, investment logic, signals | ClassPathSystem Autoload with full API surface specified |
| `class-path-system-2026-07-01.md` | Card resolution automatically increments path-tagged pattern counters via HistoryFlagManager | DecisionCardSystem increments counter in `resolve_choice()`; `card_resolved` signal triggers ClassPathSystem re-evaluation |
| `class-path-system-2026-07-01.md` | ActionSystem queries `get_active_multiplier(action_id)` on action completion | Pull model: ActionSystem calls ClassPathSystem.get_active_multiplier(); ClassPathSystem never touches ActionSystem |
| `class-path-system-2026-07-01.md` | BurnoutSystem emits `era_transitioned` → ClassPathSystem.reset_era_state() | API defined; BurnoutSystem wiring deferred to BurnoutSystem's ADR (Alpha) |
| `class-path-system-2026-07-01.md` | SaveSystem: ClassPathSystem state added to serialize/restore cycle | restore_state(data: Dictionary) per ADR-0003 pattern |
| `class-path-system.md` | F2 Investment Contribution, gated by Core Rule 4a | §8 — `invest()` implemented with card-contribution gate |
| `class-path-system.md` | F5 Active Path Resolution and Tie-Break; BUG-003 regression coverage | §9 — `_update_active_path()` fixed to track top-two-candidate margin |
| `class-path-system.md` | Tier 5 signature cards added/removed from Decision Card pool | §10 — pull-model `trigger_condition` grammar entry, no pool-mutation API |
| `class-path-system.md` | 4 paths, Tiers 1-5 (vs. MVP's 2 paths, Tiers 1-2) | §11 — data-only expansion of `_MULTIPLIER_TABLE` |

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
- Unit test: `invest()` returns `false` and applies no state change when `card_contribution[path] == 0` (§8 gate)
- Unit test: `invest()` succeeds and increments `investment_contribution[path]` when the gate condition holds
- Unit test: two paths within `PATH_AFFILIATION_TIE_BREAK_MARGIN` resolve to `""` (BUG-003 regression, §9)
- Unit test: `get_ambiguous_gap()` returns the correct positive gap when not ambiguous, `-1.0` when never computed
- Integration test: path reaches Tier 5 → signature card appears in `_build_eligible_pool()` output; era reset → card disappears again (§10)

## Related Decisions
- ADR-0001: Autoload singleton architecture (pattern basis for this decision)
- ADR-0003: Boot order and `restore_state()` protocol
- ADR-0005: HistoryFlagManager counter API consumed here
- ADR-0008: DecisionCardSystem signal architecture (precedent for additive `card_resolved` signal)
- `design/quick-specs/class-path-system-2026-07-01.md`: full path definitions, formulas, tuning knobs
