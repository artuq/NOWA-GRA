# QA Evidence: Story 002 — Class Path HUD Indicator

**STATUS: EXECUTED — manual walkthrough completed 2026-07-05.**

**Story reference**: `production/epics/class-path/story-002-class-path-hud.md`
**QA plan reference**: `production/qa/qa-plan-sprint-8-2026-07-01.md`, section 8-3

**Story Type**: UI (Test Evidence tier: ADVISORY — manual walkthrough doc)

---

## Test Environment

- **Date**: 2026-07-05
- **Tester**: Magda (user, solo dev)
- **Build**: DEBUG, Godot editor run (4.0×–8.0× time scale), screenshots captured in session
- **Device**: Godot editor, portrait mobile viewport (macOS host); physical Android device test still recommended before release
- **Godot version**: 4.6.3

---

## Test Checklist

*Manual verification steps, one per AC (from the story's `## QA Test Cases`).*

- [x] **AC-1 — HUD hidden before Tier 1**
  - Setup: fresh session, no card choices made
  - Verify: HUD indicator node is not visible in the HUD area
  - Pass condition: no path badge visible on screen in any corner
  - Result: PASS
  - Notes: Fresh save (save.json deleted). No badge in TopBar through ~1 resolved card; badge stayed hidden until the 5th pato card.

- [x] **AC-2 — HUD appears after Tier 1 reached**
  - Setup: resolve 5 pato_streamer-tagged cards (enough for T1 at CARD_AFFILIATION_PER_CHOICE=4.0 → 20.0 affiliation)
  - Verify: HUD indicator becomes visible and shows "Trash Streamer T1" (or equivalent English label with T1)
  - Pass condition: badge visible, label contains path name and "T1" in English
  - Result: PASS
  - Notes: Badge appeared next to the avatar with "Pato-Streamer T1" (screenshot captured). Display name later changed to "Trash Streamer" (user decision 2026-07-05) — re-verified as "Trash Streamer T2" in the AC-7 run.

- [x] **AC-3 — HUD updates on tier advance**
  - Setup: continue from AC-2; resolve enough additional pato_streamer cards to cross T2 (affiliation ≥ 40.0)
  - Verify: HUD indicator label updates to show "T2" without restarting
  - Pass condition: label changes to "Trash Streamer T2" in the same session
  - Result: PASS
  - Notes: Label advanced to T2 within the same session, no restart (screenshot captured).

- [ ] **AC-4 — HUD reflects path switch**
  - Setup: pato_streamer at T1; resolve 5 guru_celebryta cards (guru crosses T1 with higher affiliation than pato)
  - Verify: HUD indicator label switches from pato_streamer name to guru_celebryta name
  - Pass condition: label now shows guru display name + tier; pato label is gone
  - Result: DEFERRED — covered by automated unit tests
  - Notes: Impractical to trigger manually (guru has only 2 cards in the weighted-random pool). Path-switch logic is covered by `tests/unit/class-path/class_path_core_test.gd::test_active_path_single_path_at_tier1` and `test_active_path_changed_signal`; the HUD handler is the same code path exercised by AC-2/AC-3.

- [x] **AC-5 — English labels, no moral framing**
  - Setup: any state where path indicator is visible
  - Verify: label text is English; does not contain Polish text; does not contain "evil", "good", "bad", "corrupt", or equivalent value judgment words
  - Pass condition: only English archetype name + "T[N]" visible
  - Result: PASS
  - Notes: Label is archetype name + tier only. Display name changed from "Pato-Streamer" (Polish-only term) to "Trash Streamer" during this walkthrough — user decision, applied to `_DISPLAY_NAMES`.

- [x] **AC-6 — Mobile readability**
  - Setup: any state where HUD indicator is visible, running on target Android device (or emulated at 360×800 or equivalent)
  - Verify: text is legible without zoom; sufficient contrast against background
  - Pass condition: text readable at arm's length on target device
  - Result: PASS (editor viewport)
  - Notes: 19px label, off-white on dark pill with gold-accent border — clearly legible in portrait viewport screenshots. Physical Android device check still recommended at next device-test session.

- [x] **AC-7 — Restore state — HUD shows on session restore**
  - Setup: reach T1 on pato_streamer, save, quit, restart game
  - Verify: HUD indicator is visible immediately after load, showing correct path+tier
  - Pass condition: no need to make a new card choice for HUD to appear
  - Result: PASS (after bug fix)
  - Notes: **First run FAILED** — badge did not appear after restart, only after the next resolved card. Root cause: ClassPathSystem was never wired into SaveSystem/BootController serialize+restore (Story 001 gap). Fixed 2026-07-05 (`save_system.gd`, `boot_controller.gd` — `class_path` key added to save payload; regression 72/72 PASSED). Re-test after fix: badge "Trash Streamer T2" visible immediately on load (screenshot captured). PASS.

---

## Sign-off

| Role | Name | Date | Approved |
|------|------|------|----------|
| Lead Developer | Magda (solo dev) | 2026-07-05 | [x] Approved |

---

## Notes

- 6/7 checks executed and PASSED on editor run; AC-4 deferred to automated unit coverage (rationale above).
- One real bug found and fixed during this walkthrough (AC-7 save wiring) — the walkthrough paid for itself.
- No automated test file is required for this story (Story Type: UI) per `.claude/docs/coding-standards.md` Testing Standards table — this manual walkthrough doc is the required deliverable.
- Follow-up: repeat AC-6 on a physical Android device before release gate.
