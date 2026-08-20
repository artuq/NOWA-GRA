# ADR-0021: Algorithm Contract Ownership, Staged Return, and Exactly-Once Commit

## Status

Accepted (2026-08-11)

## Context

The Algorithm Contract Return Loop lets the player arm one optional offline
plan, previews both the chosen outcome and the neutral counterfactual on return,
then awards one persistent contract credit. It crosses offline simulation,
boot order, save durability, Class Path progression, and UI navigation.

Applying rewards during boot would mutate resources before the player sees the
report and makes crash recovery ambiguous. Applying them after a best-effort
save could duplicate a reward after retry or restart. Extending
`OfflineProgressSystem` with persistent plan and ladder state would also mix a
stateless calculator with progression ownership.

## Decision

1. Add `AlgorithmContractSystem` as a dedicated Core Autoload, registered after
   every gameplay owner it queries and before `BootController` begins restore.
   `BootController` is its sole restore caller; `SaveSystem._ready()` must not
   partially restore it. It exclusively
   owns the armed contract/revision, Business fixed-point remainder, contract
   credits, Creator Empire rung, and a transient staged-return transaction.
2. Contract definitions and ladder thresholds live in
   `res://assets/data/algorithm_contracts.json`; code validates IDs, revisions,
   terms, gates, and monotonic thresholds at load. Arming persists a complete
   immutable snapshot of the disclosed terms (not only ID/revision), so later
   balance changes cannot alter an already accepted plan. Mechanics remain in code.
3. `OfflineProgressSystem` remains a stateless simulator. It receives an
   explicit contract snapshot and returns chosen plus neutral result data; it
   never mutates contract progression or player resources.
4. Boot restores all persisted owners, computes elapsed time once, and asks the
   contract owner to stage an in-memory return result. Staging performs no
   resource, credit, rung, remainder, or save mutation. Neutral/no-contract boot
   retains the current flow.
5. The Offline Report owns confirmation UI only. On Confirm it calls one
   `commit_staged_return()` operation. The contract owner applies the staged
   resource delta once, consumes the armed contract, persists the new remainder,
   consumes the staged real-time Sponsor Shield duration exactly once, grants at
   most one credit, advances every newly satisfied ladder rung, and requests an
   immediate save.
6. `SaveSystem.save_now()` returns `bool`, propagating atomic-write success. A
   staged transaction has `STAGED`, `COMMITTING`, and `COMMITTED` phases plus an
   in-memory `effects_applied` guard. On save failure it remains `COMMITTING`;
   Retry saves the already-applied canonical state and never reapplies effects.
7. Disk remains on the old armed pre-commit state until the atomic rename
   succeeds. A process crash before success therefore re-simulates the same
   return rather than loading a partially committed transaction. Successful
   save contains resources, consumed contract, remainder, credit, and rung in
   one snapshot.
8. Burnout clears the armed contract and era-local Business remainder inside
   PrestigeSystem's synchronous transition, before its final save, but keeps
   Creator Empire credits/rung. New Game clears all contract and staged state.
9. The Away Plan/Creator Empire strip is coordinated by the existing main
   navigation owner; its panel is mutually exclusive with other panels. The
   Offline Report remains the only surface allowed to commit a staged return.
10. Offline resources never directly advance cards, decisions, challenges,
    Burnout time, eras, or Class Path history. Class Path F6 independently caps
    resource investment by card history and rejects pre-banking.
11. Offline elapsed seconds are clamped to `max(now - last_saved, 0)` before
    staging. Creator Empire eligibility is re-evaluated not only after a contract
    commit, but after every era-count or best-tier change that can satisfy a rung.

## Consequences

- Return attribution can be shown before mutation without risking duplicate
  grants.
- Save retry is observable and deterministic; no optimistic UI may dismiss a
  failed commit.
- A crash after live effects but before durable save loses only the transient
  in-memory application and safely reconstructs from the old disk snapshot.
- A new Autoload and save section are required, but persistent ownership stays
  separate from the shared offline calculator.
- Existing over-invested Class Path saves are migrated to F6 on restore; they
  are not grandfathered because that would preserve the progression skip.

## Validation

- Unit tests cover contract validation, formulas, fixed-point remainder, ladder
  multi-rung advancement, 300 s/24 h boundaries, and F6 anchors.
- Integration tests cover stage-without-mutation, confirm success, save failure
  plus retry, restart before durable commit, Burnout/New Game reset scopes, and
  neutral-flow compatibility. They also cover negative-clock clamp and Sponsor
  Shield consumption exactly once across commit retry.
- UI tests cover plan arming, staged report comparison, saving/retry states, and
  mutual exclusion through the navigation coordinator.

## Related Decisions

- ADR-0002 — atomic save format and observable save result.
- ADR-0003 — boot ordering and restore contracts.
- ADR-0006 — synchronous capped offline simulation.
- ADR-0010 — Class Path ownership and investment.
- ADR-0014 — coordinated main navigation panels.
- `design/gdd/algorithm-contract-return-loop.md`.
