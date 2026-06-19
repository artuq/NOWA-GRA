# Godot — Current Best Practices (since 4.3 training cutoff)

<!-- Last verified: 2026-06-19 -->
<!-- New features/practices introduced after the LLM's ~4.3 training cutoff that are -->
<!-- relevant to this project's GDScript / 2D / mobile scope. -->

## Mobile rendering

- Godot 4.6 reworked the **glow** post-processing effect specifically to be much
  faster on mobile (screen blend mode, applied before tone-mapping). For this
  project's "soczystość" (juice) feedback on action completion, prefer glow over
  heavier particle-based effects on Android — it's now cheap.
- Forward+ remains the renderer to evaluate first; for a 2D-only idle game, the
  Mobile renderer profile is also worth benchmarking once a vertical slice exists
  (decide in `/create-architecture`, not here).

## Physics

- Jolt is now the default physics engine for new **3D** projects in 4.6. This
  project is 2D-only, so GodotPhysics 2D continues to be the right choice —
  no action needed.

## Editor workflow (not code-relevant, but useful to know)

- 4.6 introduced a new "Modern" editor theme and made docks/panels freely
  rearrangeable. Nodes now carry a unique internal ID, making scene refactors
  safer to track. No GDScript changes required, but explains why scene-tree
  diffs may look different from pre-4.4 tutorials.

## Android export

- A companion app called **GABE** allows building Android projects with Gradle
  directly from an Android device — not required for this project's PC-based
  dev workflow, but worth knowing if remote/on-device builds become useful later.
- Watch the Android OBB export deprecation landing in 4.7 (see `deprecated-apis.md`)
  — confirm the export pipeline uses a modern delivery method.

## C# / GDExtension

- Not applicable — this project is GDScript-only (see `technical-preferences.md`).
  Listed here only because .NET 8 minimum (4.4) and GDExtension cast deprecations
  (4.6) would matter if the language choice changes later.

## Sources

- [Godot 4.6 Release: It's all about your flow](https://godotengine.org/releases/4.6/)
- [Godot 4.6: What changes for you — GDQuest](https://www.gdquest.com/library/godot_4_6_workflow_changes/)
- [Godot 4.6: What Shipped in the Final Release — Jettelly](https://jettelly.com/blog/godot-4-6-editor-improvements-workflow-changes-and-supporting-tools)
- [Godot 4.4, a unified experience](https://godotengine.org/releases/4.4/)
