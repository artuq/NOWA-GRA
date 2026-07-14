# QA Evidence: Story class-path-full/005 — Class Path Panel (Investment & Ambiguity UI)

**STATUS: EXECUTED — scene_runner()-verified, 2026-07-14.**

**Story reference**: `production/epics/class-path-full/story-005-class-path-panel-investment-ui.md`
**Story Type**: UI (Test Evidence tier: ADVISORY — manual walkthrough doc)

---

## Method note (read before the checklist)

This agent session has no way to actually look at a running Godot scene. Per this
project's standing precedent for UI-type stories
(`docs/tech-debt-register.md`, 2026-06-24 entry, "Action UI, Story 002"), the
evidence below is produced via GdUnit4's `scene_runner()` — headless
instantiation of the real `.tscn` files plus assertions on rendered node
state (text, `disabled`, `visible`, `ProgressBar.value`) — **not** a human
visual pass. This confirms the scene's structural/behavioral correctness
(right text in the right node at the right state) but does **not** confirm
layout legibility, spacing, contrast, or scroll-feel at a real mobile
viewport. A physical/emulator visual pass is still recommended before this
ships, same caveat `story-class-path-hud-evidence.md` flagged for AC-6 on
the HUD indicator.

Automated coverage: `tests/integration/class-path/class_path_panel_interaction_test.gd`
(10 test cases, all PASSED — see full-suite run below).

---

## Test Checklist

*One entry per this story's 5 acceptance criteria.*

- [x] **AC-1 — Ambiguous state shows numeric gap, no active multiplier on either tied path**
  - Setup: seeded `pato_streamer` = 45.0 (T2), `guru_celebryta` = 42.0 (T2) via the real
    `ClassPathSystem` Autoload — diff 3.0 < the 5.0 tie-break margin, so `get_active_path()`
    resolves to `&""` and `get_ambiguous_gap()` returns `3.0`.
  - Verify: both `Row1StatusLabel` (pato_streamer) and `Row2StatusLabel` (guru_celebryta)
    read exactly `"Ambiguous — keep investing to commit. (gap: 3.0)"`; neither status string
    contains "Active"; the two Tier-0 rows (ekspert_niszowy/biznesmen_contentu) show no
    ambiguous text.
  - Pass condition: text matches exactly, gap number matches `get_ambiguous_gap()`'s live
    return value.
  - Result: PASS — `test_ambiguous_state_shows_gap_on_both_tied_paths`.
  - Also covered (resolved, non-ambiguous contrast case): `test_resolved_active_path_shows_active_status_not_ambiguous`
    confirms the active path shows `"Active — Tier 2 bonus in effect"` and the non-tied
    secondary path shows `"Tier 1 (secondary — bonus inactive while another path is active)"`.

- [x] **AC-2 — All 4 paths visible simultaneously, none hidden**
  - Setup: fresh panel, no path progress.
  - Verify: all 4 rows' name/tier/affiliation-bar nodes exist and are non-null; all 4 display
    names read correctly ("Trash Streamer", "Guru Celeb", "Niche Expert", "Content Mogul");
    a zero-affiliation path (`Row4`, Content Mogul) is `visible == true` with bar value 0.0,
    not hidden.
  - Pass condition: all 4 names/tiers/bars present and legible (structurally — see Method
    note above re: no human visual pass) at scene load.
  - Result: PASS — `test_panel_shows_all_four_paths_simultaneously_and_legible`,
    `test_panel_shows_zero_affiliation_path_not_hidden`.
  - **Known gap, not required by this AC's exact wording**: the quick-spec mockup's Polish
    taglines (e.g. "Chaos to content. Hejt to zasięg.") are not rendered — no English
    equivalent copy exists anywhere in the codebase, and authoring new narrative flavor text
    is out of scope for this UI-implementation story (same category of GDD-vs-implementation
    content gap as the existing `card_screen.gd` category-icon entry in
    `docs/tech-debt-register.md`). Flagged for a future content-authoring pass, not silently
    dropped.

- [x] **AC-3 — HUD indicator absent before Tier 1, present after, for all 4 paths**
  - Setup: for each of the 4 paths in turn, reset era state, confirm the real
    `class_path_hud_indicator.tscn` is hidden, seed that path to Tier 1 (affiliation 20.0),
    confirm the indicator becomes visible.
  - Verify: `ClassPathHudIndicator.gd` itself was NOT modified by this story (per its own
    AC-3 wording, "don't rebuild it") — this test only re-confirms the existing Story
    class-path/002 behavior now holds across all 4 registered paths, not just the original
    MVP's 2.
  - Pass condition: hidden at Tier 0, visible at Tier 1+, for every path.
  - Result: PASS — `test_hud_indicator_absent_before_tier1_present_after_for_all_four_paths`.

- [x] **AC-4 — Disabled Invest control with explanatory label when `card_contribution == 0`**
  - Setup: fresh `pato_streamer` state (`card_contribution == 0`, `can_invest() == false`).
  - Verify: `Row1InvestButton.disabled == true` (visually disabled via the panel's own
    `InvestButtonDisabled` StyleBoxFlat, not just non-functional) and
    `Row1InvestExplanationLabel` is visible with text `"Make a Trash Streamer choice first"`.
  - Pass condition: disabled state is visually distinguishable (separate StyleBoxFlat) and
    the explanation label is legible.
  - Result: PASS — `test_invest_button_disabled_with_explanation_when_card_contribution_zero`.
  - Contrast cases also verified: enabled state once `can_invest()` is true
    (`test_invest_button_enabled_when_card_contribution_positive`, button text
    `"Invest 10 Cringe (+1.0 affiliation)"`); a real button press spends the resource and
    grants the previewed affiliation (`test_invest_button_press_spends_resource_and_grants_affiliation`);
    the GDD's second documented disabled case (`affiliation >= 100.0`, F3 clamp cap — not
    itself a required AC here, included as a cheap extra) shows `"Fully invested this era"`
    (`test_invest_button_disabled_when_affiliation_at_full_cap`).

- [x] **AC-5 — No moral-framing text anywhere in the panel or HUD**
  - Setup: text audit across 3 representative panel states (fresh/zero, ambiguous tie,
    resolved + at-cap) plus the HUD indicator (already covered by its own Story
    class-path/002 evidence — unmodified by this story).
  - Verify: every rendered Label/Button text in the panel, lowercased, does not contain
    "dobry", "zly"/"zły", "good", "evil", or "moral" — with "morale" (the resource name)
    explicitly stripped first so the legitimate word "Morale" in Invest button text (e.g.
    "Invest 8 Morale (+1.0 affiliation)") does not false-positive the "moral" substring
    check.
  - Pass condition: zero matches across all 3 states.
  - Result: PASS — `test_no_moral_framing_text_in_panel_across_representative_states`.

---

## Full Automated Suite Run

Command: `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests/ --ignoreHeadlessMode`

- This story's own suite (`class_path_panel_interaction_test.gd`): **10/10 PASSED**, 0 errors,
  0 failures, 0 flaky.
- Full project suite after this story's changes: **486/486 test cases PASSED**, 0 errors,
  0 failures, 0 flaky, 0 skipped (48/48 suites executed).
- **126 orphans** reported by the runner — confirmed pre-existing and unrelated to this
  story: re-ran the full suite with `class_path_panel_interaction_test.gd` temporarily
  removed and the orphan count was identical (126), both with and without this story's new
  test file/scenes in the tree.
- One real regression was found and fixed during this story's implementation (not a
  pre-existing bug): adding `ClassPathPanel` as a new sibling under `ActionScreen`'s root
  broke `card_screen_modal_test.gd`'s `test_card_screen_is_topmost_stop_modal_under_action_screen`,
  which asserts `CardScreen` is the LAST child of `ActionScreen` (so its modal always draws on
  top). Fixed by reordering `class_path_panel.tscn`'s instance to sit before `CardScreen` in
  `action_screen.tscn`, restoring `CardScreen` as the last/topmost child. Re-run confirmed
  0 failures.

---

## Sign-off

| Role | Name | Date | Approved |
|------|------|------|----------|
| Lead Developer | Magda (solo dev) | 2026-07-14 | [ ] Pending — recommend a follow-up human visual pass (layout/legibility/contrast at real mobile viewport, per Method note above) before final sign-off |

---

## Notes

- New `ClassPathSystem.can_invest(path_id)` query (added by this story, mirrors `invest()`'s
  own gate check exactly) is covered indirectly by every Invest-control test above; no
  dedicated unit test file was added for this single one-line query since it has no branching
  logic of its own to regress independently of `invest()`'s existing coverage.
- `PathButton` (new TopBar entry point wired in `action_screen.gd`/`.tscn`) is a scope
  decision made during implementation, not explicitly required by this story's 5 ACs: the
  GDD says "tapping [the HUD indicator] navigates to the Class Path Panel," but AC-3
  explicitly forbids rebuilding `ClassPathHudIndicator` (a non-Button `PanelContainer` with
  no tap affordance), and the panel needs *some* way to open for the story to be usable at
  all. Structural presence of this button is covered by `action_screen.tscn` still
  instantiating and passing the pre-existing Action UI suites (see full-suite run); no
  dedicated `PathButton` interaction test was added beyond that, since its wiring is a
  1-line `visible = true` flip identical in shape to the already-tested `SettingsButton`
  pattern.
