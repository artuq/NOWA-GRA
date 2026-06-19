# Godot — Deprecated APIs (4.3 → 4.6.3)

<!-- Last verified: 2026-06-19 -->
<!-- "Don't use X -> Use Y" reference for agents writing GDScript in this project. -->

| Deprecated | Since | Use Instead | Notes |
|---|---|---|---|
| `SkeletonIK3D` | 4.4 | New procedural animation node / 4.6's modular IK framework | Not relevant to this 2D idle project — listed for completeness |
| `object_cast_to` (GDExtension) | 4.6 | `is_class` casts | Only relevant if/when native GDExtension code is added — see `godot-gdextension-specialist` |
| `classdb_get_class_tag` (GDExtension) | 4.6 | `is_class` casts | Same as above — GDExtension only |
| Legacy Android OBB export | 4.7 (removal) | Play Asset Delivery or PCK split | Must confirm Android export pipeline doesn't rely on OBB before any future upgrade past 4.6.x |

## Notes for this project

This project is GDScript-only, 2D, mobile-targeted — most of Godot's
deprecated APIs since 4.3 are in 3D/physics/GDExtension areas that don't apply
here. The one item to actively watch is the **Android OBB export deprecation**
landing in 4.7, since this project ships to Android — confirm export settings
use a modern delivery method before any future engine version bump.

## Sources

- [Upgrading from Godot 4.5 to Godot 4.6 — official docs](https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html)
- [Godot 4.x Breaking Compatibility changes (community gist)](https://gist.github.com/raulsntos/06ac5dd10ebccc3a4f1e7e3ad30dc876)
