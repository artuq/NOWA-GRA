# QA Evidence: Juice/Feedback — Card Channel Feel (Story 003 advisory addendum)

**STATUS: EXECUTED — 2026-07-06 (developer session + external QA video review ×2).**

**Story reference**: `production/epics/juice-feedback/story-003-card-channel-pulse-shake-stinger.md`
**QA plan reference**: `production/qa/qa-plan-sprint-9-2026-07-06.md`, Manual QA Checklist

**Story Type**: Integration (this doc covers the Visual/Feel advisory addendum, Feel-1..3)

---

## Test Environment

- **Date**: 2026-07-06
- **Testers**: Magda (developer, live editor session) + QA colleague (frame-by-frame video review, 2 recordings: pre-retune and post-retune)
- **Build**: DEBUG, Godot editor 4.0×–8.0×, portrait viewport
- **Godot version**: 4.6.3

---

## Checklist

- [x] **Feel-1 — tier feel: pulse + shake read as "weight"**
  - Result: PASS (after retune)
  - Notes: **First pass FAILED productively** — pulse clearly visible at all tiers, but shake (GDD placeholder values 2–4px/≤150ms, 8px cap) was fully masked by the simultaneous scale-pulse; QA video review at normal and slow playback confirmed "physically imperceptible" on cards up to m≈0.91 (leaked_dm "Leak everything"). Verdict: As Designed / Needs Tweak. **Retuned to 6–8px mid / 8–12px high, 0.30–0.40s** (QA recommendation: on touch-only devices and web builds without haptics, visual feedback must over-communicate; easier to dial down in polish than to ship an invisible effect). Second recording reviewed by QA: shake clearly visible, appropriate — "zostaje na mur-beton". Cross-platform note: web target (confirmed 2026-07-06) has NO haptics channel, making the visible shake the only weight signal there.

- [x] **Feel-2 — touch targets / readability during shake**
  - Result: PASS
  - Notes: Shake is a visual offset around the captured rest position (layout untouched); card text remained readable on the reviewed recording at max amplitude (12px on a 720-wide canvas, ~1.7% of width). Automated test asserts exact return-to-rest (±0.01px).

- [x] **Feel-3 — blind valence test (the GDD's central guarantee)**
  - Result: PASS (structural + observational)
  - Notes: Developer confirmed pulse identical for win- and loss-flavored resolutions during the session. Structurally guaranteed by FeedbackMath's abs-only reads + dedicated sign-invariance unit tests (`test_magnitude_is_sign_invariant`, `test_mirrored_outcomes_produce_identical_magnitude`). A formal obscured-text A/B session with an external tester is deferred to the next Vertical Slice playtest (low risk: no code path can differentiate valence).

**Action channel spot-checks (Story 002, same session):**
- [x] Count-up visible (~0.6s) instead of instant snap — PASS
- [x] Pill chrome flash, number text legible throughout — PASS
- [x] Same flash for gains and losses — PASS
- [x] Morale: flash only, band label stable (no count-up flicker) — PASS (by design after code review)

---

## Sign-off

| Role | Name | Date | Approved |
|------|------|------|----------|
| Developer | Magda (solo dev) | 2026-07-06 | [x] Approved |
| External QA | QA colleague (video review) | 2026-07-06 | [x] Approved (verdict: retune stays, aspect-ratio + mouse-threshold tasks logged for cross-platform) |

---

## Notes

- Audio stinger intentionally silent (no assets until art bible + `/asset-spec`) — structural pipeline verified by automated tests (null-stream guard).
- Follow-ups logged (Sprint 10 candidates, cross-platform): web-export renderer spike, aspect-ratio strategy for 16:9 iframe, mouse swipe-threshold feel-test. Reduce-motion toggle relevance INCREASED by the shake retune (GDD Open Question updated).
