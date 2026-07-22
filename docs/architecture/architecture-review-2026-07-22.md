# Architecture Review Report

- **Date:** 2026-07-22
- **Engine:** Godot 4.6.3
- **GDDs Reviewed:** 17
- **ADRs Reviewed:** 17 (13 Accepted, 4 Proposed)
- **Mode:** `/architecture-review` full

---

## Scope note

ADR-0001–0013 are Accepted and were validated in prior independent reviews; the
TR registry (v7) records them as covered (40 TRs, 38 covered / 2 partial). This
run focuses on the **4 new Proposed ADRs (0014–0017)** authored 2026-07-22, which
no prior review or registry entry covers.

---

## Traceability Summary

| | Count |
|---|---|
| Existing TRs (registry v7) | 40 — 38 covered, 2 partial |
| New requirements (ADR-0014–0017) | 7 — all covered, 0 registered before this run |

### New requirements needing TR-IDs (all covered; registered by this run)

| Proposed ID | GDD/Spec | Requirement | ADR | Status |
|---|---|---|---|---|
| TR-nav-001 | main-navigation-screen-flow.md | `coordination_state` single source of truth, ≤1 panel visible, panel `visible` is an effect | ADR-0014 | Covered |
| TR-nav-002 | main-navigation-screen-flow.md | Card-interrupt priority (card > back > panel-tap) via one synchronous resolver | ADR-0014 | Covered |
| TR-nav-003 | main-navigation-screen-flow.md | Android (`NOTIFICATION_WM_GO_BACK_REQUEST`) + Web (`JavaScriptBridge`/`pushState`) back gesture; iOS out of scope | ADR-0014 | Covered |
| TR-nav-004 | main-navigation-screen-flow.md | Close-button rewire — `close_requested` signal, no self-`visible=false` bypass | ADR-0014 | Covered |
| TR-set-001 | art-bible.md §7 (no dedicated GDD) | `SettingsSystem` Autoload, `reduce_motion` sole-write-path, persisted via `restore_state()` | ADR-0015 | Covered |
| TR-dcs-003 | decision-card-system.md | `inject_priority_card()` internal `state==COOLDOWN` reentrancy guard | ADR-0016 | Covered |
| TR-pcs-008 | prestige-checkpoint-system.md + wypalenie-card-modal.md + challenge-selection-screen.md | Unified `compute_next_grant()` preview + `get_last_grant()`, persisted `_last_grant` | ADR-0017 | Covered |

### Existing partials (unchanged)

- **TR-cps-007** — path-multiplier offline exclusion. Behaviour correct (ADR-0006
  offline loop never calls `get_active_multiplier`); ADR-0010 lacks an explicit
  one-line statement of the exclusion. Recommend a clarification before/at ADR-0010
  next revision. Non-blocking.
- **TR-juice-005** — resolution payoff-text duration clamp. ADR-0011 asserts the
  existing `CardScreen` beat already satisfies it; verify against GDD clamp bounds
  during Story 9-2. Non-blocking.

---

## Coverage Gaps (no ADR)

**None.** `architecture.md` v2 flagged 2 gaps (Main Navigation coordinator,
Settings System); both are now closed by ADR-0014 and ADR-0015 respectively.

---

## Shipped-code verification (the 3 code-touching ADRs)

All accurate against source:

- **ADR-0015** — `src/core/settings_system.gd:21-58`: `extends Node`,
  `reduce_motion: bool = false`, `set_reduce_motion()`, `serialize_state()` /
  `restore_state()` match exactly. `SettingsSystem` and `OnboardingGate` (the cited
  precedent) are both registered autoloads. Retrofit is accurate.
- **ADR-0016** — `src/core/decision_card_system.gd:273-283`:
  `inject_priority_card()` currently checks only `_priority_card_pending`, no
  `state` guard. Premise correct — the fix is real, not already applied.
- **ADR-0017** — `src/core/prestige_system.gd:182-202`: line 183 `get_active_path()`,
  185 `_last_captured_tier`, 189 `reset_era_state()`, 202 `_apply_grant()`. Ordering
  matches the ADR's capture-before-reset design exactly.

---

## Cross-ADR Conflicts

**None.** All 4 new ADRs are strictly additive:

- **ADR-0016 vs ADR-0013** — both touch the `inject_priority_card` guard path;
  0016 explicitly preserves 0013's external `state == COOLDOWN` check (harmless
  redundancy, also serves the cringe-latch behaviour). No ownership conflict.
- **ADR-0017 vs ADR-0012** — no change to `era_transitioned` signature or atomicity
  ordering; adds two methods + one persisted field. No conflict.
- **ADR-0014** — no new Autoload/scene; extends `action_screen.gd` (ADR-0007).
  Registry `forbidden_patterns` (Central EventBus) respected; `coordination_state`
  already recorded in `docs/registry/architecture.yaml:331`.
- **ADR-0015** — documentation-of-record, zero code change.

---

## ADR Dependency Order

All 4 Proposed ADRs depend **only on Accepted ADRs** → all immediately
implementable, none blocked:

- ADR-0014 → ADR-0003, 0007, 0008 (all Accepted)
- ADR-0015 → ADR-0001, 0003 (all Accepted)
- ADR-0016 → ADR-0012, 0013 (all Accepted)
- ADR-0017 → ADR-0012, 0013 (all Accepted)

No cycles. No unresolved (Proposed→Proposed) dependencies. All 4 are ready to move
Proposed→Accepted.

---

## GDD Revision Flags

**None** — no GDD assumption contradicts verified engine behaviour. All 4 ADRs are
LOW knowledge risk, pre-4.3-stable APIs only.

---

## Engine Compatibility

Clean. No deprecated / post-cutoff API conflicts across all 17 ADRs. One standing
watch item from ADR-0014 (non-blocking, already documented in the ADR):

- godotengine/godot#105324 (`NOTIFICATION_WM_GO_BACK_REQUEST` possible multi-emit)
- godotengine/godot#64940 (`quit_on_go_back` reliability)

Smoke-test both on first Android build. `_apply_state_change()` is idempotent by
construction, so a duplicate notification in the same frame is a safe no-op.

---

## Minor issues (non-blocking, documentation-level)

1. **ADR-0014 stale entry-point count** — the 2026-07-22 revision moved every
   "6 entry points / two panels" to "8 / three", but two spots still say six:
   line 195 (Validation Criteria — actionable) and line 142 (rejected-alternative
   prose). Change to 8.
2. **systems-index.md gap** — Settings System is a listed dependency of Main
   Navigation (row 14) but has no enumeration row of its own; it now has ADR-0015
   and is a registered Autoload. Main Navigation (row 14) is still `In Review`
   though its GDD is design-complete and now ADR-backed.
3. **TR registry** — v7 (2026-07-17) predated all 4 new ADRs; Main Navigation had
   never had a single TR entry. Registered by this run (registry → v8).

---

## Verdict: PASS

All GDD/UX requirements for the 4 new ADRs are covered, no cross-ADR conflicts,
engine-clean, every dependency Accepted. The 4 Proposed ADRs are ready to move
Proposed→Accepted. Remaining items are documentation hygiene, not blockers.

### Blocking issues
None.

### Recommended next actions
1. Accept ADR-0014, 0015, 0016, 0017 (all dependencies satisfied).
2. Fix the stale "6 entry points" count in ADR-0014 (lines 142, 195).
3. Add a Settings System row to `systems-index.md`; flip Main Navigation row 14
   from `In Review` to reflect ADR-backing.
