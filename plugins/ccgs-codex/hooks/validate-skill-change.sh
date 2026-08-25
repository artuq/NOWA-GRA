#!/usr/bin/env bash
# Codex PostToolUse hook: remind the model to validate modified skills.

CCGS_HOOK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$CCGS_HOOK_DIR/hook-lib.sh"

ccgs_read_input
ccgs_enter_project || exit 0

SKILL_NAMES=""
while IFS= read -r raw_path; do
  FILE_PATH=$(ccgs_repo_relative_path "$raw_path") || continue
  SKILL_NAME=$(printf '%s\n' "$FILE_PATH" | sed -nE \
    -e 's|^plugins/ccgs-codex/skills/([^/]+)/.*|\1|p' \
    -e 's|^\.agents/skills/([^/]+)/.*|\1|p' \
    -e 's|^\.codex/skills/([^/]+)/.*|\1|p')
  if [ -n "$SKILL_NAME" ]; then
    SKILL_NAMES=$(printf '%s\n%s\n' "$SKILL_NAMES" "$SKILL_NAME" | awk 'NF && !seen[$0]++')
  fi
done <<EOF
$(ccgs_patch_paths)
EOF

if [ -n "$SKILL_NAMES" ]; then
  COMMANDS=$(printf '%s\n' "$SKILL_NAMES" | while IFS= read -r name; do
    printf '$skill-test static %s\n' "$name"
  done)
  ccgs_context "PostToolUse" "CCGS skill files changed. Validate them before finishing:\n${COMMANDS}"
fi

exit 0
