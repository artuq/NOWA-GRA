#!/usr/bin/env bash
# Record successful compaction. SessionStart(source=compact) reloads active state.

CCGS_HOOK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$CCGS_HOOK_DIR/hook-lib.sh"

ccgs_read_input
ccgs_enter_project || exit 0
mkdir -p production/session-logs 2>/dev/null
echo "Context compaction completed at $(date)." >> production/session-logs/compaction-log.txt 2>/dev/null
printf '{"continue":true}\n'
exit 0
