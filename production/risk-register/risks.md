# Risk Register

> Stood up 2026-07-24, Sprint 12 (story 12-8) — first version of this register.
> Update whenever a risk is identified, escalated, mitigated, or closed. Do not delete closed risks — mark them Closed with the date and how they resolved.

| ID | Risk | Probability | Impact | Status | Mitigation | Owner |
|----|------|-------------|--------|--------|------------|-------|
| R-001 | Performance pass (10-3) blocked on no physical Android device — carried 3 sprints (10, 11, 12) | High | Medium | Open | Web-export spike (already GO, 2026-07-06) is an acceptable interim perf proxy. Escalate if a device isn't available by Sprint 13. | solo dev |
| R-002 | Solo-playtester signal is weak evidence for "core fantasy lands" (era loop's genuine-stakes goal) | High | Medium | Open | Use the structured `playtest-question-guide.md`; explicitly log N=1 in the report; 2+ more sessions recommended before treating Production→Polish PASS as fully trusted. | solo dev |
| R-003 | Card wave 2 (12-6, carried from 11-3) still unstarted — Sprint 11's "doubled decision-card pool" goal never delivered, era loop plays with a thinner card pool than designed | Medium | Low | Open | Should Have in Sprint 12, not Must Have — the loop is playable and testable without it. Defer to Sprint 13 if capacity runs out. | narrative-director/writer |
| R-004 | Documentation/tracking runs ahead of implementation — 3 Accepted ADRs (0014, 0017, and by extension the MainNav coordinator work ADR-0014 describes) found with zero code during this sprint's implementation pass, undiscovered until someone tried to build against them | Medium | Medium | Open | No systemic fix yet — flagged as a process pattern worth watching. Consider a periodic "ADR code-coverage" spot-check (ADRs Accepted N+ sprints ago with zero matching commits) as a future retro action item. | producer |
| R-005 | MainNavCoordinator (ADR-0014) has a full design and 2 independent PASS architecture reviews but zero implementation — SettingsButton/PathButton still use pre-ADR-0014 direct `visible=true` handling; the two documented Close-button bugs (`settings_screen.gd`, `class_path_panel.gd`) are still live in shipped code | Low | Medium | Open | Not blocking Sprint 12 (12-2 was scoped to avoid touching it). Schedule as its own epic when capacity allows — this is now the largest Accepted-but-uncoded ADR in the project. | producer |

---

## Closed

*(none yet)*
