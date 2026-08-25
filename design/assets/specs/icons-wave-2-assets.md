# Asset Specs — Icons Wave 2 (4 system/card icons, 32×32 redo)

> **Source**: design/assets/entity-inventory.md (#12–15) + design/art/art-bible.md §7 semantic map
> **Art Bible**: design/art/art-bible.md
> **Status**: 4 specced / 0 in production / 0 done
> Redo of items #13–15 (currently 16×16 placeholders per the locked 32×32 grid decision); #12 is new.

## Shared Technical Block (all 4)

Same rules as Wave 1 (`icons-wave-1-assets.md`) — thick dark outline + flat fill, NO highlight, magenta (`#FF00FF`) generation background, 32×32 PNG RGBA transparent export, `texture_filter=1` NEAREST per node, `.ase` sources in `assets/_source/icons/`.

**Color family**: all 4 are UI chrome (not action controls, not resource metrics) — using the same **pale lavender-blue + dark indigo outline** family as Actions, for visual consistency with the rest of the neutral UI (the locked-badge already sits inline with action icons; a different palette there would look like a mismatched import).

**Naming**: `icon_card_[name].png` (#12) / `icon_system_[name].png` (#13–15) → `assets/ui/icons/`.

---

## ASSET-012 — Card-category — `icon_card_category.png`
**Concept clarified 2026-07-11 (v4)** — v3 fixed the document-read (clean stacked rounded-corner cards, no fold) but the blank face reads a little empty. Added a small centered accent: a two-way chevron (`«` `»`), echoing the actual swipe-decision indicators already used on card option labels (`card_screen.gd`) — reinforces "this is a decision card" using an existing game motif rather than an invented symbol. No suit pip (still no card-suit mechanic).
> A 2D video game UI icon of two stacked playing cards with rounded corners and a portrait aspect ratio (like a tarot or UNO card, taller than wide), plain card faces with no folded corner, the front card has a small centered two-way chevron symbol (pointing left and right, like « »), low-resolution 32×32 pixel art style, retro 8-bit game asset. Monochromatic pale lavender-blue color palette with thick dark indigo bold outlines. Flat solid color fill, no shading, no highlights, no gloss. Isolated on a solid flat magenta (#FF00FF) background, minimalist design, highly readable for mobile games.

## ASSET-013 — Locked — `icon_system_locked.png`
Padlock, closed U-shaped shackle only, NO keyhole (1-cutout rule — the shackle gap is the only cutout).
> A 2D video game UI icon of a padlock with a closed U-shaped shackle, no keyhole detail, low-resolution 32×32 pixel art style, retro 8-bit game asset. Monochromatic pale lavender-blue color palette with thick dark indigo bold outlines. Flat solid color fill, no shading, no highlights, no gloss. Isolated on a solid flat magenta (#FF00FF) background, minimalist design, highly readable for mobile games.

## ASSET-014 — Settings — `icon_system_settings.png`
Single gear, 6 teeth max.
> A 2D video game UI icon of a single mechanical gear with exactly 6 teeth, low-resolution 32×32 pixel art style, retro 8-bit game asset. Monochromatic pale lavender-blue color palette with thick dark indigo bold outlines. Flat solid color fill, no shading, no highlights, no gloss. Isolated on a solid flat magenta (#FF00FF) background, minimalist design, highly readable for mobile games.

## ASSET-015 — Avatar placeholder — `icon_system_avatar.png`
Bare circle chip, NO glyph inside — per art-bible §5/§7 the silhouette itself is the signifier (this is the one node in the vocabulary reserved for future cosmetic layering — accessory/hat/frame color — never a face). **No Nano Banana generation needed** — this is a single flat circle + outline, faster to draw directly in Aseprite than to round-trip through AI generation and cleanup.
Direct Aseprite spec: 32×32 circle, ~90% frame diameter, pale lavender-blue fill (`#C9C6E8`-family, match the Actions fill), dark indigo outline, no interior content.

---

## Production checklist
1. ASSET-012–014: copy prompt → Nano Banana → Aseprite cleanup (same as Wave 1: Nearest Neighbor downscale, quantize to 2 colors, magenta key, simplify)
2. ASSET-015: draw directly in Aseprite, no generation step
3. Export PNG → `assets/ui/icons/[name].png`; save `.ase` → `assets/_source/icons/`
4. Wire into `action_grid.gd` (locked badge — replaces existing 16×16 `icon_locked.png` reference), settings screen (when built), avatar chip (when built), card modal header (when built) — check which are actually wired into a scene yet vs. still pending UI construction before treating "Done" as visually confirmed
