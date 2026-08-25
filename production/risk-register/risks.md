# Risk Register

> Stood up 2026-07-24, Sprint 12 (story 12-8) — first version of this register.
> Update whenever a risk is identified, escalated, mitigated, or closed. Do not delete closed risks — mark them Closed with the date and how they resolved.

| ID | Risk | Probability | Impact | Status | Mitigation | Owner |
|----|------|-------------|--------|--------|------------|-------|
| R-001 | Performance pass (10-3) blocked on no physical Android device — carried 3 sprints (10, 11, 12) | High | Medium | Open | Web-export spike (already GO, 2026-07-06) is an acceptable interim perf proxy. Escalate if a device isn't available by Sprint 13. | solo dev |
| R-002 | Solo-playtester signal is weak evidence for "core fantasy lands" (era loop's genuine-stakes goal) | High | Medium | Open | Use the structured `playtest-question-guide.md`; explicitly log N=1 in the report; 2+ more sessions recommended before treating Production→Polish PASS as fully trusted. | solo dev |
| R-003 | Card wave 2 (12-6, carried from 11-3) still unstarted — Sprint 11's "doubled decision-card pool" goal never delivered, era loop plays with a thinner card pool than designed | Medium | Low | Open | Should Have in Sprint 12, not Must Have — the loop is playable and testable without it. Defer to Sprint 13 if capacity runs out. | narrative-director/writer |
| R-004 | Documentation/tracking runs ahead of implementation — 3 Accepted ADRs (0014, 0017, and by extension the MainNav coordinator work ADR-0014 describes) found with zero code during this sprint's implementation pass, undiscovered until someone tried to build against them | Medium | Medium | Open | No systemic fix yet — flagged as a process pattern worth watching. Consider a periodic "ADR code-coverage" spot-check (ADRs Accepted N+ sprints ago with zero matching commits) as a future retro action item. | producer |
---

## Closed

| ID | Risk | Closed | How it resolved |
|----|------|--------|-----------------|
| R-005 | MainNavCoordinator (ADR-0014) accepted but uncoded; 2 live Close-button bugs | 2026-07-28 | Implemented in full (commit 38a3f75): coordinator in `action_screen.gd`, both Close bugs fixed via `close_requested`, back gesture Android+Web, BonusesPanel as 3rd panel. StaffPanel deliberately deferred until its system exists. |
