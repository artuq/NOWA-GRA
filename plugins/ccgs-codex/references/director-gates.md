# CCGS director gates for Codex

This is the Codex-native gate contract used by CCGS workflows. A gate is an
evidence review, not an automatic permission to mutate files.

## Review mode

Resolve the mode in this order:

1. Explicit workflow argument: `solo`, `lean`, or `full`.
2. The trimmed value in `production/review-mode.txt`.
3. Default: `lean`.

- `solo`: the primary agent evaluates the requested gate directly; do not spawn
  reviewers.
- `lean`: use only the four phase gates (`CD/TD/PR/AD-PHASE-GATE`).
- `full`: run every gate requested by the workflow.

Keep the primary thread responsible for questions and final decisions. A
reviewer returns evidence, a verdict, concerns, and a recommendation to the
primary agent; it never questions the user directly. Run independent reviewers
in parallel up to the active concurrency limit and batch the rest.

## Response contract

The first non-empty line must be exactly:

```text
[GATE-ID]: [ALLOWED TOKEN]
```

Then provide:

1. evidence inspected, with repository paths;
2. failed or uncertain criteria;
3. impact if unresolved;
4. one recommended next action.

`CONCERNS` means the work may proceed only after the primary agent explains the
risk and records the user's decision. A negative verdict blocks the workflow's
dependent step. The user may override a gate, but the primary agent must record
the verdict, risk, rationale, owner, and review date in the relevant production
artifact. A gate never commits, pushes, or publishes.

## Gate catalog

| Gate ID | Role | Primary input | Criteria | Allowed tokens |
|---|---|---|---|---|
| `CD-PHASE-GATE` | creative-director | phase artifacts | pillars preserved; fantasy coherent; player value clear; no unresolved creative blocker | `READY`, `CONCERNS`, `NOT READY` |
| `TD-PHASE-GATE` | technical-director | phase artifacts, ADRs | technically coherent; dependencies mapped; engine constraints respected; critical risk owned | `READY`, `CONCERNS`, `NOT READY` |
| `PR-PHASE-GATE` | producer | scope and production state | scope fits capacity; dependencies scheduled; blockers owned; exit evidence present | `READY`, `CONCERNS`, `NOT READY` |
| `AD-PHASE-GATE` | art-director | visual and asset artifacts | visual target clear; asset scope feasible; pipeline constraints captured; blockers owned | `READY`, `CONCERNS`, `NOT READY` |
| `TD-ADR` | technical-director | proposed ADR | decision is necessary; alternatives compared; consequences explicit; superseded decisions linked | `APPROVE`, `CONCERNS`, `REJECT` |
| `AD-ART-BIBLE` | art-director | art bible | visual identity specific; references internally consistent; production constraints usable; accessibility considered | `APPROVE`, `CONCERNS`, `REJECT` |
| `AD-CONCEPT-VISUAL` | art-director | game concept | visual hook distinctive; style supports fantasy; scope producible; anchor references actionable | `APPROVE`, `CONCERNS`, `REJECT` |
| `CD-PILLARS` | creative-director | concept and pillars | pillars distinct; anti-pillars explicit; core loop reinforces them; decisions can be tested against them | `APPROVE`, `CONCERNS`, `REJECT` |
| `PR-SCOPE` | producer | concept scope tiers | MVP bounded; staffing assumptions credible; dependencies visible; cuts preserve the hook | `REALISTIC`, `CONCERNS`, `UNREALISTIC` |
| `TD-FEASIBILITY` | technical-director | concept and engine constraints | unknowns identified; hard risks testable; platform fit credible; prototype targets the riskiest claim | `LOW RISK`, `CONCERNS`, `HIGH RISK` |
| `TD-ARCHITECTURE` | technical-director | architecture document | boundaries clear; data ownership defined; non-functional needs covered; GDD requirements traceable | `APPROVE`, `CONCERNS`, `REJECT` |
| `LP-FEASIBILITY` | lead-programmer | design or architecture proposal | implementation path plausible; complexity bounded; tests possible; team skills and tools sufficient | `FEASIBLE`, `CONCERNS`, `INFEASIBLE` |
| `TD-MANIFEST` | technical-director | control manifest | every governed component listed; ownership clear; initialization order valid; change rules enforceable | `APPROVE`, `CONCERNS`, `REJECT` |
| `PR-EPIC` | producer | epic proposal | outcome measurable; scope cohesive; dependencies listed; completion fits planning horizon | `REALISTIC`, `CONCERNS`, `UNREALISTIC` |
| `QL-STORY-READY` | qa-lead | story, GDD, ADRs | acceptance criteria testable; evidence path named; dependencies ready; ambiguity low enough to implement | `ADEQUATE`, `GAPS`, `INADEQUATE` |
| `CD-GDD-ALIGN` | creative-director | system GDD | supports pillars; player-facing intent clear; interactions coherent; no anti-pillar violation | `APPROVE`, `CONCERNS`, `REJECT` |
| `TD-SYSTEM-BOUNDARY` | technical-director | systems map | responsibilities non-overlapping; inputs/outputs explicit; data owner unique; dependencies acyclic or controlled | `APPROVE`, `CONCERNS`, `REJECT` |
| `CD-SYSTEMS` | creative-director | systems index | systems collectively deliver fantasy; priority matches pillars; missing player loop identified; bloat flagged | `APPROVE`, `CONCERNS`, `REJECT` |
| `PR-MILESTONE` | producer | milestone evidence | exit criteria met; schedule variance understood; blockers owned; next milestone still feasible | `ON TRACK`, `AT RISK`, `OFF TRACK` |
| `CD-PLAYTEST` | creative-director | playtest evidence | hypothesis answered; player behavior supports intent; qualitative issues prioritized; next decision justified | `APPROVE`, `CONCERNS`, `REJECT` |
| `TD-CHANGE-IMPACT` | technical-director | proposed design change | downstream artifacts found; runtime/data impact assessed; migration need identified; verification plan complete | `APPROVE`, `CONCERNS`, `REJECT` |
| `PR-SPRINT` | producer | sprint plan | capacity respected; stories ready; dependency order workable; sprint goal coherent | `REALISTIC`, `CONCERNS`, `UNREALISTIC` |
| `QL-TEST-COVERAGE` | qa-lead | implementation and evidence | acceptance criteria covered; regressions considered; failure paths tested; evidence reproducible | `ADEQUATE`, `GAPS`, `INADEQUATE` |
| `LP-CODE-REVIEW` | lead-programmer | code diff and tests | behavior correct; architecture respected; maintainability acceptable; tests cover material risk | `APPROVE`, `CONCERNS`, `REJECT` |
