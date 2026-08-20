# Technical Preferences

<!-- Populated by $setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6.3
- **Language**: GDScript
- **Rendering**: Godot 4 Forward+ (mobile renderer recommended for Android target — revisit in `$create-architecture`)
- **Physics**: Godot Physics (built-in)

## Input & Platform

<!-- Written by $setup-engine. Read by $ux-design, $ux-review, $test-setup, $team-ui, and $dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: Android + **Web (HTML5, portale typu CrazyGames)** — iOS poza zakresem (user decision, 2026-07-22; wcześniejsze "docelowo iOS" wycofane). Uwaga: eksport web w Godot 4.x wymaga renderera **Compatibility** (WebGL2), a projekt jedzie na Forward+ — przed pierwszym buildem web potrzebny spike walidacji renderera. Kandydaci backlogowi (Sprint 10): web-export spike, strategia aspect-ratio dla 16:9 iframe/fullscreen (portrait 720×1280 + canvas_items/expand), feel-test progu commitmentu swipe'a myszą. Haptyka (design idea) = tylko Android.
- **Input Methods**: Touch (mobile) + mysz przez `emulate_touch_from_mouse=true` (web — swipe działa, próg do feel-testu)
- **Primary Input**: Touch
- **Gamepad Support**: None
- **Touch Support**: Full
- **Platform Notes**: Wszystkie akcje podstawowe muszą działać przez duże, dotykowe obszary realizowane standardowym węzłem `Button` (otrzymuje syntezowane zdarzenia dotykowe project-wide), nie `TouchScreenButton` — to przestarzały węzeł `Node2D` niezintegrowany z układem/themingiem `Control` (per ADR-0007, engine-specialist 2026-06-24). Brak hover-only interakcji. **CrazyGames SDK v3 zintegrowany (2026-07-28)**: bootstrap w `export_presets.cfg` `html/head_include` (`window.kocSDK` — init + loadingStart/Stop + gameplayStart + happytime), wywołania z GDScript przez `JavaScriptBridge` gated na `OS.has_feature("web")`; wszystko no-op poza portalem (lokalny serwer/tunel działa identycznie). Monetyzacja: DECYZJA OTWARTA — obecnie zero adsów (portal rev-share only); rewarded ads wymagałyby rozszerzenia tej integracji + decyzji designowej (satyra vs hazard).

## Naming Conventions

- **Classes**: PascalCase (e.g., `PlayerController`)
- **Variables**: snake_case (e.g., `move_speed`)
- **Signals/Events**: snake_case past tense (e.g., `health_changed`)
- **Files**: snake_case matching class (e.g., `player_controller.gd`)
- **Scenes/Prefabs**: PascalCase matching root node (e.g., `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH`)

## Performance Budgets

- **Target Framerate**: 60fps
- **Frame Budget**: 16.6ms
- **Draw Calls**: ≤100 per frame (mobile budget — revisit after first profiling pass)
- **Memory Ceiling**: [TO BE CONFIGURED — set after first profiling pass on target Android hardware]

## Testing

- **Framework**: GdUnit4 (project addon under `addons/gdUnit4/`)
- **Minimum Coverage**: [TO BE CONFIGURED]
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use $architecture-decision to create one]

## Engine Specialists

<!-- Written by $setup-engine when engine is configured. -->
<!-- Read by $code-review, $architecture-decision, $architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
