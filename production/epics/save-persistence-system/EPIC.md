# Epic: Save/Persistence System

> **Layer**: Foundation
> **GDD**: design/gdd/save-persistence-system.md
> **Architecture Module**: SaveSystem
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories save-persistence-system`

## Overview

Implements the `SaveSystem` Autoload that owns all save-file I/O: a 2s
trailing-edge debounce on `mark_dirty()`, a mobile lifecycle flush (immediate
save on app background/suspend, bypassing the debounce window), and atomic
persistence via JSON written to `user://save.tmp` then renamed to
`user://save.json` via `DirAccess.rename_absolute()`. Includes a `schema_version`
field (increment-only) with corruption/mismatch falling back safely to
first-session defaults. This is the system every other Foundation/Core module's
`restore_state()` depends on at boot.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Autoload singleton architecture | `SaveSystem` is an Autoload; `mark_dirty()`/`save_now()`/`load_save()` interface locked | LOW |
| ADR-0002: Save file format and atomic write | JSON + temp-file-write-then-rename; schema_version; corruption fallback | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-save-001 | Autoload-owned save I/O with mark_dirty/save_now/load_save interface | ADR-0001, ADR-0002 ✅ |
| TR-save-002 | Atomic write via temp-file write then rename, surviving process kill | ADR-0002 ✅ |
| TR-save-003 | schema_version field with corruption/mismatch first-session fallback | ADR-0002 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/save-persistence-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories save-persistence-system` to break this epic into implementable stories.
