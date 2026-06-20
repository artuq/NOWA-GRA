# Smoke Test: Critical Paths

**Purpose**: Run these checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches to Boot scene without crash, transitions to Main scene
2. New game (no save file) initializes all resources/flags to documented defaults
3. Main scene responds to all touch inputs without freezing

## Core Mechanic (update per sprint)

4. Player can select and complete all 3 actions (Nagraj vloga, Zrób dramę, Przeproś w internecie), each with correct duration and rewards
5. After the 3rd distinct action type completes (Onboarding Phase 1→2), the first Decision Card appears after the next action
6. Player can swipe a Decision Card left/right and see the correct resolution

## Data Integrity

7. Save game completes without error (kill app mid-session, confirm prior save intact)
8. Load game restores correct resource/flag/cooldown/onboarding-phase state
9. Corrupted/missing save file falls back to first-session state, no crash

## Offline Progress

10. Force elapsed time >= 300s before relaunch: confirm Offline Report Screen shows with correct totals
11. Force elapsed time < 300s before relaunch: confirm no report screen, main scene shows directly

## Performance

12. No visible frame rate drops on target Android hardware (60fps target)
13. No memory growth over 5 minutes of play (once core loop is implemented)
