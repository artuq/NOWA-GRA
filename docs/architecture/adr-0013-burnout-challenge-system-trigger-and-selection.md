# ADR-0013: BurnoutSystem / ChallengeSystem — Trigger Detection, Card Injection, and Challenge Selection

## Status
Accepted (2026-07-17; live-play scene boundary clarified and synced 2026-08-05)

## Date
2026-07-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | Core |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/architecture/adr-0012-prestige-checkpoint-system-autoload-orchestration.md` (Engine Compatibility precedent for the same domain), `docs/architecture/adr-0010-class-path-system-autoload-signal-multiplier.md` |
| **Post-Cutoff APIs Used** | None — this ADR only uses `_process(delta)`, `Timer`-free frame-delta accumulation, `Signal.connect()`, `Dictionary`/`StringName`, all stable pre-4.3 APIs, same class of usage already vetted safe by ADR-0012 |
| **Verification Required** | None beyond the existing zero-`await`/zero-`CONNECT_DEFERRED` static check this ADR extends from ADR-0012 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0012 (Accepted — `PrestigeSystem` owns `era_count`/`meta_bonus_totals`/the reset+grant sequence; this ADR's Autoloads call into it, not the reverse), ADR-0001 (Accepted — Autoload singleton pattern), ADR-0010 (Accepted — pull-model getter precedent, `get_active_sponsor_multiplier()`) |
| **Enables** | TR-pcs-007 closure (`docs/architecture/tr-registry.yaml`); the deferred follow-up half of prestige-checkpoint Story 008 (card re-presentation on boot, Challenge Selection kill-timing) |
| **Blocks** | Full implementation of BurnoutSystem/ChallengeSystem stories (currently only quick-specs exist, no story files) |
| **Ordering Note** | `PrestigeSystem` (ADR-0012) must remain Accepted and unchanged in its public surface — this ADR is additive on top of it, not a revision. **Autoload registration**: `BurnoutSystem` must be registered strictly *after* `DecisionCardSystem` in `project.godot`'s `[autoload]` list — its `_ready()` calls `DecisionCardSystem.card_resolved.connect(...)`, which requires that node to already exist, exactly the same requirement `ClassPathSystem` already satisfies for the identical reason (`class_path_system.gd:219`, registered after `DecisionCardSystem` at project.godot position 9). No ordering constraint exists between `BurnoutSystem`/`ChallengeSystem` and `PrestigeSystem` itself, since the calls into it happen at runtime post-boot, not from `_ready()`. |

## Context

### Problem Statement

`design/quick-specs/final-burnout-2026-07-01.md` (BurnoutSystem) and `design/quick-specs/challenge-era-runs-2026-07-01.md` (ChallengeSystem) were written 2026-07-01, before `PrestigeSystem` existed. Both quick-specs assume **BurnoutSystem** owns `era_count`, `_deferred_this_era`, `_card_pending`, the full five-resource reset, the META_BONUS grant, and emits `era_transitioned(new_era, meta_bonus_granted)`.

ADR-0012 (Accepted 2026-07-14, prestige-checkpoint epic now closed, 9/9 stories shipped) moved **all of that ownership to `PrestigeSystem`**: `era_count`, `meta_bonus_totals`, the reset sweep, the grant computation, and `era_transitioned` (no arguments) all live on `PrestigeSystem` today, verified directly against the shipped `src/core/prestige_system.gd`. The quick-specs' ownership model is now stale for everything downstream of "the player chose Accept or Defer" — only the **trigger detection** (Cringe-sustained timer, warning countdown, forced card injection) and the **Challenge Selection mechanics** (screen timing, modifier storage/stacking, application at reward resolution) remain undesigned by any ADR and unclaimed by `PrestigeSystem`.

This ADR does not re-litigate ADR-0012. It ratifies the corrected division of ownership the shipped code already reflects, and gives BurnoutSystem/ChallengeSystem (currently zero lines of code — both are still just quick-specs) an ADR to implement against.

### Constraints

- `PrestigeSystem.on_burnout_accepted()`/`on_burnout_deferred()` are ADR-0012's locked public entry points — this ADR must call into them, not modify their signatures or internals.
- ADR-0012's binding constraint (zero `await`, zero `CONNECT_DEFERRED`, zero `call_deferred` anywhere in `on_burnout_accepted()`'s call graph) is inherited: any new code that executes *before* `PrestigeSystem.era_transitioned` fires is subject to it. Code that runs *after* the signal is not.
- `PrestigeFormulas.grant_magnitude()` (Story 003, shipped) already has a `challenge_mult: float` parameter, currently hardcoded to `1.0` at its one call site in `on_burnout_accepted()`, with an explicit code comment: *"Whichever future story wires ChallengeSystem in must replace this literal with a real `ChallengeSystem.get_combined_meta_multiplier()` call."* This ADR is that future story's architecture.
- `DecisionCardSystem.card_resolved(card_id: StringName, path_tag: StringName, option_chosen: StringName)` already exists and already carries everything needed to detect "the Wypalenie card resolved, and which option was chosen" — no new API on `DecisionCardSystem` is needed.

### Requirements

- BurnoutSystem must detect the burnout trigger condition every live-play frame without per-frame allocation or signal spam beyond the warning countdown's own stated cadence.
- “Live play” is owned explicitly by `ActionScreen`: the detector is disabled by default, enabled after that scene is ready, and paused on its teardown. Boot, Start, Offline Report, and Challenge Selection must never advance or inject Burnout.
- BurnoutSystem must force-inject the Wypalenie card via the already-shipped `DecisionCardSystem.inject_priority_card()` (ADR-0012 §4, Story 002) — no new injection API.
- Choice A/B resolution must reach `PrestigeSystem.on_burnout_accepted()`/`on_burnout_deferred()` synchronously, inside the same call stack as `DecisionCardSystem.resolve_choice()`, satisfying ADR-0012's ordering guarantee.
- ChallengeSystem's combined meta-bonus multiplier must reach `PrestigeSystem`'s grant computation via a pull-model read, not a push/signal, matching ADR-0010's `get_active_sponsor_multiplier()` precedent.
- Challenge Selection's own UI flow (screen presentation, player picks 0..N challenges, confirm) is explicitly **not constrained** by ADR-0012's zero-await rule, since it runs after `era_transitioned` fires.

## Decision

### Ownership split (supersedes the quick-specs' ownership model for the overlapping fields)

| State | Quick-spec said | This ADR says (matches shipped ADR-0012 code) |
|---|---|---|
| `era_count` | BurnoutSystem | **PrestigeSystem** (ADR-0012, unchanged) |
| `_deferred_this_era` | BurnoutSystem | **PrestigeSystem** (ADR-0012 §7 Story 007, unchanged — already shipped as a placeholder field) |
| Five-resource reset, META_BONUS grant | BurnoutSystem | **PrestigeSystem** (ADR-0012, unchanged) |
| `era_transitioned` signal | `BurnoutSystem.era_transitioned(new_era, meta_bonus_granted)` | **`PrestigeSystem.era_transitioned`** (no args — already shipped; `new_era`/`meta_bonus_granted` are readable via `PrestigeSystem.get_era_count()`/`get_meta_bonus_total()` if a listener needs them) |
| `_cringe_sustained_seconds`, warning countdown, `_card_pending` | BurnoutSystem | **BurnoutSystem** (unchanged — this ADR's new scope) |
| Challenge selection, modifier storage/stacking | ChallengeSystem | **ChallengeSystem** (unchanged — this ADR's new scope) |
| `combined_meta_multiplier` | ChallengeSystem, pushed via `BurnoutSystem` reading it | **ChallengeSystem**, pulled directly by `PrestigeSystem` (this ADR's new call site) |

### BurnoutSystem (new Autoload, registered alongside but independent of `PrestigeSystem`)

Owns exactly what's left after ADR-0012: the live-play trigger detector and the forced card.

```gdscript
## Autoload. Detects sustained Cringe=100 and force-presents the Wypalenie
## card. Owns nothing PrestigeSystem already owns (era_count, resets, grants
## -- see ADR-0012). This system's only job: decide WHEN the card appears,
## and route the player's A/B choice into PrestigeSystem's two entry points.
extends Node

signal burnout_warning_changed(active: bool, seconds_remaining: float)

var _cringe_sustained_seconds: float = 0.0
var _card_pending: bool = false
var _live_play_active: bool = false

const BURNOUT_THRESHOLD: float = 300.0          # balance.json, per quick-spec
const BURNOUT_WARNING_THRESHOLD: float = 180.0  # balance.json
const BURNOUT_CARD_ID: StringName = &"final_burnout"
const BURNOUT_DEFER_MORALE_COST: float = 50.0   # balance.json

func _ready() -> void:
	DecisionCardSystem.card_resolved.connect(_on_card_resolved)
	set_process(false)

func set_live_play_active(active: bool) -> void:
	_live_play_active = active
	set_process(active)

func _process(delta: float) -> void:
	if not _live_play_active:
		return
	var cringe: float = ResourceManager.get_resource(&"Cringe")
	if cringe >= 100.0:
		_cringe_sustained_seconds += delta
		if _cringe_sustained_seconds >= BURNOUT_WARNING_THRESHOLD:
			burnout_warning_changed.emit(true, BURNOUT_THRESHOLD - _cringe_sustained_seconds)
		if _cringe_sustained_seconds >= BURNOUT_THRESHOLD and not _card_pending:
			_try_inject_burnout_card()
	else:
		if _cringe_sustained_seconds > 0.0:
			burnout_warning_changed.emit(false, 0.0)
		_cringe_sustained_seconds = 0.0

## inject_priority_card() returns bool (Story 002, ADR-0012 §4) -- false means
## either a priority card is already pending elsewhere, OR card_id failed to
## resolve in CardContentDatabase (misconfigured id, logged via push_error at
## the call site). This function also guards on DecisionCardSystem.state ==
## COOLDOWN before attempting injection, so a normal card's own
## CHECKING/PRESENTING/RESOLVING cycle is never clobbered mid-flight -- if the
## guard fails, this simply retries next frame (see Risks: BurnoutSystem
## deliberately does not reset _cringe_sustained_seconds or set _card_pending
## until injection actually succeeds, so the trigger condition stays latched
## rather than silently lost).
func _try_inject_burnout_card() -> void:
	if DecisionCardSystem.state != DecisionCardSystem.State.COOLDOWN:
		return  # mid-cycle on a normal card -- retry next frame, no reset
	if DecisionCardSystem.inject_priority_card(BURNOUT_CARD_ID):
		_card_pending = true
		_cringe_sustained_seconds = 0.0
	else:
		push_error("BurnoutSystem: inject_priority_card(%s) returned false -- " %
			BURNOUT_CARD_ID + "verify this id exists in CardContentDatabase")

## Synchronous, same-frame as DecisionCardSystem.resolve_choice() -- the
## additive card_resolved signal precedent (ADR-0008/ADR-0010) IS the
## direct-call chain here: Godot signal emission with a normally-connected
## (non-CONNECT_DEFERRED) listener runs the handler synchronously within the
## emitter's own call stack. This satisfies ADR-0012's zero-await/
## zero-CONNECT_DEFERRED constraint without a new coupling on
## DecisionCardSystem -- it doesn't need to know BurnoutSystem exists.
func _on_card_resolved(card_id: StringName, _path_tag: StringName, option_chosen: StringName) -> void:
	if card_id != BURNOUT_CARD_ID:
		return
	_card_pending = false
	if option_chosen == &"accept":
		PrestigeSystem.on_burnout_accepted()
	else:  # option_chosen == &"defer"
		PrestigeSystem.on_burnout_deferred(BURNOUT_DEFER_MORALE_COST)

func restore_state(data: Dictionary) -> void:
	_card_pending = bool(data.get("_card_pending", false))
	# _cringe_sustained_seconds intentionally NOT restored -- resets to 0.0,
	# per the quick-spec's own Pillar 4 "no surprise burnout on app open" rule.

func serialize_state() -> Dictionary:
	return {"_card_pending": _card_pending}
```

`ActionScreen._ready()` calls `BurnoutSystem.set_live_play_active(true)` only after
its children (including `CardScreen`) are ready; `_exit_tree()` calls `false`.
Deactivation pauses the accumulator without resetting it and emits no warning-cancel
signal because the owning HUD is leaving with the same scene. This is an ephemeral
lifecycle gate, not persisted state.

`_card_pending` persisting across save/load (and re-presenting the card on boot if the app was killed mid-choice) is exactly the mechanism `story-008-transition-atomicity.md`'s Scope Note flagged as deferred pending this ADR — once BurnoutSystem ships with this field, that follow-up test can be written.

### ChallengeSystem (new Autoload, independent of both BurnoutSystem and PrestigeSystem)

```gdscript
## Autoload. Owns era-local challenge selection and the reward modifiers
## challenges impose. Exposes pull-model getters -- PrestigeSystem and
## ActionSystem read from this system; this system never writes to either.
extends Node

const CHALLENGE_MAX_ACTIVE: int = 3        # balance.json
const CHALLENGE_MODIFIER_FLOOR: float = 0.05  # balance.json, safety rail

var _active_challenge_ids: Array[StringName] = []

## Pull-model read, same shape as ClassPathSystem.get_active_sponsor_multiplier()
## (ADR-0010 §5a). Called synchronously by PrestigeSystem.on_burnout_accepted()
## step 4 -- see the call site below. Returns 1.0 (safe default) if no
## challenges are active, matching the quick-spec's own stated contract.
func get_combined_meta_multiplier() -> float:
	if _active_challenge_ids.is_empty():
		return 1.0
	var product: float = 1.0
	for challenge_id: StringName in _active_challenge_ids:
		product *= _CHALLENGE_CATALOGUE[challenge_id]["meta_bonus_multiplier"]
	return product

## Pull-model read, called by ActionSystem at reward resolution (after the
## Morale multiplier, per the quick-spec's Rule 2). Returns 1.0 if the axis
## isn't targeted by any active challenge for this action -- an unaffected
## action must be a no-op multiply, not a missing-key error.
func get_modifier(action_id: StringName, axis: StringName) -> float:
	var product: float = 1.0
	for challenge_id: StringName in _active_challenge_ids:
		var entry: Dictionary = _CHALLENGE_CATALOGUE[challenge_id]
		if entry["modifier_type"] != axis:
			continue
		var applies_to: Variant = entry["applies_to"]
		if applies_to != "all" and not (applies_to as Array).has(action_id):
			continue
		product *= entry["modifier_value"]
	return maxf(CHALLENGE_MODIFIER_FLOOR, product)
```

The Challenge Selection screen (player picks 0..N, confirms) listens to `PrestigeSystem.era_transitioned` and runs entirely **after** it fires — outside `on_burnout_accepted()`'s call stack, so it may `await` freely for the UI flow without violating ADR-0012's constraint. This resolves the design question this ADR asked explicitly: the constraint's boundary is the signal emission itself, not "anything downstream of a burnout."

### `PrestigeSystem`'s one new call site (the only change to already-shipped code)

In `on_burnout_accepted()`, replace the Story 003-era stub:

```gdscript
# BEFORE (shipped, Story 003):
var challenge_mult: float = 1.0

# AFTER (this ADR):
var challenge_mult: float = ChallengeSystem.get_combined_meta_multiplier()
```

One line. `PrestigeSystem`'s public surface, signature, and every other line of `on_burnout_accepted()` are unchanged. The read is synchronous (a plain getter over an `Array`/`Dictionary` lookup, no signals, no I/O) — satisfies the zero-await constraint by construction.

### Key Interfaces

| Interface | Owner | Shape |
|---|---|---|
| `burnout_warning_changed(active: bool, seconds_remaining: float)` | BurnoutSystem | signal |
| `restore_state(data)` / `serialize_state()` | BurnoutSystem | method pair, ADR-0003 boot protocol |
| `get_combined_meta_multiplier() -> float` | ChallengeSystem | method, pull-model, called by `PrestigeSystem` |
| `get_modifier(action_id: StringName, axis: StringName) -> float` | ChallengeSystem | method, pull-model, called by `ActionSystem` |
| `restore_state(data)` / `serialize_state()` | ChallengeSystem | method pair, ADR-0003 boot protocol |

## Alternatives Considered

### Alternative 1: Merge BurnoutSystem's trigger logic directly into PrestigeSystem
- **Description**: No separate Autoload — `PrestigeSystem` gains a `_process(delta)` and owns the Cringe-sustained timer itself.
- **Pros**: One fewer Autoload; no cross-system call for the trigger.
- **Cons**: Violates ADR-0012's own framing of `PrestigeSystem` as a synchronous orchestrator invoked at a single entry point, not a per-frame ticking detector. Mixes "detect the condition" with "execute the consequence" in one class, the exact coupling ADR-0012 avoided by keeping `PrestigeSystem` reactive rather than autonomous.
- **Rejection Reason**: Contradicts ADR-0012's stated architecture, and would require reopening the already-shipped, tested `PrestigeSystem` for a change unrelated to its 9 stories' scope.

### Alternative 2: Revert PrestigeSystem's ownership to match the original quick-specs
- **Description**: Move `era_count`/`meta_bonus_totals`/the reset+grant sequence back onto BurnoutSystem, as originally specified.
- **Pros**: Matches the 2026-07-01 quick-specs exactly, zero drift to reconcile.
- **Cons**: The prestige-checkpoint epic is closed — 9 stories, 80 passing tests, all built against `PrestigeSystem` owning this state. Reverting means re-opening a closed epic to undo shipped, reviewed, tested work for a documentation-consistency reason alone.
- **Rejection Reason**: Not realistic given current project state. The quick-specs are the stale artifact here, not the shipped code.

### Alternative 3: ChallengeSystem pushes its multiplier to PrestigeSystem via a signal/event instead of a pull-model getter
- **Description**: `ChallengeSystem` emits a signal on selection confirm; `PrestigeSystem` caches the value for the next grant.
- **Pros**: Decouples the read from the exact call timing.
- **Cons**: Introduces a caching/staleness risk (what if the cached value is read after a *different* era's selection confirmed?) and breaks the "read fresh, synchronous state" pattern ADR-0012's binding constraint depends on. `ClassPathSystem`'s pull-model precedent (ADR-0010 §5a) already solved this exact shape of problem — no reason to solve it differently here.
- **Rejection Reason**: Adds a state-staleness risk class ADR-0012 was specifically designed to avoid, for no benefit over the existing pull-model precedent.

## Consequences

### Positive
- Closes TR-pcs-007, the last open GDD-requirement gap in the tr-registry.
- BurnoutSystem/ChallengeSystem can now go through `/create-stories` → `/dev-story` like every other system in this project — currently blocked by "no ADR exists."
- `PrestigeSystem`'s change surface is exactly one line (`challenge_mult` stub → real call) — lowest-possible-risk integration into an already-shipped, tested Autoload.
- Resolves prestige-checkpoint Story 008's deferred scope: `_card_pending` now has a real owner (BurnoutSystem), unblocking the card-re-presentation-on-boot follow-up test that story explicitly punted.

### Negative
- Two quick-specs now have a documented ownership mismatch against this ADR for the fields listed in the ownership-split table — future readers of the quick-specs alone (without also reading this ADR) will get a stale picture. Mitigated by the GDD Sync section below.
- `BurnoutSystem`'s `_process(delta)` runs every live-play frame — a new per-frame cost, though trivial (one `get_resource()` call, one comparison, occasional signal emit), consistent with the quick-spec's own stated design.

### Risks
- **Risk**: A future implementer reads only the quick-specs (not this ADR) and rebuilds the reset+grant sequence inside BurnoutSystem, duplicating `PrestigeSystem`'s already-shipped logic.
  - **Mitigation**: This ADR's ownership-split table is the authoritative correction; `/dev-story` for any future BurnoutSystem/ChallengeSystem story reads the governing ADR before the quick-spec per the standard skill protocol, so this ADR is read first in practice.
- **Risk**: `DecisionCardSystem.card_resolved`'s `option_chosen` value (`&"accept"`/`&"defer"`) must exactly match whatever string the Wypalenie card's content entry in `CardContentDatabase` actually uses for its two options — a naming mismatch would silently no-op both branches.
  - **Mitigation**: Flagged explicitly as a Validation Criterion below; the implementing story must assert this against the real card content entry, not assume the names in this ADR's pseudocode.
- **Risk**: `inject_priority_card(BURNOUT_CARD_ID)` returns `bool`, not `void` (verified against the shipped Story 002 signature) — a silently-discarded `false` return (unknown `card_id`, or a priority card already pending) would leave `_card_pending` never set to `true` while the trigger condition remains satisfied, soft-locking BurnoutSystem: it can never retry (guarded by `not _card_pending`, which stays `false`) and never routes to `PrestigeSystem`.
  - **Mitigation**: `_try_inject_burnout_card()` (Decision section above) explicitly checks the return value, only sets `_card_pending = true` on success, and `push_error()`s on failure so a `BURNOUT_CARD_ID`/`CardContentDatabase` mismatch is loud, not silent. Added as an explicit Validation Criterion below alongside the `option_chosen` check.
- **Risk**: BurnoutSystem's trigger timer (`_process(delta)`) is fully decoupled from `DecisionCardSystem`'s own cooldown/checking/presenting/resolving cycle. If Cringe has been pinned at 100 for the full `BURNOUT_THRESHOLD` while the player has an unresolved normal card on screen (plausible — "presenting" can persist for real wall-clock time awaiting a tap, especially on mobile), a naive unconditional `inject_priority_card()` call would clobber the in-progress card mid-choice (`present_next_card()` unconditionally overwrites `_presented_card` and re-emits `card_presented`, with no guard against `state == PRESENTING`).
  - **Mitigation**: `_try_inject_burnout_card()` guards on `DecisionCardSystem.state == State.COOLDOWN` before injecting — if the player is mid-cycle on a normal card, injection is skipped and retried every subsequent frame (harmless, since `_cringe_sustained_seconds` is deliberately not reset until injection actually succeeds) until the normal card resolves and `DecisionCardSystem` returns to `COOLDOWN`.
- **Risk**: No documented engine guarantee that Autoload `_process()` calls run in registration order.
  - **Mitigation**: Verified not load-bearing for this design — `BurnoutSystem._process()` only reads `ResourceManager.get_resource(&"Cringe")`, and `ResourceManager._process()` never writes Cringe (only the Sponsor shield timer), so there is no same-frame read-after-write staleness risk regardless of which Autoload's `_process()` runs first.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `design/quick-specs/final-burnout-2026-07-01.md` | Core Rules 1-3 (Trigger, Warning State, Card injection) | BurnoutSystem retains exactly this scope, unchanged from the quick-spec |
| `design/quick-specs/final-burnout-2026-07-01.md` | Core Rules 4-5 (Choice A/B consequences) | Delegated to `PrestigeSystem.on_burnout_accepted()`/`on_burnout_deferred()` (ADR-0012) — BurnoutSystem routes, does not implement |
| `design/quick-specs/challenge-era-runs-2026-07-01.md` | Core Rules 1-4 (Timing, Modifier Application, Storage, Stacking) | ChallengeSystem retains exactly this scope; pull-model getters replace the quick-spec's implicit push assumption |
| `design/quick-specs/challenge-era-runs-2026-07-01.md` | Core Rule 5 (Meta-Bonus Interaction) | `PrestigeSystem`'s one new call site (`ChallengeSystem.get_combined_meta_multiplier()`) closes this — previously stubbed at `1.0` |
| `design/gdd/prestige-checkpoint-system.md` | `challenge_mult` parameter of F1 (`grant_magnitude`) | Real value now sourced from ChallengeSystem instead of a hardcoded stub |

## ⚠️ GDD SYNC REQUIRED

Both quick-specs use terminology this ADR corrects:
- `final-burnout-2026-07-01.md` §4/§6: `BurnoutSystem.serialize_state()`/`restore_state()` persisting `era_count`, `_deferred_this_era` → these fields **stay on `PrestigeSystem`** (ADR-0012, already shipped); BurnoutSystem's own persistence is `_card_pending` only, per this ADR.
- `final-burnout-2026-07-01.md` §4 step 9 / `challenge-era-runs-2026-07-01.md` §1.1: `BurnoutSystem.era_transitioned(new_era, meta_bonus_granted)` → the real signal is **`PrestigeSystem.era_transitioned`** (no arguments; already shipped).
- `challenge-era-runs-2026-07-01.md` §3.1: `HistoryFlagManager.set_flag(...)` → the real shipped method name is **`set_milestone(...)`** (confirmed against `src/core/history_flag_manager.gd` and every prestige-checkpoint story's usage).

Recommend a follow-up documentation pass on both quick-specs (or a superseding note at their top, same pattern as this project uses elsewhere for stale GDD sections) before any story is written against them directly.

## Performance Implications
- **CPU**: BurnoutSystem's `_process(delta)` is O(1) per frame (one resource read, one comparison) — negligible against the project's 16.6ms budget, same class of cost as `ActionSystem`'s existing per-frame progress polling (already-accepted precedent, ADR-0004/ADR-0007).
- **Memory**: `ChallengeSystem`'s `_active_challenge_ids: Array[StringName]` is bounded by `CHALLENGE_MAX_ACTIVE` (3) — trivial.
- **Load Time**: None — no new asset loading, `_CHALLENGE_CATALOGUE` is a static const table (or loaded once from `assets/data/challenges.json` per the quick-spec, out of this ADR's scope to mandate the exact loading mechanism).

## Migration Plan
No migration — both Autoloads are net-new. `PrestigeSystem`'s one-line change (`challenge_mult` stub → real call) has no save-data implications since `challenge_mult` was never persisted, only computed per-call.

## Validation Criteria
- `DecisionCardSystem`'s real Wypalenie card content entry's two option identifiers must be read and confirmed to match `&"accept"`/`&"defer"` (or the implementing story must use whatever the real values are) before `BurnoutSystem._on_card_resolved()` ships — do not assume this ADR's pseudocode names are correct without checking `CardContentDatabase`.
- `BURNOUT_CARD_ID` (`&"final_burnout"`) must be confirmed to match the Wypalenie card's real `id` in `CardContentDatabase` before `BurnoutSystem` ships — a mismatch causes `inject_priority_card()` to return `false` every time, permanently soft-locking the trigger (see Risks). Write a regression test asserting `CardContentDatabase.get_card(BurnoutSystem.BURNOUT_CARD_ID)` resolves to a real entry, same defensive pattern already established for `inject_priority_card()`'s own Story 002 code-review fix.
- `_try_inject_burnout_card()`'s `state == COOLDOWN` guard must be covered by a test simulating "Cringe pinned at 100 while a normal card is PRESENTING" — confirming the Wypalenie card injection is deferred (not dropped, not clobbering the in-progress card) until `DecisionCardSystem` returns to `COOLDOWN`.
- The static zero-`await`/zero-`CONNECT_DEFERRED` check (ADR-0012's own Validation Criteria) must additionally cover `BurnoutSystem._on_card_resolved()` through `PrestigeSystem.on_burnout_accepted()`'s full call graph, since this ADR extends that call chain's entry point.
- `ChallengeSystem.get_combined_meta_multiplier()` returning `1.0` for zero active challenges must be covered by a unit test before `PrestigeSystem`'s call site is wired in (regression risk: a bug here would silently zero out or double every future grant).

## Related Decisions
- ADR-0012: Prestige/Checkpoint System — Autoload Orchestration (this ADR's foundation, unmodified)
- ADR-0010: Class Path System — Autoload, Signal, Multiplier (pull-model getter precedent)
- ADR-0001: Autoload Singleton vs. Event Bus (base pattern)
- `design/quick-specs/final-burnout-2026-07-01.md`, `design/quick-specs/challenge-era-runs-2026-07-01.md` (design anchors, now partially superseded per the GDD Sync section above)
