# Architecture Review Report

> Date: 2026-07-06
> Engine: Godot 4.6.3 / GDScript
> GDDs Reviewed: 13 systems + systems-index
> ADRs Reviewed: 11 (10 Accepted + ADR-0011 Proposed)
> Mode: /architecture-review full
> Verdict: **PASS** — ADR-0011 clear to move Proposed → Accepted

---

## What changed since 2026-07-01

- **ADR-0011 added** (Proposed) — Juice/Feedback System: stateless `FeedbackMath`
  static class + additive effect code in existing UI nodes (ResourceHud, CardScreen).
  No new Autoload, no new signal, no boot-order change.
- MVP + Class Path set unchanged (last PASS 2026-07-01). ADR-0010 now Accepted.

## Traceability — Juice/Feedback System (new)

`juice-feedback-system.md` requirements, newly extracted and mapped to ADR-0011:

| TR-ID | Requirement | ADR-0011 | Status |
|-------|-------------|----------|--------|
| TR-juice-001 | Magnitude formula: linear (bounded), log (unbounded), max-of-contributions, hard clamp [0,1] | §1 `FeedbackMath.magnitude()` | ✅ |
| TR-juice-002 | Two mutually-exclusive channels — Action (count-up+flash, no shake) / Card (pulse+shake+stinger) | §2, §3 | ✅ |
| TR-juice-003 | No-valence-coding, structurally testable (same magnitude → identical params) | §1 (`abs()`-only, sign-invariant pure function) | ✅ |
| TR-juice-004 | Zero-magnitude still plays lowest tier | §3 (effects always fire; magnitude only scales params) | ✅ |
| TR-juice-005 | Payoff text duration formula (clamp 1.5–2.5s) | Existing CardScreen resolution beat (verified, not rebuilt) | ⚠️ Partial |
| TR-juice-006 | Backgrounding leaves clean state, no persisted state | Fire-and-forget tweens; `_notification` extended to kill RESOLVING tweens | ✅ |
| TR-juice-007 | `resolution_reaction` content per card/option | Already present on all 12 cards (GDD Open Question RESOLVED 2026-07-06) | ✅ |

**Totals (new): 6 ✅ Covered, 1 ⚠️ Partial.** The partial (TR-juice-005) is a
verification gap, not a design gap: ADR-0011 asserts the existing
`resolution_beat_seconds + resolution_beat_per_char` implementation already
satisfies the GDD payoff timing, but the GDD specifies an exact
`clamp(D_min + (len/L_ref)(D_max−D_min), 1.5, 2.5)` formula. Confirm the shipped
beat matches those bounds during Story 9-2. Not an acceptance blocker.

## Cross-ADR Conflicts

**None blocking.** ADR-0011 is purely additive (one stateless static class + two
node-local edits): no Autoload, no signal, no boot-order change. Three load-bearing
dependency claims verified against source ADRs:

- **`action_completed` carries final applied deltas** — confirmed in ADR-0004
  (2026-06-23 correction: payload is post-Morale-scaling deltas passed to
  `apply_delta()`; ADR-0010 inserts the path multiplier into the same call site
  before emission). Magnitude therefore reflects the actual applied deltas,
  including path bonus. ✅
- **ResourceHud owns the resource labels** — ADR-0007 §49 confirms. Adding an
  `action_completed` subscription to ResourceHud respects zone ownership (signals
  are multicast; a second subscriber alongside ActionGrid/RunningActionOverlay is
  fine). Rejected Alternative C (conductor) correctly — a conductor reaching across
  zones would break ADR-0007. ✅
- **No new state / no Autoload** — consistent with ADR-0001's rationale (Autoloads
  exist to own state/lifecycle; this system owns none). ✅

### Integration concern (advisory, non-blocking)

ADR-0011 §2 says the Action-channel count-up "tweens the displayed number from old
to new," but ResourceHud's existing `resource_changed` handler already **snaps**
that label to the new value. Emission order on action completion is
`apply_delta()` → `resource_changed` (label jumps to new) → **then**
`action_completed` (count-up wants old→new, but "old" is already gone). ResourceHud
must capture the pre-update value before `resource_changed` overwrites it, or have
the count-up own the label while active. Resolvable locally in Story 9-2 but
currently unspecified in the ADR.

**Recommended one-line ADR clarification before/at acceptance:** state how the
Action-channel count-up reconciles with ResourceHud's instant `resource_changed`
label update. (Same posture as ADR-0010's optional pre-acceptance edits.)

## ADR Dependency Order

ADR-0011 `Depends On`: ADR-0001, ADR-0004, ADR-0007, ADR-0008, ADR-0010 —
**all Accepted.** No unresolved edges, no dependency cycle. No new Autoload, so no
boot-order impact (its UI nodes instantiate after all Autoloads by construction).

```
Foundation:    ADR-0001 → ADR-0002 → ADR-0003
Core:          ADR-0004 (→0001), ADR-0005 (→0001,0004), ADR-0006 (→0001,0003)
Presentation:  ADR-0007 (→0001,0004) → ADR-0008 (→0001,0007)
               ADR-0009 (→0001,0003,0006,0007)
Feature:       ADR-0010 (→0001,0003,0005,0008)
Polish/Feel:   ADR-0011 (→0001,0004,0007,0008,0010)   [Proposed → clear to Accept]
```

## GDD Revision Flags (Architecture → Design Feedback)

**None** — all GDD assumptions consistent with verified engine behaviour. The GDD
was already synced during ADR-0011 authoring (3 stale fragments corrected: no
`payoff complete` signal, states are conceptual, `resolution_reaction` resolved).

## Engine Compatibility

Engine: Godot 4.6.3. ADR-0011 self-rates **LOW** knowledge risk — confirmed:

- APIs used (`create_tween()`, `AudioStreamPlayer`, `Control.self_modulate`/
  `modulate`, `Label`, `Tween`) are all pre-4.3 stable.
  **Post-cutoff APIs: none. Deprecated APIs: none** (`deprecated-apis.md` grep clean).
- The 4.6 glow breaking-change (`breaking-changes.md`) is correctly ruled out —
  the label flash is a `modulate`/`self_modulate` pulse, not WorldEnvironment glow.
- The `self_modulate` vs `modulate` distinction (§2) is a correct GDScript call:
  `modulate` cascades to the child value Label and would tint the number text;
  `self_modulate` affects chrome only.

**Engine specialist consultation: not re-spawned.** ADR-0011 already carries an
embedded engine-specialist sign-off (2 BLOCKING fixes + 4 minors folded in,
2026-07-06). Re-spawning would duplicate that for an engine-trivial,
no-post-cutoff-API decision — consistent with same-day ADR-0007/0008 handling.

## Architecture Document Coverage

Juice/Feedback is Vertical-Slice / Feel-layer and correctly outside the MVP
`architecture.md` scope. No orphaned architecture.

## Pre-Gate Checklist

All present: ✅ `tests/unit/` ✅ `tests/integration/` ✅ `.github/workflows/tests.yml`
✅ `design/accessibility-requirements.md` ✅ `design/ux/interaction-patterns.md`.
(`tests/unit/feedback/` not created yet — expected, Story 9-2 work.)

---

## Verdict: PASS

ADR-0011 introduces no cross-ADR conflicts, is engine-clean (no post-cutoff or
deprecated APIs), and all five dependencies are Accepted. It is **clear to move
Proposed → Accepted**, unblocking Story 9-2. The single integration concern
(count-up vs. `resource_changed`) and the payoff-formula verification (TR-juice-005)
are Story-9-2 implementation items, not acceptance blockers.

### Recommended ADR-0011 edit before acceptance (optional, one line)

- Specify how the Action-channel count-up reconciles with ResourceHud's existing
  instant `resource_changed` label update (capture pre-update value, or count-up
  owns the label while active).

### Next

- Accept ADR-0011 (Proposed → Accepted) to unblock Story 9-2, optionally applying
  the one-line clarification first.
- Run `/create-epics juice-feedback` → `/create-stories` → `/dev-story` for Story 9-2.
- Re-run `/architecture-review rtm` once stories and tests exist to close the
  GDD → ADR → Story → Test chain.
