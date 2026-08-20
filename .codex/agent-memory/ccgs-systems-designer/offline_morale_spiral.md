---
name: offline-morale-spiral
description: Offline Progress System's stepped simulation drives Morale to 0 within ~2-3h of offline time for most players, since H grows unboundedly and Morale has no offline recovery source — locking the Zasięgi multiplier at 0.5x (Critical band) for the remainder of any 24h offline cap.
metadata:
  type: project
---

In "Król Cringe'u" Offline Progress System (design/gdd/offline-progress-system.md), worked example
Cringe=50, H0=5, M0=80%, Δt=24h capped: Morale crashes through all bands (High→Normal→Low→Critical)
within roughly the first 70-90 minutes of offline time, then sits at M=0/Mult=0.5x for ~21-22 of the
24 offline hours, while Hatersi (H) keeps growing unboundedly (H0=5 -> ~394 by 24h at Cringe=50).

**Why:** Resource System's locked constants (H_base=0.02, H_exp=2.0, H_max_add=1.0, M_drain_per_hater=0.15,
N_buffer=3, M_drain_exp=1.3) give Hatersi monotonic unbounded growth with no Morale recovery term and no
Hatersi ceiling offline. Once H exceeds N_buffer=3 (true almost immediately for any progressed player),
M_drain accelerates as H^1.3 and there is nothing pushing Morale back up while offline (no actions/cards
fire offline, per Core Rules). This means every returning player past early game gets the same terminal
state every day: Morale=0, Mult capped at the worst band, for the bulk of their offline window.

**How to apply:** This is a feedback-loop problem in Resource System's formulas (Formula A "Hatersi growth"
+ Formula B "Morale drain"), not a bug in the offline simulation's stepping logic — the stepped algorithm
correctly reproduces what the formulas say. Flagged as an open question for game-designer/creative-director:
options discussed were (A) add an offline Morale regen term, (B) cap/soften Hatersi growth offline, or
(C) accept the floor as an intended FOMO/urgency hook and lean into it in the Offline Report Screen's
framing. Did not pick unilaterally — escalate any decision that touches Resource System's locked constants
back through game-designer before editing design/gdd/resource-system.md or the registry.
