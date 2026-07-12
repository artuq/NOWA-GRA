# Systems Index: Król Cringe'u

> **Status**: Draft
> **Created**: 2026-06-19
> **Last Updated**: 2026-06-19
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

Król Cringe'u jest idle/incremental tycoonem na mobile, gdzie gracz wybiera akcje trwające w czasie (select-and-wait, jak Melvor Idle), zamiast tapować w kółko. Karty decyzji moralnych (styl Reigns) generują zasoby i kumulują historię w postaci flag, które otwierają satyryczne ścieżki klas influencera. Cała architektura mechaniczna stoi na czterech pillarach: uczciwa matematyka rdzenia (Pillar 1), decyzje-jako-pamięć (Pillar 2), satyra przez mechanikę nie wykład (Pillar 3) i offline jako pierwsza klasa obywatelska (Pillar 4). Systemy poniżej rozkładają to na komponenty od fundamentu (zasoby, flagi, save) przez core (akcje, karty, offline progress) do feature/presentation/polish.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Resource System | Economy | MVP | Designed | design/gdd/resource-system.md | — |
| 2 | History Flag System | Narrative | MVP | Designed | design/gdd/history-flag-system.md | — |
| 3 | Save/Persistence System (inferred) | Persistence | MVP | Designed | design/gdd/save-persistence-system.md | — |
| 4 | Card Content Database (inferred) | Narrative | MVP | Designed | design/gdd/card-content-database.md | — |
| 5 | Action System | Gameplay | MVP | Designed | design/gdd/action-system.md | Resource System |
| 6 | Decision Card System | Narrative | MVP | Designed | design/gdd/decision-card-system.md | Card Content Database, History Flag System, Resource System |
| 7 | Offline Progress System | Core | MVP | Designed | design/gdd/offline-progress-system.md | Resource System, Save/Persistence System |
| 8 | Action UI (inferred) | UI | MVP | Designed | design/gdd/action-ui.md | Action System |
| 9 | Card UI (inferred) | UI | MVP | Designed | design/gdd/card-ui.md | Decision Card System |
| 10 | Offline Report Screen (inferred) | UI | MVP | Designed | design/gdd/offline-report-screen.md | Offline Progress System |
| 11 | Onboarding/Tutorial (inferred) | Meta | MVP | Designed | design/gdd/onboarding-tutorial.md | Action System, Decision Card System |
| 12 | Class Path System | Progression | Vertical Slice | Designed | design/gdd/class-path-system.md | History Flag System, Decision Card System |
| 13 | Juice/Feedback System (inferred) | Audio | Vertical Slice | Designed | design/gdd/juice-feedback-system.md | Action System, Decision Card System |
| 14 | Main Navigation/Screen Flow (inferred) | UI | Vertical Slice | Not Started | — | Action UI, Card UI, Offline Report Screen |
| 15 | Team/Staff Management | Economy | Alpha | Not Started | — | Resource System, Offline Progress System |
| 16 | Staff/Sponsor UI (inferred) | UI | Alpha | Not Started | — | Team/Staff Management |
| 17 | Prestige/Checkpoint System | Progression | Alpha | Not Started | — | Class Path System, Offline Progress System, Save/Persistence System |
| 18 | Cosmetic Persona Customization | UI | Full Vision | Not Started | — | Class Path System |

---

## Categories

| Category | Description | Typical Systems |
|----------|-------------|-----------------|
| **Gameplay** | The systems that make the game fun | Action System |
| **Economy** | Resource creation and consumption | Resource System, Team/Staff Management |
| **Narrative** | Story and dialogue delivery | History Flag System, Card Content Database, Decision Card System |
| **Progression** | How the player grows over time | Class Path System, Prestige/Checkpoint System |
| **Core** | Foundation systems everything depends on | Offline Progress System |
| **Persistence** | Save state and continuity | Save/Persistence System |
| **UI** | Player-facing information displays | Action UI, Card UI, Offline Report Screen, Staff/Sponsor UI, Main Navigation/Screen Flow, Cosmetic Persona Customization |
| **Audio** | Sound and music systems | Juice/Feedback System |
| **Meta** | Systems outside the core game loop | Onboarding/Tutorial |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required for the core loop to function. Without these, you can't test "is this fun?" | First playable prototype | Design FIRST |
| **Vertical Slice** | Required for one complete, polished area. Demonstrates the full experience. | Vertical slice / demo | Design SECOND |
| **Alpha** | All features present in rough form. Complete mechanical scope, placeholder content OK. | Alpha milestone | Design THIRD |
| **Full Vision** | Polish, edge cases, nice-to-haves, and content-complete features. | Beta / Release | Design as needed |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. Resource System — base currencies (Cringe, Zasięgi, Hatersi, Morale, Sponsorzy); everything else reads/writes these
2. History Flag System — pure data structure recording decision history; nothing needs to exist before it
3. Save/Persistence System — serialization infrastructure; needed before anything can be considered "real" across sessions
4. Card Content Database — static content data (10-15+ cards); structurally independent of any system logic

### Core Layer (depends on foundation)

1. Action System — depends on: Resource System
2. Decision Card System — depends on: Card Content Database, History Flag System, Resource System
3. Offline Progress System — depends on: Resource System, Save/Persistence System

### Feature Layer (depends on core)

1. Class Path System — depends on: History Flag System, Decision Card System
2. Team/Staff Management — depends on: Resource System, Offline Progress System
3. Prestige/Checkpoint System — depends on: Class Path System, Offline Progress System, Save/Persistence System

### Presentation Layer (depends on features)

1. Action UI — depends on: Action System
2. Card UI — depends on: Decision Card System
3. Offline Report Screen — depends on: Offline Progress System
4. Staff/Sponsor UI — depends on: Team/Staff Management
5. Cosmetic Persona Customization — depends on: Class Path System
6. Main Navigation/Screen Flow — depends on: Action UI, Card UI, Offline Report Screen
7. Juice/Feedback System — depends on: Action System, Decision Card System

### Polish Layer (depends on everything)

1. Onboarding/Tutorial — depends on: Action System, Decision Card System

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Resource System | MVP | Foundation | game-designer, economy-designer | M |
| 2 | History Flag System | MVP | Foundation | game-designer, narrative-director | M |
| 3 | Save/Persistence System | MVP | Foundation | technical-director, godot-specialist | S |
| 4 | Card Content Database | MVP | Foundation | narrative-director, writer | M |
| 5 | Action System | MVP | Core | game-designer | M |
| 6 | Decision Card System | MVP | Core | game-designer, narrative-director | L |
| 7 | Offline Progress System | MVP | Core | game-designer, technical-director | L |
| 8 | Action UI | MVP | Presentation | ui-programmer, ux-designer | S |
| 9 | Card UI | MVP | Presentation | ui-programmer, ux-designer | M |
| 10 | Offline Report Screen | MVP | Presentation | ui-programmer, ux-designer | S |
| 11 | Onboarding/Tutorial | MVP | Polish | ux-designer, game-designer | S |
| 12 | Class Path System | Vertical Slice | Feature | game-designer, systems-designer | L |
| 13 | Main Navigation/Screen Flow | Vertical Slice | Presentation | ux-designer, ui-programmer | M |
| 14 | Juice/Feedback System | Vertical Slice | Presentation | technical-artist, sound-designer | S |
| 15 | Team/Staff Management | Alpha | Feature | economy-designer, game-designer | M |
| 16 | Staff/Sponsor UI | Alpha | Presentation | ui-programmer | S |
| 17 | Prestige/Checkpoint System | Alpha | Feature | game-designer, systems-designer | M |
| 18 | Cosmetic Persona Customization | Full Vision | Presentation | art-director, ui-programmer | M |

---

## Circular Dependencies

- None found.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Resource System | Scope | Bottleneck — Action, Decision Card, Offline Progress, and Team/Staff all depend on it. A design error here cascades into every other system. | Design and lock this GDD first; review tuning knobs carefully before any other system references it |
| History Flag System | Design | Bottleneck for the satirical narrative (Pillar 2) — if flag resolution logic is unclear, Class Path System has nothing reliable to branch on | Design with explicit flag-to-path resolution table before writing Decision Card System content |
| Offline Progress System | Technical | Core hypothesis of the MVP ("offline is satisfying") — delta-time math and background simulation must be correct from day one | Prototype the offline math in isolation (`/prototype`) before building the full system GDD |
| Decision Card System | Design | Satire may not be perceived as satire — players might just optimize numbers without recognizing the critique (noted as a Design Risk in game-concept.md) | Playtest early drafts of cards specifically for whether testers notice the satirical intent |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 18 |
| Design docs started | 13 |
| Design docs reviewed | 0 |
| Design docs approved | 0 |
| MVP systems designed | 11/11 |
| Vertical Slice systems designed | 2/3 |

---

## Next Steps

- [ ] Review and approve this systems enumeration
- [ ] Design MVP-tier systems first (use `/design-system [system-name]`)
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check pre-production` when MVP systems are designed
- [ ] Validate the highest-risk systems with `/vertical-slice` before committing to Production
