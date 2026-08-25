# Architecture Review Report

- **Date:** 2026-07-24
- **Engine:** Godot 4.6.3
- **GDDs Reviewed:** 19
- **ADRs Reviewed:** 18 (17 Accepted, 1 Proposed)
- **Mode:** `/architecture-review` full

---

## Scope note

ADR-0001–0017 are Accepted and were validated in prior independent reviews; the
TR registry (v8, 2026-07-22) records 40 TRs covered + the TR-nav/set/dcs/pcs
batch from the 2026-07-22 run. This run's **delta is two changes since that
review**:

1. **ADR-0018** (era-transition scene swap) — new, still Proposed, no TR entry yet.
2. **ADR-0014** — a second revision (2026-07-23) adding a fourth coordinated
   panel (`StaffPanel`).

Everything else is unchanged from the 2026-07-22 PASS.

---

## Traceability Summary

| | Count |
|---|---|
| Existing registry TRs (v8) | 47 — 45 covered, 2 partial (unchanged) |
| New requirement (ADR-0018) | 1 — covered, unregistered before this run |

### New requirement needing a TR-ID (covered; registered by this run)

| Proposed ID | GDD/Spec | Requirement | ADR | Status |
|---|---|---|---|---|
| TR-nav-005 | design/ux/challenge-selection-screen.md | `era_transitioned` drives synchronous scene swap `main.tscn`↔`challenge_selection.tscn`; Confirm sole exit (back-gesture/Esc no-op Android+Web); screen reads `get_last_grant()`/`get_challenge_data()` via pull-model, no signal payload | ADR-0018 | Covered |

### Existing partials (unchanged)

- **TR-cps-007** — path-multiplier offline exclusion. Behaviour correct;
  ADR-0010 lacks an explicit one-line statement of the exclusion. Non-blocking.
- **TR-juice-005** — resolution payoff-text duration clamp. Verify against GDD
  clamp bounds during Story 9-2. Non-blocking.

---

## Coverage Gaps (no ADR)

**None blocking.** One forward gap: Team/Staff Management (Alpha) is `Designed`
but has no dedicated ADR and no TRs. Legitimately pre-implementation, consistent
with how prior runs treated Alpha-tier systems. Flag for when Alpha work starts.

---

## Shipped-code verification (ADR-0018)

ADR-0018 is still **Proposed**, but its full design is **already implemented**
(commit 05d74f5, story 12-2) and matches the ADR exactly:

- `src/ui/action_screen.gd:39` connects `PrestigeSystem.era_transitioned`;
  `:55` swaps to `res://scenes/challenge_selection/challenge_selection.tscn`
  synchronously in the handler.
- `src/ui/challenge_selection.gd`: reads `PrestigeSystem.get_last_grant()`,
  `ChallengeSystem.get_challenge_data()`, `ChallengeSystem.CHALLENGE_MAX_ACTIVE`
  via pull-model in `_ready()`; Confirm calls `select_challenges()` then swaps to
  static `main_scene_path = "res://scenes/main/main.tscn"` (correctly `main.tscn`,
  not `boot.tscn`).
- Back-gesture no-op override (`NOTIFICATION_WM_GO_BACK_REQUEST`) + Web
  `history.pushState`/`popstate` no-op present. `application/config/quit_on_go_back=false`
  set in `project.godot:16`.
- Integration test `tests/integration/challenge/challenge_selection_screen_test.gd`
  covers swap-emit + return path, cap enforcement, `get_last_grant` label match,
  no-bonus state, and confirm-writes-selection → **test COVERED**.

---

## Cross-ADR Conflicts

**None.** ADR-0018 is strictly additive — reuses ADR-0003/ADR-0009 (scene swap
idiom), ADR-0014 (scene-owned coordinator wiring), ADR-0017 (`get_last_grant()`
pull-model query). No new Autoload, no new signal, no payload on `era_transitioned`.
Forbidden pattern (central EventBus) respected. `coordination_state` (ADR-0014)
untouched — the scene swap frees and re-creates it by construction.

ADR-0014's 2026-07-23 StaffPanel revision is also additive: the `PANEL_OPEN`
resolver was never panel-specific, so a fourth panel generalizes with no
architectural change. No conflict.

---

## ADR Dependency Order

ADR-0018 → ADR-0009, ADR-0014, ADR-0017 — all Accepted. No cycle, no unresolved
(Proposed→Proposed) dependency. **ADR-0018 is ready to move Proposed→Accepted.**

---

## GDD Revision Flags

**None** — no GDD assumption contradicts verified engine behaviour. ADR-0018 is
LOW knowledge risk, pre-4.3-stable APIs only.

---

## Engine Compatibility

Clean across all 18 ADRs. ADR-0018 uses `change_scene_to_file()`,
`NOTIFICATION_WM_GO_BACK_REQUEST`, `JavaScriptBridge.eval()` — all stable pre-4.3
patterns. No deprecated / post-cutoff conflicts.

`godot-specialist` already validated ADR-0018 (recorded in the ADR, 2026-07-23):
confirmed synchronous `change_scene_to_file()` + Autoload signal auto-cleanup on
scene free are safe; caught and fixed an earlier draft's
`get_viewport().set_input_as_handled()` no-op (that notification has no "handled"
flag) and its misattribution to ADR-0009. No re-spawn needed this run — the
consultation exists and is documented.

Standing watch item (inherited, non-blocking): first *round-trip* use of the
deferred-swap pattern (main → challenge_selection → main). Neither handler reads
scene state after the call, so deferred-swap semantics are inherited-safe. Confirm
mid-session era transition on a real device before production (ADR-0018 Validation
Criteria, Sprint 12 story 12-3).

---

## Findings (non-blocking)

1. **Process — code shipped ahead of ADR acceptance.** ADR-0018's Blocks clause
   states "12-2 cannot start until this is Accepted," but 12-2 (commit 05d74f5)
   shipped while the ADR is still Proposed. The code is accurate to the ADR.
   Remedy: **accept ADR-0018** — no code change required.

2. **Doc hygiene — TR-nav-004 stale.** Registry text lists close-buttons for
   "ClassPathPanel/SettingsScreen/BonusesPanel" (3 panels). ADR-0014's 2026-07-23
   revision added a fourth (StaffPanel). Text should read four panels.

3. **systems-index row 14** — Main Navigation still `In Review` though
   design-complete and ADR-0014-backed (twice-revised). Consider flipping status.

---

## Verdict: PASS

ADR-0018's requirement is covered and accurate to shipped code, zero cross-ADR
conflicts, engine-clean, all dependencies Accepted. Remaining items are
documentation hygiene and status-process, not blockers.

### Blocking issues
None.

### Recommended next actions
1. **Accept ADR-0018** (all dependencies satisfied, code already matches).
2. Update TR-nav-004 registry text to four panels; consider flipping
   systems-index row 14 out of `In Review`.
3. Team/Staff Management: author its ADR + TRs when Alpha implementation begins.
