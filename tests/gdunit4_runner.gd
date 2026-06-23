# Use addons/gdUnit4/runtest.sh directly instead of this script.
# Usage: addons/gdUnit4/runtest.sh -a tests/ --godot_binary /path/to/godot
#   (or: export GODOT_BIN=/path/to/godot first)
#
# This file previously loaded a nonexistent res://addons/gdunit4/GdUnitRunner.gd
# class — that API does not exist in real GdUnit4 (verified 2026-06-23 against
# the actual addon, v6.2.0-rc1). GdUnit4 ships its own CLI runner script
# instead; there is no public SceneTree-based runner class to load.
