# Web Publishing Best Practices — Poki/CrazyGames Intelligence

**Source**: Poki platform interview (Romy) — analyzed by QA colleague, 2026-07-06
**Status**: Reference — feeds Sprint 10 web-spike acceptance criteria and Alpha scope priorities
**Related**: `.claude/docs/technical-preferences.md` (web target confirmed 2026-07-06)

## Hard metrics (platform algorithm inputs)

| Metric | Threshold | King of Cringe status |
|---|---|---|
| Load time (Godot/Unity web avg) | ~32s vs 20s for H5 engines — every second kills CTP (Conversion to Play) | Unknown — **web-export spike must measure this first** |
| Initial download | ≤ 10 MB | Godot 4 wasm runtime alone is the main cost (brotli-compressed ~8-10 MB) — game assets currently tiny (icons + 1 font, no audio). Tight but plausible; measure in spike |
| Total game weight | ≤ 40 MB | Currently trivially under; future audio (stinger family, music loops) must stream/lazy-load, never bundle into initial |
| Smart loading | Core loop first, heavy assets in background | Card mechanic core is light; when audio lands (post-art-bible), load it deferred — architecture note for /asset-spec |
| Time-to-judgment | 15–20s INCLUDING load | See onboarding note below |
| Avg session on portal | ~22 min across ~3 games → 6–10 min per title | First 10 minutes must hook — aligns with existing first-5-min reference-games analysis |
| Day-0 content need | 25–30 min of coherent, CLOSED gameplay | **Maps exactly to one Final Burnout era arc** (build → burnout → reset). Strengthens the case for Final Burnout + era loop as the web-launch content spine (Alpha) — no Day-7/Day-30 retention mechanics needed for launch |
| Web traffic split | 48% mobile / 52% desktop, mobile trending up | Both input paths first-class: swipe (done) + mouse drag threshold feel-test (Sprint 10 candidate) |

## Implications by area

### 1. Web-export spike (Sprint 10 candidate) — acceptance criteria extended
Beyond "does it run on Compatibility renderer": measure cold-load time and initial-download size against the 10 MB / ~20-30s bars; test brotli compression hosting requirements; verify iframe embedding.

### 2. Onboarding — the 15-second rule (design question, needs game-designer pass)
Current flow: boot → action screen; first Decision Card appears only after 2 completed actions (~12-18s of tapping). For web, the interview suggests the first card (the game's identity moment) should hit near-instantly. Candidate tuning: web builds present the first card immediately (or after 1 action), no menus, no text walls. OnboardingGate already owns phase gating — this is a tuning/config change, not architecture. **Do not implement without a design decision** — log for next design session.

### 3. Hover video / thumbnail (marketing asset, production backlog)
The autoplay-on-hover gameplay clip is the primary CTR driver. The juice work (pulse + retuned shake + count-ups) is exactly what should headline that clip — swipe-resolve-shake loops read instantly. Task lands when store/portal assets are produced (Release phase), but capture good footage habitually once art bible lands.

### 4. Content scope guidance (Alpha planning input)
25–30 min closed loop > weeks of retention systems. Priority order this suggests for Alpha: Final Burnout era loop (the closed arc) > Prestige meta-bonuses (Day-1+ retention) > Team/Staff Management (long-tail). Challenge Era Runs and Soft Reach Cap stay deferred behind the era loop itself.

## Follow-up hooks
- Sprint 10 planning: web-export spike ACs now include the load/size measurements above
- Next `/design-system` or design session: 15-second onboarding tuning question
- Release phase: hover-video asset task (showcase juice)
