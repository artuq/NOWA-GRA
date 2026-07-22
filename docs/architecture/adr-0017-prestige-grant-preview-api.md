# ADR-0017: PrestigeSystem — Unified Grant Preview/Last-Grant Query API

## Status
Proposed

## Date
2026-07-22

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | Core |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/architecture/adr-0012-prestige-checkpoint-system-autoload-orchestration.md` (`era_transitioned` contract this ADR extends additively) |
| **Post-Cutoff APIs Used** | None — plain GDScript `Dictionary` return values, no engine API involved |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0012 (Accepted — `era_transitioned`'s existing no-args contract, atomicity ordering; this ADR does not modify the signal, only adds a queryable field alongside it), ADR-0013 (Accepted — `ChallengeSystem.get_combined_meta_multiplier()`, one of the read inputs) |
| **Enables** | Implementation of `design/ux/wypalenie-card-modal.md`'s meta-bonus preview requirement, `design/ux/challenge-selection-screen.md`'s and `design/ux/meta-bonus-visibility.md`'s (indirectly, via consistency) last-grant recap requirement |
| **Blocks** | Any story implementing those three UX specs' "show the number" acceptance criteria |
| **Ordering Note** | None — additive, no changes to `on_burnout_accepted()`'s existing step ordering or its zero-`await` binding constraint (ADR-0012 §2) |

## Context

### Problem Statement

Three UX specs authored 2026-07-22 (`wypalenie-card-modal.md`, `challenge-selection-screen.md`, and indirectly `meta-bonus-visibility.md`) each independently need "what meta-bonus does/did this burnout grant" — once *before* the player commits Choice A (Pillar 1 preview, Wypalenie card) and once *after* commit (recap, Challenge Selection screen / era-summary). `PrestigeSystem` has no API for either today: the grant computation is inlined directly inside `on_burnout_accepted()` (lines 195-204), reading `ClassPathSystem.get_active_path()`/`get_tier()`, `ChallengeSystem.get_combined_meta_multiplier()`, and `_first_burnout_pending()`, then calling `_apply_grant()` which mutates `meta_bonus_totals` in place with no return value — there is no way to ask "what would this compute to" without actually committing it, and no way to ask "what did it just compute to" after the fact.

Building preview and last-grant as two separate, independently-written functions risks the two numbers silently diverging (e.g., one accounting for the F2 cap/4b-i first-burnout ceiling and the other not) — a correctness risk specifically for the one screen (Wypalenie card) where GDD Pillar 1 requires the shown number to be exactly right, not approximate.

### Constraints

- Must not change `era_transitioned`'s signature (ADR-0012's existing no-args contract) or its position as the last statement in `on_burnout_accepted()` (atomicity ordering, `prestige_atomicity_test.gd`'s existing regression coverage).
- Must not mutate any state when called as a preview — `ClassPathSystem`/`ChallengeSystem`/`meta_bonus_totals` must be read-only from the preview caller's perspective, callable at any time (including from a UI `_process()`-adjacent read) with no side effects.
- Must produce byte-identical results whether called as a dry-run preview or as part of the real `on_burnout_accepted()` grant — one implementation, not two.
- Must distinguish "no active path, zero bonus" from "active path, computed bonus happens to round to a small number" — both a `granted: bool` flag and a `type`/`amount` pair, not amount alone (the null-handling gap `/ux-review` found in both `wypalenie-card-modal.md` and `challenge-selection-screen.md`).
- Must account for F2's stacking-and-cap clamp and Core Rule 4b-i's first-burnout ceiling — the *applied* delta, not the pre-cap `raw_increment`, since that is what actually lands in `meta_bonus_totals` and what a recap screen must match.

### Requirements

- A single pure function, callable any number of times without mutating state, returning `{granted: bool, type: StringName, amount: float}`.
- `on_burnout_accepted()` calls this same function exactly once to perform the real grant, and stores its result for later query.
- The stored last-grant result survives `serialize_state()`/`restore_state()` — if the app closes between `era_transitioned` firing and the Challenge Selection screen being confirmed, the recap must still be correct on the next boot.

## Decision

Add `PrestigeSystem.compute_next_grant(path_id: StringName, tier: int) -> Dictionary` — a pure function extracting the existing inline grant-computation logic from `on_burnout_accepted()` (lines 195-204) without changing its formula. **`path_id`/`tier` are explicit parameters, not fetched internally** — see Engine Specialist Validation below for why. `on_burnout_accepted()` calls it once (with the `path_id`/`tier` it already captures at lines 183-185, *before* `reset_era_state()`), applies the result directly (retiring the now-redundant `_apply_grant()`), and caches it in a new `_last_grant: Dictionary` field (persisted). The Wypalenie card UI (pre-commit preview) calls `compute_next_grant(ClassPathSystem.get_active_path(), ClassPathSystem.get_tier(...))` itself, reading live pre-reset state — safe, since preview only ever runs before any reset happens. UI callers needing the historical record (Challenge Selection, meta-bonus recap) call the new `get_last_grant() -> Dictionary` getter instead.

### Architecture Diagram

```
PrestigeSystem (Autoload)
  var _last_grant: Dictionary = {"granted": false, "type": &"", "amount": 0.0}  # persisted

  func compute_next_grant(path_id: StringName, tier: int) -> Dictionary:
    # PURE given its explicit inputs — no mutation, safe to call any number of
    # times. path_id/tier are caller-supplied (NOT ClassPathSystem.get_active_path()
    # fetched internally) specifically so this stays correct whether called
    # before or after ClassPathSystem.reset_era_state() clears that state —
    # the caller is responsible for capturing path_id/tier at the right moment.
    if path_id == &"":
      return {"granted": false, "type": &"", "amount": 0.0}
    var bonus_type: StringName = _BONUS_TYPE_BY_PATH.get(path_id, &"")
    if bonus_type == &"":
      return {"granted": false, "type": &"", "amount": 0.0}
    var challenge_mult: float = ChallengeSystem.get_combined_meta_multiplier()
    var is_first: bool = _first_burnout_pending(bonus_type)
    var raw_grant: float = PrestigeFormulas.grant_magnitude(bonus_type, tier, challenge_mult, is_first)
    var current_total: float = meta_bonus_totals.get(bonus_type, 0.0)
    var cap: float = PrestigeFormulas.META_BONUS_MAX[bonus_type]
    var post_cap_total: float = PrestigeFormulas.apply_stacking_and_cap(bonus_type, current_total, raw_grant, cap)
    return {"granted": true, "type": bonus_type, "amount": post_cap_total - current_total}
    # amount is the ACTUAL applied delta (post F2 cap / 4b-i ceiling), not raw_grant
    # NOTE: challenge_mult/meta_bonus_totals are NOT touched by reset_era_state()
    # (that only clears ClassPathSystem's own affiliation state), so fetching
    # them internally here carries no equivalent ordering hazard.

  func get_last_grant() -> Dictionary:
    return _last_grant  # queryable after era_transitioned fires

  func on_burnout_accepted() -> void:
    var path_id: StringName = ClassPathSystem.get_active_path()   # unchanged, line 183
    var tier: int = ClassPathSystem.get_tier(path_id) if path_id != &"" else 0  # unchanged, line 184
    _last_captured_tier = tier                                     # unchanged, line 185
    SaveSystem.suppress_autosave()
    ClassPathSystem.reset_era_state()
    var grant_result: Dictionary = compute_next_grant(path_id, tier)   # NEW — replaces the inlined block,
                                                                         # fed pre-reset path_id/tier captured above
    _last_grant = grant_result                                    # NEW — cache for get_last_grant()
    if grant_result["granted"]:
      var bonus_type: StringName = grant_result["type"]
      meta_bonus_totals[bonus_type] = meta_bonus_totals.get(bonus_type, 0.0) + grant_result["amount"]
      # ^ replaces the old _apply_grant() call: amount is ALREADY the post-cap delta,
      #   so this is a single addition, not a second cap computation — avoids the
      #   double-cap redundancy Engine Specialist Validation flagged. _apply_grant()
      #   is retired (Migration Plan step 3).
      if _first_burnout_pending(bonus_type):                       # unchanged milestone logic
        HistoryFlagManager.set_milestone(...)
    ...                                    # unchanged: variety check, flag sweep, era_count++, save, era_transitioned.emit()
```

### Key Interfaces

```gdscript
# PrestigeSystem (Autoload) — two new public methods, one new persisted field
func compute_next_grant(path_id: StringName, tier: int) -> Dictionary
# Returns {"granted": bool, "type": StringName, "amount": float}. Pure given
# its explicit path_id/tier inputs — mutates nothing. path_id/tier are
# caller-supplied, NOT fetched internally, so this function is safe to call
# both before ClassPathSystem.reset_era_state() (on_burnout_accepted()'s real
# grant) and independently of any reset (Wypalenie card's live preview, which
# passes ClassPathSystem.get_active_path()/get_tier() itself). "amount" is the
# post-cap applied delta, matching what a real grant would actually add.

func get_last_grant() -> Dictionary
# Returns the cached result of the most recent real grant (set inside
# on_burnout_accepted(), persisted). {"granted": false, "type": &"", "amount": 0.0}
# before any burnout has ever been accepted (first-session default, matches
# every other peer Autoload's missing-key convention).

var _last_grant: Dictionary  # private, persisted via serialize_state()/restore_state()
```

### Engine Specialist Validation

`godot-gdscript-specialist` review (2026-07-22) caught two issues in an earlier draft, both fixed above:
1. **Ordering bug**: an earlier draft had `compute_next_grant()` call `ClassPathSystem.get_active_path()`/`get_tier()` internally. Since `on_burnout_accepted()` calls `ClassPathSystem.reset_era_state()` *before* the grant computation (line 189, predating this ADR), fetching path/tier internally at that point would always read already-cleared state and return `granted: false` for every real grant. Fixed by making `path_id`/`tier` explicit parameters, captured by each caller at the correct moment.
2. **Redundant double-cap**: an earlier draft still routed the real grant through the existing `_apply_grant()`, which independently re-derives and re-applies the same cap math `compute_next_grant()` already computed. Harmless today (single-threaded, no mutation between the two calls) but wasteful and a future footgun. Fixed by retiring `_apply_grant()` and applying `grant_result["amount"]` directly (see Architecture Diagram, Migration Plan step 3).

## Alternatives Considered

### Alternative 1: Add a payload to the `era_transitioned` signal
- **Description**: `signal era_transitioned(bonus_type: StringName, bonus_amount: float, granted: bool)`.
- **Pros**: No new method — consumers already connect to this signal.
- **Cons**: Existing zero-arg spy connections in `prestige_atomicity_test.gd`, `burnout_choice_routing_test.gd`, `prestige_orchestration_test.gd`, `prestige_grant_wiring_test.gd` would keep compiling (Godot allows a `Callable` with fewer params than a signal emits), but the signal's meaning changes from "a pure lifecycle event" to "a lifecycle event carrying business data," a scope creep ADR-0012 explicitly didn't intend. Doesn't solve the preview half of the problem at all — a signal only fires post-commit, never as a dry-run.
- **Rejection Reason**: Solves only the recap half, not the preview half, and blurs `era_transitioned`'s existing narrow contract for no full benefit.

### Alternative 2: Two independent functions (preview-only ADR, last-grant deferred)
- **Description**: Scope this ADR to `get_last_grant()` only; write a separate, later ADR for the preview function.
- **Pros**: Smaller, more focused ADR.
- **Cons**: Exactly the correctness risk this ADR's Problem Statement flags — two independently-implemented copies of the same F1/F2/4b-i formula stack are one future edit away from silently disagreeing (e.g., a balance tweak to `META_CHALLENGE_SCALING_EXPONENT` applied to one copy and not the other).
- **Rejection Reason**: The whole point of unifying is eliminating that divergence risk; splitting the ADR reintroduces it.

## Consequences

### Positive
- One formula implementation, two call sites (preview, real) — cannot silently diverge.
- `on_burnout_accepted()` gets slightly *shorter* (extraction, not addition) — the inline grant block becomes a single `compute_next_grant()` call.
- Unblocks all three pending UX specs' acceptance criteria with one ADR instead of three ad-hoc ones.

### Negative
- `_last_grant` is a new field requiring `serialize_state()`/`restore_state()` wiring — a small, mechanical addition to an already-established pattern, but still a touch point in tested, shipped code.

### Risks
- Refactoring `on_burnout_accepted()`'s inline grant block into `compute_next_grant()`, and retiring `_apply_grant()`, touches a function with extensive existing atomicity/ordering test coverage (`prestige_atomicity_test.gd`) — mitigation: the refactor is behavior-preserving by construction (`meta_bonus_totals[type] = current_total + amount` where `amount` is already the post-cap delta is arithmetically identical to the old `_apply_grant()`'s `apply_stacking_and_cap()` result), not a logic change; existing tests must continue passing unchanged as the validation signal.
- `compute_next_grant()` being callable "any time" means it could theoretically be called mid-`on_burnout_accepted()` by a re-entrant caller — not currently possible (no `await` in the call graph, GDScript is single-threaded), noted for awareness only, not a real risk today.
- `path_id`/`tier` as explicit parameters (not fetched internally) puts correctness in the caller's hands — a future caller of `compute_next_grant()` that passes stale or already-reset values would get a silently wrong (but not crashing) preview. Mitigation: both current call sites (Wypalenie card preview, `on_burnout_accepted()`) capture their inputs at the correct moment per this ADR's Architecture Diagram; a future third caller should follow the same pattern, not fetch-then-call across an intervening reset.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| prestige-checkpoint-system.md | Core Rule 1 / F1 — meta-bonus grant computation, path-typed, no-active-path case | `compute_next_grant()` implements exactly this rule, extracted not reimplemented |
| prestige-checkpoint-system.md | Line 254 — Wypalenie card MUST surface "no bonus" before confirm (locked requirement) | `granted: bool` makes this an explicit, checkable field, not an inferred zero |
| design/ux/wypalenie-card-modal.md | Meta-bonus preview before commit (Pillar 1) — flagged as new architecture need | `compute_next_grant()`, called pre-commit, zero mutation |
| design/ux/challenge-selection-screen.md | Era-summary recap ("what did I just get") — flagged as new architecture need | `get_last_grant()`, queried post-commit |

## Performance Implications
- **CPU**: Negligible — same computation that already runs inside `on_burnout_accepted()`, now also callable on-demand from UI (infrequent, not per-frame).
- **Memory**: Negligible — one `Dictionary` field.
- **Load Time**: None.
- **Network**: N/A.

## Migration Plan

1. Add `compute_next_grant(path_id: StringName, tier: int) -> Dictionary` implementing the extracted formula (current inline lines ~195-204's logic, unchanged math).
2. Add `_last_grant: Dictionary` field, default `{"granted": false, "type": &"", "amount": 0.0}`.
3. In `on_burnout_accepted()`: call `compute_next_grant(path_id, tier)` using the `path_id`/`tier` already captured at lines 183-185 (before `reset_era_state()`); store the result in `_last_grant`; replace the `_apply_grant(bonus_type, grant)` call with direct application of `grant_result["amount"]` (already post-cap) to `meta_bonus_totals`. Retire `_apply_grant()` — delete it, its computation is now inside `compute_next_grant()`.
4. Add `get_last_grant() -> Dictionary` public getter.
5. Add `_last_grant` to `serialize_state()`/`restore_state()`.
6. Existing test suite (`prestige_atomicity_test.gd`, `prestige_grant_wiring_test.gd`, etc.) must pass unchanged — this is the correctness gate for the refactor being behavior-preserving. Any test that directly exercises `_apply_grant()` (if one exists — verify during implementation) needs re-pointing at `compute_next_grant()` + the new inline application instead.
7. No changes to `ClassPathSystem`, `ChallengeSystem`, `BurnoutSystem`, `DecisionCardSystem`, or the `era_transitioned` signal itself.

## Validation Criteria

New unit tests: `compute_next_grant()` called repeatedly with no state change between calls returns identical results (pure-function property); called with no active path returns `granted: false`; called for a capped type returns the post-cap delta, not the raw pre-cap `grant_magnitude()` output. Integration test: `get_last_grant()` immediately after a real `on_burnout_accepted()` call returns a result equal to what `compute_next_grant()` would have returned immediately before that call (preview/real consistency, the core guarantee this ADR exists for).

## Related Decisions
- ADR-0012 (`era_transitioned` contract, atomicity ordering — unmodified dependency)
- ADR-0013 (`ChallengeSystem.get_combined_meta_multiplier()` — one of the read inputs)
- `design/ux/wypalenie-card-modal.md`, `design/ux/challenge-selection-screen.md`, `design/ux/meta-bonus-visibility.md` (the three specs this unblocks)
