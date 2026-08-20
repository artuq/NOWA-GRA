# CCGS Codex skill quality rubric

Each metric is evaluated as `PASS`, `WARN`, or `FAIL`. Static format compliance
is assessed separately by `$skill-test static`.

## authoring

- A1: names the authoritative inputs and output location.
- A2: separates user-owned creative decisions from inferable details.
- A3: produces explicit, testable sections rather than vague prose.
- A4: identifies downstream documents or registries that need propagation.

## audit

- D1: remains read-only unless fixes are explicitly requested.
- D2: cites inspected evidence and distinguishes missing from unknown.
- D3: prioritizes findings by impact with a reproducible verdict.
- D4: recommends the smallest next action without hiding uncertainty.

## gate

- G1: names required evidence and allowed verdict tokens.
- G2: follows `references/director-gates.md` and the selected review mode.
- G3: blocks dependent work on a negative verdict and records overrides.
- G4: returns user decisions to the primary thread.

## implementation

- I1: loads the governing story/GDD/ADR context before edits.
- I2: preserves unrelated changes and scopes the implementation narrowly.
- I3: validates behavior against acceptance criteria and material risks.
- I4: does not commit, publish, or broaden scope automatically.

## production

- P1: reads current stage, sprint, capacity, blockers, and dependencies.
- P2: produces owned, ordered, status-trackable actions.
- P3: distinguishes required work from optional or repeatable work.
- P4: keeps plans consistent with source design and architecture artifacts.

## team

- T1: assigns bounded roles with explicit inputs and output contracts.
- T2: parallelizes independent work and batches beyond the slot limit.
- T3: surfaces BLOCKED/negative results before dependent work continues.
- T4: synthesizes conflicts in the primary thread without hiding dissent.

## testing

- Q1: identifies environment, fixtures, steps, expected results, and evidence.
- Q2: covers happy path, failure path, boundaries, and relevant regressions.
- Q3: separates observed results from assumptions and flaky evidence.
- Q4: produces a severity/prioritization or pass/fail decision that is reproducible.

## utility

- U1: has a narrow trigger and deterministic routing/output.
- U2: handles missing inputs with a concrete fallback or blocker.
- U3: avoids unnecessary writes and expensive scans.
- U4: hands off to a resolvable next workflow when appropriate.
