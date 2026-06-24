# Story 001: Number Formatting & Progress Bar Math

> **Epic**: Action UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: S (1-2h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-24

## Context

**GDD**: `design/gdd/action-ui.md`
**Requirement**: `TR-aui-001` (progress bar polling contract) plus the GDD's Number Formatting and Progress Bar Fill sections, neither of which has a dedicated TR-ID yet (registry-completeness gap noted in EPIC.md — not blocking)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: N/A — pure utility functions, no architectural pattern decision required. (ADR-0007 establishes that these *must* be extractable static functions, following the `ResourceFormulas` precedent, but the math itself is GDD-specified, not architecture-specified.)
**ADR Decision Summary**: ADR-0007 requires number-formatting and fill_ratio calculation to be extracted into pure static functions BEFORE being wired into any Control node — this is what makes them unit-testable without a scene tree.

**Engine**: Godot 4.6.3 | **Risk**: LOW — pure GDScript math/string functions, no engine-specific API risk
**Engine Notes**: None required.

**Control Manifest Rules (this layer)**:
- Required: PascalCase class name, snake_case file name (global convention)
- Forbidden: None layer-specific yet (Presentation layer has no Accepted ADRs covering it beyond ADR-0007)
- Guardrail: None yet

---

## Acceptance Criteria

*From GDD `design/gdd/action-ui.md`, scoped to this story:*

**Number formatting (boundaries):**
- [ ] 847 → `"847"`
- [ ] 999 → `"999"`
- [ ] 1,000 → `"1.0K"` (inclusive lower bound)
- [ ] 28,412 → `"28.4K"`
- [ ] 999,999 → `"999.9K"`
- [ ] 1,000,000 → `"1.0M"` (hard boundary)
- [x] 1,250,000 → `"1.2M"` (**CORRECTED 2026-06-24** — was `"1.3M"`; the GDD's own rounding rule and this example were mutually inconsistent, see Implementation Notes below; truncation resolved, real measured behavior is `"1.2M"`)

**Progress bar fill_ratio:**
- [ ] elapsed_time=0, duration=D>0 → fill_ratio=0, no flicker
- [ ] 0<elapsed_time<duration → fill_ratio=clamp(E/D, 0, 1)
- [ ] elapsed_time≥duration → fill_ratio=1 (clamped)

**Defined edge cases:**
- [ ] A negative Zasięgi/Sponsorzy value, when formatted, displays as-is — no UI-layer clamping (do not add a defensive clamp not in the spec)

---

## Implementation Notes

*Derived from ADR-0007's Implementation Guidelines:*

Create a new static utility class, `res://src/ui/action_ui_formatting.gd`, `class_name ActionUIFormatting`, following the exact precedent of `res://src/core/resource_formulas.gd` (`ResourceFormulas`) — stateless, static functions only, no instance vars. Two functions:

- `format_number(value: float) -> String` — implements the K/M abbreviation rule above. The 1,000 and 1,000,000 boundaries are **inclusive lower bounds** (1000 exactly → "1.0K", not "1000"; 1,000,000 exactly → "1.0M", not "1000.0K") — these are the two test cases most likely to have an off-by-one error.
- `fill_ratio(elapsed_time: float, duration: float) -> float` — implements `clamp(elapsed_time / duration, 0.0, 1.0)`. Note `duration=0` is explicitly out of scope (Action System's own invariant says this "should not occur" — testing it would require violating that contract, not asserting this GDD's behavior; do not add a defensive guard for it here).

This story produces no scene, no Control node, no visual output — it is purely the two static functions plus their test file. Stories 002-004 call these functions from their respective Control scripts.

**Performance**: O(1) pure arithmetic/string formatting, negligible even called every frame from Story 004's `_process()` loop — no profiling required at this scale.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002 (Resource HUD): calls `format_number()` to render resource values — does not implement the formatting logic itself
- Story 003 (Action Grid): calls `format_number()` for button reward labels
- Story 004 (Running Action Overlay): calls `fill_ratio()` for the progress bar and `format_number()`-adjacent time-remaining display (note: GDD doesn't specify a separate time-formatting rule beyond what's listed here — if Story 004 needs one, it should use plain integer seconds unless a new rule is specified)

---

## QA Test Cases

*Test specs reused from `production/qa/qa-plan-sprint-6-2026-06-24.md` (written 2026-06-24, before this story existed).*

- **AC: Number formatting boundaries**
  - Given: each of the 7 listed input values (847, 999, 1000, 28412, 999999, 1000000, 1250000)
  - When: `ActionUIFormatting.format_number(value)` is called
  - Then: output matches exactly (`"847"`, `"999"`, `"1.0K"`, `"28.4K"`, `"999.9K"`, `"1.0M"`, `"1.2M"` — corrected from the GDD's stated `"1.3M"`, see Implementation Notes)
  - Edge cases: the 1,000 and 1,000,000 boundaries specifically — these inclusive-lower-bound transitions are the highest off-by-one risk

- **AC: Progress bar fill_ratio**
  - Given: elapsed_time=0, duration=10 (positive, nonzero)
  - When: `ActionUIFormatting.fill_ratio(0, 10)` is called
  - Then: returns exactly 0.0
  - Edge cases: elapsed_time=duration (exactly 1.0, boundary inclusive), elapsed_time>duration (clamped to 1.0, not >1.0)

- **AC: Negative value formatting**
  - Given: a negative number (e.g. -50)
  - When: `ActionUIFormatting.format_number(-50)` is called
  - Then: returns `"-50"` as-is — no clamping to 0, no special negative-number K/M abbreviation logic beyond what the positive-number rules already imply

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/action_ui/action_ui_formatting_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 002 (Resource HUD), Story 003 (Action Grid), Story 004 (Running Action Overlay) — all three call this story's functions

---

## Completion Notes
**Completed**: 2026-06-24
**Criteria**: 11/11 passing (none deferred)
**Deviations**: 1 advisory, fully documented in 3 places (this file, `design/gdd/action-ui.md`, `src/ui/action_ui_formatting.gd`'s doc comments) — GDD's own rounding rule contradicted its own examples; resolved to truncation; `1,250,000` formats as `"1.2M"`, not the GDD's originally-stated `"1.3M"`
**Test Evidence**: Logic — `tests/unit/action_ui/action_ui_formatting_test.gd`, 13/13 passing (full regression 181/181 passing)
**Code Review**: Complete — `/code-review` APPROVED (engine specialist CLEAN; qa-tester found 3 real coverage/traceability gaps, all fixed before this closure)
