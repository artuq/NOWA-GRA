---
name: feedback-adr-conflict-routing
description: When a story review surfaces a GDD-vs-ADR or ADR-vs-ADR conflict, QA flags it explicitly rather than silently picking a resolution
metadata:
  type: feedback
---

When a QL-STORY-READY (or similar) gate review surfaces a conflict between
an ADR's literal code/spec and the GDD or another ADR it depends on, the
correct move is to: (1) name the conflict explicitly in the gate output,
(2) propose a resolution but label it as a proposal, and (3) state that the
actual document amendment is technical-director's call, not QA's — QA does
not have authority to amend architecture docs.

**Why**: Architecture documents are owned by technical-director per the
coordination rules' vertical-delegation principle. QA's job is test-evidence
and quality gating, not resolving architecture drift unilaterally — doing so
would be a cross-domain change outside QA's designated directories/authority.

**How to apply**: In future gate reviews, when you find an ADR code sample
that's stale relative to a GDD or sibling ADR (see
[[project_adr_code_drift]]), write the flag as "needs ADR amendment,
recommend routing to technical-director" rather than just telling the
implementer to follow the GDD instead of the ADR. Still write the test spec
assuming the GDD-consistent behavior (since GDD acceptance criteria are the
ground truth for what ships), but call out that the underlying ADR document
itself is unresolved.
