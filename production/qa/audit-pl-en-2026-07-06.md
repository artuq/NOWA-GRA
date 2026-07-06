# Polish→English Content Audit — Player-Facing Strings

**Date**: 2026-07-06 (Sprint 9, story 9-4 — carried from Sprint 6 retro AI #3)
**Scope**: every player-visible string in `src/` and `scenes/` (UI language is English per user decision 2026-06-25)

## Method

1. Diacritics sweep: `grep [ąćęłńśźżĄĆĘŁŃŚŹŻ]` across `src/` + `scenes/` (code, string literals, scene text properties)
2. Undiacriticized-Polish sweep: common Polish word stems (Zrob/Nagraj/Przepro/Wydaj/Udziel/Zasiegi/Sponsorzy/Hatersi/Wypalenie/...) in string literals
3. Scene `text =` property listing (all .tscn)
4. Spot review of every string-producing UI file (toasts, tooltips, fallbacks, formatters)

## Findings

| Category | Result |
|---|---|
| String literals in .gd (labels, toasts, tooltips, fallbacks) | **CLEAN** — all English (action display names, card content incl. all resolution_reactions, HUD labels, lock toasts, offline report, class path badge, Option A/B fallbacks) |
| Scene text properties (.tscn placeholders) | 1 stale item **FIXED**: `class_path_hud_indicator.tscn` placeholder "Pato-Streamer T1" → "Trash Streamer T1" (design-time only — runtime always overwrites; consistency fix) |
| Polish diacritics anywhere in src/scenes | Only in `##` code comments (6 files) — developer-facing, NOT in audit scope, no action |
| Internal identifiers (action ids `zrob_drame`, path ids `pato_streamer`, counter names) | Polish-derived by convention, intentionally retained — never player-visible (per [[class-path-display-names]] decision pattern) |
| GDD/design doc prose | Mixed PL/EN — internal documentation, out of scope for player-facing audit |

## Verdict: **PASS** — player-facing surface is 100% English (1 cosmetic fix applied)

The recurring retro item ("schedule a deliberate PL→EN pass") is hereby closed: the incremental
per-story English discipline since 2026-06-25 (card content authoring, display-name decisions,
HUD work) already converged the player-facing surface. No follow-up story needed.
