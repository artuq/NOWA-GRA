# Accessibility Requirements

> **Status**: Committed
> **Tier**: Basic
> **Author**: user + ux-designer
> **Last Updated**: 2026-07-22

## Tier Definition

**Basic** — covers the accessibility needs already implied by the game's existing design decisions, made explicit and binding rather than incidental. Does not commit to full WCAG-AA (screen reader support, full remapping, etc.) for the MVP — those are deferred, not rejected, and can be revisited at Polish phase if scope allows.

## Commitments

1. **Touch target size**: All interactive elements (buttons, swipe cards, dismiss areas) meet a minimum 44×44dp touch target, per `technical-preferences.md`'s "zero hover-only interactions" rule. No interactive element may be smaller.
2. **No information conveyed by color alone**: Every GDD-level anti-pillar against moral/valence color-coding (Resource HUD, Action Grid, Card UI, Offline Report Screen) doubles as a colorblind-accessibility commitment — resource/state meaning is always carried by icon, label, or position, never color alone. This is already locked at the design level across all 4 UI-bearing GDDs; this document makes it an explicit accessibility requirement, not just a satirical-tone choice.
3. **Text contrast**: Body and label text maintains a minimum 4.5:1 contrast ratio against its background (WCAG-AA text contrast threshold, adopted here without committing to the rest of WCAG-AA).
4. **No motion-only feedback for critical information**: Per the established pattern (Morale band crash communicated through "magnitude of motion/scale," never color alone, per `offline-report-screen.md`), critical state changes must always pair motion with a textual/iconic indicator — motion alone is not sufficient for a player with vestibular sensitivity to safely disable.
5. **Reduced-motion is shipped and MANDATORY, not deferred** *(corrected 2026-07-22 — superseded by `art-bible.md` §7, 2026-07-07 MANDATE, and `SettingsSystem.reduce_motion`, both already shipped since before this correction; this commitment's original "deferred to Polish" text was stale)*: a `SettingsSystem.reduce_motion` toggle exists and is honored by every animated UI element gated on it — shake amplitude/duration gate to near-zero; scale-pulse, flash, and stinger are explicitly unaffected (they already carry the no-valence guarantee); panel fade transitions (Main Navigation/Screen Flow, Meta-Bonus Visibility) shorten to near-instant. Any new animated UI element added to this project MUST wire into this existing flag, not treat reduced-motion as a future nice-to-have.

## Explicitly Deferred (not in scope for MVP)

- Screen reader / TalkBack support
- Full input remapping (N/A — touch-only, single input method)
- Text scaling / dynamic font size
- Full WCAG-AA screen-by-screen audit

## Open Questions

- **Text scaling** — Android system font-scaling settings are not currently tested against any UI Requirements section. *Owner: first UX spec authored per-screen. Target: Pre-Production, when first screen UX spec is written.*
