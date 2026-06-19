# Godot — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | 4.6.3 |
| **Project Pinned** | 2026-06-19 |
| **LLM Knowledge Cutoff** | May 2025 |
| **Risk Level** | HIGH — version is beyond LLM training data (training covers up to ~4.3) |
| **Last Docs Verified** | 2026-06-19 |

## Post-Cutoff Version Timeline

| Version | Status relative to training cutoff | Key changes |
|---------|--------------------------------------|--------------|
| 4.3 | Within training data | Last version well-covered by LLM training |
| 4.4 | Beyond cutoff | .NET 8 minimum for C#, Jolt Physics integrated directly, SkeletonIK3D deprecated |
| 4.5 | Beyond cutoff | See `breaking-changes.md` |
| 4.6 | Beyond cutoff (pinned version) | Jolt Physics now default for new 3D projects, SSR rewrite, glow effect changed (mobile-faster, screen blend mode, pre-tonemap), GLSL `view_matrix`/`inv_view_matrix` changed from mat4 to mat3x4, new modular IK framework, LibGodot, Modern editor theme |
| 4.6.3 | Maintenance release | Bug fixes on top of 4.6 |

## Note

This engine version is beyond the LLM's training data. Engine specialist agents
MUST consult `breaking-changes.md` and `deprecated-apis.md` before suggesting
GDScript/shader code, and use WebSearch to verify any uncertain API.

Run `/setup-engine refresh` periodically to keep these docs current.

## Sources

- [Upgrading from Godot 4.5 to Godot 4.6 — official docs](https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html)
- [Upgrading from Godot 4.4 to Godot 4.5 — official docs](https://docs.godotengine.org/en/4.5/tutorials/migrating/upgrading_to_godot_4.5.html)
- [Godot 4.6 Release: It's all about your flow](https://godotengine.org/releases/4.6/)
- [Godot 4.4, a unified experience](https://godotengine.org/releases/4.4/)
- [Godot 4.x Breaking Compatibility changes (community gist)](https://gist.github.com/raulsntos/06ac5dd10ebccc3a4f1e7e3ad30dc876)
