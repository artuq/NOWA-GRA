#!/usr/bin/env bash
# Persist a compact, file-backed checkpoint before Codex compacts context.

CCGS_HOOK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$CCGS_HOOK_DIR/hook-lib.sh"

ccgs_read_input
ccgs_enter_project || exit 0

CHECKPOINT="production/session-state/pre-compact.md"
mkdir -p "$(dirname "$CHECKPOINT")" 2>/dev/null
{
  echo "# CCGS pre-compaction checkpoint"
  echo
  echo "Generated: $(date)"
  echo
  if [ -f "production/session-state/active.md" ]; then
    echo "## Active session state"
    sed -n '1,160p' production/session-state/active.md
    echo
  fi
  echo "## Working tree paths"
  git status --short 2>/dev/null | sed -n '1,200p'
} > "${CHECKPOINT}.tmp" 2>/dev/null
mv "${CHECKPOINT}.tmp" "$CHECKPOINT" 2>/dev/null
mkdir -p production/session-logs 2>/dev/null
echo "Context compaction started at $(date)." >> production/session-logs/compaction-log.txt 2>/dev/null

printf '{"continue":true}\n'
exit 0
