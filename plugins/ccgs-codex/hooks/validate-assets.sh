#!/usr/bin/env bash
# Codex PostToolUse hook: validate every asset path changed by apply_patch.

CCGS_HOOK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$CCGS_HOOK_DIR/hook-lib.sh"

ccgs_read_input
ccgs_enter_project || exit 0

WARNINGS=""
ERRORS=""
while IFS= read -r raw_path; do
  FILE_PATH=$(ccgs_repo_relative_path "$raw_path") || continue
  case "$FILE_PATH" in
    assets/*) ;;
    *) continue ;;
  esac

  FILENAME=$(basename "$FILE_PATH")
  if printf '%s' "$FILENAME" | grep -qE '[A-Z[:space:]-]'; then
    WARNINGS="${WARNINGS}NAMING: $FILE_PATH should use lowercase underscores.\n"
  fi

  case "$FILE_PATH" in
    assets/data/*.json)
      if [ -f "$FILE_PATH" ]; then
        if command -v python3 >/dev/null 2>&1; then
          if ! python3 -m json.tool "$FILE_PATH" >/dev/null 2>&1; then
            ERRORS="${ERRORS}FORMAT: $FILE_PATH is invalid JSON after apply_patch.\n"
          fi
        elif command -v jq >/dev/null 2>&1 && ! jq empty "$FILE_PATH" >/dev/null 2>&1; then
          ERRORS="${ERRORS}FORMAT: $FILE_PATH is invalid JSON after apply_patch.\n"
        fi
      fi
      ;;
  esac
done <<EOF
$(ccgs_patch_paths)
EOF

if [ -n "$ERRORS" ]; then
  ccgs_block_post_tool "Asset validation failed; the patch was already applied and must be repaired:\n${ERRORS}"
elif [ -n "$WARNINGS" ]; then
  ccgs_context "PostToolUse" "Asset validation warnings:\n${WARNINGS}"
fi

exit 0
