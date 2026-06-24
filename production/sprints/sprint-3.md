# Sprint 3 — 2026-06-25 to 2026-06-29

## Sprint Goal
Implement the two remaining MVP Foundation-layer systems with the heaviest dependency fan-out — History Flag System and Save/Persistence System — unblocking Decision Card System and Offline Progress System. The full buffer is reserved for Save/Persistence's risk: it's the first story touching async timing, file I/O, and platform lifecycle hooks.

## Capacity
- Total days: 5 (1 week, solo dev)
- Buffer (20%): 1 day reserved for unplanned work
- Available: 4 days

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| 3-1 | History Flag System — `HistoryFlagManager` Autoload (flag log + pattern counters + `resolve_path()`) | game-designer → godot-gdscript-specialist | 1.5 | None (Foundation, Resource System already Complete) | Per `design/gdd/history-flag-system.md` AC + TR-hist-001; unit-tested |
| 3-2 | Save/Persistence System — `SaveSystem` Autoload (debounced `mark_dirty`, atomic temp-write-then-rename, schema_version, corruption fallback) | technical-director → godot-gdscript-specialist | 1.5 | None (Foundation) | Per TR-save-001/002; unit + integration tested (corruption/kill-mid-write recovery) |

### Should Have
None this sprint — Card Content Database (originally proposed as 3-3) deferred to Sprint 4 per the PR-SPRINT producer feasibility gate: SaveSystem's estimate was sized before story-level breakdown and is qualitatively new territory (first story touching `DirAccess`, async timing, platform lifecycle hooks), so the full buffer stays reserved for it rather than being spent on a Should Have.

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| 3-4 | Doc-sync: Polish→English resource keys in `resource-system.md` / `entities.yaml` (tech debt, 2 sprints overdue) | solo dev | 0.25 | None | `Zasięgi/Hatersi/Sponsorzy` references updated to `Reach/Haters/Sponsors` matching code; tech-debt entry closed |

## Carryover from Previous Sprint
None.

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Save/Persistence's atomic-write-survives-kill behavior is hard to test deterministically in GdUnit4 | Medium | Medium | Simulate via file-system state assertions rather than literal process kill; flag as advisory if untestable in isolation |
| 3-2's 1.5-day estimate was sized before `/create-stories` breakdown — PR-SPRINT gate flagged CONCERNS | Medium | Medium | Run `/create-stories save-persistence-system` first and size the debounce/dirty-flag path separately from the atomic-write/corruption-fallback path; if story-level sizing pushes past 1.5 days, the Should Have (Card Content Database) has already been deferred so the buffer absorbs it |
| History Flag System's `resolve_path()` has no consumer yet (Class Path System is Vertical-Slice tier, not built) | Low | Low | Test against the GDD's documented threshold/margin examples directly, not against a real path registry |
| Sprint 2's "uncommitted work" pattern recurs a third time | Medium | Medium | New explicit DoD checkpoint this sprint: working tree clean before sprint close |

## Dependencies on External Factors
None.

## QA Plan
No QA plan exists yet for this sprint. Run `/qa-plan sprint` before implementation begins.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-3-[date].md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Working tree is clean (all sprint work committed) — new checkpoint per Sprint 2 retro action item
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged

> ⚠️ **No QA Plan**: This sprint was started without a QA plan. Run `/qa-plan sprint`
> before the last story is implemented. The Production → Polish gate requires a QA
> sign-off report, which requires a QA plan.
