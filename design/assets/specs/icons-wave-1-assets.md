# Asset Specs — Icons Wave 1 (6 actions + 5 resources)

> **Source**: design/assets/entity-inventory.md (#1–11) + design/art/art-bible.md §7 semantic map
> **Art Bible**: design/art/art-bible.md
> **Status**: 11 specced / 0 in production / 0 done

## Shared Technical Block (all 11)

- 32×32 PNG RGBA, final export transparent bg, no AA, thick dark outline + flat fill, NO highlight/sheen (2-tone budget: outline / fill), 1–2 cutouts max where the concept needs one, pixel-perfect edges — see art-bible.md §7
- Generation happens on a solid flat magenta background (`#FF00FF`) — keys out cleanly in Aseprite cleanup, never appears elsewhere in the palette, never shipped
- Naming: `icon_action_[name].png` / `icon_resource_[name].png` → `assets/ui/icons/`
- `.ase` source → `assets/_source/icons/` (mirror 1:1)
- Godot import: `texture_filter = 1` (NEAREST) at node, mipmaps off, `compress/mode=0` lossless, `.import` committed with PNG
- Color families: **actions = pale lavender-blue fill + dark indigo outline** — controls, not metrics; **resources = vibrant version of the locked §4 hex + dark outline of the same hue** — sole exception: vlog rec-dot stays `#E5484D` as a 3rd accent tone
- Acceptance: 5 resource icons must stay distinguishable in **grayscale render** (§4 colorblind criterion)

---

## ASSET-001 — Record a Vlog — `icon_action_vlog.png`
Rounded camera body with a triangular lens/viewfinder flap on the side (classic camcorder silhouette), ~70% frame; solid rec-dot `#E5484D` on the body — only non-neutral color in the action set.
> A 2D video game UI icon of a video camera — a rounded camera body with a triangular lens flap on the side, like a classic camcorder silhouette — with a small solid red recording dot on the body, low-resolution 32×32 pixel art style, retro 8-bit game asset. Monochromatic pale lavender-blue color palette with thick dark indigo bold outlines. Flat solid color fill, no shading, no highlights, no gloss. No noise or dither texture. Simple silhouette, minimal detail. Isolated on a solid flat magenta (#FF00FF) background, minimalist design, highly readable for mobile games.

## ASSET-002 — Make Drama — `icon_action_drama.png`
Megaphone, bell to upper-right, diagonal cone; one jagged crack through the bell as a cutout notch.
> A 2D video game UI icon of a megaphone angled diagonally, with one jagged crack cut through the bell, low-resolution 32×32 pixel art style, retro 8-bit game asset. Monochromatic pale lavender-blue color palette with thick dark indigo bold outlines. Flat solid color fill, no shading, no highlights, no gloss. Isolated on a solid flat magenta (#FF00FF) background, minimalist design, highly readable for mobile games.

## ASSET-003 — Apologize Online — `icon_action_apologize.png`
**Concept revised 2026-07-11** — "hand + note" was too oblique. Praying/pleading hands (two hands pressed together, classic "sorry/begging" gesture) reads instantly — user referenced a stock line-icon (outline-only, no fill), shape adopted, style rejected (not pixel art, no fill).
> A 2D video game UI icon of two hands pressed together in a praying/pleading gesture (like a sorry or begging gesture), low-resolution 32×32 pixel art style, retro 8-bit game asset. Monochromatic pale lavender-blue color palette with thick dark indigo bold outlines. Flat solid color fill, no shading, no highlights, no gloss. Isolated on a solid flat magenta (#FF00FF) background, minimalist design, highly readable for mobile games.

## ASSET-004 — Record a Collab — `icon_action_collab.png`
**Concept revised 2026-07-11** — two overlapping webcam circles didn't read distinct from ASSET-001 (the risk this entry already flagged). Handshake reads instantly as "collab" and is automatically distinct from the camcorder silhouette. User referenced a stock line-icon (outline-only, no fill), shape adopted, style rejected. **Note**: Sponsors (ASSET-011) also uses a handshake-derived concept (abstracted to two chevrons) — no collision, different execution (literal hands vs abstract chevrons) and different color family (action lavender vs resource green).
> A 2D video game UI icon of a handshake — two hands clasped together in a handshake gesture, low-resolution 32×32 pixel art style, retro 8-bit game asset. Monochromatic pale lavender-blue color palette with thick dark indigo bold outlines. Flat solid color fill, no shading, no highlights, no gloss. Isolated on a solid flat magenta (#FF00FF) background, minimalist design, highly readable for mobile games.

## ASSET-005 — Give an Interview — `icon_action_interview.png`
**Concept revised 2026-07-11** — a bare mic read as generic "record audio," not specifically "interview." A hand gripping a microphone (with a short cable) reads as interviewer-holding-mic instantly. User referenced a stock line-icon (outline-only, no fill), shape adopted, style rejected.
> A 2D video game UI icon of a hand gripping a microphone with a short cable trailing from its base, low-resolution 32×32 pixel art style, retro 8-bit game asset. Monochromatic pale lavender-blue color palette with thick dark indigo bold outlines. Flat solid color fill, no shading, no highlights, no gloss. Isolated on a solid flat magenta (#FF00FF) background, minimalist design, highly readable for mobile games.

## ASSET-006 — Launch a Course — `icon_action_course.png`
**Concept revised 2026-07-11** — browser window (rounded frame, top chrome bar with 3 dots) with an open book overlapping its lower-right corner. User referenced a stock line-icon, shape adopted, style rejected. **Risk flagged (art-director)**: 2 compound shapes (window + book) is more elements than any other icon in the set (all others are 1 shape + 1 accent) — recheck legibility after Aseprite cleanup at actual 32px/chip scale; simplify to book-only + play-triangle if it reads muddy.
> A 2D video game UI icon of a browser window (rounded rectangle frame with a top chrome bar containing three small dots) with a small open book overlapping its lower-right corner, low-resolution 32×32 pixel art style, retro 8-bit game asset. Monochromatic pale lavender-blue color palette with thick dark indigo bold outlines. Flat solid color fill, no shading, no highlights, no gloss. Isolated on a solid flat magenta (#FF00FF) background, minimalist design, highly readable for mobile games.

## ASSET-007 — Reach — `icon_resource_reach.png` — base `#4A8A91` (teal)
**Concept revised 2026-07-11** — eye+signal-arc was too abstract for "audience-size metric." Hub-and-spoke network glyph (central person-in-circle, 6 small satellite nodes radiating out on connecting lines) reads clearly as "your reach extends outward" and stays a single organized silhouette (radial symmetry scales down cleaner than a crowd of overlapping figures — rejected the crowd/browser-window variants for that reason). User referenced stock line-icons, shape adopted, style rejected.
> A 2D video game UI icon of a network glyph — a central person silhouette inside a circle, with 6 small satellite circles radiating outward on connecting lines, low-resolution 32×32 pixel art style, retro 8-bit game asset. Vibrant cyan-teal color palette with thick dark teal-navy bold outlines. Flat solid color fill, no shading, no highlights, no gloss. Isolated on a solid flat magenta (#FF00FF) background, minimalist design, highly readable for mobile games.
**Grayscale check** vs ASSET-011.

## ASSET-008 — Cringe — `icon_resource_cringe.png` — base `#9A6B92` (mauve)
Rounded speech-bubble shard (no tail); one jagged diagonal crack splits it into two slightly separated pieces.
> A 2D video game UI icon of a rounded speech-bubble shard split by one jagged diagonal crack into two slightly separated pieces, low-resolution 32×32 pixel art style, retro 8-bit game asset. Vibrant magenta-mauve color palette with thick dark deep plum bold outlines. Flat solid color fill, no shading, no highlights, no gloss. Isolated on a solid flat magenta (#FF00FF) background, minimalist design, highly readable for mobile games.
**Grayscale check** vs ASSET-009 — **elevated risk (2026-07-11)**: both are now speech-bubble silhouettes on adjacent purple hues, so the shape-backup that used to separate them (bubble vs fist) is gone. Differentiation now rides on the interior content (crack vs symbol-cluster) — check this pair extra carefully at grayscale/chip scale before signing off.

## ASSET-009 — Haters — `icon_resource_haters.png` — base `#6F62A8` (violet)
**Concept revised 2026-07-11** — clenched fist worked but a censored-profanity speech bubble (comic-book `#!$!` symbol cluster) reads more specifically as "hostile comments" and pairs thematically with Cringe (ASSET-008, also a speech-bubble icon) — both communication-metric icons now share a family shape. Rejected an alternate reference (head + 3 thumbs-down hands): reintroduces a face (Section 5 reserves faces for the avatar only) and adds too many compound elements for 32px, same problem flagged on ASSET-007's crowd variant.
> A 2D video game UI icon of a comic-book speech bubble containing a cluster of censored profanity symbols (#, !, $), low-resolution 32×32 pixel art style, retro 8-bit game asset. Vibrant blue-violet color palette with thick dark deep indigo bold outlines. Flat solid color fill, no shading, no highlights, no gloss. Isolated on a solid flat magenta (#FF00FF) background, minimalist design, highly readable for mobile games.
**Grayscale check** vs ASSET-008 — see elevated-risk note above.

## ASSET-010 — Morale — `icon_resource_morale.png` — base `#A88F5C` (tan/gold)
**Concept revised 2026-07-11** — battery read as generic "energy," not specifically "team wellbeing." Single static flame — classic "team spirit" idiom ("keep morale burning"), one flat shape, NO size/intensity variants or comparison states (rejected reference showed a 3-state high/neutral/low flame scale with trend labels — that's a gauge in disguise, same forbidden pattern). One flame, one size, one color — never implies a level.
> A 2D video game UI icon of a single simple flame glyph, low-resolution 32×32 pixel art style, retro 8-bit game asset. Vibrant amber-gold color palette with thick dark deep brown bold outlines. Flat solid color fill, no shading, no highlights, no gloss. Isolated on a solid flat magenta (#FF00FF) background, minimalist design, highly readable for mobile games.

## ASSET-011 — Sponsors — `icon_resource_sponsors.png` — base `#5C8F68` (green)
**Concept revised 2026-07-11** — chevron gen came out as a jagged star/pinwheel, didn't read as "sponsors" anyway. Handshake + dollar-coin above reads instantly as "sponsorship deal." **Flagged collision (art-director)**: Collab (ASSET-004) is also a literal handshake — these two icons now share a base silhouette, differentiated only by the coin accent + color family (action lavender vs resource green). §4's accessibility backstop principle wants silhouette to carry meaning independent of color; this pair leans on color+accent instead. User decided to keep it anyway — accepted risk, not overlooked.
> A 2D video game UI icon of a handshake with a small dollar-sign coin floating above it, low-resolution 32×32 pixel art style, retro 8-bit game asset. Vibrant green color palette with thick dark deep forest green bold outlines. Flat solid color fill, no shading, no highlights, no gloss. Isolated on a solid flat magenta (#FF00FF) background, minimalist design, highly readable for mobile games.
**Grayscale check** vs ASSET-007 AND vs ASSET-004 (new — silhouette collision, see note above).

---

## Production checklist (per icon)
1. Copy the prompt block → Nano Banana → pick best gen
2. Aseprite cleanup: downscale 1024→32 Nearest Neighbor, index/quantize to exactly 2 colors (outline/fill), flatten any noise/dither, simplify to 1 shape + 1 accent max, key magenta bg → transparent
3. Export PNG → `assets/ui/icons/[name].png`; save `.ase` → `assets/_source/icons/`
4. Resource icons: grayscale render check (pairs 007/011, 008/009)
5. Integration story wires scenes to new paths + sets NEAREST filter per node
