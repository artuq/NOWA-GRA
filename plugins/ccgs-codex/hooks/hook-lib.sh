#!/usr/bin/env bash

# Shared helpers for CCGS Codex command hooks.

ccgs_read_input() {
  CCGS_HOOK_INPUT=$(cat)
}

ccgs_json_get() {
  local path="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$CCGS_HOOK_INPUT" | jq -r "${path} // empty" 2>/dev/null
    return
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$CCGS_HOOK_INPUT" | python3 -c '
import json, sys
try:
    value = json.load(sys.stdin)
    for key in sys.argv[1].lstrip(".").split("."):
        value = value[key]
    if value is not None:
        print(value)
except Exception:
    pass
' "$path" 2>/dev/null
  fi
}

ccgs_enter_project() {
  local hook_cwd
  hook_cwd=$(ccgs_json_get '.cwd')
  if [ -n "$hook_cwd" ] && [ -d "$hook_cwd" ]; then
    cd "$hook_cwd" || return 1
  fi
  CCGS_PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  cd "$CCGS_PROJECT_ROOT" || return 1
}

ccgs_context() {
  local event="$1"
  local message="$2"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json, sys
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": sys.argv[1], "additionalContext": sys.argv[2]
}}))
' "$event" "$message"
  elif command -v jq >/dev/null 2>&1; then
    jq -n --arg event "$event" --arg message "$message" \
      '{hookSpecificOutput:{hookEventName:$event,additionalContext:$message}}'
  fi
}

ccgs_block_post_tool() {
  local reason="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.dumps({"decision":"block","reason":sys.argv[1]}))' "$reason"
    return
  fi
  printf '%s\n' "$reason" >&2
  exit 2
}

ccgs_patch_paths() {
  local patch_command legacy_path
  patch_command=$(ccgs_json_get '.tool_input.command')
  legacy_path=$(ccgs_json_get '.tool_input.file_path')
  {
    printf '%s\n' "$patch_command" | sed -nE \
      -e 's/^\*\*\* (Add|Update|Delete) File: //p' \
      -e 's/^\*\*\* Move to: //p'
    [ -n "$legacy_path" ] && printf '%s\n' "$legacy_path"
  } | awk 'NF && !seen[$0]++'
}

ccgs_repo_relative_path() {
  local path="$1"
  path=$(printf '%s' "$path" | sed 's|\\|/|g')
  case "$path" in
    "$CCGS_PROJECT_ROOT"/*) printf '%s\n' "${path#"$CCGS_PROJECT_ROOT"/}" ;;
    /*) return 1 ;;
    *) printf '%s\n' "${path#./}" ;;
  esac
}
