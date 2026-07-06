# Web Export Spike — GO/NO-GO (Sprint 10, task 10-1 + 10-2)

**Date**: 2026-07-06
**Verdict**: **GO** ✅

## Measurements vs Poki/CrazyGames bars

| Metric | Bar | Measured | Verdict |
|---|---|---|---|
| Initial download (brotli) | ≤ 10 MB | **~6.8 MB** (wasm 6.49 + pck 0.21 + js 0.07) | ✅ PASS |
| Initial download (gzip fallback) | ≤ 10 MB | ~9.7 MB | ✅ PASS (tight) |
| Total game weight | ≤ 40 MB | 38 MB raw / ~6.8 MB compressed | ✅ PASS |
| Game content (pck) | — | **0.36 MB raw** (after excluding gdUnit4 addon) | headroom ~3 MB initial for future assets |

**Hosting requirement**: brotli-compressed serving (portals do this natively). Self-hosting needs `Content-Encoding: br` support.

## Export configuration (export_presets.cfg, "Web" preset)

- **Template**: 4.6.2.stable web_nothreads_release (`variant/thread_support=false` — deliberate: no SharedArrayBuffer/COOP-COEP requirement, works on every portal without cross-origin-isolation headers)
- **Renderer**: Compatibility (WebGL2) — automatic for web export; visual pass done (see findings)
- **exclude_filter**: build/prototypes/production/docs/design/tests/reports + **addons/gdUnit4** (was 1.4 MB of pck bloat)
- **canvas_resize_policy=0** + custom `html/head_include` shell (task 10-2): JS resizer locks the canvas to **9:16 portrait** (user decision 2026-07-06) fitted to window/iframe, centered, with a styled radial-gradient page background + canvas glow (no bare black bars). Transfers 1:1 to portal iframes — the shell ships in our index.html.

## Visual pass findings (Compatibility renderer) — 3 real bugs found & fixed

1. **Missing font glyphs** (cross-platform bug, not web-only): ← → (U+2190/92) and 🔒 emoji are NOT in OpenSans; desktop silently falls back to system fonts, wasm has none → hex boxes. Fixed: option markers → doubled guillemets `«« »»` (verified in font cmap); lock prefix → **padlock PNG badge** (LOCKED_ICON TextureRect) inline next to the title.
2. **Autowrap-in-HBox collapse**: the badge row (Label with WORD_SMART inside HBoxContainer) collapsed titles to 1 char/line. Fixed: autowrap OFF while locked, restored on unlock. Plus two runtime-node gotchas fixed: reparented nodes need `owner` restored (or owned `find_child()` prunes them) and the whole wrapper chain must be owned.
3. **Readability at 9:16**: font sizes raised after two user review passes — pills 19→24, action titles 24→28, action stats 16→24, card options 26→30 (+doubled guillemets). User + external verdict: readable.

## Remote test results (2026-07-06, Cloudflare quick tunnel, developer devices)

First real-network, real-device test — desktop browser + **mobile phone browser** (the 9:16 decision's target case):
- **Readability**: PASS on both devices (post font-raise sizes confirmed)
- **Swipe**: PASS with mouse (desktop) AND finger (mobile browser) — commitment threshold feels right on both, no tuning needed → **closes task 10-4** (external QA colleague may add a second data point later)
- **9:16 presentation**: PASS on both (phone: native full-view; desktop: pillarboxed)
- **Cold load on phone**: noticeably slow — EXPECTED: the tunnel served the raw 38 MB (python http.server, no compression). Portal serving with brotli cuts this 5.5× to ~6.8 MB; treat the tunnel timing as a worst-case ceiling, not the portal expectation. Real portal timing lands with the first upload (Release phase).

## Follow-ups

- **15-second onboarding (10-5)**: pending quick-design
- **Portal-side cold-load timing**: first portal/itch upload (Release phase) — tunnel test confirmed the mechanism, not the number
- **Font rendering quality**: sizes are fixed; if the FACE itself still strains eyes, that's an art-bible decision (typography section), not a size knob
- **Art pipeline unblocked need**: icons/thumbnail/hover-video all gated on `/art-bible` → `/asset-spec` — proposed Sprint 11 goal (user offers Aseprite + Nano Banana generation workflow)

## Local test loop

```
godot --headless --path . --export-release "Web" build/web/index.html
cd build/web && python3 -m http.server 8060   # http://localhost:8060
```
