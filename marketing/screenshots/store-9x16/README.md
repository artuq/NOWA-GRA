# Store screenshots — 9:16

- Format: PNG
- Resolution: 1080×1920
- Source: real Godot scenes rendered from isolated marketing-only runtime state
- Promotional slogans are filenames only; they are not baked into the artwork
- Player save is not modified

## Mini-game captures

The set also includes six real in-game captures from the two optional card
mini-games:

- `Mini Game - Feed Sprint Card.png`
- `Mini Game - Feed Sprint - Catch the Trend.png`
- `Mini Game - Feed Sprint - Dodge the Strike.png`
- `Mini Game - Comment Moderation Card.png`
- `Mini Game - Comment Moderation - Keep or Delete.png`
- `Mini Game - Comment Moderation - Correct Call.png`

## Current-build substitutions

These captures show only features that exist in the current build. Four requested
concepts do not yet have their final dedicated presentation, so the closest
truthful in-game surface is used:

- `Rule the Algorithm.png` — Permanent Bonuses panel; the Algorithm Contract UI
  is designed but not implemented yet.
- `Embrace the Cringe.png` — max-Cringe main screen; outfit/customization is not
  implemented yet.
- `From Empty Pub to Stardom.png` — fresh-career main screen; evolving room/studio
  backgrounds and a before/after collage are not implemented yet.
- `Unlock Satirical Eras.png` — Permanent Bonuses/Era count; a dedicated
  Prestige/Checkpoint presentation is not currently available.

## Reproduction

The capture harness is `res://tools/marketing_capture.tscn`. Run it in a 1080×1920
Godot window. It overwrites this set deterministically and uses
`user://save.marketing-capture.json`, never the normal player save.
