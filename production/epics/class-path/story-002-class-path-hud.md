# Story 002: Class Path HUD Indicator

> **Epic**: Class Path System
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: S (1–2h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-07-05

## Context

**GDD**: `design/quick-specs/class-path-system-2026-07-01.md`
**Requirements**: HUD indicator ACs (no TR-cps ID — HUD display spec is within quick-spec ACs, not a separate registered TR)
*(Requirement text: "A persistent HUD indicator shows the active path+tier label once Tier 1 is reached")*

**ADR Governing Implementation**: ADR-0010: Class Path System Architecture — Autoload, Signal Contract, and Multiplier Application
**ADR Decision Summary**: HUD widget reads from `ClassPathSystem.active_path_changed` and `tier_unlocked` signals. No HUD logic owns path state — display only; all state in ClassPathSystem.

**Secondary ADR**: ADR-0007: Action UI and Touch Input — `Button` control node required for all interactive elements; no `TouchScreenButton`; touch-compatible areas. HUD indicator is display-only (no interaction required), so Button is not needed — `Label` or `HBoxContainer` with `Label` is sufficient.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: All APIs (Control, Label, HBoxContainer, signal connection) are pre-4.3 stable. No post-cutoff APIs used.

**Control Manifest Rules (Presentation layer)**:
- Required: Presentation layer reads data — does not own it; signals for reactive updates; no direct game-state writes from UI code
- Forbidden: UI nodes modifying ClassPathSystem state; HUD owning any affiliation or tier state
- Guardrail: no new Autoload; HUD is a scene child, not singleton

**Note — Manifest Version**: control-manifest.md covers ADRs 0001–0006 (v2026-06-20). ADR-0010 post-dates the manifest. The manifest's Presentation rules above fully apply; ADR-0010 display rules are embedded in `## Implementation Notes` below.

**Depends on**: Story 001 (Class Path Core) must be DONE — ClassPathSystem signals must exist before HUD can connect to them.

---

## Acceptance Criteria

*From `design/quick-specs/class-path-system-2026-07-01.md`, MVP scope (HUD indicator only):*

- [ ] **GIVEN** no active path (Tier 0 on all paths), **THEN** HUD indicator is hidden / not visible
- [ ] **GIVEN** pato_streamer reaches Tier 1, **THEN** HUD indicator becomes visible with label showing the correct path name + tier (e.g., "Pato-Streamer T1" or equivalent English label)
- [ ] **GIVEN** active path changes (pato_streamer → guru_celebryta crosses Tier 1), **THEN** HUD indicator updates to show new active path without restart
- [ ] **GIVEN** active path advances to Tier 2, **THEN** HUD indicator updates tier display to "T2"
- [ ] HUD indicator displays in English — no Polish path names in the label text (path internal IDs may be Polish, display labels must be English)
- [ ] HUD indicator uses no moral framing in the label text — no "good", "bad", "evil" — only the archetype name + tier number
- [ ] HUD indicator is readable on mobile (minimum 14sp font size equivalent, sufficient contrast)

---

## Implementation Notes

*From ADR-0010 (primary), ADR-0007 (Button/touch rules — display-only exception):*

### Step 1: Create HUD widget scene

Create `src/ui/class_path_hud_indicator.gd` + `src/ui/ClassPathHudIndicator.tscn`.

Root node: `HBoxContainer` (or `PanelContainer` for background). Contains a `Label` for the path name + tier.

```gdscript
extends HBoxContainer

@onready var _label: Label = $Label

func _ready() -> void:
    hide()
    ClassPathSystem.active_path_changed.connect(_on_active_path_changed)
    ClassPathSystem.tier_unlocked.connect(_on_tier_unlocked)

func _on_active_path_changed(path_id: StringName) -> void:
    if path_id.is_empty():
        hide()
    else:
        _refresh_label()
        show()

func _on_tier_unlocked(_path_id: StringName, _tier: int) -> void:
    _refresh_label()

func _refresh_label() -> void:
    var path_id: StringName = ClassPathSystem.get_active_path()
    var tier: int = ClassPathSystem.get_tier(path_id)
    _label.text = _get_display_name(path_id) + " T" + str(tier)

func _get_display_name(path_id: StringName) -> String:
    match path_id:
        &"pato_streamer": return "Pato-Streamer"
        &"guru_celebryta": return "Guru Celeb"
        _: return str(path_id)  # fallback for future paths
```

### Step 2: Display name table

Display names must be English, no moral framing:
- `pato_streamer` → `"Pato-Streamer"`
- `guru_celebryta` → `"Guru Celeb"`

Do not use Polish display text. Do not add "evil", "good", "corrupt" or equivalent moral labels.

### Step 3: Add to main HUD scene

Add `ClassPathHudIndicator.tscn` as a child of the main HUD scene (the CanvasLayer or HUD root). Place in a top-corner position or equivalent — check `src/ui/` for the existing HUD container node name before placing.

The widget starts hidden (`hide()` in `_ready()`). It only becomes visible after `active_path_changed` fires with a non-empty path ID.

### Step 4: Font size / contrast (mobile)

Set `Label.theme_override_font_sizes/font_size` to a minimum of 18px (approx 14sp on 160dpi) or inherit from the global theme if the global theme already enforces mobile-readable sizes. Do not add a custom theme file — inherit from project theme.

### Step 5: Session state / restore

On `restore_state()` (boot), ClassPathSystem restores its state from save — `active_path_changed` will NOT re-fire for restored state (no signal on restore). To handle this, add a one-shot `call_deferred("_sync_on_ready")` at the end of `_ready()`:

```gdscript
func _ready() -> void:
    hide()
    ClassPathSystem.active_path_changed.connect(_on_active_path_changed)
    ClassPathSystem.tier_unlocked.connect(_on_tier_unlocked)
    call_deferred("_sync_on_ready")

func _sync_on_ready() -> void:
    var path_id: StringName = ClassPathSystem.get_active_path()
    _on_active_path_changed(path_id)
```

This handles the case where a returning player has a persisted active path — the HUD syncs on first frame without needing a re-emitted signal.

---

## Out of Scope

*Do NOT implement in this story:*

- Story 001 (Class Path Core): ClassPathSystem Autoload, affiliation logic, tier progression — must be DONE before this story begins
- Class Path Panel (full expanded path view) — Alpha scope
- Path choice UI (showing all 4 paths with affiliation bars) — Alpha scope
- Tap-to-expand interaction on the HUD indicator — not in MVP (display only)
- Animation on tier unlock (particle burst, badge flash) — Nice to have, separate story if scoped

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-8-2026-07-01.md`, section 8-3.*

Manual verification steps (Story Type: UI):

- **AC-1**: HUD hidden before Tier 1
  - Setup: fresh session, no card choices made
  - Verify: HUD indicator node is not visible in the HUD area
  - Pass condition: no path badge visible on screen in any corner

- **AC-2**: HUD appears after Tier 1 reached
  - Setup: resolve 5 pato_streamer-tagged cards (enough for T1 at CARD_AFFILIATION_PER_CHOICE=4.0 → 20.0 affiliation)
  - Verify: HUD indicator becomes visible and shows "Pato-Streamer T1" (or equivalent English label with T1)
  - Pass condition: badge visible, label contains path name and "T1" in English

- **AC-3**: HUD updates on tier advance
  - Setup: continue from AC-2; resolve enough additional pato_streamer cards to cross T2 (affiliation ≥ 40.0)
  - Verify: HUD indicator label updates to show "T2" without restarting
  - Pass condition: label changes to "Pato-Streamer T2" in the same session

- **AC-4**: HUD reflects path switch
  - Setup: pato_streamer at T1; resolve 5 guru_celebryta cards (guru crosses T1 with higher affiliation than pato)
  - Verify: HUD indicator label switches from pato_streamer name to guru_celebryta name
  - Pass condition: label now shows guru display name + tier; pato label is gone

- **AC-5**: English labels, no moral framing
  - Setup: any state where path indicator is visible
  - Verify: label text is English; does not contain Polish text; does not contain "evil", "good", "bad", "corrupt", or equivalent value judgment words
  - Pass condition: only English archetype name + "T[N]" visible

- **AC-6**: Mobile readability
  - Setup: any state where HUD indicator is visible, running on target Android device (or emulated at 360×800 or equivalent)
  - Verify: text is legible without zoom; sufficient contrast against background
  - Pass condition: text readable at arm's length on target device

- **AC-7**: Restore state — HUD shows on session restore
  - Setup: reach T1 on pato_streamer, save, quit, restart game
  - Verify: HUD indicator is visible immediately after load, showing correct path+tier
  - Pass condition: no need to make a new card choice for HUD to appear

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/story-class-path-hud-evidence.md` — manual walkthrough checklist with each AC above checked off, plus notes on mobile device tested
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Class Path Core) must be DONE — `ClassPathSystem.active_path_changed` and `ClassPathSystem.tier_unlocked` signals must exist
- Unlocks: None (last story in the class-path epic MVP scope)

## Completion Notes
**Completed**: 2026-07-05
**Criteria**: 6/7 passing manually + AC-4 deferred to unit coverage (path-switch logic tested in class_path_core_test.gd; impractical to trigger manually with 2 guru cards in the weighted pool)
**Deviations**: (1) AC-7 walkthrough found a real bug — ClassPathSystem was never wired into SaveSystem/BootController (Story 001 gap); fixed in save_system.gd + boot_controller.gd, regression 72/72 PASSED. (2) Display name changed mid-walkthrough: "Pato-Streamer" → "Trash Streamer" (user decision — Polish-only term meaningless to English audience). (3) PanelContainer root + %ClassPathLabel instead of story's HBoxContainer/$Label samples — matches ResourceHud convention.
**Test Evidence**: UI: production/qa/evidence/story-class-path-hud-evidence.md — EXECUTED, signed off. Follow-up: repeat AC-6 readability check on physical Android device before release gate.
**Code Review**: Skipped as standalone /code-review for widget files (display-only, 70 lines, reviewed directly in-session); Story 001 core files went through full /code-review earlier this session.
