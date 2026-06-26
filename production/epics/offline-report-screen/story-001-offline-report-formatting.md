# Story 001: Offline Report Formatting

> **Epic**: Offline Report Screen (+ Boot Flow)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: S (1-2h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-26

## Context

**GDD**: `design/gdd/offline-report-screen.md`
**Requirement**: `TR-ors-001` — Offline simulation result presentation screen with dismiss gesture (this story implements its one genuine display derivation, `format_duration`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009: Offline Report Screen — scene, transient hand-off, dismiss
**ADR Decision Summary**: `format_duration(elapsed_seconds) -> String` lives in a stateless static utility `OfflineReportFormatting` (`res://src/ui/offline_report_formatting.gd`, `class_name OfflineReportFormatting`), headlessly unit-testable against the GDD's exact ACs — same precedent as `CardSwipeMath` / `ResourceFormulas` / `ActionUIFormatting`.

**Engine**: Godot 4.6.3 | **Risk**: LOW — pure GDScript integer math, no engine-specific API
**Engine Notes**: None — no post-cutoff APIs.

**Control Manifest Rules (this layer — Presentation)**:
- Required: PascalCase `class_name` (`OfflineReportFormatting`), snake_case file name; stateless static utility (no instance vars, ever — same invariant as the sibling formatting/formula utilities)
- Forbidden: any scene/Autoload dependency in this class — pure function of its argument
- Guardrail: O(1) per call, negligible

---

## Acceptance Criteria

*From GDD `design/gdd/offline-report-screen.md` Formulas + Acceptance Criteria (`format_duration` block), scoped to this story:*

`format_duration(elapsed_seconds: int) -> String` = pick the largest unit U ∈ {hours, minutes} where `Δt ≥ U.seconds`, floor, render `"N unit(s)"` (no "days"; capped context is 24h):

- [ ] Δt=300 → "5 minutes"
- [ ] Δt=3599 → "59 minutes" (just under 1 hour, still minutes)
- [ ] Δt=3600 → "1 hour" (singular, exact hour boundary)
- [ ] Δt=3601 → "1 hour" (single-unit, no remainder shown)
- [ ] Δt=85620 → "23 hours"
- [ ] Δt=86400 → "24 hours" (max cap — never "1 day", never "1440 minutes")
- [ ] Singular/plural correct: 1 → "minute"/"hour", >1 → "minutes"/"hours" (e.g. Δt=60 → "1 minute", Δt=120 → "2 minutes")

---

## Implementation Notes

*Derived from ADR-0009 Decision §4:*

Create `res://src/ui/offline_report_formatting.gd`, `class_name OfflineReportFormatting`, `extends RefCounted`, stateless — exactly the shape of `src/ui/action_ui_formatting.gd`. One static function:

```gdscript
class_name OfflineReportFormatting
extends RefCounted

const SECONDS_PER_HOUR: int = 3600
const SECONDS_PER_MINUTE: int = 60

## Largest whole unit (hours, else minutes), floored, with correct pluralisation.
## No "days" tier — offline is capped at 24h (MAX_OFFLINE_CAP_SECONDS), so the
## max output is "24 hours". Single-unit only: no "1 hour 5 minutes" remainder.
static func format_duration(elapsed_seconds: int) -> String:
    if elapsed_seconds >= SECONDS_PER_HOUR:
        var hours: int = elapsed_seconds / SECONDS_PER_HOUR  # int division floors
        return "%d %s" % [hours, "hour" if hours == 1 else "hours"]
    var minutes: int = elapsed_seconds / SECONDS_PER_MINUTE
    return "%d %s" % [minutes, "minute" if minutes == 1 else "minutes"]
```

Note: integer division floors naturally (3601/3600 = 1 → "1 hour"; 3599/60 = 59 → "59 minutes"). The caller's contract guarantees `elapsed_seconds ∈ [300, 86400]` (gated by the threshold and the cap), so no sub-minute or over-cap handling is needed — same trust-the-caller stance as the sibling utilities. Do NOT reuse this for the headline number — that's `ActionUIFormatting.format_number` (the K/M convention).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002 (Offline Report Screen): the scene, reading `last_simulation_result`, the headline number format (`ActionUIFormatting.format_number`), ΔHaters/Morale/capped rendering, dismiss — this story only provides the duration string
- Story 003 (Boot Flow): the threshold gate, `simulate_offline` wiring — this util is threshold-agnostic

---

## QA Test Cases

*Automated unit-test specs, from the GDD's exact `format_duration` ACs.*

- **AC: format_duration boundaries and pluralisation**
  - Given: each `elapsed_seconds` value from the ACs above
  - When: `OfflineReportFormatting.format_duration(elapsed_seconds)` is called
  - Then: the returned String matches exactly
  - Edge cases: the unit-switch boundary (3599 → "59 minutes" vs 3600 → "1 hour"), the no-remainder rule (3601 → "1 hour", not "1 hour 1 second"), the cap (86400 → "24 hours", never "1 day"), and singular vs plural (60 → "1 minute", 3600 → "1 hour")

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/offline_report/offline_report_formatting_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 002 (Offline Report Screen) — uses `format_duration` for the duration line

---

## Completion Notes
**Completed**: 2026-06-26
**Criteria**: all passing (9 unit tests, one per GDD duration AC + pluralisation)
**Deviations**: None
**Test Evidence**: Logic — `tests/unit/offline_report/offline_report_formatting_test.gd`, 9/9 passing (full regression 249/249)
**Code Review**: Complete — godot-gdscript-specialist verdict CLEAN (fully typed, int-division flooring correct for the non-negative trusted range, unit-switch boundary precise, tests map 1:1 to ACs)
