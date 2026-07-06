# Requirements Traceability Index

> Human-readable index over `docs/architecture/tr-registry.yaml` (the machine-readable
> source of truth, maintained by `/architecture-review`). This file exists to satisfy
> gate-check's literal filename check — do not hand-edit requirement entries here;
> edit `tr-registry.yaml` and regenerate this table, or run `/architecture-review` again.

**Last updated**: 2026-07-06 (from `tr-registry.yaml` v6)
**Total requirements**: 28 | **Covered**: 24 | **Partial**: 3 | **Gap (deferred by design)**: 1

| TR-ID | System | Requirement | ADR(s) | Status |
|---|---|---|---|---|
| TR-res-001 | resource-system | Resource mutations traceable to trigger; formulas shared live/offline | ADR-0001, ADR-0006 | ✅ covered |
| TR-hist-001 | history-flag-system | Flag log + pattern counters, single Autoload owner | ADR-0001 | ✅ covered |
| TR-save-001 | save-persistence-system | Autoload-owned save I/O, mark_dirty/save_now/load_save | ADR-0001, ADR-0002 | ✅ covered |
| TR-save-002 | save-persistence-system | Atomic write via temp-file + rename, survives process kill | ADR-0002 | ✅ covered |
| TR-save-003 | save-persistence-system | schema_version field, corruption/mismatch fallback | ADR-0002 | ✅ covered |
| TR-off-001 | offline-progress-system | Stepped 1-min simulation, capped 1440 iterations (24h) | ADR-0006 | ✅ covered |
| TR-off-002 | offline-progress-system | Launch-time init sequencing | ADR-0003 | ✅ covered |
| TR-act-001 | action-system | Single Timer, single-concurrency, 3 actions 4-9s | ADR-0004 | ✅ covered |
| TR-dcs-001 | decision-card-system | Weighted-random pick scaled by Cringe | ADR-0005 | ✅ covered |
| TR-dcs-002 | decision-card-system | Cooldown counted in completed actions, default 2 | ADR-0005 | ✅ covered |
| TR-onb-001 | onboarding-tutorial | Card suppression (Phase 1) + force-cooldown-zero (1→2) | ADR-0001, ADR-0003, ADR-0005 | ✅ covered |
| TR-aui-001 | action-ui | Progress bar, per-frame poll, not throttled | ADR-0004, ADR-0007 | ✅ covered |
| TR-cui-001 | card-ui | Swipe/drag modal presentation, commitment threshold | ADR-0008 | ✅ covered |
| TR-ors-001 | offline-report-screen | Offline result presentation, dismiss gesture | ADR-0009 | ✅ covered |
| TR-cps-001 | class-path-system | ClassPathSystem Autoload owns affiliation floats [0–100], tier ints [0–5], active path | ADR-0010 | ✅ covered |
| TR-cps-002 | class-path-system | Card resolution → additive card_resolved signal → path counter + affiliation recalc | ADR-0010 | ✅ covered |
| TR-cps-003 | class-path-system | ActionSystem applies tier multiplier via pull-model get_active_multiplier(action_id) | ADR-0010 | ✅ covered |
| TR-cps-004 | class-path-system | Save/restore affiliation + tier via restore_state(data) (ADR-0003 pattern) | ADR-0010 | ✅ covered |
| TR-cps-005 | class-path-system | reset_era_state resets era-local state, preserves meta milestone flags | ADR-0010 | ⚠️ partial (BurnoutSystem wiring deferred to Alpha) |
| TR-cps-006 | class-path-system | Tier-5 signature card add/remove to DecisionCardSystem pool | — | ❌ gap (Alpha scope) |
| TR-cps-007 | class-path-system | Path multipliers excluded from offline progress by default (Pillar 4) | ADR-0006, ADR-0010 | ⚠️ partial (behaviour correct, not stated explicitly) |
| TR-juice-001 | juice-feedback-system | Magnitude formula — linear/log, max-of-contributions, clamp [0,1] | ADR-0011 | ✅ covered |
| TR-juice-002 | juice-feedback-system | Two mutually-exclusive channels (Action count-up+flash / Card pulse+shake+stinger) | ADR-0011 | ✅ covered |
| TR-juice-003 | juice-feedback-system | No-valence-coding, structurally testable (abs-only) | ADR-0011 | ✅ covered |
| TR-juice-004 | juice-feedback-system | Zero-magnitude still plays lowest tier | ADR-0011 | ✅ covered |
| TR-juice-005 | juice-feedback-system | Payoff text duration formula, clamp [1.5, 2.5]s | ADR-0011 | ⚠️ partial (verify existing beat matches GDD bounds in Story 9-2) |
| TR-juice-006 | juice-feedback-system | Backgrounding leaves clean state, no persisted state | ADR-0011 | ✅ covered |
| TR-juice-007 | juice-feedback-system | resolution_reaction content per card/option | ADR-0011 | ✅ covered |

**Foundation layer coverage**: 5/5 Foundation-tier requirements (TR-res-001, TR-hist-001, TR-save-001/002/003) are ✅ covered — **zero Foundation gaps**.

**Partials / gaps**: all four remaining non-covered items are Vertical-Slice/Alpha-scoped
deferrals, not Foundation/Core gaps:
- TR-cps-005, TR-cps-007 — Class Path Alpha deferrals (BurnoutSystem wiring; explicit
  offline-exclusion statement). Behaviour correct today.
- TR-cps-006 — Tier-5 signature cards, Alpha scope, needs a follow-up ADR.
- TR-juice-005 — payoff-duration formula verification against the existing CardScreen
  resolution beat, to confirm during Story 9-2.

## Source

Regenerate this table from `docs/architecture/tr-registry.yaml` whenever `/architecture-review`
is re-run. Do not let this file drift from the YAML — the YAML is authoritative.
