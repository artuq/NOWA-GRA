# Standing Smoke Test Checklist

Checks that must be run as REAL headless (or editor) launches, not via GdUnit4
`scene_runner()` — `scene_runner` instances a scene as a *child* of a test
harness tree, never as the tree's own root, so any bug that only manifests
when a scene IS the live Main Scene is invisible to the automated suite no
matter how much coverage exists. These are permanent manual/launch-time checks,
re-run whenever boot-sequence code changes.

## Cold-start boot flow (added 2026-06-29, Offline Report Screen Story 003)

**Why this can't be a unit/integration test**: `BootController.boot_with()` is
fully unit-tested (see `tests/integration/offline_report/boot_flow_test.gd`),
but a real bug — `change_scene_to_file()` called synchronously from the Main
Scene's own `_ready()` erroring with "Parent node is busy adding/removing
children" — only reproduces when `boot.tscn` is the actual `run/main_scene`
mid-instantiation. Fixed via `.call_deferred()`; a future refactor that
removes the deferred call would keep the entire automated suite green while
reintroducing this crash.

**Check** (run via `godot --headless --path .` for ~3-4 seconds, then kill):
- [ ] **First session** (no `user://save.json`): cold start reaches `main.tscn`
  with no error in stdout/stderr.
- [ ] **Returning session, short gap** (`user://save.json` with `last_saved_at`
  < 5 minutes ago): cold start reaches `main.tscn` directly, no report screen,
  no error.
- [ ] **Returning session, long gap** (`user://save.json` with `last_saved_at`
  ≥ 5 minutes ago, e.g. 2+ hours): cold start reaches `offline_report.tscn`,
  no error, and the report's hero number is non-zero if Haters > 0 at save time.

Verified 2026-06-29: all three pass after the `.call_deferred()` fix (empty
save, and a manually-injected 2-hour-old `save.json` at
`~/Library/Application Support/Godot/app_userdata/King of Cringe/save.json`
on macOS — path varies by platform, see Godot's `user://` docs).
