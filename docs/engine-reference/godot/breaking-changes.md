# Godot — Breaking Changes (4.3 → 4.6.3)

<!-- Last verified: 2026-06-19 -->
<!-- Project is pinned to Godot 4.6.3. LLM training data covers up to ~4.3. -->
<!-- This file covers breaking changes introduced in 4.4, 4.5, and 4.6 that an LLM trained -->
<!-- on pre-4.4 Godot would not know about. -->

## Godot 4.4

- **C# / .NET**: Minimum required .NET version raised to **.NET 8**. Projects opened
  in 4.4 are auto-upgraded; projects that stay on older Godot releases keep targeting .NET 6.
  Not relevant for this project (GDScript-only), but relevant if C# is added later.
- **Physics**: Jolt Physics is now integrated directly into the engine core (previously
  an addon). Existing physics code using GodotPhysics should still work, but new projects
  should consider Jolt for 3D.
- **Animation**: `SkeletonIK3D` is deprecated in favor of a new procedural animation node
  (continues into 4.6's modular IK framework).

## Godot 4.5

- See official migration guide for the full breaking-change list (link below). No
  GDScript-breaking API removals were reported as critical for typical 2D/UI-driven
  idle games like this project's.

## Godot 4.6

- **Glow post-processing**: Changed to use screen blending mode and now happens
  *before* tone-mapping. Significantly faster on mobile — relevant since this
  project targets Android. If glow is used for "soczystość" (juice) effects on
  action-completion feedback, re-tune glow intensity after implementing — old
  tuning values from pre-4.6 tutorials will look different.
- **GLSL shaders**: Built-in `SceneData` uniform's `view_matrix` and `inv_view_matrix`
  changed from `mat4` to `mat3x4`. Any custom shader using these requires matrix
  transpose operation updates. Relevant only if custom shaders read view/inv-view matrices.
- **Physics**: Jolt Physics is now the **default** physics engine for new 3D
  projects (this project is 2D-only, so GodotPhysics 2D is unaffected).
- **Node identity**: Nodes now have a unique internal ID for reliable tracking across
  scene reorganization — does not require code changes, but worth knowing when
  debugging scene-tree refactors.

## Godot 4.7 (not yet pinned, future awareness)

- Shader preprocessor restrictions: some macro patterns valid in 4.6 will no longer
  compile in 4.7. Not relevant until project upgrades past 4.6.x.
- Android OBB support removed — if Android export pipeline ever uses legacy OBB,
  must migrate to Play Asset Delivery or PCK split before upgrading past 4.6.

## Sources

- [Upgrading from Godot 4.5 to Godot 4.6 — official docs](https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html)
- [Upgrading from Godot 4.4 to Godot 4.5 — official docs](https://docs.godotengine.org/en/4.5/tutorials/migrating/upgrading_to_godot_4.5.html)
- [4.5 -> 4.6 migration guide GLSL shader issue thread](https://github.com/godotengine/godot-docs/issues/11744)
- [Godot 4.6: What changes for you — GDQuest](https://www.gdquest.com/library/godot_4_6_workflow_changes/)
- [Godot 4.x Breaking Compatibility changes (community gist)](https://gist.github.com/raulsntos/06ac5dd10ebccc3a4f1e7e3ad30dc876)
