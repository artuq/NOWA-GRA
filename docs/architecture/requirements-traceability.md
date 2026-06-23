# Requirements Traceability Index

> Human-readable index over `docs/architecture/tr-registry.yaml` (the machine-readable
> source of truth, maintained by `/architecture-review`). This file exists to satisfy
> gate-check's literal filename check — do not hand-edit requirement entries here;
> edit `tr-registry.yaml` and regenerate this table, or run `/architecture-review` again.

**Last updated**: 2026-06-20 (from `tr-registry.yaml` v1)
**Total requirements**: 14 | **Covered**: 11 | **Partial**: 1 | **Gap (deferred by design)**: 2

> Note: the original `/architecture-review` report cited 17 total / 12 covered against a broader baseline drawn directly from `architecture.md`'s Technical Requirements Baseline. `tr-registry.yaml` (this table's source) persists 14 of those as stable TR-IDs — the count difference is `tr-registry.yaml` consolidating a few closely-related baseline items under single IDs, not a coverage regression. Treat `tr-registry.yaml` as authoritative going forward.

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
| TR-aui-001 | action-ui | Progress bar, per-frame poll, not throttled | ADR-0004 | ⚠️ partial |
| TR-cui-001 | card-ui | Swipe/drag modal presentation, commitment threshold | — | ❌ gap (deferred) |
| TR-ors-001 | offline-report-screen | Offline result presentation, dismiss gesture | — | ❌ gap (deferred) |

**Foundation layer coverage**: 5/5 Foundation-tier requirements (TR-res-001, TR-hist-001, TR-save-001/002/003) are ✅ covered — **zero Foundation gaps**, satisfying this gate's traceability requirement.

**Deferred gaps**: TR-cui-001 and TR-ors-001 are intentionally deferred per `architecture.md`'s own "Required ADRs → Can defer to implementation" list — both are conventional Control-node UI patterns, low architectural risk, fully specified at the GDD level already. Not a Foundation or Core gap.

**Partial**: TR-aui-001 — `ADR-0004` defines `get_progress()` as a polled method, satisfying the "every frame, not throttled" requirement, but doesn't separately address whether polling vs. a per-frame signal is the right long-term contract between Core and Presentation. Flagged by Technical Director at the Pre-Production gate-check as the first thing to validate once the Vertical Slice exercises this path.

## Source

Regenerate this table from `docs/architecture/tr-registry.yaml` whenever `/architecture-review` is re-run. Do not let this file drift from the YAML — the YAML is authoritative.
