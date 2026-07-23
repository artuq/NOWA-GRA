# Consistency Check Report

**Date**: 2026-07-23
**Registry**: `design/registry/entities.yaml` — 5 resources, 12 cards, 3 counters, 25 formulas, 4 meta-bonus types, 4 class paths, 40 constants
**GDDs scanned**: 17 (all of `design/gdd/*.md` excluding `game-concept.md`, `systems-index.md`, `game-pillars.md`)

---

## Conflicts Found

None. 🔴 0 conflicts.

Every registered formula/constant that appears in more than one GDD was checked
in context (`CARD_CONTRIBUTION_MAX`, `action_zasiegi_base`, `hire_cost`,
`simulate_offline`, `META_SPONSOR_MULT`/`META_HATERS_RESIST`/`META_SPONSOR_FLOOR`,
`H_base`/`H_exp`/`H_max_add`/`N_buffer`/`M_drain_per_hater`/`M_drain_exp`/`Z_per_hater`).
All cross-references are consistent, pass-through mentions (no GDD redefines a
value already owned by another) — the two largest cross-doc integrations added
this session (Team/Staff Management's `hire_cost()` resolving the Sponsor
zero-sink question, and Cosmetic Persona Customization's `HistoryFlagManager`
milestone read) both hold up against their source GDDs.

## Stale Registry Entries (referenced_by lists behind actual usage)

None blocking, but `referenced_by` is under-populated for several entries — the
name appears in a GDD that isn't listed:

⚠️ `Reach` — registry lists only `card-content-database.md`; also appears in
`class-path-system.md` and `prestige-checkpoint-system.md` (both use it as a
reward/investment-resource reference, no redefinition).

⚠️ `affiliation` — registry lists none; appears in `prestige-checkpoint-system.md`
and `team-staff-management.md` in addition to source `class-path-system.md`.

⚠️ `pato_streamer` / `guru_celebryta` / `ekspert_niszowy` / `biznesmen_contentu` —
registry lists none for any of the 4 class paths; all four now also appear in
`cosmetic-persona-customization.md` and `prestige-checkpoint-system.md`.

⚠️ `simulate_offline` — registry lists none; appears in `offline-report-screen.md`,
`prestige-checkpoint-system.md`, and `team-staff-management.md` as pass-through
references, in addition to source `offline-progress-system.md`.

⚠️ `hire_cost`, `action_zasiegi_base`, `CARD_CONTRIBUTION_MAX` — each has one
additional cross-reference beyond what's currently listed (see grep hits below).

These are bookkeeping gaps, not design conflicts — every value checked out.

## Unverifiable References (informational)

~35 registered formula/constant names (e.g. `class_path_tier`,
`meta_bonus_grant_magnitude`, all `MAX_MULTIPLIER_*`/`STAFF_HALF_POINT_*`/
`HIRE_BASE_COST_*`/`HIRE_COST_GROWTH_*` per-type constants) don't appear as
literal identifier strings in GDD prose — expected, since GDDs describe
mechanics in Polish/English prose and only sometimes spell out the exact
snake_case symbol. No conflict possible without a comparable attribute stated.

## Clean Entries

All 5 resources, all 12 cards, all 3 counters, and every multi-file formula/
constant checked verified consistent across GDDs.

---

**Verdict: PASS**
