# ADR-0015: Settings System — Autoload Shape and `reduce_motion` Ownership (Retrofit)

## Status
Accepted (2026-07-22, following independent `/architecture-review` in a fresh session — verdict PASS, shipped-code claims re-verified against `settings_system.gd:21-58` line-by-line, no conflicts. TR-set-001 registered, tr-registry.yaml v7→v8.)

## Date
2026-07-22

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | Core / Foundation |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/architecture/adr-0001-autoload-singleton-vs-event-bus.md` (Autoload pattern this retrofit documents an instance of) |
| **Post-Cutoff APIs Used** | None — `extends Node` Autoload with a plain `bool` field and a public setter, no engine API beyond the stable Autoload registration mechanism |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted — Autoload singleton pattern this module already follows), ADR-0003 (Accepted — `BootController`'s `restore_state()` call order, which `SettingsSystem` already participates in) |
| **Enables** | Formal ADR coverage for `docs/architecture/adr-0014-main-navigation-coordinator.md`'s dependency on `SettingsScreen`/`SettingsSystem`; closes the traceability gap flagged in `architecture.md` v2's ADR Audit |
| **Blocks** | Nothing — `SettingsSystem` is already shipped and in production use; this ADR is documentation, not a design change |
| **Ordering Note** | None |

## Context

### Problem Statement

`src/core/settings_system.gd` has been shipped and working since the Reduce Motion accessibility feature landed, but no ADR was ever written for it — a real traceability gap (`architecture.md` v2's ADR Audit flagged this explicitly: 0/2 requirement groups covered for Settings System, alongside Main Navigation). Both `SettingsScreen` (existing UI) and the newly-drafted `MainNavCoordinator` (ADR-0014) depend on `SettingsSystem`'s contract — this ADR retroactively documents the shape already in production so future readers of `architecture.md`'s Module Ownership table have a real ADR to cite, not a gap.

### Constraints

- This ADR must describe the shipped code accurately — it is not proposing a change. Any discrepancy between this ADR and `settings_system.gd`'s actual behavior is a bug in the ADR, not a to-be-implemented delta.
- `reduce_motion` is the only field today. This ADR documents the one-field shape as it exists — it does not pre-design a multi-setting future that has no current requirement (YAGNI, per `coding-standards.md`).
- UI must never mutate `reduce_motion` directly — the established "UI displays state, does not own it" convention (matches `ActionSystem.start_action()` being the sole write path for its own state).

### Requirements

- `reduce_motion: bool` must persist across sessions via `SaveSystem`.
- Exactly one write path (`set_reduce_motion()`); reads go directly to the public field.
- Must restore correctly in `BootController`'s dependency-ordered `restore_state()` pass (ADR-0003).
- Default value (`false`, motion effects at full strength) must match the "first-session default" convention every other peer Autoload uses (e.g., `HistoryFlagManager`'s empty counters).

## Decision

`SettingsSystem` is a plain Autoload singleton (`extends Node`), identical in shape to `OnboardingGate` (already the ADR-0001-registered precedent for "simple peer-module Autoload, no signal, no complex state machine"). It owns a single field, `reduce_motion: bool`, defaulting to `false`.

### Architecture Diagram

```
SettingsSystem (Autoload, extends Node)
  var reduce_motion: bool = false

  func set_reduce_motion(value: bool) -> void:
    reduce_motion = value
    SaveSystem.mark_dirty()          # sole write path

  func serialize_state() -> Dictionary
  func restore_state(data: Dictionary) -> void   # called by BootController, ADR-0003 order

Readers (no write access):
  SettingsScreen  -- toggle UI, calls set_reduce_motion() on user interaction, reads
                     SettingsSystem.reduce_motion directly on _on_visibility_changed()
  CardScreen      -- reads reduce_motion at resolution time to gate shake amplitude/duration
                     (art-bible.md §7 MANDATE — scale-pulse/flash/stinger unaffected)
  (planned) MainNavCoordinator (ADR-0014) -- panel fade-duration gating under Reduce Motion
```

### Key Interfaces

```gdscript
# SettingsSystem (Autoload) — as shipped, src/core/settings_system.gd
var reduce_motion: bool = false
func set_reduce_motion(value: bool) -> void   # sole write path; marks SaveSystem dirty
func serialize_state() -> Dictionary
func restore_state(data: Dictionary) -> void
# Invariant: reduce_motion is read directly (var access), never through a getter method —
# matches HistoryFlagManager.get_counter()'s "reads free, writes gated" split precedent,
# except here even the read has no wrapper method at all (simplest case: one bool, no
# derived computation needed on read, unlike get_counter()'s aggregation)
```

## Alternatives Considered

### Alternative 1: Fold `reduce_motion` into `SaveSystem` directly, no dedicated module
- **Description**: `SaveSystem` owns the flag as one more field in its save blob, with a free function or a global `Engine`-level flag for reads.
- **Pros**: One fewer Autoload.
- **Cons**: Breaks the "every module owning persisted state implements `restore_state()`/`serialize_state()`" convention (registered `api_decision`, ADR-0003) — `SaveSystem` would become a special case that also *owns* gameplay-adjacent state instead of only serializing other modules' state. No clear sole-write-path enforcement without inventing one anyway.
- **Rejection Reason**: Violates the established ownership separation between "state owner" and "serialization mechanism" that every other Core/Foundation module already follows.

### Alternative 2: General-purpose `Settings` Autoload sized for future toggles
- **Description**: Design a `Dictionary`-backed or resource-backed settings store now, anticipating future accessibility/audio/gameplay toggles.
- **Pros**: Would not need a second migration if more settings appear later.
- **Cons**: No current requirement beyond `reduce_motion` — speculative generality with no GDD backing it (`coding-standards.md`'s "no half-finished implementations," `architecture.md` Principle 3 spirit). A `Dictionary`-backed store also loses static typing on individual settings.
- **Rejection Reason**: YAGNI — this ADR documents what exists; a future settings-expansion ADR can supersede this one if/when a second toggle is actually designed.

## Consequences

### Positive
- Closes a real traceability gap without touching any shipped code — pure documentation-of-record.
- Establishes the citable precedent ("same shape as `OnboardingGate`") that future single-flag Autoloads can point to instead of re-deriving the pattern.

### Negative
- None — no code change, no new risk introduced.

### Risks
- If `reduce_motion` grows into multiple settings later, this ADR's "one field, no wrapper read" shape will need a follow-up ADR (Alternative 2's rejected design becomes worth revisiting at that point, not before).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| (no dedicated GDD — `design/art/art-bible.md` §7 MANDATE) | Reduce Motion must gate shake amplitude/duration; scale-pulse/flash/stinger explicitly unaffected | `reduce_motion: bool`, read directly by `CardScreen`/`FeedbackMath` call sites at resolution time |
| main-navigation-screen-flow.md | Visual/Audio Requirements — panel fade shortens to near-instant under Reduce Motion | `MainNavCoordinator` (ADR-0014, planned) reads `SettingsSystem.reduce_motion` directly, same read-path convention |

## Performance Implications
- **CPU**: None — a single boolean field read.
- **Memory**: Negligible.
- **Load Time**: None.
- **Network**: N/A.

## Migration Plan

None — this ADR documents already-shipped code. No files change as a result of writing it.

## Validation Criteria

Cross-checked against `src/core/settings_system.gd` line-by-line during authoring; any future change to that file that contradicts this ADR's Key Interfaces should trigger either a code fix or an ADR revision, not silent drift.

## Related Decisions
- ADR-0001 (Autoload singleton pattern — the shape this ADR retroactively documents an instance of)
- ADR-0003 (boot restore order — `SettingsSystem.restore_state()` participates in this sequence)
- ADR-0014 (Main Navigation Coordinator — a new, planned consumer of this contract)
- `design/art/art-bible.md` §7 (the MANDATE this field satisfies)
