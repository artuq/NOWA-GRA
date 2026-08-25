# ADR-0012: Prestige/Checkpoint System — Autoload, Orchestration Order, and META_BONUS API

## Status
Accepted (2026-07-14, following independent `/architecture-review` — verdict CONCERNS overall (one open gap: TR-pcs-007 Burnout/Challenge have no ADR), but no conflicts or blockers against this ADR specifically; all four dependencies ADR-0001/0002/0003/0010 Accepted, engine-clean, dependency APIs verified against shipped code)

## Date
2026-07-13

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | Core |
| **Knowledge Risk** | LOW — Autoload registration, direct method calls, and `Dictionary`-based state are stable pre-4.3 APIs; no post-cutoff breaking change touches this domain |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | Typed Dictionary syntax (`Dictionary[StringName, float]`, §1) — 4.4+ feature. Usage is correct and safe in 4.6.3; flagged here per this project's version-awareness protocol, not a risk. |
| **Verification Required** | None beyond standard `await`/`CONNECT_DEFERRED` audit already mandated by the GDD's own call-contract lock (see Decision §2) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload singleton architecture), ADR-0003 (`restore_state()` boot protocol), ADR-0010 (ClassPathSystem — `get_active_path()`, `get_tier()`, `reset_era_state()` are read/called directly by this ADR's orchestrator), ADR-0002 (SaveSystem — `suppress_autosave()`/`resume_autosave()` already added 2026-07-13 for this exact purpose) |
| **Enables** | BurnoutSystem and ChallengeSystem implementation stories (both quick-spec-locked, blocked on `PrestigeSystem` existing since both call into it) |
| **Blocks** | Sprint 11 11-2 (BurnoutSystem core implementation) — cannot start until this ADR is Accepted |
| **Ordering Note** | `PrestigeSystem` must be registered as an Autoload *below* `ClassPathSystem`, `DecisionCardSystem`, `SaveSystem`, and `HistoryFlagManager` in `project.godot` (it calls into all four; none of them may call into it — see Decision §1) |

## Context

### Problem Statement
`prestige-checkpoint-system.md` defines a meta-progression layer built on two already-locked sub-specs (BurnoutSystem, ChallengeSystem) but introduces genuinely new architecture: a `PrestigeSystem` that orchestrates the era-transition sequence (read Class Path state before it's cleared → trigger the reset → compute and grant a permanent META_BONUS → sweep era-local vs meta-persistent flags → save → signal). This sequence has hard ordering constraints the GDD itself flags as bug-prone (a silent-wrong-bonus risk if the read happens after the reset) and explicitly forbids solving with signals or `await` (both would silently break the same-frame guarantee). No ADR currently exists for this system — it needs one before any story can be written.

### Constraints
- Godot 4.6.3, GDScript, no threading (per `architecture.md` Principle 1)
- The read-then-reset sequence (`get_active_path()` → `get_tier()` → `reset_era_state()`) must be guaranteed same-frame — no signal round-trip, no `CONNECT_DEFERRED`, no `await` anywhere in the call chain (GDD States and Transitions, Call-contract lock)
- `PrestigeSystem`'s own `_ready()` must not depend on any other Autoload's `_ready()` having completed (GDD's Autoload initialization-order contract) — all cross-autoload calls happen in response to the runtime event of Choice A confirming, never during boot
- META_BONUS values are permanent, additive-per-type, and must never be reduced by a future cap-lowering balance pass (GDD Core Rule 5)

### Requirements
- Must expose a single, clearly-owned orchestration entry point for "Choice A confirmed" that no other system reimplements
- Must compute META_BONUS magnitude via pure functions (GDD Formulas F1/F1b/F2/F3a-d) that are independently unit-testable without a live Autoload
- Must integrate with `SaveSystem.suppress_autosave()`/`resume_autosave()` (ADR-0002, already added) and `DecisionCardSystem`'s new `inject_priority_card()` (this ADR defines it)
- Must persist `era_count`, per-type META_BONUS totals, and the meta-persistent flag set via the ADR-0003 `restore_state()` protocol

## Decision

### 1. `PrestigeSystem` as a new Core Autoload

Registered below `ClassPathSystem` (#9), `DecisionCardSystem`, `SaveSystem`, and `HistoryFlagManager` in `project.godot` — it depends on all four; none of them import or reference it (same one-directional-dependency discipline as ADR-0010 §1 established for `ClassPathSystem`). `PrestigeSystem` owns: `era_count` (int), `meta_bonus_totals` (`Dictionary[StringName, float]`, keyed by bonus type), and the four `first_burnout_bonus_used[type]` + `variety_bonus_used` meta-persistent flags (stored as `HistoryFlagManager` milestones, same pattern ClassPathSystem already uses for its own per-path milestones — not a second flag-storage mechanism).

### 2. Era-transition orchestration — synchronous call chain, no signals in the critical path

`PrestigeSystem.on_burnout_accepted() -> void` is the single entry point BurnoutSystem's Choice A handler calls. It performs, in order, entirely within one synchronous call stack (no `await`, no deferred call, anywhere in this method or in anything it calls):

```gdscript
func on_burnout_accepted() -> void:
    var path_id: StringName = ClassPathSystem.get_active_path()
    var tier: int = ClassPathSystem.get_tier(path_id) if path_id != &"" else 0
    var challenge_mult: float = ChallengeSystem.get_combined_meta_multiplier()

    SaveSystem.suppress_autosave()

    ClassPathSystem.reset_era_state()

    if path_id != &"":
        var bonus_type: StringName = _BONUS_TYPE_BY_PATH[path_id]
        var grant: float = PrestigeFormulas.grant_magnitude(bonus_type, tier, challenge_mult,
            _first_burnout_pending(bonus_type))
        _apply_grant(bonus_type, grant)
        if _first_burnout_pending(bonus_type):
            HistoryFlagManager.set_milestone(StringName("prestige.first_burnout_used." + String(bonus_type)))
    _check_variety_bonus()  # Core Rule 4c — fires at most once per save, see F1b

    era_count += 1
    _sweep_era_local_flags()  # Core Rule 7 — delegates the actual clear/preserve calls to HistoryFlagManager

    SaveSystem.save_now()
    SaveSystem.resume_autosave()

    era_transitioned.emit()
```

Every call above (`ClassPathSystem.get_active_path()`, `get_tier()`, `reset_era_state()`; `PrestigeFormulas.grant_magnitude()`; `HistoryFlagManager` calls; `SaveSystem.save_now()`) MUST be a plain synchronous GDScript function with no `await` in its own body or anywhere in its call graph — this is a binding implementation constraint (GDD Call-contract lock), not a style preference. `era_transitioned` fires only after this entire sequence completes — nothing in this method may yield control before it.

**Implementation note (2026-07-15, code-review amendment):** The shipped code in `src/core/prestige_system.gd` orders these steps differently from the pseudocode above: `_check_variety_bonus()` → `_sweep_era_local_flags()` → `_apply_sponsors_era_start_override()` → `era_count += 1` → `HistoryFlagManager.set_milestone("burnout_accepted_era_N")`. This is intentional, not undocumented drift: neither `_sweep_era_local_flags()` nor `_apply_sponsors_era_start_override()` reads `era_count`, so their position relative to the increment has no functional effect either way. The two binding constraints are (1) the read-before-reset ordering (step 1 before `reset_era_state()`) and (2) sweep-before-override (AC-3, spy-verified) — both of which the shipped code satisfies regardless of where the increment falls. The pseudocode above is retained as an illustrative sketch of the overall sequence, not a statement that `era_count += 1` must precede the sweep.

**Why not a signal-driven design**: `ClassPathSystem.era_transitioned` (a hypothetical signal `ClassPathSystem` could emit for others to react to) is exactly the pattern the GDD forbids for the *read* step — by the time any signal fires, the emitting call has already returned and state may have moved on. `PrestigeSystem` is deliberately the *caller*, not a *listener*, for this one sequence. (`ClassPathSystem`'s own `active_path_changed`/`tier_unlocked` signals, used by UI, are unaffected — this constraint applies only to the read-then-reset chain.)

### 3. META_BONUS formulas — stateless static methods, same precedent as ADR-0011/ADR-0006

`PrestigeFormulas` (`res://src/core/prestige_formulas.gd`, `class_name PrestigeFormulas`) implements GDD Formulas F1 (`grant_magnitude`), F1b (variety bonus), F2 (per-type stacking + cap), F3a-d (final reward stacking) as pure static functions taking explicit arguments — no Autoload state, no `self`. Same shape as `ResourceFormulas` (ADR-0006, shared online/offline consistency) and `FeedbackMath` (ADR-0011, stateless-by-design for testability). `PrestigeSystem` calls these functions and applies their results to its own owned state (`meta_bonus_totals`); the functions themselves never touch `HistoryFlagManager`, `SaveSystem`, or any Autoload.

```gdscript
# res://src/core/prestige_formulas.gd
class_name PrestigeFormulas

static func tier_factor(tier: int, tier_flat_base: int) -> float:
    return (float(tier_flat_base) + float(tier)) * 5.0 / (float(tier_flat_base) + 5.0)

static func grant_magnitude(bonus_type: StringName, tier: int, challenge_mult: float,
        is_first_burnout: bool) -> float:
    # F1 — full derivation and worked examples in design/gdd/prestige-checkpoint-system.md
    ...

static func apply_stacking_and_cap(bonus_type: StringName, current_total: float,
        grant: float, cap: float) -> float:
    # F2
    return minf(current_total + grant, cap)
```

### 4. `DecisionCardSystem.inject_priority_card(card_id: StringName)` — new API (GDD Core Rule 6)

Additive to `DecisionCardSystem`, same additive-signal/API precedent as ADR-0010 §2's `card_resolved`. Adds a `priority_card_pending` state orthogonal to the existing `cooldown → checking → presenting → resolving` cycle (GDD Interactions): while pending, normal `_check_pool()` presentation is blocked, but the cooldown counter keeps accumulating underneath so a normal card is immediately eligible the instant the priority card resolves. `inject_priority_card()` bypasses `_build_eligible_pool()`'s `trigger_condition`/milestone filtering entirely — the caller (BurnoutSystem, and any future forced-card mechanic) is responsible for knowing the card should be shown unconditionally.

```gdscript
func inject_priority_card(card_id: StringName) -> void:
    assert(not _priority_card_pending, "inject_priority_card called while one is already pending")
    _priority_card_pending = true
    var card: Dictionary = CardContentDatabase.get_card(card_id)
    present_next_card([card])
```

### 5. Flag classification sweep — `PrestigeSystem` owns the list, `HistoryFlagManager` owns the mechanics

Per GDD Core Rule 7, `PrestigeSystem._sweep_era_local_flags()` calls existing `HistoryFlagManager.reset_counter()`/`clear_milestone()`-shaped APIs (whichever already exist per ADR-0001's `HistoryFlagManager` interface) for the era-local set, and does nothing for the meta-persistent set (never cleared, by construction — absence of a clear call is the mechanism, not a separate "preserve" call). `ClassPathSystem.reset_era_state()` already clears its own era-local counters (ADR-0010) — `PrestigeSystem`'s sweep covers what's left: `BurnoutSystem._deferred_this_era`, active Challenge flags, and the 5 resource defaults (via `ResourceManager`, per Final Burnout spec §4.2, already locked and out of this ADR's scope).

### 6. Save / Load

`PrestigeSystem.restore_state(data: Dictionary) -> void` — called by `BootController` per ADR-0003, positioned after `ClassPathSystem.restore_state()` in the boot sequence (no ordering dependency between them at boot time — both just need to run before first frame). Persists and restores `era_count` (int) and `meta_bonus_totals` (Dictionary, String keys per the JSON-serialization convention ADR-0002/ADR-0010 already established). The four `first_burnout_bonus_used[type]` and `variety_bonus_used` flags are `HistoryFlagManager` milestones (§1) and are restored through `HistoryFlagManager`'s own existing restore path, not duplicated here.

### Architecture Diagram

```
BurnoutSystem (Choice A confirmed) ─────────→ PrestigeSystem.on_burnout_accepted()
                                                       │
                                    ┌──────────────────┼──────────────────────────┐
                                    │                  │                          │
                     ClassPathSystem.get_active_path() │           ChallengeSystem.get_combined_meta_multiplier()
                     ClassPathSystem.get_tier(path_id)  │
                                    │                  │
                     SaveSystem.suppress_autosave()     │
                                    │                  │
                     ClassPathSystem.reset_era_state()  │
                                    │                  │
                     PrestigeFormulas.grant_magnitude() ◄──────────────┘
                                    │
                     HistoryFlagManager (flag sweep, Rule 7)
                                    │
                     SaveSystem.save_now() → SaveSystem.resume_autosave()
                                    │
                     era_transitioned.emit()
                                    │
                     ChallengeSystem shows Challenge Selection (player-paced, outside suppression window)

DecisionCardSystem.inject_priority_card(card_id)  ◄── called by BurnoutSystem when Cringe=100 sustained
BootController._ready() ─────────→ PrestigeSystem.restore_state(data)
```

### Key Interfaces

```gdscript
# PrestigeSystem (Autoload)
signal era_transitioned  # fires only after the full synchronous sequence in §2 completes

func on_burnout_accepted() -> void  # single entry point for BurnoutSystem's Choice A
func get_meta_bonus_total(bonus_type: StringName) -> float
func get_era_count() -> int
func restore_state(data: Dictionary) -> void
func serialize_state() -> Dictionary

# PrestigeFormulas (stateless static utility, no Autoload)
static func tier_factor(tier: int, tier_flat_base: int) -> float
static func grant_magnitude(bonus_type: StringName, tier: int, challenge_mult: float, is_first_burnout: bool) -> float
static func apply_stacking_and_cap(bonus_type: StringName, current_total: float, grant: float, cap: float) -> float

# DecisionCardSystem — additive (§4)
func inject_priority_card(card_id: StringName) -> void
```

## Alternatives Considered

### Alternative A: `ClassPathSystem` emits `era_transitioned`-adjacent signal, `PrestigeSystem` listens
`ClassPathSystem` reads its own state, decides a bonus, and emits a signal `PrestigeSystem` subscribes to.
- **Pros**: Keeps `ClassPathSystem` self-contained; `PrestigeSystem` stays purely reactive.
- **Cons**: Puts META_BONUS domain knowledge (bonus types, formulas, caps) inside `ClassPathSystem`, which owns none of that per the GDD — `ClassPathSystem`'s job is affiliation/tier, not meta-progression. Also reintroduces exactly the signal-round-trip ordering risk the GDD explicitly forbids for this read.
- **Rejection Reason**: Wrong ownership (violates single-owner principle) and reintroduces the ordering bug the GDD's call-contract lock exists to prevent.

### Alternative B: No new Autoload — fold orchestration into `BurnoutSystem`
BurnoutSystem's own Choice A handler directly calls `ClassPathSystem`, computes the grant inline, and writes to a `meta_bonus` dictionary it owns.
- **Pros**: One fewer Autoload.
- **Cons**: META_BONUS state and formulas have nothing to do with Burnout's own domain (threshold detection, warning countdown, defer-once cost) — `ChallengeSystem` also needs to read meta-bonus totals independent of Burnout, and Team/Staff Management (Alpha, per Dependencies) will need to read them too. Bundling creates a god-object risk in a system whose own spec is already locked and shouldn't be reopened.
- **Rejection Reason**: Violates single-responsibility; couples an unrelated future system's read path to BurnoutSystem's internals.

### Alternative C: `PrestigeSystem` as a new Core Autoload with a synchronous orchestration entry point — CHOSEN
Described above.

## Consequences

### Positive
- The GDD's explicit "no signals, no await" ordering requirement is enforced by construction — there is exactly one call path, owned by one method, with no alternate route for the read-then-reset sequence to be accidentally reordered
- META_BONUS formulas are independently unit-testable without any live Autoload (`PrestigeFormulas` static methods), consistent with `ResourceFormulas`/`FeedbackMath` precedent
- `PrestigeSystem` becomes the single, discoverable owner of "what does era reset actually do" — BurnoutSystem, ChallengeSystem, and any future forced-reset mechanic all call the same entry point

### Negative
- A 5th cross-cutting Autoload dependency chain (`PrestigeSystem` → `ClassPathSystem`, `DecisionCardSystem`, `SaveSystem`, `HistoryFlagManager`, `ChallengeSystem`) — the largest fan-out of any Autoload in the project so far. Mitigated by the one-directional-dependency discipline (§1) keeping all 5 dependencies ignorant of `PrestigeSystem`'s existence.
- `on_burnout_accepted()` is a long synchronous method touching 5 other systems in one call — a single bug anywhere in the chain (e.g. an accidentally-introduced `await`) breaks silently per the GDD's own stated risk. Mitigated by Validation Criteria below requiring an explicit `await`/`CONNECT_DEFERRED` grep-based lint check in the story's test evidence, not just a manual code read.

### Risks
- **Silent `await` regression**: any future edit to `ClassPathSystem.get_active_path()`, `get_tier()`, `reset_era_state()`, or any function in their call graph, that introduces an `await` breaks the ordering guarantee with no compile error. Mitigation: story test evidence must include a static check (grep for `await` in the relevant files, or a code-review checklist item) as part of `/story-done`'s Phase 4 deviation checks, not just a runtime test (a runtime test may not reliably catch a yield that still resolves before the next read in practice, only under load).
- **`PrestigeSystem` becomes a large dependency hub**: if a 6th system later needs a similar orchestration read, extending `on_burnout_accepted()` risks growing an unmanageable method. Mitigation: not a problem yet (5 dependencies, one entry point) — revisit only if a second orchestration entry point is ever needed.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `prestige-checkpoint-system.md` | `PrestigeSystem` (new Autoload) orchestrates era transition | §1-2 — Autoload registration + `on_burnout_accepted()` |
| `prestige-checkpoint-system.md` | Read-then-reset must be synchronous, no signals/await (Call-contract lock) | §2 — single synchronous method, explicit binding constraint |
| `prestige-checkpoint-system.md` | Autoload initialization-order contract (no `_ready()` cross-dependency) | §1 — `PrestigeSystem` registered below its 4 dependencies; all cross-calls are runtime-event-triggered, never boot-time |
| `prestige-checkpoint-system.md` | F1/F1b/F2/F3a-d META_BONUS formulas, independently verifiable | §3 — `PrestigeFormulas` stateless static methods |
| `prestige-checkpoint-system.md` | `DecisionCardSystem.inject_priority_card()` (Core Rule 6) | §4 |
| `prestige-checkpoint-system.md` | Flag classification sweep (Core Rule 7) | §5 |
| `prestige-checkpoint-system.md` | `SaveSystem.suppress_autosave()`/`resume_autosave()`, atomicity contract | Already added to ADR-0002 (2026-07-13, `/propagate-design-change`) — referenced, not duplicated here |
| `prestige-checkpoint-system.md` | Save/restore of `era_count`, per-type totals, meta flags | §6 |

## Performance Implications
- **CPU**: `on_burnout_accepted()` runs once per era transition (a rare event, not per-frame or per-action) — negligible even with 5 cross-system calls
- **Memory**: `meta_bonus_totals` is a small Dictionary (4 entries) plus one int (`era_count`). Negligible.
- **Load Time**: `restore_state()` does 2 Dictionary reads. Negligible.
- **Network**: N/A

## Migration Plan
N/A — first ADR for this system, no existing code to migrate.

## Validation Criteria
- Unit test: `PrestigeFormulas.grant_magnitude()` matches GDD F1's worked examples exactly (including the Tier-5/stacked-challenge cap-safety case and the first-burnout ceiling case, F1/4b-i)
- Unit test: `PrestigeFormulas.apply_stacking_and_cap()` absorbs grants past `META_BONUS_MAX[type]` with no overflow
- Integration test: `on_burnout_accepted()` with an active path at Tier 3 produces the correct grant, correct flag sweep, and fires `era_transitioned` exactly once, in the correct order relative to `ClassPathSystem.reset_era_state()`
- Integration test: `on_burnout_accepted()` with no active path (ambiguous or Tier 0) grants nothing but still resets the era (Edge Cases)
- Static check (code review, not runtime): grep `src/core/prestige_system.gd`, `src/core/class_path_system.gd`'s `get_active_path`/`get_tier`/`reset_era_state`, `ChallengeSystem.get_combined_meta_multiplier()`, `HistoryFlagManager`'s sweep calls, and `SaveSystem.save_now()`/`resume_autosave()` — and their full call graphs — for `await` and `CONNECT_DEFERRED` — must return zero matches across all of them, not just the two named in the original draft (godot-gdscript-specialist review, 2026-07-13)
- Dev note: `assert()` in `inject_priority_card()` (§4) is stripped in exported release builds — it is a dev-time guard only, not a production safety net (godot-gdscript-specialist review, 2026-07-13)
- Integration test: `SaveSystem.suppress_autosave()` is active for the full duration of steps 1-5 (§2) and inactive before `era_transitioned` fires

## Related Decisions
- ADR-0001: Autoload singleton architecture (pattern basis)
- ADR-0003: Boot order and `restore_state()` protocol
- ADR-0010: Class Path System — `PrestigeSystem` is a hard caller of its `get_active_path()`/`get_tier()`/`reset_era_state()`
- ADR-0002: Save File Format — `suppress_autosave()`/`resume_autosave()` (already added, referenced not duplicated)
- ADR-0011: Juice/Feedback stateless math precedent — basis for `PrestigeFormulas`' stateless-static-methods shape
- ADR-0006: `ResourceFormulas` — same online/offline-consistency-by-construction precedent
