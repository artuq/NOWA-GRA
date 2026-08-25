---
name: project-adr-code-drift
description: ADR-0004's code sample lagged behind ADR-0001's own stated pattern and the GDD — pattern worth re-checking in future ADRs
metadata:
  type: project
---

Found during QL-STORY-READY gate review of Action System Story 002
(2026-06-23): ADR-0004 (Action System Timer/Concurrency, Accepted
2026-06-20)'s illustrative code block shows `_on_action_timeout()` emitting
`action_completed` with raw/unscaled `ACTION_REWARDS`, with no
`ResourceManager.apply_delta()` call at all. But ADR-0001 (Accepted same
day), which ADR-0004 explicitly depends on, uses *this exact scenario*
("ActionSystem calling ResourceManager.apply_delta() after an action
completes") as its own canonical example of the direct-call communication
pattern. And the GDD (action-system.md) requires final-scaled-Zasięgi to be
written via apply_delta before resolution completes. So ADR-0004's code
sample is stale/incomplete relative to both its own dependency (ADR-0001)
and the GDD it implements — even though all three documents were "Accepted"
on the same date.

**Why**: ADRs accepted in the same review pass can still drift from each
other if a later ADR's code sample wasn't updated to reflect an earlier
ADR's worked example. The "Accepted" status and date don't guarantee
internal consistency across sibling ADRs.

**How to apply**: When gate-reviewing any story that implements an ADR's
code sample, cross-check that code block against (a) the ADRs it depends on
("Depends On" field) and (b) the current GDD section it implements — don't
assume an Accepted ADR's code is the final word if a dependency ADR shows a
different/fuller pattern for the same call site. Flag drift to
technical-director for amendment rather than letting the story silently
diverge from the ADR's literal text (see [[feedback_adr_conflict_routing]]).
