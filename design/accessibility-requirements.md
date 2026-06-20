# Accessibility Requirements

> **Status**: Committed
> **Tier**: Basic
> **Author**: user + ux-designer
> **Last Updated**: 2026-06-20

## Tier Definition

**Basic** — covers the accessibility needs already implied by the game's existing design decisions, made explicit and binding rather than incidental. Does not commit to full WCAG-AA (screen reader support, full remapping, etc.) for the MVP — those are deferred, not rejected, and can be revisited at Polish phase if scope allows.

## Commitments

1. **Touch target size**: All interactive elements (buttons, swipe cards, dismiss areas) meet a minimum 44×44dp touch target, per `technical-preferences.md`'s "zero hover-only interactions" rule. No interactive element may be smaller.
2. **No information conveyed by color alone**: Every GDD-level anti-pillar against moral/valence color-coding (Resource HUD, Action Grid, Card UI, Offline Report Screen) doubles as a colorblind-accessibility commitment — resource/state meaning is always carried by icon, label, or position, never color alone. This is already locked at the design level across all 4 UI-bearing GDDs; this document makes it an explicit accessibility requirement, not just a satirical-tone choice.
3. **Text contrast**: Body and label text maintains a minimum 4.5:1 contrast ratio against its background (WCAG-AA text contrast threshold, adopted here without committing to the rest of WCAG-AA).
4. **No motion-only feedback for critical information**: Per the established pattern (Morale band crash communicated through "magnitude of motion/scale," never color alone, per `offline-report-screen.md`), critical state changes must always pair motion with a textual/iconic indicator — motion alone is not sufficient for a player with vestibular sensitivity to safely disable.
5. **Reduced-motion consideration deferred, flagged**: full reduced-motion mode (disabling count-up animations, card entrance slides, etc.) is NOT committed for MVP — flagged as an Open Question below for Polish-phase reconsideration.

## Explicitly Deferred (not in scope for MVP)

- Screen reader / TalkBack support
- Full input remapping (N/A — touch-only, single input method)
- Text scaling / dynamic font size
- Reduced-motion toggle
- Full WCAG-AA screen-by-screen audit

## Open Questions

- **Reduced-motion mode** — deferred per Commitment 5. Revisit at Polish phase if a player or playtester flags motion sensitivity as a real barrier. *Owner: future `/ux-design` revision. Target: Polish.*
- **Text scaling** — Android system font-scaling settings are not currently tested against any UI Requirements section. *Owner: first UX spec authored per-screen. Target: Pre-Production, when first screen UX spec is written.*
