# Sprint 11 — 2026-07-12 to 2026-07-18

## Sprint Goal
Build the core of long-session play: the era loop (Burnout → reset → meta-bonus) designed and playable + doubled decision-card pool — the game stops reading as a "30-minute" experience and starts being a real incremental with genuine stakes.

## Capacity
- Total days: 6
- Buffer (20%): 1.2 days reserved for unplanned work
- Available: ~4.8

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 11-1 | Prestige/Checkpoint + Burnout design day — full GDD (`/design-system`, anchored on `design/quick-specs/final-burnout-2026-07-01.md`) + ADR + epic + stories | game-designer, systems-designer, technical-director | 1 | — | 8-section GDD approved; ADR Accepted; stories Ready |
| 11-2 | BurnoutSystem core — trigger (Cringe sustained at 100), forced "Wypalenie" (Final Burnout) decision card, era transition + resource reset + 1 permanent meta-bonus | gameplay-programmer | 1.5 | 11-1 | Unit + integration tests green; era-reset preserves meta-bonus across save/load |
| 11-3 | Card wave 2 — 12→24 decision cards (new cards with `resolution_reaction` + `path_tags`, English) | narrative-director, writer | 1 | — | 12 new cards in the database; path_tags confirmed with user (per memory: class-path-display-names); all fields English |

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 11-4 | Challenge Era Runs — implement per `design/quick-specs/challenge-era-runs-2026-07-01.md` (era-start challenge picker, ratio multipliers, larger meta-bonus) | gameplay-programmer | 1 | 11-2 | Tests green; challenges are era-local; multiplicative stacking |
| 11-5 | Era-start/era-end screens (minimal — transition wipe + challenge selection) | ui-programmer | 0.5 | 11-2 | Era transition reads clearly; no new UI patterns introduced |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 11-6 | Post-MVP action expansion — economy pass on the 4 straightforward candidates (design only, no implementation) | economy-designer | 0.5 | — | Fit/duplicate verdict for Merch Drop / Giveaway / Product Placement / Streamer Collab |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| 10-3 Performance pass on device | Still blocked — no physical Android device available | 0.5 (once device available) |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Prestige GDD grows past 1 day (large system) | Medium | High | Quick-spec anchors already narrow scope; GDD may explicitly defer part to a future Alpha pass |
| Era-reset vs. existing save schema (versioning) | Medium | High | 11-1's ADR must explicitly resolve schema migration; SaveSystem already has `schema_version` |
| 24 cards = doubled EN/path_tags audit surface | Low | Medium | Reuse the PL→EN audit pattern from Sprint 9 |

## Dependencies on External Factors
- 10-3: physical Android device (user)
- 11-3 path_tags: user confirmation on new cards (locked habit per memory)

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-11.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged

> PR-SPRINT feasibility gate skipped — Lean mode.
