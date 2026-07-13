# Story 005: Class Path Panel — Investment & Ambiguity UI

> **Epic**: Class Path System (Full)
> **Status**: Ready
> **Layer**: Core
> **Type**: UI
> **Estimate**: L (4h+, consider splitting if the panel's full 4-path layout takes longer)
> **Manifest Version**: 2026-06-20
> **Last Updated**:

## Context

**GDD**: `design/gdd/class-path-system.md`
**Requirement**: UI Requirements section + UI Acceptance Criteria (no dedicated TR-ID — UI surface for TR-cps-008/009)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 §8 (Investment API), §9 (Ambiguity query) — secondary references, not primary architectural decisions for this story (this is a Control-node UI story, low architectural risk, per the project's Presentation-layer convention of implementing directly against the GDD without a dedicated UI ADR)
**ADR Decision Summary**: `invest(path_id, resource_id, amount) -> bool` and `get_ambiguous_gap() -> float` are the query/command surface this UI calls. No new architectural pattern — standard Button/Label Control-node wiring against existing ClassPathSystem queries, same shape as the existing HUD indicator (Story 002 of the MVP epic).

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: None post-cutoff.

**Control Manifest Rules (this layer)**:
- Required: large touch-target Buttons (per `technical-preferences.md` Platform Notes — no `TouchScreenButton`, standard `Button` nodes only)
- Forbidden: hover-only interactions (no hover-only state may gate functionality — mouse-emulated touch must work identically)
- Guardrail: n/a — this is event-driven UI, no `_process()` needed (same discipline as `action_grid.gd`'s header comment)

---

## Acceptance Criteria

*From GDD `design/gdd/class-path-system.md` §UI, scoped to this story:*

- [ ] GIVEN the active path is ambiguous, WHEN the player opens the Class Path Panel, THEN both tied paths' cards show "Ambiguous — keep investing to commit." with the numeric gap remaining (via `get_ambiguous_gap()`), and neither shows an active-tier multiplier
- [ ] GIVEN all four paths exist with varying (including zero) affiliation, WHEN the Class Path Panel opens, THEN all four are visible and legible — none hidden (Core Rule 1)
- [ ] GIVEN no path has reached Tier 1, THEN the HUD indicator is absent. GIVEN a path reaches Tier 1, THEN the HUD indicator appears with tier badge + path name (already implemented for 2 paths in the MVP epic's Story 002 — this AC confirms it still holds for all 4)
- [ ] GIVEN a path has `card_contribution == 0`, WHEN the player views that path's Invest control, THEN it renders visually disabled with an explanatory label (e.g. "Make a [Path] choice first"), not merely non-functional
- [ ] GIVEN any path/tier state, THEN no UI string in the Class Path Panel or HUD contains "dobry"/"zły"/"good"/"evil"/"moral" or an equivalent (Anti-Pillar, Core Rule 8 — text-audit walkthrough)

---

## Implementation Notes

Reads-only against `ClassPathSystem`'s existing query surface — this story adds no new ClassPathSystem API beyond what Stories 002/003 already expose (`invest()`, `get_ambiguous_gap()`, `get_affiliation()`, `get_tier()`, `get_active_path()`). The Invest button's `pressed` signal calls `ClassPathSystem.invest(path_id, resource_id, amount)` directly (same "Button wired directly to Autoload" pattern as `action_grid.gd`'s unlocked slots — no intermediate signal layer needed).

Disabled-state rendering: check `ClassPathSystem.get_affiliation(path_id)`'s card-contribution component is `> 0` before enabling the Invest button (this requires the query surface to expose the F1 term separately, or a dedicated `can_invest(path_id) -> bool` helper — confirm with whoever implements Story 002 whether such a query already exists or needs adding as a small additive method during that story).

Per Core Rule 8 (no explicit moral score), affiliation renders as a neutral progress bar labeled with tier names — never framed as "good"/"evil."

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the `invest()` gate logic itself (this story only renders its result)
- Story 003: the tie-break computation itself (this story only renders `get_ambiguous_gap()`'s output)
- Story 004: signature card unlock toast (a nice-to-have addition to this panel, not required for this story's DoD — flag as a follow-up if time allows)

---

## QA Test Cases

**UI — manual verification steps:**

- **AC-1 (ambiguous state display)**:
  - Setup: force two paths into an ambiguous tie via debug console (both Tier 1+, affiliation within margin)
  - Verify: both cards show "Ambiguous — keep investing to commit." with the correct numeric gap; neither shows a multiplier
  - Pass condition: text matches exactly, gap number matches `get_ambiguous_gap()`'s return value

- **AC-2 (all 4 paths visible)**:
  - Setup: fresh game, no path progress
  - Verify: Class Path Panel shows all 4 path cards simultaneously, all legible (no clipping/overlap — this is the same class of bug just found in `action_grid.gd`, verify carefully)
  - Pass condition: all 4 names, taglines, and progress bars readable at default window size and at the narrowest supported web viewport

- **AC-3 (HUD indicator presence)**:
  - Setup: progress a path to just below Tier 1, then past it
  - Verify: HUD indicator absent below Tier 1, appears with correct tier badge + path name at Tier 1+
  - Pass condition: matches MVP epic's Story 002 behavior, now confirmed across all 4 paths

- **AC-4 (disabled Invest control)**:
  - Setup: a path with zero card-tagged choices this era
  - Verify: Invest button renders visually disabled (not just non-functional) with explanatory label
  - Pass condition: disabled state is visually distinguishable from enabled at a glance, label text is readable

- **AC-5 (no moral-framing text)**:
  - Setup: text audit — grep all Class Path Panel / HUD strings
  - Verify: no occurrence of "dobry"/"zły"/"good"/"evil"/"moral" or equivalent
  - Pass condition: zero matches

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/class-path-panel-evidence.md` — manual walkthrough doc, ADVISORY gate

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (Investment gate must exist to render), Story 003 (`get_ambiguous_gap()` must exist to render)
- Unlocks: None
