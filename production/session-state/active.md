# Session State

<!-- File-backed memory. Read this first after any compaction or new session. -->

## Current Task
Designing Save/Persistence System GDD (`design/gdd/save-persistence-system.md`)

## Current Section
Starting (skeleton created)

## File
design/gdd/save-persistence-system.md

## Progress Checklist
- [x] Resource System, History Flag System, Card Content Database, Action System, Decision Card System GDDs complete (5/11 MVP)
- [x] consistency-check PASS x4
- [ ] Save/Persistence System — IN PROGRESS (out-of-order #3 in design order, skipped earlier, now being corrected)
- [ ] Remaining MVP GDDs: Offline Progress System, Action UI, Card UI, Offline Report Screen, Onboarding/Tutorial

## Key Context for This GDD
- Must define what state gets serialized: Resource System's 5 resources, History Flag System's milestone flags + pattern counters, Decision Card System's cooldown state + milestone exclusions
- Pillar 4 alignment: this is the foundation Offline Progress System needs to function
- No engine-reference module for save/load yet, but standard Godot functionality, low technical risk

## Next
Continue Save/Persistence System section-by-section design, starting with Overview.
