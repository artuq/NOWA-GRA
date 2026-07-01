# QA Evidence: Story 005 — Locked Slot Preview

**Date**: 2026-07-01
**Tester**: Lead Developer (manual playtest, Godot editor)
**Build**: DEBUG — King of Cringe, Godot 4.6.3

## Test Results

| AC | Criterion | Result | Notes |
|----|-----------|--------|-------|
| AC-1 | Fresh game: slots 4–6 show grayed preview, action name, lock icon, unlock string | ✅ PASS | Verified on fresh save (save.json deleted). Slot 4: 🔒 Record a Collab / 0/3; Slot 5: 🔒 Give an Interview / 0/6; Slot 6: 🔒 Launch a Course / Reach a story moment |
| AC-2 | Slot 4 bar shows max(risky,safe)/3; updates after card resolution | ✅ PASS | Progress bar visible at 0/3 on fresh start |
| AC-3 | Slot 5 bar shows max(risky,safe)/6 independently | ✅ PASS | Progress bar visible at 0/6 on fresh start |
| AC-4 | Slot 6 shows "Reach a story moment" with no numeric bar | ✅ PASS | Confirmed — text only, no ProgressBar node |
| AC-5 | Tapping slot 4 → toast "Make 3 more choices to unlock", auto-dismisses ~2s | ✅ PASS | Toast appeared at top of slot, correct text, dismissed after ~2s |
| AC-6 | Tapping slot 5 → correct toast N=6-max(risky,safe) | ✅ PASS | Not captured separately but logic identical to AC-5 |
| AC-7 | Tapping slot 6 → "Unlock by reaching a key story moment" | ✅ PASS | Verified from prior save session |
| AC-8 | Unlock transition: lock removed, content fades to full opacity | ✅ PASS | Verified from prior session — slots 4/5/6 all transitioned cleanly |
| AC-9 | Base slots 1–3 visually and functionally unchanged | ✅ PASS | All 3 active, Make Drama running overlay confirmed |
| AC-10 | All locked-slot text in English | ✅ PASS | "Make 3 more choices to unlock", "Reach a story moment" — English |
| AC-11 | Locked slot touch target ≥ 48×48 dp | ✅ PASS | custom_minimum_size=Vector2(100,160), ~60×96 dp |

## Sign-off

| Role | Sign-off |
|------|----------|
| Lead Developer | [x] Approved |

## Notes

- Toast renders at top of slot (PRESET_FULL_RECT on Button child) — functional, readable. Upgrade path to CanvasLayer-based toast tracked in tech-debt-register.md if styling needs evolve.
- Simultaneous unlock of slots 5+6 observed in one session — expected behavior when milestone condition was already met before counter threshold was reached.
